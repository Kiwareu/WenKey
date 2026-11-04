import UIKit

/// P1 手势扩展口（P0 只留接口，不挂任何手势识别器、不改打字行为）。
///
/// P1 的接法：实现该协议，在 KeyboardViewController 里赋值给 `gestureHandler`，
/// 再由实现方给空格键（`spaceButton`）、删除键（`deleteButton`）、字母键
/// 挂对应的手势识别器，把事件回调到这里的方法。P0 不赋值，全部手势保持未接通。
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
