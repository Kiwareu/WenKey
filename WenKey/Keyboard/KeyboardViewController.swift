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

    /// P1 手势扩展口：实现见文件末尾的 KeyboardGestureHandler 扩展；
    /// setupP1Gestures() 里赋值并挂手势识别器。
    var gestureHandler: KeyboardGestureHandler?
    /// 当前正在拼的拼音字母（小写）。中文模式专用。
    private var pinyinBuffer = ""
    /// 剪贴板面板是否打开：打开时候选栏显示剪贴板历史，点一条上屏。
    private var clipboardMode = false
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

    // MARK: - P1 手势状态

    /// 空格触控板：上次手指位置（view 坐标）、未满一个字符的剩余位移。
    private var spaceTrackpadLastX: CGFloat = 0
    private var spaceTrackpadRemainder: CGFloat = 0
    /// 删词滑动：上次手指位置、净左滑距离（右滑缩减）、历史最大左滑距离、当前预览词数。
    private var deleteSwipeLastX: CGFloat = 0
    private var deleteSwipeDistance: CGFloat = 0
    private var deleteSwipeMaxDistance: CGFloat = 0
    private var deleteSwipeWordCount = 0
    /// 滑行：是否正在滑行、轨迹字母、当前预览词、起手字母（手势代理在 shouldBegin 里记下）。
    private var glideActive = false
    private var glidePath: [String] = []
    private var glidePreview: String?
    private var glideSeedLetter: String?
    private var glidePanRecognizer: UIPanGestureRecognizer?
    /// 长按符号面板与遮罩（点遮罩关闭面板）。
    private var symbolPanel: UIView?
    private var symbolPanelOverlay: UIControl?
    /// 长按已弹面板时，本次触摸抬起触发的 letterTapped 应跳过（不重复输入字母）。
    private var suppressNextLetterTap = false
    /// 上次普通空格插入时间（双击空格句号的窗口判断用）。
    private var lastSpaceTapAt: Date?

    /// 长按符号表：每键长按出的符号（首个同时写入 KeyButton.longPressTitle）。
    private static let longPressSymbols: [String: [String]] = [
        "q": ["1"], "w": ["2"], "e": ["3"], "r": ["4"], "t": ["5"],
        "y": ["6"], "u": ["7"], "i": ["8"], "o": ["9"], "p": ["0"],
        "a": ["@"], "s": ["#"], "d": ["$"], "f": ["%"], "g": ["&"],
        "h": ["-", "_"], "j": ["+", "="], "k": ["("], "l": [")"],
        "z": ["*"], "x": ["\""], "c": ["'"], "v": [":"], "b": [";"],
        "n": ["!"], "m": ["?"],
    ]

    private let letterRows = ["qwertyuiop", "asdfghjkl", "zxcvbnm"]

    override func viewDidLoad() {
        super.viewDidLoad()
        keyHaptic.prepare()
        buildUI()
        setupP1Gestures()
        applyTheme()
        refreshKeyTitles()
        refreshCandidates()
        // 键盘固定高度：候选栏 40 + 4 行 × 50 + 间距。
        view.heightAnchor.constraint(equalToConstant: 272).isActive = true
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // 从容器 App 回来时主题可能已改，重新读取。
        applyTheme()
        // 完全访问已开时：键盘每次出现都把系统剪贴板当前内容记一条
        // （没开完全访问时扩展读不到共享剪贴板，这里什么都不做）。
        if hasFullAccess, let text = UIPasteboard.general.string {
            ClipboardStore.shared.add(text)
        }
        if clipboardMode {
            rebuildCandidateBar()
        }
    }

    // MARK: - 搭建 UI

    private func buildUI() {
        view.backgroundColor = theme.color(for: .keyboardBackground)

        rootStack.axis = .vertical
        rootStack.spacing = 5
        rootStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(rootStack)
        NSLayoutConstraint.activate([
            rootStack.topAnchor.constraint(equalTo: view.topAnchor, constant: 4),
            rootStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 4),
            rootStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -4),
            rootStack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -4),
        ])

        // 候选栏：横向滚动，整句候选在前，分词候选在后（以 ｜ 分隔）。
        // P1 按页滚动：滑动一次翻一屏候选。
        candidateScrollView.isPagingEnabled = true
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
        candidateScrollView.heightAnchor.constraint(equalToConstant: 40).isActive = true
        rootStack.addArrangedSubview(candidateScrollView)

        // 三行字母键。第 2、3 行左右缩进，像正常键盘那样错开，不再是齐边网格。
        for (rowIndex, row) in letterRows.enumerated() {
            let rowStack = UIStackView()
            rowStack.axis = .horizontal
            rowStack.spacing = 5
            rowStack.distribution = .fillEqually
            if rowIndex == 1 {
                rowStack.isLayoutMarginsRelativeArrangement = true
                rowStack.layoutMargins = UIEdgeInsets(top: 0, left: 18, bottom: 0, right: 18)
            } else if rowIndex == 2 {
                rowStack.isLayoutMarginsRelativeArrangement = true
                rowStack.layoutMargins = UIEdgeInsets(top: 0, left: 36, bottom: 0, right: 36)
            }
            for char in row {
                let letter = String(char)
                let button = makeKeyButton(title: letter.uppercased(), isFunction: false)
                button.addTarget(self, action: #selector(letterTapped(_:)), for: .touchUpInside)
                button.accessibilityLabel = letter
                // P1 长按符号的数据位：首个符号；面板内容见 longPressSymbols。
                button.longPressTitle = Self.longPressSymbols[letter]?.first
                letterButtons.append((letter, button))
                rowStack.addArrangedSubview(button)
            }
            rowStack.heightAnchor.constraint(equalToConstant: 50).isActive = true
            rootStack.addArrangedSubview(rowStack)
        }

        // 底行：地球键、Shift、中英切换、空格、剪贴板、删除、回车。
        // 注意：语音还是占位键，先不放到底行占宽，等 P3 真做了再放回来；
        // 底行固定宽之和必须小于最窄屏幕，否则回车键会被挤出屏幕（v0.2.1 的 bug）。
        buildBottomRow()
    }

    private func buildBottomRow() {
        let row = UIStackView()
        row.axis = .horizontal
        row.spacing = 4
        row.distribution = .fill

        let globe = makeKeyButton(systemImage: "globe", isFunction: true)
        globe.accessibilityLabel = "切换到下一个键盘"
        globe.addTarget(self, action: #selector(globeTapped), for: .touchUpInside)
        globe.widthAnchor.constraint(equalToConstant: 40).isActive = true

        shiftButton = makeKeyButton(systemImage: "shift", isFunction: true)
        shiftButton.accessibilityLabel = "Shift"
        shiftButton.addTarget(self, action: #selector(shiftTapped), for: .touchUpInside)
        shiftButton.widthAnchor.constraint(equalToConstant: 44).isActive = true

        modeButton = makeKeyButton(title: "中文", isFunction: true)
        modeButton.accessibilityLabel = "切换中英文"
        modeButton.addTarget(self, action: #selector(modeTapped), for: .touchUpInside)
        modeButton.widthAnchor.constraint(equalToConstant: 52).isActive = true

        spaceButton = makeKeyButton(title: "", isFunction: false)
        let space = spaceButton!
        space.accessibilityLabel = "空格"
        // P1：空格的点按与长按都走手势识别器（setupP1Gestures 里挂），
        // 不再用 touchUpInside，避免长按触控板后抬起又多插一个空格。
        space.setContentHuggingPriority(.defaultLow, for: .horizontal)

        // 剪贴板：点一下候选栏变剪贴板历史，点一条上屏；再点关掉。
        // 需要完全访问才能自动记录，App 里有手动导入兜底。
        let clipboard = makeKeyButton(systemImage: "doc.on.clipboard", isFunction: true)
        clipboard.accessibilityLabel = "剪贴板"
        clipboard.addTarget(self, action: #selector(clipboardTapped), for: .touchUpInside)
        clipboard.widthAnchor.constraint(equalToConstant: 40).isActive = true

        deleteButton = makeKeyButton(systemImage: "delete.left", isFunction: true)
        let delete = deleteButton!
        delete.accessibilityLabel = "删除"
        // P1：删除的点按与长按都走手势识别器（setupP1Gestures 里挂），
        // 不再用 touchUpInside，避免长按滑动后抬起又多删一字。
        delete.widthAnchor.constraint(equalToConstant: 44).isActive = true

        let enter = makeKeyButton(systemImage: "return", isFunction: true)
        enter.accessibilityLabel = "回车"
        enter.addTarget(self, action: #selector(returnTapped), for: .touchUpInside)
        enter.widthAnchor.constraint(equalToConstant: 52).isActive = true

        for button in [globe, shiftButton!, modeButton!, space, clipboard, delete, enter] {
            row.addArrangedSubview(button)
        }
        row.heightAnchor.constraint(equalToConstant: 50).isActive = true
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
        // 新一屏候选从头看；滑行/删词预览期间也一样（预览只有一项）。
        candidateScrollView.setContentOffset(.zero, animated: false)
        // 剪贴板面板：优先于拼音候选显示。
        if clipboardMode {
            let items = ClipboardStore.shared.items()
            if items.isEmpty {
                let hint = UILabel()
                hint.text = hasFullAccess ? "剪贴板是空的：先在别处复制一段，再回键盘看" : "剪贴板是空的：先在设置里开完全访问，或去 App 里手动导入"
                hint.font = UIFont.systemFont(ofSize: 14)
                hint.textColor = .secondaryLabel
                candidateStack.addArrangedSubview(hint)
            } else {
                for item in items.prefix(20) {
                    let button = makeCandidateButton(title: item.text) { [weak self] in
                        self?.commitClipboardItem(item.text)
                    }
                    candidateStack.addArrangedSubview(button)
                }
            }
            return
        }
        // P1 预览优先于常规内容：滑行匹配词、删词词数。
        if let preview = glidePreview {
            let label = UILabel()
            label.text = preview
            label.font = UIFont.systemFont(ofSize: 17)
            label.textColor = theme.color(for: .candidateText)
            candidateStack.addArrangedSubview(label)
            return
        }
        if deleteSwipeWordCount > 0 {
            let label = UILabel()
            label.text = "松手删除 \(deleteSwipeWordCount) 个词"
            label.font = UIFont.systemFont(ofSize: 15)
            label.textColor = .secondaryLabel
            candidateStack.addArrangedSubview(label)
            return
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
            // 拼不出合法音节：把原因写清楚，别让用户以为键盘坏了。
            // 比如 hh j h 这种串没有任何合法音节，就出不了中文。
            let raw = UILabel()
            raw.text = "\(pinyinBuffer)（拼不出来，删掉重拼完整拼音）"
            raw.font = UIFont.systemFont(ofSize: 15)
            raw.textColor = .secondaryLabel
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
        // P1 长按已弹符号面板时，抬起这次触摸不重复输入字母。
        if suppressNextLetterTap {
            suppressNextLetterTap = false
            return
        }
        keyHaptic.impactOccurred()
        clipboardMode = false
        guard let pair = letterButtons.first(where: { $0.button === sender }) else { return }
        switch mode {
        case .english:
            var char = (shiftState == .off) ? pair.letter : pair.letter.uppercased()
            // P1 英文句首自动大写：只在未按 Shift 时补，Shift 自身逻辑不动。
            if shiftState == .off,
               FeatureFlagStore.shared.isEnabled(.autoCapitalization),
               isSentenceStart() {
                char = char.uppercased()
            }
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

    /// 句首判定（启发式）：文档开头、换行后、句末标点后都算句首。
    /// 读不到文档上下文的应用返回 false（不大写），不猜。
    private func isSentenceStart() -> Bool {
        guard let before = textDocumentProxy.documentContextBeforeInput else { return false }
        var text = before
        while text.hasSuffix(" ") || text.hasSuffix("\t") { text.removeLast() }
        if text.isEmpty { return true }
        guard let last = text.last else { return true }
        return last == "." || last == "!" || last == "?" || last == "\n"
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
            lastSpaceTapAt = Date()
        } else if isDoubleSpaceTap() {
            // P1 双击空格：删掉上一个空格，换成句号。
            // 英文句号后带空格，中文句号不带；句号后不再武装双击，避免连点出连续句号。
            textDocumentProxy.deleteBackward()
            if mode == .chinese {
                textDocumentProxy.insertText("。")
            } else {
                textDocumentProxy.insertText(". ")
            }
            lastSpaceTapAt = nil
        } else {
            textDocumentProxy.insertText(" ")
            lastSpaceTapAt = Date()
        }
    }

    /// 双击空格判定：开关开 + 上次空格在 0.5 秒内 + 光标前确有一个空格。
    /// 光标前无空格时（如刚打完字母、删过字）自动不触发，不需要额外复位标志。
    private func isDoubleSpaceTap() -> Bool {
        guard FeatureFlagStore.shared.isEnabled(.doubleSpacePeriod),
              let last = lastSpaceTapAt,
              Date().timeIntervalSince(last) < 0.5,
              let before = textDocumentProxy.documentContextBeforeInput,
              before.hasSuffix(" ") else { return false }
        return true
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

    @objc private func clipboardTapped() {
        keyHaptic.impactOccurred()
        clipboardMode.toggle()
        rebuildCandidateBar()
    }

    private func commitClipboardItem(_ text: String) {
        selectionHaptic.selectionChanged()
        textDocumentProxy.insertText(text)
        clipboardMode = false
        rebuildCandidateBar()
    }

    // MARK: - P1 手势接线

    /// 挂 P1 手势识别器（viewDidLoad 里 buildUI 之后调）。
    /// 开关门控不在挂接时做，而在手势代理 shouldBegin 里做：开关关了，
    /// 对应长按/滑行根本不开始，轻点行为完全不受影响。
    private func setupP1Gestures() {
        gestureHandler = self

        // 空格：轻点插空格（tap），长按变触控板（long-press）。
        // tap 等 long-press 失败才触发，长按后抬起不重复插空格。
        let spaceTap = UITapGestureRecognizer(target: self, action: #selector(spaceTapped))
        spaceTap.delegate = self
        spaceButton.addGestureRecognizer(spaceTap)
        let spaceLongPress = UILongPressGestureRecognizer(target: self, action: #selector(spaceLongPressChanged(_:)))
        spaceLongPress.minimumPressDuration = 0.3
        spaceLongPress.allowableMovement = .greatestFiniteMagnitude
        spaceLongPress.cancelsTouchesInView = false
        spaceLongPress.delegate = self
        spaceButton.addGestureRecognizer(spaceLongPress)
        spaceTap.require(toFail: spaceLongPress)

        // 删除：轻点删一字，长按左滑按词删（松手执行，右滑缩减）。
        let deleteTap = UITapGestureRecognizer(target: self, action: #selector(deleteTapped))
        deleteTap.delegate = self
        deleteButton.addGestureRecognizer(deleteTap)
        let deleteLongPress = UILongPressGestureRecognizer(target: self, action: #selector(deleteLongPressChanged(_:)))
        deleteLongPress.minimumPressDuration = 0.3
        deleteLongPress.allowableMovement = .greatestFiniteMagnitude
        deleteLongPress.cancelsTouchesInView = false
        deleteLongPress.delegate = self
        deleteButton.addGestureRecognizer(deleteLongPress)
        deleteTap.require(toFail: deleteLongPress)

        // 字母：长按出符号面板（点选插入）；抬起那下不重复输入字母。
        for pair in letterButtons {
            let longPress = UILongPressGestureRecognizer(target: self, action: #selector(letterLongPressChanged(_:)))
            longPress.minimumPressDuration = 0.4
            longPress.allowableMovement = .greatestFiniteMagnitude
            // 不取消按键触摸：抬起仍走 letterTapped，由防重复标志跳过本次输入。
            longPress.cancelsTouchesInView = false
            longPress.delegate = self
            pair.button.addGestureRecognizer(longPress)
        }

        // 滑行：仅英文模式、在字母键上起手；其余区域与候选栏不受影响。
        let glidePan = UIPanGestureRecognizer(target: self, action: #selector(glidePanChanged(_:)))
        glidePan.delegate = self
        view.addGestureRecognizer(glidePan)
        glidePanRecognizer = glidePan
    }

    // MARK: - P1 手势翻译（识别器事件 → 协议回调）

    @objc private func spaceLongPressChanged(_ recognizer: UILongPressGestureRecognizer) {
        switch recognizer.state {
        case .began:
            spaceTrackpadLastX = recognizer.location(in: view).x
            spaceTrackpadRemainder = 0
            selectionHaptic.selectionChanged()
        case .changed:
            let x = recognizer.location(in: view).x
            gestureHandler?.spaceCursorMoved(deltaX: x - spaceTrackpadLastX)
            spaceTrackpadLastX = x
        case .ended, .cancelled:
            gestureHandler?.spaceCursorEnded()
        default:
            break
        }
    }

    @objc private func deleteLongPressChanged(_ recognizer: UILongPressGestureRecognizer) {
        switch recognizer.state {
        case .began:
            deleteSwipeLastX = recognizer.location(in: view).x
            deleteSwipeDistance = 0
            deleteSwipeMaxDistance = 0
            deleteSwipeWordCount = 0
            selectionHaptic.selectionChanged()
        case .changed:
            let x = recognizer.location(in: view).x
            gestureHandler?.deleteSwipeMoved(deltaX: x - deleteSwipeLastX)
            deleteSwipeLastX = x
        case .ended:
            gestureHandler?.deleteSwipeEnded(committed: deleteSwipeWordCount > 0)
        case .cancelled:
            // 取消不删：只清状态与预览，不调协议（协议的 ended 含松手删除语义）。
            deleteSwipeDistance = 0
            deleteSwipeMaxDistance = 0
            deleteSwipeWordCount = 0
            rebuildCandidateBar()
        default:
            break
        }
    }

    @objc private func letterLongPressChanged(_ recognizer: UILongPressGestureRecognizer) {
        guard let button = recognizer.view as? KeyButton,
              let pair = letterButtons.first(where: { $0.button === button }) else { return }
        switch recognizer.state {
        case .began:
            // 滑行中不弹面板（按住后起滑时面板由滑行开始处关闭）。
            if glideActive { return }
            gestureHandler?.keyLongPressed(letter: pair.letter)
        case .ended:
            // 抬起时手指已滑出按键：不会再有 letterTapped，清除防重复标志。
            let location = recognizer.location(in: button)
            if !button.bounds.contains(location) {
                suppressNextLetterTap = false
            }
        case .cancelled:
            suppressNextLetterTap = false
            dismissSymbolPanel()
        default:
            break
        }
    }

    @objc private func glidePanChanged(_ recognizer: UIPanGestureRecognizer) {
        switch recognizer.state {
        case .began:
            glideActive = true
            glidePath = []
            glidePreview = nil
            suppressNextLetterTap = false
            dismissSymbolPanel()
            if let seed = glideSeedLetter {
                glidePath.append(seed)
            }
            glideSeedLetter = nil
            if let letter = letter(at: recognizer.location(in: view)),
               letter != glidePath.last {
                glidePath.append(letter)
            }
            if !glidePath.isEmpty {
                gestureHandler?.glidePathUpdated(letters: glidePath)
            }
        case .changed:
            guard glideActive else { return }
            if let letter = letter(at: recognizer.location(in: view)),
               letter != glidePath.last {
                glidePath.append(letter)
                gestureHandler?.glidePathUpdated(letters: glidePath)
            }
        case .ended:
            glideActive = false
            gestureHandler?.glidePathEnded()
        case .cancelled:
            glideActive = false
            glidePath = []
            glidePreview = nil
            rebuildCandidateBar()
        default:
            break
        }
    }

    /// 该点落在哪个字母键上（候选栏、底行功能键都返回 nil）。
    private func letter(at point: CGPoint) -> String? {
        guard let hit = view.hitTest(point, with: nil) as? KeyButton,
              let pair = letterButtons.first(where: { $0.button === hit }) else { return nil }
        return pair.letter
    }

    // MARK: - P1 符号面板

    @objc private func dismissSymbolPanel() {
        symbolPanel?.removeFromSuperview()
        symbolPanel = nil
        symbolPanelOverlay?.removeFromSuperview()
        symbolPanelOverlay = nil
    }

    private func insertSymbol(_ symbol: String) {
        selectionHaptic.selectionChanged()
        if mode == .chinese && !pinyinBuffer.isEmpty {
            // 组词中：先把已拼内容按原样上屏，再插符号，不丢字。
            commitBufferFallback()
            clearBuffer()
        }
        textDocumentProxy.insertText(symbol)
        dismissSymbolPanel()
    }
}

// MARK: - P1 手势（KeyboardGestureHandler 实现）

extension KeyboardViewController: KeyboardGestureHandler {
    func spaceCursorMoved(deltaX: CGFloat) {
        // 每 10pt 移动一个字符；不足一个字符的余量累计到下次。
        // 只做水平移动：adjustTextPosition 只能按字符偏移，不对应视觉行。
        spaceTrackpadRemainder += deltaX
        var steps = 0
        while spaceTrackpadRemainder >= 10 {
            steps += 1
            spaceTrackpadRemainder -= 10
        }
        while spaceTrackpadRemainder <= -10 {
            steps -= 1
            spaceTrackpadRemainder += 10
        }
        if steps != 0 {
            textDocumentProxy.adjustTextPosition(byCharacterOffset: steps)
        }
    }

    func spaceCursorEnded() {
        spaceTrackpadRemainder = 0
    }

    func deleteSwipeMoved(deltaX: CGFloat) {
        deleteSwipeDistance = max(0, deleteSwipeDistance - deltaX)
        deleteSwipeMaxDistance = max(deleteSwipeMaxDistance, deleteSwipeDistance)
        // 组词中不删词：不算词数、不出预览；松手逻辑见 deleteSwipeEnded。
        guard pinyinBuffer.isEmpty else { return }
        let maxWords = maxDeletableWords()
        let count = min(Int(deleteSwipeDistance / 28), maxWords, 20)
        if count != deleteSwipeWordCount {
            deleteSwipeWordCount = count
            selectionHaptic.selectionChanged()
            rebuildCandidateBar()
        }
    }

    func deleteSwipeEnded(committed: Bool) {
        defer {
            deleteSwipeDistance = 0
            deleteSwipeMaxDistance = 0
            deleteSwipeWordCount = 0
            rebuildCandidateBar()
        }
        if !pinyinBuffer.isEmpty {
            // 组词中：滑动忽略；纯按住松手等同点按，删一个拼音字母。
            if !committed && deleteSwipeMaxDistance <= 12 {
                pinyinBuffer.removeLast()
                refreshCandidates()
            }
            return
        }
        if committed {
            let chars = charsForDeletingWords(deleteSwipeWordCount)
            for _ in 0..<chars {
                textDocumentProxy.deleteBackward()
            }
        } else if deleteSwipeMaxDistance <= 12 {
            // 纯按住松手（没滑）：等同点按，删一字。
            textDocumentProxy.deleteBackward()
        }
        // 滑出又滑回（committed=false 且滑过）：取消，什么都不删。
    }

    func keyLongPressed(letter: String) {
        dismissSymbolPanel()
        guard let symbols = Self.longPressSymbols[letter], !symbols.isEmpty,
              let button = letterButtons.first(where: { $0.letter == letter })?.button else { return }
        suppressNextLetterTap = true
        selectionHaptic.selectionChanged()
        // 遮罩：点其他地方关闭面板。
        let overlay = UIControl(frame: view.bounds)
        overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        overlay.backgroundColor = .clear
        overlay.addTarget(self, action: #selector(dismissSymbolPanel), for: .touchUpInside)
        view.addSubview(overlay)
        symbolPanelOverlay = overlay
        // 面板：横向符号按钮，位于按键上方。
        let panel = UIView()
        panel.backgroundColor = theme.color(for: .candidateBarBackground)
        panel.layer.cornerRadius = 12
        panel.layer.cornerCurve = .continuous
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 2
        stack.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(stack)
        for symbol in symbols {
            let symbolButton = UIButton(type: .system)
            var config = UIButton.Configuration.plain()
            config.title = symbol
            config.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 6, bottom: 6, trailing: 6)
            config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
                var outgoing = incoming
                outgoing.font = UIFont.systemFont(ofSize: 20)
                return outgoing
            }
            symbolButton.configuration = config
            symbolButton.setTitleColor(theme.color(for: .candidateText), for: .normal)
            symbolButton.addAction(UIAction { [weak self] _ in self?.insertSymbol(symbol) }, for: .touchUpInside)
            symbolButton.widthAnchor.constraint(equalToConstant: 44).isActive = true
            stack.addArrangedSubview(symbolButton)
        }
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: panel.topAnchor, constant: 4),
            stack.bottomAnchor.constraint(equalTo: panel.bottomAnchor, constant: -4),
            stack.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 4),
            stack.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -4),
        ])
        view.addSubview(panel)
        symbolPanel = panel
        // 位置：按键上方居中，左右不出键盘。
        let buttonFrame = view.convert(button.frame, from: button.superview)
        let panelWidth = CGFloat(symbols.count * 44 + (symbols.count - 1) * 2 + 8)
        let panelHeight: CGFloat = 52
        var x = buttonFrame.midX - panelWidth / 2
        x = max(8, min(x, view.bounds.width - panelWidth - 8))
        let y = buttonFrame.minY - panelHeight - 8
        panel.frame = CGRect(x: x, y: max(8, y), width: panelWidth, height: panelHeight)
    }

    func glidePathUpdated(letters: [String]) {
        glidePreview = EnglishGlideMatcher.bestMatch(for: letters)
        rebuildCandidateBar()
    }

    func glidePathEnded() {
        defer {
            glidePath = []
            glidePreview = nil
            rebuildCandidateBar()
        }
        guard mode == .english, let word = glidePreview, !word.isEmpty else { return }
        // 滑行词：Shift 开着或句首时首字母大写（词表全小写，capitalized 安全）。
        var text = word
        if shiftState != .off ||
            (FeatureFlagStore.shared.isEnabled(.autoCapitalization) && isSentenceStart()) {
            text = word.capitalized
        }
        textDocumentProxy.insertText(text)
        // 滑行后自动补一个空格（跟 Gboard / 苹果 QuickPath 一致）；
        // 紧接着想打标点时，空格会在标点前，需按一次删除——P2 纠错可再优化。
        textDocumentProxy.insertText(" ")
        lastSpaceTapAt = Date()
        if shiftState == .on {
            shiftState = .off
            refreshKeyTitles()
        }
    }
}

// MARK: - P1 手势代理（开关门控与滑行起手）

extension KeyboardViewController: UIGestureRecognizerDelegate {
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer === glidePanRecognizer {
            // 滑行：仅英文模式，且起手落在字母键上；同时记下起手字母，
            // 避免手势开始时手指已滑到邻键导致首字母丢了。
            guard FeatureFlagStore.shared.isEnabled(.glideTyping), mode == .english else { return false }
            guard let letter = letter(at: gestureRecognizer.location(in: view)) else { return false }
            glideSeedLetter = letter
            return true
        }
        if let longPress = gestureRecognizer as? UILongPressGestureRecognizer,
           let button = longPress.view as? KeyButton {
            if button === spaceButton {
                return FeatureFlagStore.shared.isEnabled(.spaceCursor)
            }
            if button === deleteButton {
                return FeatureFlagStore.shared.isEnabled(.deleteSwipe)
            }
            if letterButtons.contains(where: { $0.button === button }) {
                return FeatureFlagStore.shared.isEnabled(.longPressSymbols)
            }
        }
        return true
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        // 按住字母后起滑：滑行与字母长按可同时追踪，面板冲突由 glideActive 门控处理。
        let isGlide = gestureRecognizer === glidePanRecognizer || otherGestureRecognizer === glidePanRecognizer
        let otherIsLetterLongPress: Bool = {
            guard let longPress = (gestureRecognizer as? UILongPressGestureRecognizer) ?? (otherGestureRecognizer as? UILongPressGestureRecognizer),
                  let button = longPress.view as? KeyButton else { return false }
            return letterButtons.contains(where: { $0.button === button })
        }()
        return isGlide && otherIsLetterLongPress
    }
}

// MARK: - P1 删词边界（词 = 空格分隔的连续非空格串，中日韩文按字算）

extension KeyboardViewController {
    private func isCJK(_ ch: Character) -> Bool {
        guard let scalar = ch.unicodeScalars.first else { return false }
        let v = scalar.value
        return (0x4E00...0x9FFF).contains(v) || (0x3400...0x4DBF).contains(v)
            || (0xF900...0xFAFF).contains(v) || (0x20000...0x2A6DF).contains(v)
            || (0x3040...0x309F).contains(v) || (0x30A0...0x30FF).contains(v)
            || (0xAC00...0xD7AF).contains(v)
    }

    /// 光标前最多能删几个词（用于滑动上限；读不到文档上下文时为 0）。
    private func maxDeletableWords() -> Int {
        guard let text = textDocumentProxy.documentContextBeforeInput else { return 0 }
        var count = 0
        var index = text.endIndex
        while index > text.startIndex {
            while index > text.startIndex, text[text.index(before: index)] == " " {
                index = text.index(before: index)
            }
            if index == text.startIndex { break }
            if isCJK(text[text.index(before: index)]) {
                index = text.index(before: index)
            } else {
                while index > text.startIndex {
                    let ch = text[text.index(before: index)]
                    if ch == " " || isCJK(ch) { break }
                    index = text.index(before: index)
                }
            }
            count += 1
        }
        return count
    }

    /// 删 count 个词需要按几次 deleteBackward（含词前空格，一并吃掉）。
    private func charsForDeletingWords(_ count: Int) -> Int {
        guard let text = textDocumentProxy.documentContextBeforeInput else { return 0 }
        var index = text.endIndex
        var deleted = 0
        for _ in 0..<count {
            while index > text.startIndex, text[text.index(before: index)] == " " {
                index = text.index(before: index)
                deleted += 1
            }
            if index == text.startIndex { break }
            if isCJK(text[text.index(before: index)]) {
                index = text.index(before: index)
                deleted += 1
            } else {
                while index > text.startIndex {
                    let ch = text[text.index(before: index)]
                    if ch == " " || isCJK(ch) { break }
                    index = text.index(before: index)
                    deleted += 1
                }
            }
        }
        return deleted
    }
}

/// 按键：按下时轻微缩放的触感动画。
final class KeyButton: UIButton {
    /// P1 长按符号的数据位：该键长按时出的首个符号（面板内容见 longPressSymbols）。
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
