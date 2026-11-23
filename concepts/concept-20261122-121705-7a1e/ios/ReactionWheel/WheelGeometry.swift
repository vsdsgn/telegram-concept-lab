import CoreGraphics

enum WheelAxis: CGFloat, CaseIterable {
    case up = 0, upRight = 45, right = 90, downRight = 135
    case down = 180, downLeft = 225, left = 270, upLeft = 315
    static let preference: [WheelAxis] = [.up, .down, .right, .left, .downRight, .downLeft, .upRight, .upLeft]
}

struct WheelPlacement {
    let center: CGPoint
    let axis: WheelAxis
    let itemCenters: [CGPoint]
    let labelFrame: CGRect
    let compact: Bool
}

enum WheelGeometry {
    static let baseRadius: CGFloat = 108

    static func centers(center: CGPoint, axis: WheelAxis, scale: CGFloat, rtl: Bool) -> [CGPoint] {
        let radius = baseRadius * scale
        let a = axis.rawValue * .pi / 180
        let direction = CGPoint(x: sin(a), y: -cos(a))
        let horizontalOrder = abs(direction.x) > 0.9
        let desired = horizontalOrder ? CGPoint(x: 0, y: 1) : CGPoint(x: rtl ? -1 : 1, y: 0)
        let tangentAtZero = CGPoint(x: cos(a), y: sin(a))
        let sigma: CGFloat = tangentAtZero.x * desired.x + tangentAtZero.y * desired.y >= 0 ? 1 : -1
        return (0..<6).map { index in
            let phi = (-90 + CGFloat(index) * 36) * .pi / 180
            let theta = a + sigma * phi
            return CGPoint(x: center.x + radius * sin(theta), y: center.y - radius * cos(theta))
        }
    }

    static func place(anchor: CGPoint, safeRect: CGRect, scale: CGFloat, rtl: Bool, persistent: Bool, labelSize: CGSize = CGSize(width: 220, height: 40)) -> WheelPlacement {
        let selectedRadius = 0.5 * 1.4 * 48 * scale
        let allowed = safeRect.insetBy(dx: ceil(8 + selectedRadius), dy: ceil(8 + selectedRadius))
        var fallbacks: [(distance: CGFloat, order: Int, placement: WheelPlacement)] = []
        for (order, axis) in WheelAxis.preference.enumerated() {
            let offsets = centers(center: .zero, axis: axis, scale: scale, rtl: rtl)
            var feasible = CGRect(x: -10_000, y: -10_000, width: 20_000, height: 20_000)
            for offset in offsets {
                feasible = feasible.intersection(CGRect(x: allowed.minX - offset.x, y: allowed.minY - offset.y, width: allowed.width, height: allowed.height))
            }
            guard !feasible.isNull, !feasible.isEmpty else { continue }
            let center = CGPoint(x: min(max(anchor.x, feasible.minX), feasible.maxX), y: min(max(anchor.y, feasible.minY), feasible.maxY))
            let distance = hypot(center.x - anchor.x, center.y - anchor.y)
            guard distance <= 120 else { continue }
            let items = centers(center: center, axis: axis, scale: scale, rtl: rtl)
            guard persistent || items.allSatisfy({ hypot($0.x - anchor.x, $0.y - anchor.y) >= 96 }) else { continue }
            let closeFrame = CGRect(x: center.x - 24, y: center.y - 24, width: 48, height: 48)
            if persistent {
                guard safeRect.insetBy(dx: 8, dy: 8).contains(closeFrame),
                      items.allSatisfy({ !closeFrame.intersects(itemBox(center: $0, scale: scale)) }),
                      boxesAreDisjoint(items.map { itemBox(center: $0, scale: scale) }) else { continue }
            }
            guard let labelFrame = labelFrame(center: center, axis: axis, items: items, safeRect: safeRect, selectedRadius: selectedRadius, scale: scale, size: labelSize, closeFrame: persistent ? closeFrame : nil) else { continue }
            let placement = WheelPlacement(center: center, axis: axis, itemCenters: items, labelFrame: labelFrame, compact: false)
            if distance <= 24 { return placement }
            fallbacks.append((distance, order, placement))
        }
        if let best = fallbacks.min(by: { $0.distance == $1.distance ? $0.order < $1.order : $0.distance < $1.distance }) { return best.placement }
        return WheelPlacement(center: anchor, axis: .up, itemCenters: [], labelFrame: .zero, compact: true)
    }

    private static func itemBox(center: CGPoint, scale: CGFloat) -> CGRect {
        CGRect(x: center.x - 24 * scale, y: center.y - 24 * scale, width: 48 * scale, height: 48 * scale)
    }

    private static func boxesAreDisjoint(_ boxes: [CGRect]) -> Bool {
        for i in boxes.indices { for j in boxes.indices where j > i { if boxes[i].intersects(boxes[j]) { return false } } }
        return true
    }

    private static func labelFrame(center: CGPoint, axis: WheelAxis, items: [CGPoint], safeRect: CGRect, selectedRadius: CGFloat, scale: CGFloat, size: CGSize, closeFrame: CGRect?) -> CGRect? {
        let a = axis.rawValue * .pi / 180
        let d = baseRadius * scale + 56
        let safe = safeRect.insetBy(dx: 8, dy: 8)
        let candidates = [
            CGPoint(x: center.x + sin(a) * d, y: center.y - cos(a) * d),
            CGPoint(x: center.x - sin(a) * 56, y: center.y + cos(a) * 56),
            CGPoint(x: safe.midX, y: safe.minY + size.height / 2),
            CGPoint(x: safe.midX, y: safe.maxY - size.height / 2),
        ]
        for point in candidates {
            let rect = CGRect(x: point.x - size.width / 2, y: point.y - size.height / 2, width: size.width, height: size.height).integral
            guard safe.contains(rect), closeFrame.map({ !$0.intersects(rect) }) ?? true else { continue }
            guard items.allSatisfy({ !circle(center: $0, radius: selectedRadius, intersects: rect) }) else { continue }
            return rect
        }
        return nil
    }

    private static func circle(center: CGPoint, radius: CGFloat, intersects rect: CGRect) -> Bool {
        let closest = CGPoint(x: min(max(center.x, rect.minX), rect.maxX), y: min(max(center.y, rect.minY), rect.maxY))
        return hypot(center.x - closest.x, center.y - closest.y) < radius
    }
}
