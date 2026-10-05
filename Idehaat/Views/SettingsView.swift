import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(AppLock.self) private var lock
    @Environment(\.dismiss) private var dismiss
    @Query private var cards: [Card]

    @AppStorage(WalletService.includePhotoKey) private var walletIncludePhoto = true
    @AppStorage(WalletService.includeBarcodeKey) private var walletIncludeBarcode = false
    @State private var includeInBackup = Vault.includeInBackup

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle(isOn: Binding(
                        get: { lock.isEnabled },
                        set: { newValue in
                            if newValue {
                                lock.setEnabled(true)
                            } else {
                                Task { if await lock.confirmOwner() { lock.setEnabled(false) } }
                            }
                        }
                    )) {
                        Label("Lock with \(lock.biometryName)", systemImage: lock.biometrySymbol)
                    }
                } header: {
                    Text("Security")
                } footer: {
                    Text("The app locks every time you leave it. Card images are encrypted by iOS and hidden from the app switcher.")
                }

                Section {
                    Toggle(isOn: $includeInBackup) {
                        Label("Include in iPhone backup", systemImage: "externaldrive.badge.icloud")
                    }
                    .onChange(of: includeInBackup) { _, value in Vault.includeInBackup = value }
                } header: {
                    Text("Storage")
                } footer: {
                    Text("Your cards are stored only on this iPhone. Turn this on if you want them restored when you move to a new iPhone from a backup.")
                }

                Section {
                    Toggle(isOn: $walletIncludePhoto) {
                        Label("Show card photo on the pass", systemImage: "photo")
                    }
                    Toggle(isOn: $walletIncludeBarcode) {
                        Label("Add QR code with card number", systemImage: "qrcode")
                    }
                } header: {
                    Text("Apple Wallet")
                } footer: {
                    Text("To create a Wallet pass, the card details (and the photo, if enabled) are sent securely to the Idehaat signing server, signed, and returned immediately. Nothing is stored on the server.")
                }

                Section {
                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                    } label: {
                        Label("App language", systemImage: "globe")
                    }
                } footer: {
                    Text("Choose Arabic or English for Idehaat from the iPhone Settings app.")
                }

                Section("About") {
                    LabeledContent("Cards", value: "\(cards.count)")
                    LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                    Text("Idehaat keeps personal copies of your cards. Copies are not official documents and don't replace the original cards.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
    }
}
