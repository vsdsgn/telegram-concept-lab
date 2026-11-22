import UIKit

@MainActor protocol ReactionWheelDelegate: AnyObject {
    func wheel(_ wheel: ReactionWheelView, committed index: Int)
    func wheelCancelled(_ wheel: ReactionWheelView)
}

final class ReactionWheelView: UIView {
    weak var delegate: ReactionWheelDelegate?
    private let scrim = UIControl()
    private let plate = CAShapeLayer()
    private let label = UILabel()
    private let close = UIButton(type: .system)
    private var buttons: [UIButton] = []
    private var placement: WheelPlacement!
    private var anchor: CGPoint = .zero
    private var selected: Int?
    private var current: Int?
    private var persistent = false
    private var lastTick = Date.distantPast
    private let selectionHaptic = UISelectionFeedbackGenerator()
    private let impact = UIImpactFeedbackGenerator(style: .light)

    init(frame: CGRect, anchor: CGPoint, safeRect: CGRect, current: Int?, persistent: Bool, rtl: Bool) {
        super.init(frame: frame)
        self.anchor = anchor; self.current = current; self.persistent = persistent
        let scale = min(max(UIFontMetrics.default.scaledValue(for: 1), 1), 1.3)
        placement = WheelGeometry.place(anchor: anchor, safeRect: safeRect, scale: scale, rtl: rtl, persistent: persistent)
        accessibilityIdentifier = "wheel.root"
        if placement.compact { buildCompact(); return }
        buildRadial(scale: scale)
    }
    required init?(coder: NSCoder) { fatalError() }

    private func buildRadial(scale: CGFloat) {
        scrim.frame = bounds; scrim.backgroundColor = Palette.scrim; scrim.accessibilityIdentifier = "wheel.scrim"
        scrim.addTarget(self, action: #selector(cancel), for: .touchUpInside); addSubview(scrim)
        layer.addSublayer(plate)
        let path = UIBezierPath()
        for (i,p) in placement.itemCenters.enumerated() { i == 0 ? path.move(to: p) : path.addLine(to: p) }
        plate.path = path.cgPath; plate.strokeColor = Palette.plate.cgColor; plate.fillColor = UIColor.clear.cgColor; plate.lineWidth = 64*scale; plate.lineCap = .round
        for i in 0..<6 {
            let button = UIButton(type: .system)
            button.frame = CGRect(x: 0, y: 0, width: 48*scale, height: 48*scale); button.center = placement.itemCenters[i]
            button.backgroundColor = current == i ? Palette.selected : Palette.plate
            button.layer.cornerRadius = 24*scale
            button.titleLabel?.font = .systemFont(ofSize: 28*scale)
            button.setTitle(reactions[i].glyph, for: .normal)
            button.accessibilityLabel = "\(reactions[i].name), \(i+1) of 6"
            button.accessibilityHint = current == i ? String(format: NSLocalizedString("a11y.removeReactionNamed", comment: ""), reactions[i].name) : nil
            button.accessibilityIdentifier = "wheel.item.\(i)"; button.tag = i
            button.addTarget(self, action: #selector(itemTapped(_:)), for: .touchUpInside)
            addSubview(button); buttons.append(button)
        }
        label.text = persistent ? NSLocalizedString("wheel.choose", comment: "") : NSLocalizedString("wheel.slide", comment: "")
        label.font = .preferredFont(forTextStyle: .footnote); label.textColor = .white; label.backgroundColor = UIColor.black.withAlphaComponent(0.88)
        label.textAlignment = .center; label.numberOfLines = 2; label.layer.cornerRadius = 16; label.clipsToBounds = true
        label.bounds = CGRect(x: 0, y: 0, width: 220, height: 40); label.center = placement.labelCenter; label.accessibilityIdentifier = "wheel.label"; addSubview(label)
        if persistent {
            close.setImage(UIImage(systemName: "xmark"), for: .normal); close.accessibilityLabel = NSLocalizedString("common.close", comment: "")
            close.accessibilityIdentifier = "wheel.close"; close.frame = CGRect(x: 0, y: 0, width: 48, height: 48); close.center = placement.center
            close.addTarget(self, action: #selector(cancel), for: .touchUpInside); addSubview(close)
            accessibilityViewIsModal = true; accessibilityElements = buttons + [close]
        }
        animateOpen()
    }

    private func buildCompact() {
        scrim.frame = bounds; scrim.backgroundColor = Palette.scrim; scrim.addTarget(self, action: #selector(cancel), for: .touchUpInside); addSubview(scrim)
        let panel = UIStackView(); panel.axis = .vertical; panel.spacing = 8; panel.layoutMargins = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16); panel.isLayoutMarginsRelativeArrangement = true
        panel.backgroundColor = Palette.plate; panel.layer.cornerRadius = 20; panel.translatesAutoresizingMaskIntoConstraints = false; panel.accessibilityIdentifier = "compact.root"; addSubview(panel)
        let title = UILabel(); title.text = NSLocalizedString("wheel.choose", comment: ""); title.font = .preferredFont(forTextStyle: .headline); panel.addArrangedSubview(title)
        for i in 0..<6 { let b = UIButton(type: .system); b.tag=i; b.setTitle("\(reactions[i].glyph)  \(reactions[i].name)", for:.normal); b.heightAnchor.constraint(greaterThanOrEqualToConstant:48).isActive=true; b.addTarget(self,action:#selector(itemTapped(_:)),for:.touchUpInside); b.accessibilityIdentifier="compact.item.\(i)"; panel.addArrangedSubview(b); buttons.append(b) }
        close.setTitle(NSLocalizedString("common.close", comment: ""), for: .normal); close.heightAnchor.constraint(greaterThanOrEqualToConstant:48).isActive=true; close.addTarget(self,action:#selector(cancel),for:.touchUpInside); close.accessibilityIdentifier="compact.close"; panel.addArrangedSubview(close)
        NSLayoutConstraint.activate([panel.centerXAnchor.constraint(equalTo:centerXAnchor),panel.centerYAnchor.constraint(equalTo:centerYAnchor),panel.widthAnchor.constraint(lessThanOrEqualToConstant:320),panel.leadingAnchor.constraint(greaterThanOrEqualTo:leadingAnchor,constant:8),panel.trailingAnchor.constraint(lessThanOrEqualTo:trailingAnchor,constant:-8)])
        accessibilityViewIsModal=true; accessibilityElements=buttons+[close]
    }

    func updateFinger(_ point: CGPoint) {
        guard !persistent, !placement.compact else { return }
        let rho = hypot(point.x-anchor.x, point.y-anchor.y)
        if rho < 32 { setSelection(nil, outside: false); return }
        let distances = placement.itemCenters.map { hypot(point.x-$0.x, point.y-$0.y) }
        if let old = selected, distances[old] <= 96 {
            if let candidate = distances.enumerated().min(by: {$0.element<$1.element}), candidate.offset != old, candidate.element + 8 < distances[old], candidate.element <= 80, rho >= 44 { setSelection(candidate.offset, outside:false) }
            return
        }
        if rho >= 44, let candidate = distances.enumerated().min(by: {$0.element<$1.element}), candidate.element <= 80 { setSelection(candidate.offset, outside:false) }
        else { setSelection(nil, outside: rho >= 12) }
    }

    func finish(at point: CGPoint) {
        guard !persistent, !placement.compact else { return }
        let rho = hypot(point.x-anchor.x, point.y-anchor.y)
        if let i=selected, rho >= 32, hypot(point.x-placement.itemCenters[i].x, point.y-placement.itemCenters[i].y) <= 96 { commit(i) } else { cancel() }
    }

    private func setSelection(_ index: Int?, outside: Bool) {
        guard selected != index || outside else { return }; selected=index
        if index != nil, Date().timeIntervalSince(lastTick)>=0.085, DemoSettings.shared.hapticsEnabled { selectionHaptic.selectionChanged(); lastTick=Date() }
        label.text = index.map { current == $0 ? String(format:NSLocalizedString("wheel.remove",comment:""),reactions[$0].glyph) : reactions[$0].name } ?? (outside ? NSLocalizedString("wheel.cancel",comment:"") : NSLocalizedString("wheel.slide",comment:""))
        let reduced=DemoSettings.shared.reduceMotion
        for (i,b) in buttons.enumerated() { let s:CGFloat = reduced ? 1 : (index == nil ? 1 : (i == index ? 1.4 : 0.9)); b.layer.borderWidth = i == index ? 2 : (i == current ? 2 : 0); b.layer.borderColor=Palette.accent.cgColor; UIView.animate(withDuration:reduced ? 0.08:0.2,delay:0,usingSpringWithDamping:0.75,initialSpringVelocity:0,options:[.beginFromCurrentState,.allowUserInteraction]) { b.transform=CGAffineTransform(scaleX:s,y:s); b.alpha=outside ? 0.6:1 } }
    }
    private func animateOpen() { let reduced=DemoSettings.shared.reduceMotion; for (i,b) in buttons.enumerated() { b.alpha=0; if !reduced { b.transform=CGAffineTransform(scaleX:0.3,y:0.3) }; UIView.animate(withDuration:reduced ? 0.1:0.45,delay:reduced ? 0:Double(i)*0.03,usingSpringWithDamping:0.7,initialSpringVelocity:0,options:[.allowUserInteraction]) { b.alpha=1;b.transform = .identity } }; if persistent { DispatchQueue.main.async { UIAccessibility.post(notification:.screenChanged,argument:self.buttons.first) } } }
    @objc private func itemTapped(_ sender:UIButton){ commit(sender.tag) }
    private func commit(_ index:Int){ if DemoSettings.shared.hapticsEnabled { impact.impactOccurred() }; delegate?.wheel(self,committed:index) }
    @objc private func cancel(){ delegate?.wheelCancelled(self) }
    override func accessibilityPerformEscape() -> Bool { cancel(); return true }
    override func draw(_ rect: CGRect) {
        guard DemoSettings.shared.showHitZones, placement?.compact == false, let context = UIGraphicsGetCurrentContext() else { return }
        context.saveGState(); context.setLineWidth(1); context.setStrokeColor(UIColor.systemPink.withAlphaComponent(0.7).cgColor)
        for radius in [CGFloat(12), 32, 44] { context.strokeEllipse(in: CGRect(x: anchor.x-radius, y: anchor.y-radius, width: radius*2, height: radius*2)) }
        context.setStrokeColor(UIColor.systemTeal.withAlphaComponent(0.65).cgColor)
        for point in placement.itemCenters { context.strokeEllipse(in: CGRect(x: point.x-80, y: point.y-80, width: 160, height: 160)) }
        context.restoreGState()
    }
}
