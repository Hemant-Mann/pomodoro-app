import Foundation

/// Break nags, and a tiny cowsay so they arrive with a bit of personality.
enum Quotes {

    static let shortBreak = [
        "Your eyes have been eating pixels for a while. Blink. Twice.",
        "The bug will still be there in a few minutes. It's patient like that.",
        "Stand up. Your spine has filed a formal complaint.",
        "Look at something 20 feet away for 20 seconds. Your retinas insist.",
        "Unclench your jaw. Drop your shoulders. There you go.",
        "You are not a compiler. You're allowed to stop.",
        "Hydrate. Coffee doesn't count, and you know it.",
        "Roll your shoulders back. Yes, right now, while I'm watching.",
        "Even the CPU throttles itself. Be more like the CPU.",
        "Three minutes off now beats thirty minutes of brain fog later.",
        "Breathe out slowly. Longer than you think. Nice.",
        "That thing you're stuck on? Breaks are where the fix shows up.",
        "Wrists off the keyboard. Shake them out like you mean it.",
        "The screen will keep glowing without your supervision.",
        "Your neck isn't supposed to bend like that. Fix it.",
        "Shake out your hands. You've been gripping the mouse like it owes you money.",
        "Refill the water. Yes, the one you forgot about an hour ago.",
        "Close your eyes for ten seconds. Free reset, no reboot required.",
        "Step outside for a second. The sun still exists.",
        "That variable name you're agonizing over? Still bad in five minutes. Rest first.",
        "Stretch your fingers. They've been doing all the work while you sat still.",
        "Your posture just filed a second complaint. It's escalating.",
    ]

    static let longBreak = [
        "An hour down. Stand up and walk — your legs are not decorative.",
        "Time to stretch. The chair will cope without you, somehow.",
        "Go take a lap. The best debugger is a hallway.",
        "Sixty minutes of focus just bought you ten minutes of being a human.",
        "Walk to a window. Look far away. Real depth of field!",
        "Your hips have been at 90 degrees for an hour. Go negotiate.",
        "Stretch, walk, drink water. In that order. Off you go.",
        "Ten minutes on your feet now, or a stiff neck at midnight. Choose.",
        "Make a snack. A real one, not just more coffee.",
        "Lie down for a minute. Horizontal is a valid posture.",
        "Do a lap around the block. Your legs remember how, promise.",
        "Text a friend something that isn't a screenshot of an error.",
        "Look at literally anything that isn't backlit.",
    ]

    static func message(for phase: Phase) -> String {
        let pool = phase == .longBreak ? longBreak : shortBreak
        return pool.randomElement() ?? "Take a break."
    }

    /// Short line for the notification banner.
    static func notificationTitle(for phase: Phase) -> String {
        phase == .longBreak ? "Time to stretch your legs" : "Break time"
    }

    // MARK: - cowsay

    private static let cows = [
        """
        \\   ^__^
         \\  (oo)\\_______
            (__)\\       )\\/\\
                ||----w |
                ||     ||
        """,
        """
        \\   ^__^
         \\  (--)\\_______
            (__)\\       )\\/\\
                ||----w |
                ||     ||
        """,
        """
        \\    ,__,
         \\   (oo)____
             (__)    )\\
                ||--|| *
        """,
    ]

    static func randomCow() -> String {
        cows.randomElement() ?? cows[0]
    }

    /// Renders text in a cowsay speech bubble. Wraps at `width` columns. `cow` is passed in
    /// rather than picked here so a caller re-rendering on every tick doesn't reroll it and
    /// resize the bubble underneath itself.
    static func cowsay(_ text: String, cow: String, width: Int = 42) -> String {
        let lines = wrap(text, width: width)
        let inner = lines.map(\.count).max() ?? 0

        var out = " " + String(repeating: "_", count: inner + 2)

        if lines.count == 1 {
            out += "\n< " + lines[0].padded(to: inner) + " >"
        } else {
            for (i, line) in lines.enumerated() {
                let (l, r): (String, String)
                switch i {
                case 0: (l, r) = ("/", "\\")
                case lines.count - 1: (l, r) = ("\\", "/")
                default: (l, r) = ("|", "|")
                }
                out += "\n\(l) " + line.padded(to: inner) + " \(r)"
            }
        }

        out += "\n " + String(repeating: "-", count: inner + 2)
        out += "\n" + cow.split(separator: "\n").map { "        " + $0 }.joined(separator: "\n")
        return out
    }

    private static func wrap(_ text: String, width: Int) -> [String] {
        var lines: [String] = []
        var current = ""
        for word in text.split(separator: " ") {
            if current.isEmpty {
                current = String(word)
            } else if current.count + 1 + word.count <= width {
                current += " " + word
            } else {
                lines.append(current)
                current = String(word)
            }
        }
        if !current.isEmpty { lines.append(current) }
        return lines.isEmpty ? [""] : lines
    }
}

private extension String {
    func padded(to width: Int) -> String {
        self + String(repeating: " ", count: max(width - count, 0))
    }
}
