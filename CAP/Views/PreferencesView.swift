import SwiftUI

struct PreferencesView: View {
    @EnvironmentObject private var appState: AppState
    @State private var maxHistory = Preferences.maxHistoryCount
    @State private var launchAtLogin = LaunchAtLogin.isEnabled
    @State private var closeAfterPaste = Preferences.closePanelAfterPaste
    @State private var generalShortcut = Preferences.generalScopeShortcut
    @State private var launchAtLoginError: String?
    @State private var accessibilityTrusted = AccessibilityAuthorization.isTrusted
    @State private var autoCheckUpdates = UpdaterController.shared.automaticallyChecksForUpdates

    var body: some View {
        Form {
            GroupsSettingsView()

            Section {
                Toggle("Chiudi il pannello dopo l’incolla", isOn: $closeAfterPaste)

                if accessibilityTrusted {
                    Label("Incolla automatico attivo", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.secondary)
                } else {
                    Label("Serve autorizzazione Accessibilità", systemImage: "lock.fill")
                        .foregroundStyle(.secondary)

                    Button("Aggiungi CAP in Accessibilità") {
                        AccessibilityAuthorization.openRegistrationAssistant()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
            } header: {
                Text("Incolla automatico")
            } footer: {
                if accessibilityTrusted {
                    Text("Dopo il primo permesso in Accessibilità, esci da CAP e riaprilo una volta. Poi l’incolla automatico resta attivo.")
                } else {
                    Text(accessibilityFooterSteps)
                }
            }

            Section("Generale") {
                Picker("Torna a Generale", selection: $generalShortcut) {
                    ForEach(GeneralScopeShortcut.allCases) { shortcut in
                        Text(shortcut.title).tag(shortcut)
                    }
                }
                Toggle("Apri all’avvio del Mac", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in
                        applyLaunchAtLogin(enabled)
                    }
                if let launchAtLoginError {
                    Text(launchAtLoginError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Section("Cronologia") {
                Stepper(value: $maxHistory, in: 50...10_000, step: 50) {
                    Text("Conserva fino a \(maxHistory) elementi")
                }
                Button("Svuota tutta la cronologia", role: .destructive) {
                    appState.clearHistory()
                }
            }

            Section {
                LabeledContent("Versione", value: UpdaterController.currentVersionDescription)
                if UpdaterController.shared.isAvailable {
                    Toggle("Controlla automaticamente", isOn: $autoCheckUpdates)
                        .onChange(of: autoCheckUpdates) { _, enabled in
                            UpdaterController.shared.automaticallyChecksForUpdates = enabled
                        }
                    Button("Controlla aggiornamenti…") {
                        UpdaterController.shared.checkForUpdates()
                    }
                }
            } header: {
                Text("Aggiornamenti")
            } footer: {
                if !UpdaterController.shared.isAvailable {
                    Text("Gli aggiornamenti automatici sono disattivati nelle build Debug.")
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 460, height: 600)
        .onAppear { refreshAccessibilityStatus() }
        .onReceive(Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()) { _ in
            refreshAccessibilityStatus()
        }
        .onDisappear(perform: save)
    }

    private var accessibilityFooterSteps: String {
        """
        CAP non compare da sola in elenco (normale per le build in Debug). \
        Dopo il pulsante sopra: in Accessibilità premi + in basso, scegli CAP.app nel Finder (cartella evidenziata), attiva il toggle. \
        In elenco può comparire come CAP o CAP Debug; il bundle è \(AppIdentity.bundleIdentifier).
        """
    }

    private func refreshAccessibilityStatus() {
        accessibilityTrusted = AccessibilityAuthorization.isTrusted
    }

    private func applyLaunchAtLogin(_ enabled: Bool) {
        launchAtLoginError = nil
        do {
            try LaunchAtLogin.setEnabled(enabled)
        } catch {
            launchAtLoginError = error.localizedDescription
            launchAtLogin = LaunchAtLogin.isEnabled
        }
    }

    private func save() {
        Preferences.setClosePanelAfterPaste(closeAfterPaste)
        Preferences.setGeneralScopeShortcut(generalShortcut)
        Preferences.setMaxHistoryCount(maxHistory)
    }
}
