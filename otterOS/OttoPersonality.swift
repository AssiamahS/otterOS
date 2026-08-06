import Foundation

/// Otto's voice: eager, proud, never guilt-tripping. Lines rotate daily so the
/// greeting doesn't go stale, keyed off day-of-year so it's stable within a day.
enum OttoPersonality {
    private static var daySeed: Int {
        Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1
    }

    private static func pick(_ lines: [String]) -> String {
        lines[daySeed % lines.count]
    }

    static func greeting(name: String, hour: Int) -> String {
        let base = hour < 12 ? "Morning" : hour < 17 ? "Afternoon" : "Evening"
        return "\(base), \(name)."
    }

    static func pitch(openCount: Int, firstTitle: String?, doneToday: Int, streak: Int) -> String {
        if openCount == 0 && doneToday > 0 {
            return pick([
                "List is CLEAR. That's a sunrise-worthy day.",
                "Everything crossed off. I'm doing a little otter spin.",
                "Clean slate. You and me — unstoppable.",
                "All done. Honestly? Showing off at this point.",
            ])
        }
        if openCount == 0 {
            return pick([
                "Nothing on the list. Add one thing and let's pounce on it.",
                "Empty list. Give me something to chase.",
                "I'm stretched and ready. What are we crossing off today?",
            ])
        }
        guard let title = firstTitle else { return "Let's get after it." }
        return pick([
            "Let's knock out “\(title)” — I want this one gone.",
            "First up: “\(title)”. I've been staring at it all night.",
            "“\(title)” first? Say the word and it's history.",
            "I picked “\(title)” for us. Small bite, big momentum.",
        ])
    }

    static func streakLine(_ streak: Int) -> String? {
        switch streak {
        case 0, 1: return nil
        case 2...4: return "🔥 \(streak)-day streak"
        case 5...9: return "🔥 \(streak) days straight — Otto is STRUTTING"
        default: return "🔥 \(streak)-day streak. Legendary."
        }
    }

    static func carriedLine(_ count: Int) -> String? {
        guard count > 0 else { return nil }
        return pick([
            "Carried \(count) over from yesterday — fresh start, zero guilt.",
            "\(count) rolled over. Yesterday's history; today's ours.",
            "Brought \(count) along. We finish stories, not feel bad about them.",
        ])
    }
}
