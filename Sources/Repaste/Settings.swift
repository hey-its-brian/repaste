import AppKit
import Combine
import ServiceManagement
import SwiftUI
import RepasteCore

enum SettingsKey {
    static let historyLimit = "historyLimit"
    static let autoPaste = "autoPaste"
}

enum SettingsDefaults {
    static let historyLimit = 20

    static func register() {
        UserDefaults.standard.register(defaults: [
            SettingsKey.historyLimit: historyLimit,
            SettingsKey.autoPaste: false,
        ])
    }
}

struct SettingsView: View {
    @AppStorage(SettingsKey.historyLimit) private var historyLimit = SettingsDefaults.historyLimit
    @AppStorage(SettingsKey.autoPaste) private var autoPaste = false
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var accessibilityTrusted = AutoPaster.isTrusted
    @ObservedObject var excludedApps: ExcludedApps

    private let trustTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private let range = HistoryStore.limitRange

    var body: some View {
        Form {
            Section("History") {
                LabeledContent("Entries to keep") {
                    HStack(spacing: 6) {
                        TextField("", value: clampedLimit, format: .number)
                            .labelsHidden()
                            .multilineTextAlignment(.trailing)
                            .frame(width: 56)
                        Stepper("", value: clampedLimit, in: range)
                            .labelsHidden()
                    }
                }
                Text("The menu shows your last \(historyLimit) copied items (\(range.lowerBound) to \(range.upperBound)).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Excluded Apps") {
                ForEach(excludedApps.bundleIDs.map(AppInfo.init).sorted { $0.name < $1.name }, id: \.bundleID) { app in
                    HStack {
                        Image(nsImage: app.icon)
                            .resizable()
                            .frame(width: 18, height: 18)
                        Text(app.name)
                        if !app.isInstalled {
                            Text("Not installed")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button {
                            excludedApps.remove(app.bundleID)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.borderless)
                        .help("Record copies from \(app.name) again")
                    }
                }
                HStack {
                    Text("Nothing copied while these apps are in front is recorded. Adding an app also deletes its existing entries.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Add App…") { excludedApps.chooseAndAdd() }
                }
            }

            Section("Pasting") {
                Toggle("Paste automatically after choosing an entry", isOn: $autoPaste)
                if autoPaste && !accessibilityTrusted {
                    HStack {
                        Text("Needs Accessibility permission to send ⌘V.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Grant Access…") { AutoPaster.requestTrust() }
                    }
                }
                if !autoPaste {
                    Text("Choosing an entry copies it to the clipboard; press ⌘V to paste.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("General") {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in setLaunchAtLogin(enabled) }
            }
        }
        .formStyle(.grouped)
        .frame(width: 440)
        .fixedSize()
        .onReceive(trustTimer) { _ in accessibilityTrusted = AutoPaster.isTrusted }
    }

    private var clampedLimit: Binding<Int> {
        Binding(
            get: { historyLimit },
            set: { historyLimit = min(max($0, range.lowerBound), range.upperBound) }
        )
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("Repaste: launch at login change failed: \(error)")
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}

final class SettingsWindowController {
    private var window: NSWindow?
    private let excludedApps: ExcludedApps

    init(excludedApps: ExcludedApps) {
        self.excludedApps = excludedApps
    }

    func show() {
        if window == nil {
            let window = NSWindow(contentViewController: NSHostingController(rootView: SettingsView(excludedApps: excludedApps)))
            window.title = "Repaste Settings"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.center()
            self.window = window
        }
        // An accessory app is never active on its own; activate so the window comes to the front.
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
    }
}
