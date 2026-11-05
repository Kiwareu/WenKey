import Foundation

/// 常用语快捷输入的数据存取：触发码 → 短语文本（比如打 dz 出地址）。
///
/// 存取走 App Group 共享区，容器 App 与键盘扩展共用；App Group 不可用时
/// 回落到标准 UserDefaults（仅本进程内可见），不崩溃。
public struct CommonPhrase: Codable, Equatable {
    public let trigger: String
    public let text: String

    public init(trigger: String, text: String) {
        self.trigger = trigger
        self.text = text
    }
}

public final class CommonPhrasesStore {
    public static let shared = CommonPhrasesStore()

    private let defaults: UserDefaults
    private let key = "wenkey.phrases"

    private init() {
        if let shared = UserDefaults(suiteName: WenKeyConstants.appGroupID) {
            self.defaults = shared
        } else {
            self.defaults = .standard
        }
    }

    /// 全部常用语，按触发码排序。
    public func phrases() -> [CommonPhrase] {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode([CommonPhrase].self, from: data) else {
            return []
        }
        return decoded.sorted { $0.trigger < $1.trigger }
    }

    /// 按触发码查短语。
    public func phrase(for trigger: String) -> String? {
        return phrases().first { $0.trigger == trigger }?.text
    }

    /// 新增或覆盖一条常用语。触发码或短语为空时不写。
    public func save(_ phrase: CommonPhrase) {
        let trigger = phrase.trigger.trimmingCharacters(in: .whitespacesAndNewlines)
        let text = phrase.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trigger.isEmpty, !text.isEmpty else { return }
        var current = phrases().filter { $0.trigger != trigger }
        current.append(CommonPhrase(trigger: trigger, text: text))
        if let data = try? JSONEncoder().encode(current) {
            defaults.set(data, forKey: key)
        }
    }

    /// 按触发码删除一条常用语。
    public func delete(trigger: String) {
        let current = phrases().filter { $0.trigger != trigger }
        if let data = try? JSONEncoder().encode(current) {
            defaults.set(data, forKey: key)
        }
    }
}
