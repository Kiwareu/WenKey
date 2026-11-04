import Foundation

/// 常用语快捷输入的数据存取（P4 实现，P0 只留空壳）。
///
/// 数据形态：触发码 → 短语文本（比如打 dz 出地址），存在 App Group 共享区，
/// 与剪贴板放一起管理（DESIGN.md 补全功能一节）。
/// P4 的接法：`phrases()` 从共享区读全部常用语，`phrase(for:)` 供引擎
/// 在候选栏里匹配触发码，`save` / `delete` 供管理页增删。
public struct CommonPhrase {
    public let trigger: String
    public let text: String

    public init(trigger: String, text: String) {
        self.trigger = trigger
        self.text = text
    }
}

public final class CommonPhrasesStore {
    public static let shared = CommonPhrasesStore()

    private init() {}

    /// 全部常用语。P0 恒为空，P4 从共享区读取。
    public func phrases() -> [CommonPhrase] {
        return []
    }

    /// 按触发码查短语。P0 恒为 nil，P4 实现匹配。
    public func phrase(for trigger: String) -> String? {
        return nil
    }

    /// 新增或覆盖一条常用语。P0 占位，P4 写共享区。
    public func save(_ phrase: CommonPhrase) {
        // P4: 写入 App Group 共享区。
    }

    /// 按触发码删除一条常用语。P0 占位，P4 写共享区。
    public func delete(trigger: String) {
        // P4: 从 App Group 共享区删除。
    }
}
