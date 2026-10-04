import CoreGraphics
import Foundation

/// 手势阶段（计划书 6.1）。
enum GesturePhase: Equatable {
    case idle
    case possibleHorizontalSwipe
    case possibleVerticalMark
    case pinching
    case panning
    case animating
}

/// 手势仲裁参数（计划书 6.3 的初始阈值，未真机验证，需调参）。
struct GestureThresholds {
    var horizontalSwipeThreshold: CGFloat = 80
    var verticalMarkThreshold: CGFloat = 100
    /// 主运动方向优势：|主轴| >= 次轴 * dominanceRatio 才算方向明确
    var dominanceRatio: CGFloat = 1.3
    var maxZoom: CGFloat = 4
    var minZoom: CGFloat = 1
}

/// 手势仲裁结论：手势结束后允许执行的意图。
enum GestureDecision: Equatable {
    case next
    case previous
    case markForDeletion
    case none
}

/// 手势协调器（计划书 4.3）。纯逻辑仲裁，不直接调用 PhotoKit，不操作 UI。
///
/// 规则要点：
/// - 方向强制约定：水平向左 = 下一张；水平向右 = 上一张；垂直向上 = 标记待删除。
/// - 放大状态（scale > 1）下单指拖动只平移，绝不触发切换或标记（计划书 6.5）。
/// - 意图不明确时返回 `.none`，宁可取消识别也不猜测用户想删除（计划书 6.4）。
/// - 动画期间（isAnimating）锁定一切手势。
struct GestureCoordinator {
    var thresholds = GestureThresholds()

    private(set) var phase: GesturePhase = .idle
    /// 缩放比例接近 1 视为未放大
    var zoomScale: CGFloat = 1
    var isAnimating: Bool = false
    var isCommittingDeletion: Bool = false

    var isZoomed: Bool { zoomScale > thresholds.minZoom + 0.001 }

    // MARK: - 结束判定

    /// 手指抬起时调用，基于累计位移判定意图。
    func decideEndGesture(translation: CGSize) -> GestureDecision {
        // 动画或删除提交期间：锁定
        if isAnimating || isCommittingDeletion { return .none }

        let dx = translation.width
        let dy = translation.height
        let adx = abs(dx)
        let ady = abs(dy)

        // 放大状态下拖动：只平移
        if isZoomed { return .none }

        // 方向优势判定：斜向拖动意图不明时取消识别
        guard adx >= ady * thresholds.dominanceRatio || ady >= adx * thresholds.dominanceRatio else {
            return .none
        }

        if ady > adx {
            // 垂直主导：仅向上且达到阈值 → 标记
            guard dy < 0, ady >= thresholds.verticalMarkThreshold else { return .none }
            return .markForDeletion
        } else {
            // 水平主导：左滑（dx<0）下一张；右滑（dx>0）上一张
            guard adx >= thresholds.horizontalSwipeThreshold else { return .none }
            return dx < 0 ? .next : .previous
        }
    }

    // MARK: - 双指缩放

    /// 双指捏合时的缩放钳制。放大状态本身不触发切换/标记。
    mutating func updatePinch(scale: CGFloat) -> CGFloat {
        phase = .pinching
        return min(max(scale * 1, thresholds.minZoom), thresholds.maxZoom)
    }

    mutating func beginPinch() { phase = .pinching }
    mutating func beginPan() { phase = isZoomed ? .panning : phase }
    mutating func beginAnimation() { phase = .animating }
    mutating func endAnimation() { phase = .idle }
    mutating func reset() { phase = .idle }
}
