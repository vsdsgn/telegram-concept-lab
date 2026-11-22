import UIKit

final class ChatViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, UIGestureRecognizerDelegate, MessageCellDelegate, ReactionWheelDelegate {
    private let table = UITableView(frame: .zero, style: .plain)
    private var messages = DemoMessages.all
    private var wheel: ReactionWheelView?
    private var activeIndex: Int?
    private var longPress: UILongPressGestureRecognizer!

    override func viewDidLoad() {
        super.viewDidLoad()
        title = NSLocalizedString("app.title", comment: "")
        view.backgroundColor = Palette.chat
        navigationItem.rightBarButtonItem = UIBarButtonItem(image: UIImage(systemName: "gearshape"), style: .plain, target: self, action: #selector(openSettings))
        navigationItem.rightBarButtonItem?.accessibilityLabel = NSLocalizedString("settings.accessibility", comment: "")
        navigationItem.rightBarButtonItem?.accessibilityIdentifier = "settings.open"
        let banner = makeInfoLabel(NSLocalizedString("demo.banner", comment: ""), id: "chat.banner")
        let hint = makeInfoLabel(NSLocalizedString("demo.hint", comment: ""), id: "chat.hint")
        let stack = UIStackView(arrangedSubviews: [banner, hint, table]); stack.axis = .vertical; stack.translatesAutoresizingMaskIntoConstraints = false; view.addSubview(stack)
        NSLayoutConstraint.activate([stack.leadingAnchor.constraint(equalTo:view.leadingAnchor),stack.trailingAnchor.constraint(equalTo:view.trailingAnchor),stack.topAnchor.constraint(equalTo:view.safeAreaLayoutGuide.topAnchor),stack.bottomAnchor.constraint(equalTo:view.bottomAnchor)])
        table.backgroundColor = Palette.chat; table.separatorStyle = .none; table.dataSource=self; table.delegate=self; table.register(MessageCell.self, forCellReuseIdentifier:MessageCell.reuseID); table.accessibilityIdentifier="chat.list"; table.keyboardDismissMode = .interactive
        longPress=UILongPressGestureRecognizer(target:self,action:#selector(handleLongPress(_:))); longPress.minimumPressDuration=0.35; longPress.allowableMovement=10; longPress.cancelsTouchesInView=true; longPress.delaysTouchesBegan=false; longPress.delegate=self; table.addGestureRecognizer(longPress)
        NotificationCenter.default.addObserver(self, selector:#selector(interrupted), name:UIApplication.willResignActiveNotification, object:nil)
        DispatchQueue.main.async { self.table.scrollToRow(at:IndexPath(row:self.messages.count-1,section:0),at:.bottom,animated:false) }
    }
    private func makeInfoLabel(_ text:String,id:String)->UILabel { let l=UILabel();l.text=text;l.textAlignment = .center;l.numberOfLines=0;l.font = .preferredFont(forTextStyle:.caption1);l.textColor=Palette.secondary;l.backgroundColor=Palette.chat;l.accessibilityIdentifier=id;l.setContentHuggingPriority(.required,for:.vertical);l.layoutMargins=UIEdgeInsets(top:6,left:16,bottom:6,right:16);return l }
    func tableView(_ tableView:UITableView,numberOfRowsInSection section:Int)->Int{messages.count}
    func tableView(_ tableView:UITableView,cellForRowAt indexPath:IndexPath)->UITableViewCell { let cell=tableView.dequeueReusableCell(withIdentifier:MessageCell.reuseID,for:indexPath) as! MessageCell;cell.configure(messages[indexPath.row]);cell.delegate=self;return cell }
    func gestureRecognizer(_ gestureRecognizer:UIGestureRecognizer,shouldReceive touch:UITouch)->Bool { guard !table.isDecelerating else{return false};let point=touch.location(in:table);guard let index=table.indexPathForRow(at:point),let cell=table.cellForRow(at:index) as? MessageCell else{return false};return cell.bubbleView.frame.contains(touch.location(in:cell)) }
    @objc private func handleLongPress(_ g:UILongPressGestureRecognizer){ let p=g.location(in:view);switch g.state { case .began: guard let ip=table.indexPathForRow(at:g.location(in:table)),let cell=table.cellForRow(at:ip) as? MessageCell else{return};activeIndex=ip.row;cell.setLifted(true);table.isScrollEnabled=false;openWheel(anchor:p,persistent:false)
        case .changed: wheel?.updateFinger(p)
        case .ended: wheel?.finish(at:p)
        case .cancelled,.failed: cancelWheel(animated:false)
        default:break } }
    private func openWheel(anchor:CGPoint,persistent:Bool){ cancelWheel(animated:false);guard let window=view.window else{return};let safe=window.bounds.inset(by:window.safeAreaInsets);let w=ReactionWheelView(frame:view.bounds,anchor:anchor,safeRect:safe,current:activeIndex.flatMap{messages[$0].reactionIndex},persistent:persistent,rtl:view.effectiveUserInterfaceLayoutDirection == .rightToLeft);w.delegate=self;view.addSubview(w);wheel=w;if DemoSettings.shared.hapticsEnabled{UIImpactFeedbackGenerator(style:.medium).impactOccurred()} }
    func wheel(_ wheel:ReactionWheelView,committed index:Int){ guard let row=activeIndex else{return};let old=messages[row].reactionIndex;messages[row].reactionIndex = old == index ? nil:index;let announcement:String;if old == index { announcement=NSLocalizedString("announce.removed",comment:"") } else if old == nil { announcement=String(format:NSLocalizedString("announce.added",comment:""),reactions[index].name) } else { announcement=String(format:NSLocalizedString("announce.changed",comment:""),reactions[index].name) };finishWheel(row:row,announcement:announcement) }
    func wheelCancelled(_ wheel:ReactionWheelView){cancelWheel(animated:true)}
    private func finishWheel(row:Int,announcement:String){let ip=IndexPath(row:row,section:0);table.reloadRows(at:[ip],with:DemoSettings.shared.reduceMotion ? .none:.fade);cancelWheel(animated:true);DispatchQueue.main.asyncAfter(deadline:.now()+0.12){UIAccessibility.post(notification:.announcement,argument:announcement);if let cell=self.table.cellForRow(at:ip) as? MessageCell{UIAccessibility.post(notification:.layoutChanged,argument:cell.bubbleView)}}}
    private func cancelWheel(animated:Bool){guard let w=wheel else{table.isScrollEnabled=true;return};wheel=nil;table.isScrollEnabled=true;let completion: () -> Void = {w.removeFromSuperview()};if animated{UIView.animate(withDuration:DemoSettings.shared.reduceMotion ? 0.1:0.16,animations:{w.alpha=0},completion:{_ in completion()})}else{completion()} }
    @objc private func interrupted(){cancelWheel(animated:false)}
    override func viewWillTransition(to size:CGSize,with coordinator:UIViewControllerTransitionCoordinator){cancelWheel(animated:false);super.viewWillTransition(to:size,with:coordinator)}
    func messageCellDidTapReaction(_ cell:MessageCell){guard let ip=table.indexPath(for:cell) else{return};messages[ip.row].reactionIndex=nil;finishWheel(row:ip.row,announcement:NSLocalizedString("announce.removed",comment:""))}
    func messageCellDidRequestPicker(_ cell:MessageCell){guard let ip=table.indexPath(for:cell) else{return};activeIndex=ip.row;let rect=cell.bubbleView.convert(cell.bubbleView.bounds,to:view);openWheel(anchor:CGPoint(x:rect.midX,y:rect.midY),persistent:true)}
    @objc private func openSettings(){let s=SettingsViewController();s.onChange={ [weak self] in self?.applyTheme();self?.table.reloadData() };s.onReset={ [weak self] in guard let self else{return};for i in messages.indices{messages[i].reactionIndex=nil};table.reloadData() };let nav=UINavigationController(rootViewController:s);if let sheet=nav.sheetPresentationController{sheet.detents=[.medium()]};present(nav,animated:true)}
    private func applyTheme(){let style:UIUserInterfaceStyle=switch DemoSettings.shared.theme{case .system:.unspecified;case .light:.light;case .dark:.dark};view.window?.overrideUserInterfaceStyle=style}
}
