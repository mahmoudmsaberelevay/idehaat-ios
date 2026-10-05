import SwiftUI

struct LockView: View {
    @Environment(AppLock.self) private var lock
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            BrandBackground()
            VStack(spacing: 24) {
                Spacer()
                Image("AppIcon-Display")
                    .resizable()
                    .frame(width: 96, height: 96)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .shadow(radius: 12)
                Text("Idehaat")
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(.white)
                Text("Your cards are locked")
                    .foregroundStyle(.white.opacity(0.75))
                Spacer()
                Button {
                    Task { await lock.authenticate() }
                } label: {
                    Label("Unlock with \(lock.biometryName)", systemImage: lock.biometrySymbol)
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(.white.opacity(0.18))
                .padding(.horizontal, 32)
                .padding(.bottom, 40)
            }
        }
        .task {
            if scenePhase == .active { await lock.authenticate() }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await lock.authenticate() } }
        }
    }
}

/// Shown in the app switcher so card images never appear in the snapshot.
struct PrivacyCoverView: View {
    var body: some View {
        ZStack {
            BrandBackground()
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 56))
                .foregroundStyle(.white.opacity(0.85))
        }
    }
}

struct BrandBackground: View {
    var body: some View {
        LinearGradient(
            colors: [Color(hex: "#12203A"), Color(hex: "#206E82")],
            startPoint: .top, endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}
