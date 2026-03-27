import SwiftUI

@main
struct LazyClipApp: App {
    @State private var appState: AppState?
    @State private var startupErrorMessage: String?
    @State private var hasStartedLifecycle = false
    @State private var pollingTask: Task<Void, Never>?

    init() {
        do {
            _appState = State(initialValue: try AppContainer().appState)
        } catch {
            _appState = State(initialValue: nil)
            _startupErrorMessage = State(initialValue: error.localizedDescription)
        }
    }

    var body: some Scene {
        MenuBarExtra {
            Group {
                if let appState {
                    HistoryPanelView(appState: appState)
                } else {
                    unavailableView
                }
            }
            .frame(width: 420, height: 480)
            .task {
                await startLifecycleIfNeeded()
            }
        } label: {
            Label("LazyClip", image: "MenuBarIcon")
        }
        .menuBarExtraStyle(.window)
    }

    private var unavailableView: some View {
        ContentUnavailableView(
            "LazyClip Unavailable",
            systemImage: "exclamationmark.triangle",
            description: Text(startupErrorMessage ?? "Unable to load clipboard history.")
        )
    }

    @MainActor
    private func startLifecycleIfNeeded() async {
        guard hasStartedLifecycle == false, let appState else {
            return
        }

        hasStartedLifecycle = true

        do {
            try appState.loadInitialData()
        } catch {
            appState.storageErrorMessage = error.localizedDescription
        }

        pollingTask = Task {
            while Task.isCancelled == false {
                try? await Task.sleep(for: .seconds(AppConfiguration.pasteboardPollInterval))
                guard Task.isCancelled == false else {
                    break
                }

                await MainActor.run {
                    do {
                        try appState.handleClipboardPoll()
                    } catch {
                        appState.storageErrorMessage = error.localizedDescription
                    }
                }
            }
        }
    }
}
