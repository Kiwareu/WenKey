import Foundation

/// 剪贴板历史：分类 + 不限量（实际只做一个很宽的上限防存储爆炸，日常用不到）。
///
/// 存取走 App Group 共享区，容器 App 与键盘扩展共用；App Group 不可用时
/// 回落到标准 UserDefaults（仅本进程内可见），不崩溃。
/// 分类自动判定：链接 / 文本 / 其他；容器 App 里按分类过滤查看。
public enum ClipboardCategory: String, Codable, CaseIterable {
    case text = "text"
    case link = "link"
    case other = "other"

    public var displayName: String {
        switch self {
        case .text: return "文本"
        case .link: return "链接"
        case .other: return "其他"
        }
    }

    public static func category(for text: String) -> ClipboardCategory {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = trimmed.lowercased()
        if lower.hasPrefix("http://") || lower.hasPrefix("https://") || lower.hasPrefix("www.") {
            return .link
        }
        if trimmed.isEmpty {
            return .other
        }
        return .text
    }
}

public struct ClipboardItem: Codable, Equatable {
    public let id: UUID
    public let text: String
    public let category: ClipboardCategory
    public let date: Date

    public init(id: UUID = UUID(), text: String, category: ClipboardCategory, date: Date = Date()) {
        self.id = id
        self.text = text
        self.category = category
        self.date = date
    }
}

public final class ClipboardStore {
    public static let shared = ClipboardStore()

    private let defaults: UserDefaults
    private let key = "wenkey.clipboard.items"
    /// 防存储爆炸的宽上限，日常使用远达不到，效果上就是不限量。
    private let maxItems = 5000

    private init() {
        if let shared = UserDefaults(suiteName: WenKeyConstants.appGroupID) {
            self.defaults = shared
        } else {
            self.defaults = .standard
        }
    }

    public func items() -> [ClipboardItem] {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode([ClipboardItem].self, from: data) else {
            return []
        }
        return decoded
    }

    /// 新增一条；空文本、与最新一条完全相同的不重复记。返回是否真的记下了。
    @discardableResult
    public func add(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        var current = items()
        if current.first?.text == trimmed { return false }
        current.insert(ClipboardItem(text: trimmed, category: ClipboardCategory.category(for: trimmed)), at: 0)
        if current.count > maxItems {
            current = Array(current.prefix(maxItems))
        }
        save(current)
        return true
    }

    public func delete(id: UUID) {
        save(items().filter { $0.id != id })
    }

    public func clear() {
        save([])
    }

    private func save(_ items: [ClipboardItem]) {
        if let data = try? JSONEncoder().encode(items) {
            defaults.set(data, forKey: key)
        }
    }
}
