import Foundation

/// 英文滑行输入的词匹配（P1）。
///
/// 词表是内置常用英文词小表，按常用程度粗排（并列时取靠前的词）。
/// 这只是滑行匹配用，不是 P2 的英文纠错联想词库：P2 会扩词库、加纠错与联想，
/// 到时这个小表可以被更大的词库取代，匹配规则不变。
/// 注意：词表只有小写无撇号词；缩写（如 don't）滑不出来，点按输入。
enum EnglishGlideMatcher {
    static let words: [String] = [
        "the", "of", "and", "to", "in", "is", "you", "that", "it", "he",
        "was", "for", "on", "are", "as", "with", "his", "they", "at", "be",
        "this", "have", "from", "or", "one", "had", "by", "but", "not", "what",
        "all", "were", "we", "when", "your", "can", "said", "there", "use", "an",
        "each", "which", "she", "do", "how", "their", "if", "will", "up", "other",
        "about", "out", "many", "then", "them", "these", "so", "some", "her", "would",
        "make", "like", "him", "into", "time", "has", "look", "two", "more", "write",
        "go", "see", "number", "no", "way", "could", "people", "my", "than", "first",
        "water", "been", "call", "who", "oil", "its", "now", "find", "long", "down",
        "day", "did", "get", "come", "made", "may", "part", "over", "new", "sound",
        "take", "only", "little", "work", "know", "place", "year", "live", "me", "back",
        "give", "most", "very", "after", "thing", "our", "just", "name", "good", "sentence",
        "man", "think", "say", "great", "where", "help", "through", "much", "before", "line",
        "right", "too", "mean", "old", "any", "same", "tell", "boy", "follow", "came",
        "want", "show", "also", "around", "form", "three", "small", "set", "put", "end",
        "does", "another", "well", "large", "must", "big", "even", "such", "because", "turn",
        "here", "why", "ask", "went", "men", "read", "need", "land", "different", "home",
        "us", "move", "try", "kind", "hand", "picture", "again", "change", "off", "play",
        "spell", "air", "away", "animal", "house", "point", "page", "letter", "mother", "answer",
        "found", "study", "still", "learn", "should", "world", "high", "every", "near", "add",
        "food", "between", "own", "below", "country", "plant", "last", "school", "father", "keep",
        "tree", "never", "start", "city", "earth", "eye", "light", "thought", "head", "under",
        "story", "saw", "left", "few", "while", "along", "might", "close", "something", "seem",
        "next", "hard", "open", "example", "begin", "life", "always", "those", "both", "paper",
        "together", "got", "group", "often", "run", "dog", "horse", "cat", "bird",
        "fish", "book", "table", "chair", "door", "window", "fire", "sun", "moon",
        "star", "night", "morning", "evening", "today", "tomorrow", "yesterday", "week", "month", "woman",
        "child", "friend", "family", "money", "love", "happy", "bad", "young", "hot",
        "cold", "warm", "cool", "fast", "slow", "easy", "true", "false", "yes", "please",
        "thank", "sorry", "hello", "hi", "bye", "ok", "really", "already", "either", "neither",
        "none", "possible", "necessary", "free", "busy", "ready", "sure", "careful", "quick", "strong",
        "weak", "rich", "poor", "full", "empty", "closed", "safe", "apple", "google", "phone",
        "computer", "internet", "email", "message", "photo", "video", "music", "game", "movie", "car",
        "bus", "train", "plane", "bike", "road", "street", "park", "store", "shop",
        "market", "bank", "hotel", "coffee", "tea", "milk", "bread", "rice", "meat",
        "fruit", "banana", "orange", "sad", "angry", "tired", "hungry", "sick", "beautiful",
        "pretty", "clean", "dirty", "difficult", "important",
    ]

    /// 滑行轨迹 → 最佳匹配词；无合适匹配时返回 nil（不插入任何内容）。
    ///
    /// 规则：轨迹先去连续重复字母；首尾字母必须与词的首尾一致；
    /// 轨迹与词的最长公共子序列长度至少为轨迹长度减一（允许滑过一个无关字母）；
    /// 并列时取词表靠前的常用词。
    static func bestMatch(for path: [String]) -> String? {
        let collapsed = collapse(path)
        guard collapsed.count >= 2,
              let first = collapsed.first,
              let last = collapsed.last else { return nil }
        var best: String?
        var bestScore = 0
        for word in words {
            guard let wordFirst = word.first, let wordLast = word.last,
                  String(wordFirst) == first, String(wordLast) == last else { continue }
            let score = lcsLength(collapsed, word.map { String($0) })
            if score > bestScore {
                bestScore = score
                best = word
            }
        }
        guard let match = best, bestScore >= collapsed.count - 1 else { return nil }
        return match
    }

    /// 去连续重复字母（如 h-e-l-l-o → h-e-l-o）。
    private static func collapse(_ path: [String]) -> [String] {
        var out: [String] = []
        for letter in path where out.last != letter {
            out.append(letter)
        }
        return out
    }

    /// 最长公共子序列长度（两行 DP；轨迹和词都很短，开销可忽略）。
    private static func lcsLength(_ a: [String], _ b: [String]) -> Int {
        var prev = Array(repeating: 0, count: b.count + 1)
        var curr = Array(repeating: 0, count: b.count + 1)
        for i in 1...a.count {
            for j in 1...b.count {
                curr[j] = (a[i - 1] == b[j - 1]) ? prev[j - 1] + 1 : max(prev[j], curr[j - 1])
            }
            prev = curr
        }
        return prev[b.count]
    }
}
