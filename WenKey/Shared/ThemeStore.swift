import UIKit

/// 键盘可调色的部位。容器 App 里调色（P4 做调色 UI），扩展实时读取。
public enum ThemePart: String, CaseIterable {
    /// 键盘整体背景。
    case keyboardBackground = "keyboardBackground"
    /// 普通字母键。
    case keyBackground = "keyBackground"
    /// 功能键（Shift、删除、切换、回车等）。
    case functionKeyBackground = "functionKeyBackground"
    /// 候选栏背景。
    case candidateBarBackground = "candidateBarBackground"
    /// 候选文字颜色。
    case candidateText = "candidateText"
    /// 按键文字颜色。
    case keyText = "keyText"
    /// 工具栏（候选栏右侧占位区）背景。
    case toolbarBackground = "toolbarBackground"

    /// 给容器 App 设置页用的中文名（不直接展示英文标识符）。
    var displayName: String {
        switch self {
        case .keyboardBackground: return "键盘背景"
        case .keyBackground: return "按键"
        case .functionKeyBackground: return "功能键"
        case .candidateBarBackground: return "候选栏"
        case .candidateText: return "候选文字"
        case .keyText: return "按键文字"
        case .toolbarBackground: return "工具栏"
        }
    }
}

/// 一套内置皮肤：名字 + 每个部位的十六进制颜色。全部内置，不做皮肤商城。
public struct ThemePreset {
    public let name: String
    public let colors: [ThemePart: String]

    public static let all: [ThemePreset] = [
        ThemePreset(name: "默认", colors: [
            .keyboardBackground: "#E8E8F0FF", .keyBackground: "#FFFFFFFF",
            .functionKeyBackground: "#C7C7D1FF", .candidateBarBackground: "#F5F5F7FF",
            .candidateText: "#000000FF", .keyText: "#000000FF", .toolbarBackground: "#F5F5F7FF",
        ]),
        ThemePreset(name: "粉嫩通透", colors: [
            .keyboardBackground: "#FFD6E8B3", .keyBackground: "#FFFFFFCC",
            .functionKeyBackground: "#FFB3D1CC", .candidateBarBackground: "#FFF0F5CC",
            .candidateText: "#7A2E4DFF", .keyText: "#5C2340FF", .toolbarBackground: "#FFF0F5CC",
        ]),
        ThemePreset(name: "蓝色清透", colors: [
            .keyboardBackground: "#C7E3FFB3", .keyBackground: "#FFFFFFCC",
            .functionKeyBackground: "#9CC8FFCC", .candidateBarBackground: "#EAF4FFCC",
            .candidateText: "#1A4A7AFF", .keyText: "#16365CFF", .toolbarBackground: "#EAF4FFCC",
        ]),
        ThemePreset(name: "暖橙", colors: [
            .keyboardBackground: "#FFE0BFB3", .keyBackground: "#FFFFFFCC",
            .functionKeyBackground: "#FFC79ACC", .candidateBarBackground: "#FFF3E8CC",
            .candidateText: "#7A3E12FF", .keyText: "#5C2E0DFF", .toolbarBackground: "#FFF3E8CC",
        ]),
        ThemePreset(name: "墨绿", colors: [
            .keyboardBackground: "#C8E6D0B3", .keyBackground: "#FFFFFFCC",
            .functionKeyBackground: "#9CCFAECC", .candidateBarBackground: "#EDF7F0CC",
            .candidateText: "#1E4D33FF", .keyText: "#143826FF", .toolbarBackground: "#EDF7F0CC",
        ]),
        ThemePreset(name: "深夜", colors: [
            .keyboardBackground: "#1C1C28FF", .keyBackground: "#3A3A4DFF",
            .functionKeyBackground: "#55556EFF", .candidateBarBackground: "#262633FF",
            .candidateText: "#FFFFFFFF", .keyText: "#FFFFFFFF", .toolbarBackground: "#262633FF",
        ]),
    ]
}

/// 分部位主题颜色存取，走 App Group 的 UserDefaults，容器 App 与扩展共用。
/// 颜色以 #RRGGBB / #RRGGBBAA 十六进制字符串存储。
/// 注意：App Group 需在开发者账号里开通并签名一致，否则 `UserDefaults(suiteName:)`
/// 返回 nil，此时自动回落到标准 UserDefaults（仅本进程内可见），扩展与 App 无法同步。
public final class ThemeStore {
    public static let shared = ThemeStore()

    private let defaults: UserDefaults
    private let keyPrefix = "wenkey.theme."

    private init() {
        if let shared = UserDefaults(suiteName: WenKeyConstants.appGroupID) {
            self.defaults = shared
        } else {
            // App Group 未配置时的回落：不崩溃，但跨进程同步失效。
            self.defaults = .standard
        }
    }

    /// 读取某部位的颜色，未设置时返回 P0 默认值。
    public func color(for part: ThemePart) -> UIColor {
        if let hex = defaults.string(forKey: keyPrefix + part.rawValue),
           let color = UIColor(wenKeyHex: hex) {
            return color
        }
        return Self.defaultColor(for: part)
    }

    /// 设置某部位的颜色（P4 调色 UI 调用）。
    public func setColor(_ color: UIColor, for part: ThemePart) {
        defaults.set(color.wenKeyHexString, forKey: keyPrefix + part.rawValue)
    }

    /// 一键换一套皮肤：把预设里每个部位的颜色全部写进去。
    public func applyPreset(_ preset: ThemePreset) {
        for (part, hex) in preset.colors {
            defaults.set(hex, forKey: keyPrefix + part.rawValue)
        }
    }

    /// 整体透明度：把键盘背景与按键的 alpha 统一改成给定值（0.5…1），
    /// 其它部位颜色不动。液态玻璃下半透明效果更明显。
    public func applyTransparency(_ alpha: CGFloat) {
        let clamped = max(0.5, min(1.0, alpha))
        for part in [ThemePart.keyboardBackground, .keyBackground, .functionKeyBackground, .candidateBarBackground] {
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, _a: CGFloat = 0
            color(for: part).getRed(&r, green: &g, blue: &b, alpha: &_a)
            let color = UIColor(red: r, green: g, blue: b, alpha: clamped)
            defaults.set(color.wenKeyHexString, forKey: keyPrefix + part.rawValue)
        }
    }

    /// P0 默认配色：浅灰底 + 白键 + 灰功能键（液态玻璃开启时按键底色会被玻璃效果覆盖，见 KeyboardViewController）。
    public static func defaultColor(for part: ThemePart) -> UIColor {
        switch part {
        case .keyboardBackground:
            return UIColor(red: 0.91, green: 0.91, blue: 0.94, alpha: 1)
        case .keyBackground:
            return .white
        case .functionKeyBackground:
            return UIColor(red: 0.78, green: 0.78, blue: 0.82, alpha: 1)
        case .candidateBarBackground:
            return UIColor(red: 0.96, green: 0.96, blue: 0.97, alpha: 1)
        case .candidateText:
            return .black
        case .keyText:
            return .black
        case .toolbarBackground:
            return UIColor(red: 0.96, green: 0.96, blue: 0.97, alpha: 1)
        }
    }
}

private extension UIColor {
    /// 解析 #RRGGBB 或 #RRGGBBAA。
    convenience init?(wenKeyHex hex: String) {
        var cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("#") { cleaned.removeFirst() }
        guard cleaned.count == 6 || cleaned.count == 8,
              let value = UInt64(cleaned, radix: 16) else { return nil }
        if cleaned.count == 6 {
            let r = CGFloat((value >> 16) & 0xFF) / 255
            let g = CGFloat((value >> 8) & 0xFF) / 255
            let b = CGFloat(value & 0xFF) / 255
            self.init(red: r, green: g, blue: b, alpha: 1)
        } else {
            let r = CGFloat((value >> 24) & 0xFF) / 255
            let g = CGFloat((value >> 16) & 0xFF) / 255
            let b = CGFloat((value >> 8) & 0xFF) / 255
            let a = CGFloat(value & 0xFF) / 255
            self.init(red: r, green: g, blue: b, alpha: a)
        }
    }

    /// 输出 #RRGGBBAA。
    var wenKeyHexString: String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "#%02X%02X%02X%02X",
                      Int(round(r * 255)), Int(round(g * 255)),
                      Int(round(b * 255)), Int(round(a * 255)))
    }
}
