import Foundation

/// 用户自学习词频存取。
///
/// P0 状态：空壳。`recordSelection` 现在只做内存记录（不落盘、不影响排序），
/// `boostedFrequency` 恒返回 0，`customWords` 恒返回空数组。
/// P1 再填：把选词记录写进 App Group 共享区，引擎排序时按提频加权，并支持用户自定义词。
public final class UserLearningStore {
    public static let shared = UserLearningStore()

    private init() {}

    /// 用户在候选栏点选了一个候选词。P0 仅占位，P1 落盘。
    public func recordSelection(_ text: String) {
        // P1: 写入 App Group 共享区（选词计数 + 组词计数），供引擎提频。
    }

    /// 该词因用户自学习获得的额外频次加权。P0 恒为 0。
    public func boostedFrequency(for text: String) -> Double {
        return 0
    }

    /// 用户自定义词。P0 恒为空，P1 从共享区读取。
    public func customWords() -> [DictionaryEntry] {
        return []
    }
}
