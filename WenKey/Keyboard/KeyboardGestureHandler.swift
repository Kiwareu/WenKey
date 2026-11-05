import UIKit

/// P1 手势扩展口（P1 已接通：KeyboardViewController 实现该协议，
/// setupP1Gestures() 里赋值并给空格键、删除键、字母键挂手势识别器）。
///
/// 协议方法是事件回调：识别器翻译层（控制器里的 *Changed 方法）把原始手势
/// 转成这里的方法，真正的光标/删词/面板/滑行逻辑在实现里。
/// 开关门控在手势代理 shouldBegin 里做，不在协议方法里重复判断。
protocol KeyboardGestureHandler: AnyObject {
    /// 空格键长按变触控板：滑动增量（pt，正值向右），P1 据此移动光标。
    func spaceCursorMoved(deltaX: CGFloat)
    /// 空格触控板手势结束。
    func spaceCursorEnded()
    /// 删除键左滑批量删词：滑动增量（pt，负值向左），P1 按词扩展选中范围；右滑缩减。
    func deleteSwipeMoved(deltaX: CGFloat)
    /// 删词滑动手势结束，committed 表示松手是否执行删除。
    func deleteSwipeEnded(committed: Bool)
    /// 字母键长按出符号：P1 弹符号面板；这里只回调被长按的字母。
    func keyLongPressed(letter: String)
    /// 滑行输入（英文模式）：手指轨迹依次经过的字母，P1 做单词匹配。
    func glidePathUpdated(letters: [String])
    /// 滑行手势结束（手指抬起），P1 确认联想词。
    func glidePathEnded()
}
