import SwiftUI

/// The panel shown when the menu bar item is clicked.
struct DashboardView: View {
    @ObservedObject var engine = TimerEngine.shared
    @ObservedObject var stats = Stats.shared
    let onPreferences: () -> Void
    let onQuit: () -> Void

    private var stateLabel: String {
        if engine.phase == .idle { return "Stopped" }
        if engine.isPaused { return "Paused" }
        switch engine.phase {
        case .focus: return "Focusing"
        case .shortBreak: return "Short break"
        case .longBreak: return "Long break"
        case .idle: return "Stopped"
        }
    }

    private var accent: Color {
        switch engine.phase {
        case .idle: return .secondary
        case .focus: return Color(red: 0.46, green: 0.58, blue: 0.98)
        case .shortBreak: return Color(red: 0.42, green: 0.84, blue: 0.86)
        case .longBreak: return Color(red: 1.00, green: 0.72, blue: 0.30)
        }
    }

    private var blockLabel: String {
        guard engine.phase != .idle else { return "Press Start to begin a session" }
        var parts = ["\(Int((engine.blockDuration / 60).rounded())) min block"]
        if engine.phase == .focus {
            parts.append("long break in \(engine.minutesUntilLongBreak) min")
        }
        if engine.skipStreak > 0 {
            parts.append("\(engine.skipStreak) skipped in a row")
        }
        return parts.joined(separator: " · ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            progressBar

            Text(blockLabel)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            Divider()

            section("TODAY") {
                row("Focused", Stats.duration(stats.todayFocus))
                row("Breaks taken", "\(stats.todayTaken)")
                row("Breaks skipped", "\(stats.todaySkipped)")
            }

            section("ALL TIME") {
                row("Focused", Stats.duration(stats.allFocus))
                row("Breaks taken", "\(stats.allTaken)")
            }

            Divider()

            controls
            footer
        }
        .padding(16)
        .frame(width: 268)
    }

    // MARK: - Pieces

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(stateLabel)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
            Spacer()
            Text(engine.phase == .idle ? "--:--" : clock(engine.remaining))
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(accent)
        }
    }

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(.quaternary)
                Capsule()
                    .fill(accent)
                    .frame(width: geo.size.width * engine.progress)
                    .animation(.linear(duration: 0.5), value: engine.progress)
            }
        }
        .frame(height: 6)
    }

    private var controls: some View {
        HStack(spacing: 8) {
            if engine.phase == .idle {
                action("Start", filled: true) { engine.startSession() }
            } else {
                action(engine.isPaused ? "Resume" : "Pause") { engine.togglePause() }

                if engine.phase.isBreak {
                    action("Skip") { engine.skipBreak() }
                } else {
                    action("Break") { engine.breakNow() }
                }

                action("Stop") { engine.stopSession() }
            }
        }
    }

    private var footer: some View {
        HStack {
            linkButton("Preferences…", action: onPreferences)
            Spacer()
            linkButton("Quit", action: onQuit)
        }
    }

    // MARK: - Building blocks

    private func section<Content: View>(_ title: String,
                                        @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.tertiary)
                .kerning(0.6)
            content()
        }
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 12, weight: .medium))
                .monospacedDigit()
        }
    }

    private func action(_ title: String, filled: Bool = false,
                        run: @escaping () -> Void) -> some View {
        Button(action: run) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 7)
                        .fill(filled ? Color(red: 0.24, green: 0.70, blue: 0.44)
                                     : Color.primary.opacity(0.08))
                )
                .foregroundStyle(filled ? .white : .primary)
        }
        .buttonStyle(.plain)
    }

    private func linkButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
    }

    private func clock(_ t: TimeInterval) -> String {
        let total = Int(t.rounded(.up))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
