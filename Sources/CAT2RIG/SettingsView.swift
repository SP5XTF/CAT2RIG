import SwiftUI
import AppKit
import ServiceManagement

enum AppLanguage: String, CaseIterable, Identifiable {
    case system, pl, en
    var id: String { rawValue }
}

/// Okno Ustawień (⌘,) – uruchamianie przy logowaniu i wybór języka programu.
struct SettingsView: View {
    @State private var language: AppLanguage = LanguageSettings.current
    @State private var changed = false
    @StateObject private var loginItem = LoginItem()

    var body: some View {
        Form {
            Toggle("Uruchamiaj przy logowaniu do macOS", isOn: Binding(
                get: { loginItem.isEnabled },
                set: { loginItem.set($0) }
            ))
            .disabled(!loginItem.isAvailable)

            if !loginItem.isAvailable {
                Text("Dostępne tylko w zbudowanej aplikacji CAT2RIG.app (./build_app.sh).")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else if loginItem.status == .requiresApproval {
                Text("macOS wymaga zgody: włącz CAT2RIG w Ustawieniach systemowych → Ogólne → Rzeczy otwierane podczas logowania.")
                    .font(.callout)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Otwórz Ustawienia systemowe") {
                    SMAppService.openSystemSettingsLoginItems()
                }
            } else if loginItem.isEnabled {
                Text("Wskazówka: zaznacz też „Start automatycznie” w oknie głównym – wtedy po zalogowaniu CAT2RIG od razu połączy się z radiem.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let err = loginItem.lastError {
                Text(err)
                    .font(.callout)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()

            Picker("Język programu:", selection: $language) {
                Text("Systemowy").tag(AppLanguage.system)
                Text(verbatim: "Polski").tag(AppLanguage.pl)
                Text(verbatim: "English").tag(AppLanguage.en)
            }
            .onChange(of: language) { newValue in
                LanguageSettings.set(newValue)
                changed = true
            }
            if changed {
                Text("Zmiana języka zadziała po ponownym uruchomieniu programu.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Button("Uruchom ponownie teraz") { LanguageSettings.relaunch() }
            }
        }
        .padding(20)
        .frame(width: 480)
        .onAppear { loginItem.refresh() }     // użytkownik mógł zmienić to w Ustawieniach systemowych
    }
}

/// Uruchamianie przy logowaniu przez SMAppService (macOS 13+).
@MainActor
final class LoginItem: ObservableObject {
    @Published private(set) var status: SMAppService.Status = .notRegistered
    @Published private(set) var lastError: String?

    init() { refresh() }

    /// Rejestracja ma sens tylko dla pakietu .app (nie przy `swift run` / Xcode ▶).
    var isAvailable: Bool {
        Bundle.main.bundleURL.pathExtension == "app" && Bundle.main.bundleIdentifier != nil
    }

    var isEnabled: Bool {
        status == .enabled || status == .requiresApproval
    }

    func refresh() {
        status = isAvailable ? SMAppService.mainApp.status : .notRegistered
    }

    func set(_ on: Bool) {
        guard isAvailable else { return }
        do {
            if on {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
        refresh()
    }
}

enum LanguageSettings {
    /// Język wybrany dla tej aplikacji (nie systemowy).
    static var current: AppLanguage {
        guard let id = Bundle.main.bundleIdentifier,
              let langs = UserDefaults.standard.persistentDomain(forName: id)?["AppleLanguages"] as? [String],
              let first = langs.first else { return .system }
        if first.hasPrefix("en") { return .en }
        if first.hasPrefix("pl") { return .pl }
        return .system
    }

    static func set(_ lang: AppLanguage) {
        switch lang {
        case .system: UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        case .pl: UserDefaults.standard.set(["pl"], forKey: "AppleLanguages")
        case .en: UserDefaults.standard.set(["en"], forKey: "AppleLanguages")
        }
    }

    /// Język, w którym program faktycznie działa ("pl" albo "en").
    static var effective: String {
        Bundle.main.preferredLocalizations.first.map { $0.hasPrefix("en") ? "en" : "pl" } ?? "pl"
    }

    static func relaunch() {
        let cfg = NSWorkspace.OpenConfiguration()
        cfg.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: cfg) { _, _ in
            DispatchQueue.main.async { NSApp.terminate(nil) }
        }
    }
}
