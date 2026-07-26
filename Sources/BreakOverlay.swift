import SwiftUI
import AppKit

/// Real desktop blur behind the overlay.
struct VisualEffectBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }
    func updateNSView(_ view: NSVisualEffectView, context: Context) {}
}

struct BreakOverlay: View {
    @ObservedObject var engine = TimerEngine.shared
    /// Held steady for the whole break so the message doesn't reshuffle every tick.
    let message: String
    let onSkip: () -> Void

    @State private var appeared = false

    private var isLong: Bool { engine.phase == .longBreak }

    private var accent: [Color] {
        isLong
            ? [Color(red: 1.00, green: 0.72, blue: 0.30), Color(red: 0.98, green: 0.45, blue: 0.42)]
            : [Color(red: 0.42, green: 0.84, blue: 0.86), Color(red: 0.46, green: 0.58, blue: 0.98)]
    }

    private var heading: String {
        isLong ? "Stretch your legs" : "Take a breath"
    }

    private var subheading: String {
        if isLong { return "You've focused for an hour. Stand up and walk it off." }
        if engine.skipStreak > 0 {
            return "Skipped \(engine.skipStreak) break\(engine.skipStreak == 1 ? "" : "s") — this one is longer."
        }
        return "Step away from the screen for a moment."
    }

    var body: some View {
        ZStack {
            VisualEffectBackground().ignoresSafeArea()

            LinearGradient(colors: accent.map { $0.opacity(0.22) },
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
                .blendMode(.plusLighter)

            VStack(spacing: 34) {
                VStack(spacing: 8) {
                    Text(heading)
                        .font(.system(size: 42, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)
                    Text(subheading)
                        .font(.system(size: 15, weight: .regular, design: .rounded))
                        .foregroundStyle(.secondary)
                }

                ring

                Text(Quotes.cowsay(message))
                    .font(.system(size: 13, weight: .regular, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineSpacing(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize()

                Button(action: onSkip) {
                    Text("Skip this break")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 9)
                        .background(Capsule().fill(.white.opacity(0.10)))
                        .overlay(Capsule().stroke(.white.opacity(0.18), lineWidth: 1))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Next focus block gets shorter and the next break gets longer.")
            }
            .padding(60)
            .scaleEffect(appeared ? 1 : 0.94)
            .opacity(appeared ? 1 : 0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.82)) { appeared = true }
        }
    }

    private var ring: some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(0.10), lineWidth: 14)

            Circle()
                .trim(from: 0, to: engine.progress)
                .stroke(
                    AngularGradient(colors: accent + [accent[0]], center: .center),
                    style: StrokeStyle(lineWidth: 14, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.5), value: engine.progress)

            VStack(spacing: 2) {
                Text(format(engine.remaining))
                    .font(.system(size: 52, weight: .medium, design: .rounded))
                    .monospacedDigit()
                Text("remaining")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(width: 220, height: 220)
    }

    private func format(_ t: TimeInterval) -> String {
        let total = Int(t.rounded(.up))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
