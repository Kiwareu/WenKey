import Foundation

/// 功能开关（P0 只留存取口，不做开关 UI、不改任何行为）。
///
/// 规则：所有 P1 及之后的功能默认全部关闭；功能实现后，设置页再接开关 UI，
/// 扩展侧读开关决定是否启用。开关存 App Group UserDefaults，容器 App 与扩展共用。
/// 未设置过的开关读出来就是 false（关闭），不需要预写默认值。
public enum FeatureFlag: String, CaseIterable {
    case glideTyping = "glideTyping"                    // P1 滑行输入（英文）
    case spaceCursor = "spaceCursor"                    // P1 空格光标
    case deleteSwipe = "deleteSwipe"                    // P1 删词滑动
    case longPressSymbols = "longPressSymbols"          // P1 长按符号
    case doubleSpacePeriod = "doubleSpacePeriod"        // P1 双击空格句号
    case autoCapitalization = "autoCapitalization"      // P1 英文句首自动大写
    case englishCorrection = "englishCorrection"        // P2 英文纠错联想
    case voiceInput = "voiceInput"                      // P3 离线语音
    case clipboard = "clipboard"                        // P4 剪贴板
    case commonPhrases = "commonPhrases"                // P4 常用语
    case numberRow = "numberRow"                        // P5 数字行（默认关）
    case oneHandedMode = "oneHandedMode"                // P5 单手模式
    case emojiSearch = "emojiSearch"                    // P5 表情搜索
    case keySound = "keySound"                          // P5 按键音
    case followSystemAppearance = "followSystemAppearance" // P5 跟随系统深浅色

    public var displayName: String {
        switch self {
        case .glideTyping: return "滑行输入"
        case .spaceCursor: return "空格光标"
        case .deleteSwipe: return "删词滑动"
        case .longPressSymbols: return "长按符号"
        case .doubleSpacePeriod: return "双击空格句号"
        case .autoCapitalization: return "英文句首自动大写"
        case .englishCorrection: return "英文纠错联想"
        case .voiceInput: return "离线语音"
        case .clipboard: return "剪贴板"
        case .commonPhrases: return "常用语"
        case .numberRow: return "数字行"
        case .oneHandedMode: return "单手模式"
        case .emojiSearch: return "表情搜索"
        case .keySound: return "按键音"
        case .followSystemAppearance: return "跟随系统深浅色"
        }
    }
}

public final class FeatureFlagStore {
    public static let shared = FeatureFlagStore()

    private let defaults: UserDefaults
    private let keyPrefix = "wenkey.flag."

    private init() {
        if let shared = UserDefaults(suiteName: WenKeyConstants.appGroupID) {
            self.defaults = shared
        } else {
            // App Group 未配置时的回落：不崩溃，但跨进程同步失效。
            self.defaults = .standard
        }
    }

    /// 开关是否打开。未设置过的一律读作 false（关闭）。
    public func isEnabled(_ flag: FeatureFlag) -> Bool {
        return defaults.bool(forKey: keyPrefix + flag.rawValue)
    }

    /// 设置开关（P1/P5 的设置页开关 UI 调用）。
    public func setEnabled(_ flag: FeatureFlag, _ enabled: Bool) {
        defaults.set(enabled, forKey: keyPrefix + flag.rawValue)
    }
}
