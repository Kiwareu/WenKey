import UIKit

// MARK: - 小工具

private extension UIColor {
    convenience init?(wenKeyAppHex hex: String) {
        var cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("#") { cleaned.removeFirst() }
        guard (cleaned.count == 6 || cleaned.count == 8),
              let value = UInt64(cleaned, radix: 16) else { return nil }
        if cleaned.count == 6 {
            self.init(red: CGFloat((value >> 16) & 0xFF) / 255,
                      green: CGFloat((value >> 8) & 0xFF) / 255,
                      blue: CGFloat(value & 0xFF) / 255, alpha: 1)
        } else {
            self.init(red: CGFloat((value >> 24) & 0xFF) / 255,
                      green: CGFloat((value >> 16) & 0xFF) / 255,
                      blue: CGFloat((value >> 8) & 0xFF) / 255,
                      alpha: CGFloat(value & 0xFF) / 255)
        }
    }
}

private func makeLabel(_ text: String, size: CGFloat = 15, bold: Bool = false, color: UIColor = .label) -> UILabel {
    let label = UILabel()
    label.text = text
    label.font = bold ? UIFont.systemFont(ofSize: size, weight: .semibold) : UIFont.systemFont(ofSize: size)
    label.textColor = color
    label.numberOfLines = 0
    return label
}

private func makeSectionTitle(_ text: String) -> UILabel {
    let label = makeLabel(text, size: 17, bold: true)
    label.textColor = .label
    return label
}

extension UIViewController {
    func showToast(_ text: String) {
        let alert = UIAlertController(title: nil, message: text, preferredStyle: .alert)
        present(alert, animated: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            alert.dismiss(animated: true)
        }
    }

    func openSystemSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - 主界面：5 个页

final class MainTabBarController: UITabBarController {
    override func viewDidLoad() {
        super.viewDidLoad()
        let keyboard = UINavigationController(rootViewController: KeyboardTabViewController())
        keyboard.tabBarItem = UITabBarItem(title: "键盘", image: UIImage(systemName: "keyboard"), tag: 0)
        let clipboard = UINavigationController(rootViewController: ClipboardTabViewController())
        clipboard.tabBarItem = UITabBarItem(title: "剪贴板", image: UIImage(systemName: "doc.on.clipboard"), tag: 1)
        let phrases = UINavigationController(rootViewController: PhrasesTabViewController())
        phrases.tabBarItem = UITabBarItem(title: "常用语", image: UIImage(systemName: "text.bubble"), tag: 2)
        let skins = UINavigationController(rootViewController: SkinsTabViewController())
        skins.tabBarItem = UITabBarItem(title: "皮肤", image: UIImage(systemName: "paintpalette"), tag: 3)
        let settings = UINavigationController(rootViewController: SettingsViewController())
        settings.tabBarItem = UITabBarItem(title: "设置", image: UIImage(systemName: "gear"), tag: 4)
        viewControllers = [keyboard, clipboard, phrases, skins, settings]
    }
}

// MARK: - 键盘页：启用步骤 + 试打框 + 完全访问

final class KeyboardTabViewController: UIViewController {
    private let testField = UITextField()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "WenKey"
        view.backgroundColor = .systemBackground

        let scroll = UIScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scroll)
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: scroll.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: scroll.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: scroll.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: scroll.bottomAnchor, constant: -16),
            stack.widthAnchor.constraint(equalTo: scroll.widthAnchor, constant: -32),
        ])

        stack.addArrangedSubview(makeSectionTitle("启用键盘"))
        stack.addArrangedSubview(makeLabel("1. 设置 → 通用 → 键盘 → 键盘 → 添加新键盘 → 选择 WenKey", color: .secondaryLabel))
        stack.addArrangedSubview(makeLabel("2. 在任意输入框点地球键，切换到 WenKey", color: .secondaryLabel))
        stack.addArrangedSubview(makeLabel("3. 如果切过去又弹回原生键盘：先把 WenKey 从键盘列表里删掉重加一次，再重启手机；仍不行就换自签方式重装（见设置页的排查说明）", color: .secondaryLabel))

        stack.addArrangedSubview(makeSectionTitle("在这里试打"))
        testField.placeholder = "点一下这里，再点地球键切到 WenKey 试试"
        testField.borderStyle = .roundedRect
        testField.font = UIFont.systemFont(ofSize: 16)
        stack.addArrangedSubview(testField)

        stack.addArrangedSubview(makeSectionTitle("完全访问"))
        stack.addArrangedSubview(makeLabel("剪贴板自动记录、粘贴板读取需要完全访问。添加键盘后，在设置 → 通用 → 键盘 → 键盘 → WenKey 里打开“允许完全访问”。不开也能打字，只是剪贴板自动记录用不了。", color: .secondaryLabel))
        let settingsButton = UIButton(type: .system)
        settingsButton.setTitle("打开系统设置", for: .normal)
        settingsButton.addAction(UIAction { [weak self] _ in self?.openSystemSettings() }, for: .touchUpInside)
        stack.addArrangedSubview(settingsButton)

        stack.addArrangedSubview(makeSectionTitle("当前状态"))
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        stack.addArrangedSubview(makeLabel("内置词典：\(DictionaryData.entries.count) 条 · 版本 \(version)", color: .secondaryLabel))
        stack.addArrangedSubview(makeLabel("打字方式：26 键全拼，整行拼音自动成句；另有英文键盘。", color: .secondaryLabel))
    }
}

// MARK: - 剪贴板页：分类查看、导入、清空

final class ClipboardTabViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    private let tableView = UITableView()
    private let segment = UISegmentedControl(items: ["全部", "文本", "链接", "其他"])
    private let hintLabel = UILabel()
    private var filter: ClipboardCategory?
    private var shown: [ClipboardItem] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "剪贴板"
        view.backgroundColor = .systemBackground
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "清空", style: .plain, target: self, action: #selector(clearAll))

        segment.selectedSegmentIndex = 0
        segment.addTarget(self, action: #selector(filterChanged), for: .valueChanged)
        segment.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(segment)

        let importButton = UIButton(type: .system)
        importButton.setTitle("从剪贴板导入当前内容", for: .normal)
        importButton.addAction(UIAction { [weak self] _ in self?.importCurrent() }, for: .touchUpInside)
        importButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(importButton)

        hintLabel.text = "在键盘里复制内容后（需完全访问），会自动记到这里；也可以点上面手动导入。"
        hintLabel.font = UIFont.systemFont(ofSize: 13)
        hintLabel.textColor = .secondaryLabel
        hintLabel.numberOfLines = 0
        hintLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(hintLabel)

        tableView.dataSource = self
        tableView.delegate = self
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            segment.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            segment.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            segment.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            importButton.topAnchor.constraint(equalTo: segment.bottomAnchor, constant: 12),
            importButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            hintLabel.topAnchor.constraint(equalTo: importButton.bottomAnchor, constant: 8),
            hintLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            hintLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            tableView.topAnchor.constraint(equalTo: hintLabel.bottomAnchor, constant: 8),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reload()
    }

    private func reload() {
        let all = ClipboardStore.shared.items()
        if let filter = filter {
            shown = all.filter { $0.category == filter }
        } else {
            shown = all
        }
        hintLabel.text = all.isEmpty
            ? "还没有剪贴板记录。在键盘里复制内容后（需完全访问），会自动记到这里；也可以点上面手动导入。"
            : "共 \(all.count) 条，点一条可复制回剪贴板。"
        tableView.reloadData()
    }

    @objc private func filterChanged() {
        switch segment.selectedSegmentIndex {
        case 1: filter = .text
        case 2: filter = .link
        case 3: filter = .other
        default: filter = nil
        }
        reload()
    }

    @objc private func importCurrent() {
        guard let text = UIPasteboard.general.string, !text.isEmpty else {
            showToast("当前剪贴板是空的")
            return
        }
        if ClipboardStore.shared.add(text) {
            reload()
            showToast("已导入")
        } else {
            showToast("这条已经记过了")
        }
    }

    @objc private func clearAll() {
        let alert = UIAlertController(title: "清空剪贴板历史？", message: "全部记录都会删除，不可恢复。", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "清空", style: .destructive) { [weak self] _ in
            ClipboardStore.shared.clear()
            self?.reload()
        })
        present(alert, animated: true)
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return shown.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell")
            ?? UITableViewCell(style: .subtitle, reuseIdentifier: "cell")
        let item = shown[indexPath.row]
        cell.textLabel?.text = item.text
        cell.textLabel?.numberOfLines = 2
        cell.detailTextLabel?.text = item.category.displayName
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        UIPasteboard.general.string = shown[indexPath.row].text
        showToast("已复制到剪贴板，去输入框粘贴就行")
    }

    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            ClipboardStore.shared.delete(id: shown[indexPath.row].id)
            reload()
        }
    }
}

// MARK: - 常用语页：新增、删除、点按复制

final class PhrasesTabViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    private let tableView = UITableView()
    private var phrases: [CommonPhrase] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "常用语"
        view.backgroundColor = .systemBackground
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addPhrase))

        tableView.dataSource = self
        tableView.delegate = self
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        phrases = CommonPhrasesStore.shared.phrases()
        tableView.reloadData()
    }

    @objc private func addPhrase() {
        let alert = UIAlertController(title: "新增常用语", message: "触发码是简短代号，短语是完整内容。", preferredStyle: .alert)
        alert.addTextField { $0.placeholder = "触发码，比如 dz" }
        alert.addTextField { $0.placeholder = "短语内容" }
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "保存", style: .default) { [weak self] _ in
            let trigger = alert.textFields?.first?.text ?? ""
            let text = alert.textFields?.last?.text ?? ""
            CommonPhrasesStore.shared.save(CommonPhrase(trigger: trigger, text: text))
            self?.viewWillAppear(false)
        })
        present(alert, animated: true)
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return phrases.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell")
            ?? UITableViewCell(style: .subtitle, reuseIdentifier: "cell")
        let phrase = phrases[indexPath.row]
        cell.textLabel?.text = phrase.trigger
        cell.detailTextLabel?.text = phrase.text
        cell.detailTextLabel?.numberOfLines = 2
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        UIPasteboard.general.string = phrases[indexPath.row].text
        showToast("已复制到剪贴板，去输入框粘贴就行")
    }

    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            CommonPhrasesStore.shared.delete(trigger: phrases[indexPath.row].trigger)
            viewWillAppear(false)
        }
    }
}

// MARK: - 皮肤页：内置预设 + 分部位调色 + 透明度

final class SkinsTabViewController: UIViewController {
    private let swatchHexes = ["#FF6B81", "#4A90E2", "#34C759", "#FF9500", "#AF52DE", "#000000", "#FFFFFF", "#8E8E93"]

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "皮肤"
        view.backgroundColor = .systemBackground

        let scroll = UIScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scroll)
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: scroll.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: scroll.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: scroll.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: scroll.bottomAnchor, constant: -16),
            stack.widthAnchor.constraint(equalTo: scroll.widthAnchor, constant: -32),
        ])

        stack.addArrangedSubview(makeSectionTitle("内置皮肤（点一下就换）"))
        stack.addArrangedSubview(makeLabel("全部内置，没有商城和付费。换完去键盘里看效果。", color: .secondaryLabel))
        for preset in ThemePreset.all {
            let button = UIButton(type: .system)
            button.setTitle(preset.name, for: .normal)
            button.contentHorizontalAlignment = .left
            button.addAction(UIAction { [weak self] _ in
                ThemeStore.shared.applyPreset(preset)
                self?.showToast("已换成\(preset.name)，去键盘里看效果")
            }, for: .touchUpInside)
            stack.addArrangedSubview(button)
        }

        stack.addArrangedSubview(makeSectionTitle("分部位调色"))
        stack.addArrangedSubview(makeLabel("先点部位那一行的颜色，立刻生效。", color: .secondaryLabel))
        for part in ThemePart.allCases {
            let row = UIStackView()
            row.axis = .horizontal
            row.spacing = 8
            row.alignment = .center
            let label = makeLabel(part.displayName, size: 14)
            label.widthAnchor.constraint(equalToConstant: 72).isActive = true
            row.addArrangedSubview(label)
            for hex in swatchHexes {
                let swatch = UIButton(type: .system)
                swatch.backgroundColor = UIColor(wenKeyAppHex: hex)
                swatch.layer.cornerRadius = 11
                swatch.layer.borderWidth = 0.5
                swatch.layer.borderColor = UIColor.systemGray4.cgColor
                swatch.widthAnchor.constraint(equalToConstant: 22).isActive = true
                swatch.heightAnchor.constraint(equalToConstant: 22).isActive = true
                swatch.addAction(UIAction { _ in
                    if let color = UIColor(wenKeyAppHex: hex) {
                        ThemeStore.shared.setColor(color, for: part)
                    }
                }, for: .touchUpInside)
                row.addArrangedSubview(swatch)
            }
            stack.addArrangedSubview(row)
        }

        stack.addArrangedSubview(makeSectionTitle("透明度"))
        let slider = UISlider()
        slider.minimumValue = 0.5
        slider.maximumValue = 1.0
        slider.value = 1.0
        slider.addAction(UIAction { _ in
            ThemeStore.shared.applyTransparency(CGFloat(slider.value))
        }, for: .valueChanged)
        stack.addArrangedSubview(slider)
        stack.addArrangedSubview(makeLabel("往左更透，往右更实。只影响键盘背景和按键。", color: .secondaryLabel))
    }
}

// MARK: - 设置页：功能开关 + 唤起排查

final class SettingsViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "设置"
        view.backgroundColor = .systemBackground
        tableView.dataSource = self
        tableView.delegate = self
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    func numberOfSections(in tableView: UITableView) -> Int { return 2 }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return section == 0 ? FeatureFlag.allCases.count : diagnosticLines().count
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return section == 0 ? "功能开关（改完去键盘里即生效）" : "诊断信息"
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell")
            ?? UITableViewCell(style: .default, reuseIdentifier: "cell")
        if indexPath.section == 0 {
            let flag = FeatureFlag.allCases[indexPath.row]
            cell.textLabel?.text = flag.displayName
            let toggle = UISwitch()
            toggle.isOn = FeatureFlagStore.shared.isEnabled(flag)
            toggle.tag = indexPath.row
            toggle.addTarget(self, action: #selector(flagChanged(_:)), for: .valueChanged)
            cell.accessoryView = toggle
            cell.selectionStyle = .none
        } else {
            // 诊断区复用同一行数，第一行放关键信息，其余行放排查步骤。
            let lines = diagnosticLines()
            cell.textLabel?.text = lines[min(indexPath.row, lines.count - 1)]
            cell.textLabel?.numberOfLines = 0
            cell.accessoryView = nil
            cell.selectionStyle = .none
        }
        return cell
    }

    private func diagnosticLines() -> [String] {
        return [
            "App：com.wenx.wenkey · 键盘：com.wenx.wenkey.keyboard",
            "键盘弹回原生时先排查：1) 键盘列表里删掉 WenKey 重加；2) 重启手机；3) 别在密码框里试（系统会强制用原生键盘）；4) 看设置 → 隐私与安全性 → 分析与改进 → 分析数据里有没有 WenKeyKeyboard 开头的崩溃日志，有就发给我。",
            "安装方式很关键：自签（AltStore / Sideloadly，用你自己的 Apple ID 签）比假签更可能让键盘扩展正常唤起；如果现在是假签装的，换自签重装一次再试。",
        ]
    }

    @objc private func flagChanged(_ sender: UISwitch) {
        let flag = FeatureFlag.allCases[sender.tag]
        FeatureFlagStore.shared.setEnabled(flag, sender.isOn)
    }
}
