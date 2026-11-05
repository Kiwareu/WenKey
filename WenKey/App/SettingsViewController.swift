import UIKit

/// P0 容器 App 设置页：启用说明 + 当前状态展示。
/// 调色（P4）、剪贴板管理（P3）、词库与自学习管理（P1）都在后续阶段往这里加。
final class SettingsViewController: UIViewController {
    private let textView = UITextView()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "WenKey"
        view.backgroundColor = .systemBackground

        textView.isEditable = false
        textView.font = UIFont.systemFont(ofSize: 16)
        textView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(textView)
        NSLayoutConstraint.activate([
            textView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            textView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            textView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            textView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
        ])
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        textView.text = statusText()
    }

    private func statusText() -> String {
        let themeParts = ThemePart.allCases.map { $0.displayName }.joined(separator: "、")
        // 功能开关只读展示：P1 手势默认开，其余默认关；开关 UI 在 P5 接。
        let flagLines = FeatureFlag.allCases.map { flag in
            "· \(flag.displayName)：\(FeatureFlagStore.shared.isEnabled(flag) ? "开" : "关")"
        }.joined(separator: "\n")
        return """
        WenKey（个人 iOS 输入法，P0 骨架）

        启用方法：
        设置 → 通用 → 键盘 → 键盘 → 添加新键盘 → 选择 WenKey。
        之后在任意输入框长按地球键可切换到 WenKey。

        注意（P3 才相关）：
        剪贴板自动记录需要在这里手动打开“允许完全访问”，
        否则键盘扩展读不到系统剪贴板。这是苹果的限制，不是 bug。

        当前状态：
        · 内置词典：\(DictionaryData.entries.count) 条（词典 v\(WenKeyConstants.dictionaryVersion)）
        · 主题可调部位：\(themeParts)
        · App Group：\(WenKeyConstants.appGroupID)

        P0 已实现：键盘 UI、拼音整句联想、中英切换、Shift、删除、空格、回车。
        P1 已实现：滑行输入、空格光标、删词滑动、长按符号、双击空格句号、句首大写。
        后续阶段：P2 词库与自学习 + 英文纠错、P3 离线语音、
        P4 剪贴板 + 常用语、P5 主题与反馈 + 顺手功能。

        功能开关（P1 手势默认开，其余默认关，开关 UI 在 P5 接）：
        \(flagLines)
        """
    }
}
