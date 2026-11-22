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
    let labelCenter: CGPoint
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

    static func place(anchor: CGPoint, safeRect: CGRect, scale: CGFloat, rtl: Bool, persistent: Bool) -> WheelPlacement {
        let selectedRadius = 0.5 * 1.4 * 48 * scale
        let inset = ceil(8 + selectedRadius)
        let allowed = safeRect.insetBy(dx: inset, dy: inset)
        for axis in WheelAxis.preference {
            for distance in stride(from: CGFloat(0), through: 120, by: 4) {
                for angle in stride(from: CGFloat(0), to: 360, by: 15) {
                    if distance == 0 && angle > 0 { continue }
                    let r = angle * .pi / 180
                    let center = CGPoint(x: anchor.x + cos(r) * distance, y: anchor.y + sin(r) * distance)
                    let items = centers(center: center, axis: axis, scale: scale, rtl: rtl)
                    guard items.allSatisfy({ allowed.contains($0) }) else { continue }
                    if !persistent && items.map({ hypot($0.x-anchor.x, $0.y-anchor.y) }).min()! < 96 { continue }
                    if persistent {
                        let close = CGRect(x: center.x - 24, y: center.y - 24, width: 48, height: 48)
                        guard safeRect.insetBy(dx: 8, dy: 8).contains(close), items.allSatisfy({ !close.intersects(CGRect(x: $0.x-24*scale, y: $0.y-24*scale, width: 48*scale, height: 48*scale)) }) else { continue }
                    }
                    if let label = labelCenter(center: center, axis: axis, items: items, safeRect: safeRect, selectedRadius: selectedRadius, scale: scale) {
                        return WheelPlacement(center: center, axis: axis, itemCenters: items, labelCenter: label, compact: false)
                    }
                }
            }
        }
        return WheelPlacement(center: anchor, axis: .up, itemCenters: [], labelCenter: .zero, compact: true)
    }

    private static func labelCenter(center: CGPoint, axis: WheelAxis, items: [CGPoint], safeRect: CGRect, selectedRadius: CGFloat, scale: CGFloat) -> CGPoint? {
        let a = axis.rawValue * .pi / 180
        let d = baseRadius * scale + 56
        let candidates = [
            CGPoint(x: center.x + sin(a)*d, y: center.y-cos(a)*d),
            CGPoint(x: center.x - sin(a)*56, y: center.y+cos(a)*56),
            CGPoint(x: safeRect.midX, y: safeRect.minY+24),
            CGPoint(x: safeRect.midX, y: safeRect.maxY-24),
        ]
        for point in candidates {
            let rect = CGRect(x: point.x-110, y: point.y-20, width: 220, height: 40)
            guard safeRect.insetBy(dx: 8, dy: 8).contains(rect) else { continue }
            if items.allSatisfy({ hypot($0.x-point.x, $0.y-point.y) > selectedRadius + 28 }) { return point }
        }
        return nil
    }
}
