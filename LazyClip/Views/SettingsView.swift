import AppKit
import SwiftUI

struct SettingsView: View {
    @ObservedObject var appState: AppState
    @State private var showsClearAllConfirmation = false

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Text(Self.versionText(from: Bundle.main.infoDictionary))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Toggle("Pause recording", isOn: pauseBinding)

                Picker("History limit", selection: historyLimitBinding) {
                    ForEach([100, 500, 1000, 5000], id: \.self) { limit in
                        Text("\(limit)").tag(limit)
                    }
                }

                Picker("Image size limit", selection: imageSizeLimitBinding) {
                    ForEach([5, 10, 20, 50, 100], id: \.self) { mb in
                        Text("\(mb) MB").tag(mb)
                    }
                }

                Button(role: .destructive) {
                    showsClearAllConfirmation.toggle()
                } label: {
                    Text("Clear all history")
                }

                if showsClearAllConfirmation {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Clear all clipboard history?")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Text("This deletes all saved clipboard history.")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        HStack {
                            Button("No") {
                                showsClearAllConfirmation = false
                            }

                            Button(role: .destructive) {
                                do {
                                    try appState.clearAll()
                                    showsClearAllConfirmation = false
                                } catch {
                                    appState.storageErrorMessage = error.localizedDescription
                                }
                            } label: {
                                Text("Yes")
                                    .foregroundStyle(.red)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }

                if let storageErrorMessage = appState.storageErrorMessage {
                    Text(storageErrorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            .formStyle(.grouped)
            .padding(.horizontal, 8)
            .padding(.top, 8)
            .padding(.bottom, 12)

            HStack {
                Spacer()

                Button(role: .destructive) {
                    NSApplication.shared.terminate(nil)
                } label: {
                    Text("Exit")
                        .foregroundStyle(.red)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
    }

    private var pauseBinding: Binding<Bool> {
        Binding(
            get: { appState.settings.isPaused },
            set: { isPaused in
                do {
                    try appState.updatePauseState(isPaused)
                } catch {
                    appState.storageErrorMessage = error.localizedDescription
                }
            }
        )
    }

    private var historyLimitBinding: Binding<Int> {
        Binding(
            get: { appState.settings.historyLimit },
            set: { historyLimit in
                do {
                    try appState.updateHistoryLimit(historyLimit)
                } catch {
                    appState.storageErrorMessage = error.localizedDescription
                }
            }
        )
    }

    private var imageSizeLimitBinding: Binding<Int> {
        Binding(
            get: { appState.settings.imageSizeLimitMB },
            set: { mb in
                do {
                    try appState.updateImageSizeLimit(mb)
                } catch {
                    appState.storageErrorMessage = error.localizedDescription
                }
            }
        )
    }

    static func versionText(from infoDictionary: [String: Any]?) -> String {
        let version = (infoDictionary?["CFBundleShortVersionString"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if let version, !version.isEmpty {
            return "Version \(version)"
        }

        return "Version -"
    }

    static func formRowTitles(versionText: String) -> [String] {
        [versionText, "Pause recording", "History limit", "Image size limit", "Clear all history"]
    }
}
