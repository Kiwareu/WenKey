# WenKey P0 骨架说明

> 依据 `DESIGN.md`（含 2026-11-04 补全功能一节）。P0 只做骨架：能进 Xcode、能打字。
> 本机没有 macOS，编不过是正常的；下一轮 CI（Xcode 26）验证编译。

## 打开方式

用 Xcode 26 打开 `WenKey/WenKey.xcodeproj`，选 `WenKey` target 运行。
签名需填自己的 Development Team；App Group（`group.com.wenx.wenkey`）需在开发者账号开通，
否则主题/开关跨进程同步会回落为单进程默认值（不崩溃，见 `ThemeStore` / `FeatureFlagStore` 注释）。

- 容器 App Bundle ID：`com.wenx.wenkey`；键盘扩展：`com.wenx.wenkey.keyboard`
- Deployment target：iOS 26；SDK：iOS 26；零第三方依赖，只用 UIKit 等系统框架。

## 文件清单

```
WenKey/
  WenKey.xcodeproj/project.pbxproj   工程（容器 App + 键盘扩展两个 target）
  App/
    AppDelegate.swift                 容器 App 入口
    SceneDelegate.swift               窗口，根视图为设置页
    SettingsViewController.swift      P0 设置页：启用说明 + 状态 + 功能开关只读展示
    Info.plist                      容器 App 信息（含 Scene 配置）
    WenKey.entitlements             App Group
  Keyboard/
    KeyboardViewController.swift      键盘 UI + 输入处理（26 键、候选栏、中英切换）
    KeyboardGestureHandler.swift      P1 手势扩展口（只留协议，不挂手势）
    Info.plist                      扩展信息（com.apple.keyboard-service 主键盘配置）
    WenKeyKeyboard.entitlements     App Group
  Shared/  （双 target 共用）
    Constants.swift                   Bundle ID / App Group 常量
    PinyinEngine.swift                整行拼音 → 切分 → 组词 → 整句排序
    DictionaryData.swift              内置常用词词典（手写相对词频，见文件头说明）
    ThemeStore.swift                  分部位颜色存取（App Group UserDefaults）
    UserLearningStore.swift           自学习词频存取（P1 填）
    FeatureFlags.swift                功能开关存取（P1/P5 接开关 UI，默认全关）
    CommonPhrasesStore.swift          常用语数据存取（P4 填）
```

## P0 已实现

- 26 键 QWERTY 三行 + 底行（地球键、Shift、中英切换、空格、删除、回车）。
- 拼音模式按键显示大写字母；英文模式 Shift 大小写、双击 Shift 大写锁定。
- 整行拼音整句联想：打 `woxiangchifan` 出“我想吃饭”这类整句；候选栏前半是整句候选，
  后半（｜之后）是首音节的单字分词候选，点单字上屏后剩余音节继续留着拼。
- 删除（先删拼音字母再删正文）、空格（首选上屏 + 空格）、回车（首选上屏 / 换行）。
- 按键：连续圆角大圆角；iOS 26 用 `UIGlassEffect` 液态玻璃（走配置背景 visualEffect），低版本回落主题纯色。
- 按键缩放动画 + 轻触感（`UIImpactFeedbackGenerator`）、候选点选反馈。
- 主题分部位颜色存取已通（调色 UI 在 P5）。

## 占位点（明确未实现，不冒充功能）

| 占位 | 位置 | 说明 |
|---|---|---|
| 语音按钮 | 键盘底行 mic 键 | 置灰禁用；P3 接 Speech 离线识别（`requiresOnDeviceRecognition`） |
| 剪贴板按钮 | 键盘底行剪贴板键 | 置灰禁用；P4 接分类管理 + 面板，需手动开“允许完全访问” |
| 自学习 | `UserLearningStore` | `recordSelection` 只占位，`boostedFrequency` 恒 0；P2 填 |
| 常用语 | `CommonPhrasesStore` | `phrases()` 恒空；P4 填（触发码 → 短语，存共享区） |
| 调色 UI | 容器 App 设置页 | 只有只读展示；P5 接分部位调色 |
| 功能开关 UI | 容器 App 设置页 | 只有只读展示；P1/P5 接开关 UI |

## 给 P1 及之后留的扩展口（P0 已留好，未接通）

- **手势**：`KeyboardViewController.gestureHandler`（`KeyboardGestureHandler` 协议：空格光标、
  删词滑动、长按符号、滑行输入）；空格键、删除键已存为属性供 P1 挂手势识别器；
  `KeyButton.longPressTitle` 是长按符号的数据位。P0 不挂任何手势，打字行为不受影响。
- **候选栏滑动**：候选栏本身就是横向 `UIScrollView`，P1 接翻页/更多候选不用改结构。
- **双击空格句号 / 英文句首自动大写**：接线点在 `spaceTapped` / `letterTapped`，P1 在里面加。
- **功能开关**：`FeatureFlagStore` 已通 App Group，开关默认全关；设置页开关 UI 在 P1/P5 接。
- **常用语**：`CommonPhrasesStore` 数据形态已定（触发码 → 短语），P4 填共享区读写，
  候选栏匹配触发码时复用现有候选栏结构。

## 已知 P0 限制（不是 bug，下一轮解决）

- 词典只覆盖常用词；冷僻音节没有单字可出时，候选栏显示原文，空格原样上屏。P2 扩词库。
- 中文模式下 Shift 不参与拼音输入（按钮置灰）；P1 可再定 Shift 在中文模式的行为。
- 点分词候选只保留首选切法的剩余音节；多切法歧义时以首选为准。P2 可优化。
- 液态玻璃用 iOS 26 UIKit 的 `UIGlassEffect`（走配置背景 visualEffect；UIButton 本身没有
  glassEffect 属性，2026-11-05 CI 已证实）。

## 下一轮要补什么（按 DESIGN.md 修订后的分阶段）

1. CI 编译验证（Xcode 26）：2026-11-05 已修编译错误（底行 IUO 解包、UIGlassEffect 走
   visualEffect、segmentationLimit 改 public——公开函数的默认值只能引用公开成员），等新一轮结果。
2. P1 效率手势：滑行（英文）、空格光标、删词手势、长按符号、双击空格句号、
   自动大写、候选栏滑动——接上面留好的扩展口。
3. P2 词库与自学习 + 英文纠错联想。
4. P3 离线语音、P4 剪贴板 + 常用语、P5 主题与反馈 + 顺手功能、P6 打包安装（复用 Lowex CI 路子出 IPA）。
