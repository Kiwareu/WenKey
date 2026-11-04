import Foundation

/// 一条整句候选：中文文本 + 组成它的词 + 排序分（越高越靠前）。
public struct SentenceCandidate: Equatable {
    public let text: String
    public let words: [String]
    public let score: Double

    public init(text: String, words: [String], score: Double) {
        self.text = text
        self.words = words
        self.score = score
    }
}

/// 拼音引擎：整行拼音 → 音节切分 → 词典查词 → 整句候选排序。
///
/// 流程（对应 DESIGN.md）：
/// 1. 切分：动态规划把整行拼音切成合法音节序列，偏好“音节少、音节长”的切法，
///    保留前几名切法（因为同一串字母可能有多种切法，如 xian → xi'an / xian）。
/// 2. 组词：对每个切法再做一次 DP，用词典词覆盖音节序列，得到整句。
/// 3. 排序：log 词频占比之和 + 自学习提频 − 每多一个词的小惩罚。
///    注意 log 占比一定是负数：词越多、负项越多、分数越低，天然倾向长词、少断点；
///    这就是 P0 的“简单衔接分”。（如果直接对词频取 log，log 为正、词越多分越高，
///    单字组合会系统性打败整词——P0 验证时已踩过这个坑。）
///    P1 会换成真实二元衔接统计。
///
/// 限制（P0 已知，P1 解决）：
/// - 只能处理无声调全拼；ü 在输入里按 v 拼（nv、lv、nve、lve）。
/// - 词典未覆盖的冷僻音节没有单字可出，整句会出不来；此时键盘回落为原文上屏。
public final class PinyinEngine {

    /// 合法音节表（无声调全拼）。切分只认表里的音节。
    public static let validSyllables: Set<String> = [
        "a", "ai", "an", "ang", "ao",
        "ba", "bai", "ban", "bang", "bao", "bei", "ben", "beng", "bi", "bian", "biao", "bie", "bin", "bing", "bo", "bu",
        "ca", "cai", "can", "cang", "cao", "ce", "cen", "ceng", "cha", "chai", "chan", "chang", "chao", "che", "chen", "cheng", "chi", "chong", "chou", "chu", "chua", "chuai", "chuan", "chuang", "chui", "chun", "chuo", "ci", "cong", "cou", "cu", "cuan", "cui", "cun", "cuo",
        "da", "dai", "dan", "dang", "dao", "de", "dei", "den", "deng", "di", "dia", "dian", "diao", "die", "ding", "diu", "dong", "dou", "du", "duan", "dui", "dun", "duo",
        "e", "ei", "en", "eng", "er",
        "fa", "fan", "fang", "fei", "fen", "feng", "fo", "fou", "fu",
        "ga", "gai", "gan", "gang", "gao", "ge", "gei", "gen", "geng", "gong", "gou", "gu", "gua", "guai", "guan", "guang", "gui", "gun", "guo",
        "ha", "hai", "han", "hang", "hao", "he", "hei", "hen", "heng", "hong", "hou", "hu", "hua", "huai", "huan", "huang", "hui", "hun", "huo",
        "ji", "jia", "jian", "jiang", "jiao", "jie", "jin", "jing", "jiong", "jiu", "ju", "juan", "jue", "jun",
        "ka", "kai", "kan", "kang", "kao", "ke", "kei", "ken", "keng", "kong", "kou", "ku", "kua", "kuai", "kuan", "kuang", "kui", "kun", "kuo",
        "la", "lai", "lan", "lang", "lao", "le", "lei", "leng", "li", "lia", "lian", "liang", "liao", "lie", "lin", "ling", "liu", "long", "lou", "lu", "luan", "lue", "lun", "luo", "lv", "lve",
        "ma", "mai", "man", "mang", "mao", "me", "mei", "men", "meng", "mi", "mian", "miao", "mie", "min", "ming", "miu", "mo", "mou", "mu",
        "na", "nai", "nan", "nang", "nao", "ne", "nei", "nen", "neng", "ni", "nian", "niang", "niao", "nie", "nin", "ning", "niu", "nong", "nou", "nu", "nuan", "nue", "nun", "nuo", "nv", "nve",
        "o", "ou",
        "pa", "pai", "pan", "pang", "pao", "pei", "pen", "peng", "pi", "pian", "piao", "pie", "pin", "ping", "po", "pou", "pu",
        "qi", "qia", "qian", "qiang", "qiao", "qie", "qin", "qing", "qiong", "qiu", "qu", "quan", "que", "qun",
        "ran", "rang", "rao", "re", "ren", "reng", "ri", "rong", "rou", "ru", "ruan", "rui", "run", "ruo",
        "sa", "sai", "san", "sang", "sao", "se", "sen", "seng", "sha", "shai", "shan", "shang", "shao", "she", "shei", "shen", "sheng", "shi", "shou", "shu", "shua", "shuai", "shuan", "shuang", "shui", "shun", "shuo", "si", "song", "sou", "su", "suan", "sui", "sun", "suo",
        "ta", "tai", "tan", "tang", "tao", "te", "teng", "ti", "tian", "tiao", "tie", "ting", "tong", "tou", "tu", "tuan", "tui", "tun", "tuo",
        "wa", "wai", "wan", "wang", "wei", "wen", "weng", "wo", "wu",
        "xi", "xia", "xian", "xiang", "xiao", "xie", "xin", "xing", "xiong", "xiu", "xu", "xuan", "xue", "xun",
        "ya", "yan", "yang", "yao", "ye", "yi", "yin", "ying", "yo", "yong", "you", "yu", "yuan", "yue", "yun",
        "za", "zai", "zan", "zang", "zao", "ze", "zei", "zen", "zeng", "zha", "zhai", "zhan", "zhang", "zhao", "zhe", "zhen", "zheng", "zhi", "zhong", "zhou", "zhu", "zhua", "zhuai", "zhuan", "zhuang", "zhui", "zhun", "zhuo", "zi", "zong", "zou", "zu", "zuan", "zui", "zun", "zuo",
    ]

    /// 每步 DP 保留的候选数上限（防组合爆炸）。
    private static let beamWidth = 12
    /// 每步切分保留的切法数上限。
    static let segmentationLimit = 4
    /// 每多一个词的惩罚（倾向长词、少断点）。
    private static let perWordPenalty = 0.5

    private let wordsByFirstSyllable: [String: [DictionaryEntry]]
    private let totalFrequency: Double
    private let learning = UserLearningStore.shared

    public init() {
        let allEntries = DictionaryData.entries + learning.customWords()
        var index: [String: [DictionaryEntry]] = [:]
        var total = 0.0
        for entry in allEntries {
            total += Double(entry.frequency)
            guard let first = entry.pinyin.first else { continue }
            index[first, default: []].append(entry)
        }
        self.wordsByFirstSyllable = index
        self.totalFrequency = max(total, 1)
    }

    // MARK: - 对外接口

    /// 整行拼音的整句候选（按分数从高到低）。输入含非法字母或切不出合法音节时返回空数组。
    public func candidates(for input: String, limit: Int = 9) -> [SentenceCandidate] {
        let cleaned = input.lowercased().filter { $0.isLetter }
        guard !cleaned.isEmpty else { return [] }
        var merged: [String: SentenceCandidate] = [:]
        for segmentation in segmentations(for: cleaned) {
            for candidate in sentences(for: segmentation) {
                if let old = merged[candidate.text] {
                    if candidate.score > old.score { merged[candidate.text] = candidate }
                } else {
                    merged[candidate.text] = candidate
                }
            }
        }
        return merged.values.sorted { $0.score > $1.score }.prefix(limit).map { $0 }
    }

    /// 某个音节的单字候选（分词候选），按词频从高到低，去重。
    public func characterCandidates(for syllable: String, limit: Int = 9) -> [String] {
        let singles = (wordsByFirstSyllable[syllable] ?? []).filter {
            $0.pinyin.count == 1 && $0.text.count == 1
        }
        var seen: Set<String> = []
        var result: [String] = []
        for entry in singles.sorted(by: { $0.frequency > $1.frequency }) {
            if seen.insert(entry.text).inserted {
                result.append(entry.text)
            }
            if result.count >= limit { break }
        }
        return result
    }

    /// 整行拼音的前几种音节切法（供键盘取首音节做分词候选）。
    public func segmentations(for input: String, limit: Int = segmentationLimit) -> [[String]] {
        let chars = Array(input)
        let n = chars.count
        guard n > 0 else { return [] }
        // dp[i]：前缀 chars[0..<i] 的切法（切法，分数）。dp[i] 在处理到 i 时已完整，
        // 因为所有贡献都来自更小的位置。
        var dp: [[(segments: [String], score: Double)]] = Array(repeating: [], count: n + 1)
        dp[0] = [([], 0)]
        for i in 0..<n {
            dp[i] = topSegmentations(dp[i], limit: Self.beamWidth)
            guard !dp[i].isEmpty else { continue }
            for length in 1...6 {
                guard i + length <= n else { break }
                let syllable = String(chars[i..<i + length])
                guard Self.validSyllables.contains(syllable) else { continue }
                // 每多一个音节扣 10 分、音节越长加分越少扣：偏好“音节少、音节长”。
                let step = Double(length) - 10.0
                for entry in dp[i] {
                    dp[i + length].append((entry.segments + [syllable], entry.score + step))
                }
            }
        }
        return topSegmentations(dp[n], limit: limit).map { $0.segments }
    }

    // MARK: - 内部 DP

    /// 用词典词覆盖一个音节序列，得到整句候选。
    private func sentences(for syllables: [String]) -> [SentenceCandidate] {
        let n = syllables.count
        guard n > 0 else { return [] }
        // dp[i]：覆盖 syllables[0..<i] 的整句候选。
        var dp: [[SentenceCandidate]] = Array(repeating: [], count: n + 1)
        dp[0] = [SentenceCandidate(text: "", words: [], score: 0)]
        for i in 0..<n {
            dp[i] = topCandidates(dp[i], limit: Self.beamWidth)
            guard !dp[i].isEmpty else { continue }
            for entry in wordsByFirstSyllable[syllables[i]] ?? [] {
                let length = entry.pinyin.count
                guard i + length <= n else { continue }
                guard Array(syllables[i..<i + length]) == entry.pinyin else { continue }
                // log 词频占比（恒为负）：词越多分数越低，倾向长词、少断点。
                let wordScore = log(Double(entry.frequency) / totalFrequency)
                    + learning.boostedFrequency(for: entry.text)
                for prev in dp[i] {
                    let candidate = SentenceCandidate(
                        text: prev.text + entry.text,
                        words: prev.words + [entry.text],
                        score: prev.score + wordScore - Self.perWordPenalty
                    )
                    dp[i + length].append(candidate)
                }
            }
        }
        return topCandidates(dp[n], limit: Self.beamWidth).filter { !$0.text.isEmpty }
    }

    private func topSegmentations(
        _ list: [(segments: [String], score: Double)],
        limit: Int
    ) -> [(segments: [String], score: Double)] {
        return list.sorted { $0.score > $1.score }.prefix(limit).map { $0 }
    }

    private func topCandidates(_ list: [SentenceCandidate], limit: Int) -> [SentenceCandidate] {
        return list.sorted { $0.score > $1.score }.prefix(limit).map { $0 }
    }
}
