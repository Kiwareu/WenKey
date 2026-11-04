import UIKit

/// WenKey 键盘扩展主控制器（P0）。
///
/// 支持：26 键 QWERTY、拼音模式（按键显示大写字母）与英文模式切换、
/// 整行拼音整句候选、删除 / 空格 / 回车 / Shift、中英文切换。
/// 占位（P2/P3 再实现，按钮已置灰禁用，不冒充功能）：语音、剪贴板。
/// 外观：连续圆角大圆角按键；iOS 26 用液态玻璃（UIGlassEffect），低版本回落纯色。
final class KeyboardViewController: UIInputViewController {

    // MARK: - 状态

    private enum Mode {
        case chinese
        case english
    }

    private enum ShiftState {
        case off
        case on
        case capsLock
    }

    private var mode: Mode = .chinese
    private var shiftState: ShiftState = .off
    private var lastShiftTapTime: Date?

    /// P1 手势扩展口：P0 不赋值，不挂任何手势识别器。
    /// P1 实现 KeyboardGestureHandler 并赋值后，再给空格键、删除键、字母键挂手势。
    var gestureHandler: KeyboardGestureHandler?
    /// 当前正在拼的拼音字母（小写）。中文模式专用。
    private var pinyinBuffer = ""
    private var sentenceCandidates: [SentenceCandidate] = []
    private var charCandidates: [String] = []
    /// 当前切法的首选分词（用于分词候选点选后保留剩余音节）。
    private var currentSegmentation: [String] = []

    private let engine = PinyinEngine()
    private let theme = ThemeStore.shared
    private let keyHaptic = UIImpactFeedbackGenerator(style: .light)
    private let selectionHaptic = UISelectionFeedbackGenerator()

    // MARK: - UI

    private let rootStack = UIStackView()
    private let candidateScrollView = UIScrollView()
    private let candidateStack = UIStackView()
    private var letterButtons: [(letter: String, button: KeyButton)] = []
    private var functionButtons: [KeyButton] = []
    private var shiftButton: KeyButton!
    private var modeButton: KeyButton!
    /// 存为属性供 P1 挂手势用：空格键（长按变触控板）、删除键（左滑批量删词）。
    private var spaceButton: KeyButton!
    private var deleteButton: KeyButton!

    private let letterRows = ["qwertyuiop", "asdfghjkl", "zxcvbnm"]

    override func viewDidLoad() {
        super.viewDidLoad()
        keyHaptic.prepare()
        buildUI()
        applyTheme()
        refreshKeyTitles()
        refreshCandidates()
        // 键盘固定高度：候选栏 44 + 4 行 × 52 + 间距。
        view.heightAnchor.constraint(equalToConstant: 288).isActive = true
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // 从容器 App 回来时主题可能已改，重新读取。
        applyTheme()
    }

    // MARK: - 搭建 UI

    private func buildUI() {
        view.backgroundColor = theme.color(for: .keyboardBackground)

        rootStack.axis = .vertical
        rootStack.spacing = 6
        rootStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(rootStack)
        NSLayoutConstraint.activate([
            rootStack.topAnchor.constraint(equalTo: view.topAnchor, constant: 6),
            rootStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 6),
            rootStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -6),
            rootStack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -6),
        ])

        // 候选栏：横向滚动，整句候选在前，分词候选在后（以 ｜ 分隔）。
        candidateScrollView.showsHorizontalScrollIndicator = false
        candidateScrollView.backgroundColor = theme.color(for: .candidateBarBackground)
        candidateScrollView.layer.cornerRadius = 12
        candidateScrollView.layer.cornerCurve = .continuous
        candidateStack.axis = .horizontal
        candidateStack.spacing = 4
        candidateStack.alignment = .center
        candidateStack.translatesAutoresizingMaskIntoConstraints = false
        candidateScrollView.addSubview(candidateStack)
        NSLayoutConstraint.activate([
            candidateStack.topAnchor.constraint(equalTo: candidateScrollView.topAnchor),
            candidateStack.bottomAnchor.constraint(equalTo: candidateScrollView.bottomAnchor),
            candidateStack.leadingAnchor.constraint(equalTo: candidateScrollView.leadingAnchor, constant: 8),
            candidateStack.trailingAnchor.constraint(equalTo: candidateScrollView.trailingAnchor, constant: -8),
        ])
        candidateScrollView.heightAnchor.constraint(equalToConstant: 44).isActive = true
        rootStack.addArrangedSubview(candidateScrollView)

        // 三行字母键。
        for row in letterRows {
            let rowStack = UIStackView()
            rowStack.axis = .horizontal
            rowStack.spacing = 6
            rowStack.distribution = .fillEqually
            for char in row {
                let letter = String(char)
                let button = makeKeyButton(title: letter.uppercased(), isFunction: false)
                button.addTarget(self, action: #selector(letterTapped(_:)), for: .touchUpInside)
                button.accessibilityLabel = letter
                letterButtons.append((letter, button))
                rowStack.addArrangedSubview(button)
            }
            rowStack.heightAnchor.constraint(equalToConstant: 52).isActive = true
            rootStack.addArrangedSubview(rowStack)
        }

        // 底行：地球键、Shift、中英切换、语音（占位）、空格、剪贴板（占位）、删除、回车。
        buildBottomRow()
    }

    private func buildBottomRow() {
        let row = UIStackView()
        row.axis = .horizontal
        row.spacing = 6
        row.distribution = .fill

        let globe = makeKeyButton(systemImage: "globe", isFunction: true)
        globe.accessibilityLabel = "切换到下一个键盘"
        globe.addTarget(self, action: #selector(globeTapped), for: .touchUpInside)
        globe.widthAnchor.constraint(equalToConstant: 48).isActive = true

        shiftButton = makeKeyButton(systemImage: "shift", isFunction: true)
        shiftButton.accessibilityLabel = "Shift"
        shiftButton.addTarget(self, action: #selector(shiftTapped), for: .touchUpInside)
        shiftButton.widthAnchor.constraint(equalToConstant: 52).isActive = true

        modeButton = makeKeyButton(title: "中文", isFunction: true)
        modeButton.accessibilityLabel = "切换中英文"
        modeButton.addTarget(self, action: #selector(modeTapped), for: .touchUpInside)
        modeButton.widthAnchor.constraint(equalToConstant: 64).isActive = true

        // 语音：P2 占位。置灰禁用，不冒充已实现。
        let voice = makeKeyButton(systemImage: "mic.fill", isFunction: true)
        voice.accessibilityLabel = "语音输入（P2 接入，暂未实现）"
        voice.isEnabled = false
        voice.alpha = 0.5
        voice.widthAnchor.constraint(equalToConstant: 48).isActive = true

        spaceButton = makeKeyButton(title: "", isFunction: false)
        let space = spaceButton!
        space.accessibilityLabel = "空格"
        space.addTarget(self, action: #selector(spaceTapped), for: .touchUpInside)
        space.setContentHuggingPriority(.defaultLow, for: .horizontal)

        // 剪贴板：P3 占位。置灰禁用，不冒充已实现。
        let clipboard = makeKeyButton(systemImage: "doc.on.clipboard", isFunction: true)
        clipboard.accessibilityLabel = "剪贴板（P3 接入，暂未实现）"
        clipboard.isEnabled = false
        clipboard.alpha = 0.5
        clipboard.widthAnchor.constraint(equalToConstant: 48).isActive = true

        deleteButton = makeKeyButton(systemImage: "delete.left", isFunction: true)
        let delete = deleteButton!
        delete.accessibilityLabel = "删除"
        delete.addTarget(self, action: #selector(deleteTapped), for: .touchUpInside)
        delete.widthAnchor.constraint(equalToConstant: 52).isActive = true

        let enter = makeKeyButton(systemImage: "return", isFunction: true)
        enter.accessibilityLabel = "回车"
        enter.addTarget(self, action: #selector(returnTapped), for: .touchUpInside)
        enter.widthAnchor.constraint(equalToConstant: 64).isActive = true

        for button in [globe, shiftButton!, modeButton!, voice, space, clipboard, delete, enter] {
            row.addArrangedSubview(button)
        }
        row.heightAnchor.constraint(equalToConstant: 52).isActive = true
        rootStack.addArrangedSubview(row)
    }

    // MARK: - 按键外观

    private func makeKeyButton(title: String? = nil, systemImage: String? = nil, isFunction: Bool) -> KeyButton {
        let button = KeyButton(type: .system)
        var config = UIButton.Configuration.plain()
        if let title = title { config.title = title }
        if let systemImage = systemImage { config.image = UIImage(systemName: systemImage) }
        config.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 4, bottom: 0, trailing: 4)
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = UIFont.systemFont(ofSize: 20, weight: .regular)
            return outgoing
        }
        config.background.cornerRadius = 12
        if #available(iOS 26.0, *) {
            // UIKit 液态玻璃：UIGlassEffect 是 UIVisualEffect，走配置背景的 visualEffect。
            // 注意 UIButton 本身没有 glassEffect 属性（CI 已证实），不要再往 button 上挂。
            config.background.visualEffect = UIGlassEffect(style: .regular)
        } else {
            config.background.backgroundColor = theme.color(for: isFunction ? .functionKeyBackground : .keyBackground)
        }
        button.configuration = config
        button.tintColor = theme.color(for: .keyText)
        // 连续圆角 + 大圆角：直角方框不要，圆润有弧度。
        button.layer.cornerRadius = 12
        button.layer.cornerCurve = .continuous
        if isFunction { functionButtons.append(button) }
        return button
    }

    private func applyTheme() {
        view.backgroundColor = theme.color(for: .keyboardBackground)
        candidateScrollView.backgroundColor = theme.color(for: .candidateBarBackground)
        for pair in letterButtons {
            setButtonBackground(pair.button, color: theme.color(for: .keyBackground))
        }
        for button in functionButtons {
            setButtonBackground(button, color: theme.color(for: .functionKeyBackground))
        }
    }

    private func setButtonBackground(_ button: UIButton, color: UIColor) {
        guard var config = button.configuration else { return }
        config.background.backgroundColor = color
        button.configuration = config
    }

    // MARK: - 按键标题（模式 / Shift 状态）

    private func refreshKeyTitles() {
        for pair in letterButtons {
            guard var config = pair.button.configuration else { continue }
            switch mode {
            case .chinese:
                // 拼音模式按键显示大写字母。
                config.title = pair.letter.uppercased()
            case .english:
                config.title = (shiftState == .off) ? pair.letter : pair.letter.uppercased()
            }
            pair.button.configuration = config
        }
        modeButton.configuration?.title = (mode == .chinese) ? "中文" : "EN"
        // 中文模式下 Shift 不参与拼音输入，置灰提示不可用；英文模式恢复。
        shiftButton.alpha = (mode == .chinese) ? 0.4 : 1.0
        shiftButton.configuration?.image = UIImage(systemName: shiftState == .capsLock ? "capslock.fill" : "shift")
    }

    // MARK: - 候选栏

    private func refreshCandidates() {
        if pinyinBuffer.isEmpty {
            sentenceCandidates = []
            charCandidates = []
            currentSegmentation = []
        } else {
            sentenceCandidates = engine.candidates(for: pinyinBuffer)
            let segmentations = engine.segmentations(for: pinyinBuffer)
            currentSegmentation = segmentations.first ?? []
            if let first = currentSegmentation.first {
                charCandidates = engine.characterCandidates(for: first)
            } else {
                charCandidates = []
            }
        }
        rebuildCandidateBar()
    }

    private func rebuildCandidateBar() {
        for subview in candidateStack.arrangedSubviews {
            candidateStack.removeArrangedSubview(subview)
            subview.removeFromSuperview()
        }
        if pinyinBuffer.isEmpty {
            // 未输入时显示当前模式提示。
            let hint = UILabel()
            hint.text = (mode == .chinese) ? "WenKey · 中文" : "WenKey · English"
            hint.font = UIFont.systemFont(ofSize: 15)
            hint.textColor = .secondaryLabel
            candidateStack.addArrangedSubview(hint)
            return
        }
        if sentenceCandidates.isEmpty && charCandidates.isEmpty {
            // 拼不出合法音节时原样显示正在拼的字母，提示用户可删除重拼。
            let raw = UILabel()
            raw.text = pinyinBuffer
            raw.font = UIFont.systemFont(ofSize: 17)
            raw.textColor = theme.color(for: .candidateText)
            candidateStack.addArrangedSubview(raw)
            return
        }
        for candidate in sentenceCandidates {
            let button = makeCandidateButton(title: candidate.text) { [weak self] in
                self?.commitCandidate(candidate)
            }
            candidateStack.addArrangedSubview(button)
        }
        if !charCandidates.isEmpty {
            let divider = UILabel()
            divider.text = "｜"
            divider.textColor = .secondaryLabel
            candidateStack.addArrangedSubview(divider)
            for char in charCandidates {
                let button = makeCandidateButton(title: char) { [weak self] in
                    self?.commitCharCandidate(char)
                }
                candidateStack.addArrangedSubview(button)
            }
        }
    }

    private func makeCandidateButton(title: String, action: @escaping () -> Void) -> UIButton {
        let button = UIButton(type: .system)
        var config = UIButton.Configuration.plain()
        config.title = title
        config.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12)
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = UIFont.systemFont(ofSize: 17)
            return outgoing
        }
        button.configuration = config
        button.setTitleColor(theme.color(for: .candidateText), for: .normal)
        button.addAction(UIAction { _ in action() }, for: .touchUpInside)
        return button
    }

    // MARK: - 输入处理

    private func commitCandidate(_ candidate: SentenceCandidate) {
        selectionHaptic.selectionChanged()
        textDocumentProxy.insertText(candidate.text)
        UserLearningStore.shared.recordSelection(candidate.text)
        clearBuffer()
    }

    /// 点选分词候选：上屏该单字，剩余音节继续留在输入框里。
    private func commitCharCandidate(_ char: String) {
        selectionHaptic.selectionChanged()
        textDocumentProxy.insertText(char)
        let remaining = currentSegmentation.dropFirst().joined()
        pinyinBuffer = remaining
        refreshCandidates()
    }

    private func clearBuffer() {
        pinyinBuffer = ""
        refreshCandidates()
    }

    private func commitBufferFallback() {
        // 缓冲区有内容但无候选时：按切换/空格前的原样处理。
        // 调用方在调用后自行 clearBuffer。
        if !pinyinBuffer.isEmpty {
            if let first = sentenceCandidates.first {
                textDocumentProxy.insertText(first.text)
                UserLearningStore.shared.recordSelection(first.text)
            } else {
                // 拼不出合法音节：原文上屏，不丢用户已打的字母。
                textDocumentProxy.insertText(pinyinBuffer)
            }
        }
    }

    @objc private func letterTapped(_ sender: KeyButton) {
        keyHaptic.impactOccurred()
        guard let pair = letterButtons.first(where: { $0.button === sender }) else { return }
        switch mode {
        case .english:
            let char = (shiftState == .off) ? pair.letter : pair.letter.uppercased()
            textDocumentProxy.insertText(char)
            if shiftState == .on {
                shiftState = .off
                refreshKeyTitles()
            }
        case .chinese:
            pinyinBuffer += pair.letter
            refreshCandidates()
        }
    }

    @objc private func deleteTapped() {
        keyHaptic.impactOccurred()
        if mode == .chinese && !pinyinBuffer.isEmpty {
            pinyinBuffer.removeLast()
            refreshCandidates()
        } else {
            textDocumentProxy.deleteBackward()
        }
    }

    @objc private func spaceTapped() {
        keyHaptic.impactOccurred()
        if mode == .chinese && !pinyinBuffer.isEmpty {
            if sentenceCandidates.isEmpty {
                // 无候选：原文 + 空格上屏。
                textDocumentProxy.insertText(pinyinBuffer)
                textDocumentProxy.insertText(" ")
                clearBuffer()
            } else {
                commitCandidate(sentenceCandidates[0])
                textDocumentProxy.insertText(" ")
            }
        } else {
            textDocumentProxy.insertText(" ")
        }
    }

    @objc private func returnTapped() {
        keyHaptic.impactOccurred()
        if mode == .chinese && !pinyinBuffer.isEmpty && !sentenceCandidates.isEmpty {
            commitCandidate(sentenceCandidates[0])
        } else {
            textDocumentProxy.insertText("\n")
        }
    }

    @objc private func shiftTapped() {
        // 中文模式下 Shift 不参与拼音输入，忽略（按钮已置灰）。
        guard mode == .english else { return }
        keyHaptic.impactOccurred()
        let now = Date()
        if let last = lastShiftTapTime, now.timeIntervalSince(last) < 0.35 {
            // 快速连点两次：大写锁定。
            shiftState = (shiftState == .capsLock) ? .off : .capsLock
            lastShiftTapTime = nil
        } else {
            shiftState = (shiftState == .off) ? .on : .off
            lastShiftTapTime = now
        }
        refreshKeyTitles()
    }

    @objc private func modeTapped() {
        keyHaptic.impactOccurred()
        if mode == .chinese && !pinyinBuffer.isEmpty {
            commitBufferFallback()
            clearBuffer()
        }
        mode = (mode == .chinese) ? .english : .chinese
        shiftState = .off
        refreshKeyTitles()
        refreshCandidates()
    }

    @objc private func globeTapped() {
        advanceToNextInputMode()
    }
}

/// 按键：按下时轻微缩放的触感动画。
final class KeyButton: UIButton {
    /// P1 长按符号的数据位：该键长按时出的符号（如 q → 1）。P0 不用、不显示。
    var longPressTitle: String?

    override var isHighlighted: Bool {
        didSet {
            let scale: CGFloat = isHighlighted ? 0.92 : 1.0
            UIView.animate(withDuration: 0.08) {
                self.transform = CGAffineTransform(scaleX: scale, y: scale)
            }
        }
    }
}
