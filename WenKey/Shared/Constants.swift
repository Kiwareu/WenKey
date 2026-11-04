import Foundation

/// WenKey 全局常量。容器 App 与键盘扩展共用。
/// Bundle ID / App Group 如需改名，这里和工程设置、entitlements 要同步改。
public enum WenKeyConstants {
    /// 容器 App 的 Bundle ID。
    public static let appBundleID = "com.wenx.wenkey"
    /// 键盘扩展的 Bundle ID。
    public static let keyboardBundleID = "com.wenx.wenkey.keyboard"
    /// 容器 App 与扩展共享数据的 App Group。
    public static let appGroupID = "group.com.wenx.wenkey"
    /// 当前词典数据版本（P1 扩词库时递增）。
    public static let dictionaryVersion = 1
}
