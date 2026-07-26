import SwiftUI
import ServiceManagement

struct PreferencesView: View {
    @ObservedObject private var settings = Settings.shared
    @ObservedObject private var stats = Stats.shared
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var loginError: String?

    var body: some View {
        Form {
            Section {
                stepper("Focus block", value: $settings.focusMinutes, range: 5...120)
                stepper("Short break", value: $settings.breakMinutes, range: 1...30)
            }
            Section {
                stepper("Long break", value: $settings.longBreakMinutes, range: 3...60)
                stepper("Long break every", value: $settings.longBreakIntervalMinutes,
                        range: 20...240, step: 10)
            }
            Section {
                Toggle("Start at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, wanted in setLoginItem(wanted) }
                if let loginError {
                    Text(loginError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            Section {
                HStack {
                    Text("Today: \(Stats.duration(stats.todayFocus)) focused, "
                         + "\(stats.todayTaken) breaks")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Reset") { stats.resetToday() }
                        .controlSize(.small)
                }
            }
            Section {
                Text("Skipping a break halves the next focus block and doubles the next break, "
                     + "down to \(settings.minFocusMinutes) min focus and up to "
                     + "\(settings.maxBreakMinutes) min break. Finishing a break resets it.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .formStyle(.grouped)
        .frame(width: 360)
        .onChange(of: settings.focusMinutes) { _, _ in TimerEngine.shared.resetCycle() }
    }

    private func setLoginItem(_ wanted: Bool) {
        do {
            if wanted {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            loginError = nil
        } catch {
            loginError = error.localizedDescription
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }

    private func stepper(_ label: String, value: Binding<Int>,
                         range: ClosedRange<Int>, step: Int = 1) -> some View {
        Stepper(value: value, in: range, step: step) {
            HStack {
                Text(label)
                Spacer()
                Text("\(value.wrappedValue) min")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
    }
}
