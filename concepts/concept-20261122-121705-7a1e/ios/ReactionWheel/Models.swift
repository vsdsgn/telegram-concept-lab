import UIKit

struct Reaction: Equatable {
    let glyph: String
    let name: String
}

let reactions = [
    Reaction(glyph: "👍", name: NSLocalizedString("reaction.like", comment: "")),
    Reaction(glyph: "❤️", name: NSLocalizedString("reaction.love", comment: "")),
    Reaction(glyph: "😂", name: NSLocalizedString("reaction.laugh", comment: "")),
    Reaction(glyph: "😮", name: NSLocalizedString("reaction.wow", comment: "")),
    Reaction(glyph: "😢", name: NSLocalizedString("reaction.sad", comment: "")),
    Reaction(glyph: "🔥", name: NSLocalizedString("reaction.fire", comment: "")),
]

struct Message: Equatable {
    let id: Int
    let sender: String
    let text: String
    let time: String
    let outgoing: Bool
    var reactionIndex: Int?
}

enum DemoMessages {
    static let all: [Message] = [
        Message(id: 0, sender: "Alex", text: "Are we still on for the park this weekend?", time: "10:32", outgoing: false),
        Message(id: 1, sender: NSLocalizedString("sender.you", comment: ""), text: "Yes! Saturday morning works for me.", time: "10:34", outgoing: true),
        Message(id: 2, sender: "Sam", text: "I can bring coffee and those cinnamon rolls from the corner bakery.", time: "10:35", outgoing: false),
        Message(id: 3, sender: NSLocalizedString("sender.you", comment: ""), text: "Perfect. I’ll pack a blanket.", time: "10:36", outgoing: true),
        Message(id: 4, sender: "Robin", text: "🌤️", time: "10:37", outgoing: false),
        Message(id: 5, sender: "Alex", text: "The forecast says clear skies until late afternoon.", time: "10:38", outgoing: false),
        Message(id: 6, sender: NSLocalizedString("sender.you", comment: ""), text: "I also finished the release notes for our imaginary app: faster startup, clearer empty states, and a tiny celebration when a task is completed.", time: "10:40", outgoing: true),
        Message(id: 7, sender: "Sam", text: "That sounds delightful.", time: "10:41", outgoing: false),
        Message(id: 8, sender: "Robin", text: "Should we invite Casey too?", time: "10:42", outgoing: false),
        Message(id: 9, sender: NSLocalizedString("sender.you", comment: ""), text: "Absolutely — I’ll send a message now.", time: "10:43", outgoing: true),
        Message(id: 10, sender: "Alex", text: "Recipe reminder: two cups of flour, one cup of yogurt, a pinch of salt, then bake until golden.", time: "10:44", outgoing: false),
        Message(id: 11, sender: "Sam", text: "See everyone Saturday!", time: "10:45", outgoing: false),
    ]
}

extension Message {
    init(id: Int, sender: String, text: String, time: String, outgoing: Bool) {
        self.init(id: id, sender: sender, text: text, time: time, outgoing: outgoing, reactionIndex: nil)
    }
}

enum ThemeChoice: Int { case system, light, dark }

@MainActor final class DemoSettings {
    static let shared = DemoSettings()
    var theme: ThemeChoice = .system
    var reduceMotionOverride = false
    var hapticsEnabled = true
    var showHitZones = false
    var reduceMotion: Bool { reduceMotionOverride || UIAccessibility.isReduceMotionEnabled }
}
