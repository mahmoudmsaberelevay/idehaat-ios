import SwiftUI
import SwiftData

@main
struct IdehaatApp: App {
    @State private var lock = AppLock()
    @Environment(\.scenePhase) private var scenePhase
    private let container: ModelContainer

    init() {
        Vault.prepare()
        do {
            let configuration = ModelConfiguration(url: Vault.storeURL)
            container = try ModelContainer(for: Card.self, configurations: configuration)
        } catch {
            fatalError("Could not open Idehaat database: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                // When locked, the whole UI (including any open sheet) is removed, not just covered.
                if lock.isEnabled && lock.isLocked {
                    LockView()
                        .transition(.opacity)
                } else {
                    HomeView()
                    if scenePhase != .active { PrivacyCoverView() }
                }
            }
            .animation(.easeInOut(duration: 0.2), value: lock.isLocked)
            .environment(lock)
        }
        .modelContainer(container)
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { lock.lock() }
        }
    }
}
