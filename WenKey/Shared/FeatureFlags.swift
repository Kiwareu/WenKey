import Foundation

/// 功能开关（存取口已通；开关 UI 在 P5 接）。
///
/// 默认规则：P1 核心手势默认开——用户明确要做且尚无开关 UI，关了等于 P1 白做；
/// P5 顺手功能默认关（默认不打扰）。一旦用户在设置页改过，以用户设置为准。
/// 未设置过的开关读出来就是默认值，不需要预写。
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

    /// P1 核心手势默认开，P5 顺手功能默认关；用户改过之后以用户设置为准。
    public var defaultEnabled: Bool {
        switch self {
        case .glideTyping, .spaceCursor, .deleteSwipe,
             .longPressSymbols, .doubleSpacePeriod, .autoCapitalization:
            return true
        default:
            return false
        }
    }

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

    /// 开关是否打开。未设置过的读默认值（P1 核心手势默认开，P5 默认关）。
    public func isEnabled(_ flag: FeatureFlag) -> Bool {
        let key = keyPrefix + flag.rawValue
        if defaults.object(forKey: key) == nil {
            return flag.defaultEnabled
        }
        return defaults.bool(forKey: key)
    }

    /// 设置开关（P1/P5 的设置页开关 UI 调用）。
    public func setEnabled(_ flag: FeatureFlag, _ enabled: Bool) {
        defaults.set(enabled, forKey: keyPrefix + flag.rawValue)
    }
}
