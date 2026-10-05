import SwiftUI
import SwiftData

struct CardDetailView: View {
    @Bindable var card: Card
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @AppStorage(WalletService.includePhotoKey) private var walletIncludePhoto = true
    @AppStorage(WalletService.includeBarcodeKey) private var walletIncludeBarcode = false

    @State private var showBack = false
    @State private var showEditor = false
    @State private var showDeleteConfirm = false
    @State private var fullScreenImage: IdentifiedImage?
    @State private var isCreatingPass = false
    @State private var passItem: PassItem?
    @State private var walletError: String?
    @State private var copied = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                flipCard
                sideToggle
                walletSection
                detailsSection
                if !card.notes.isEmpty { notesSection }
            }
            .padding()
        }
        .navigationTitle(card.displayTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button { showEditor = true } label: { Label("Edit", systemImage: "pencil") }
                    if let front = ImageStore.load(card.frontImageName) {
                        ShareLink(item: Image(uiImage: front), preview: SharePreview(card.displayTitle, image: Image(uiImage: front))) {
                            Label("Share front image", systemImage: "square.and.arrow.up")
                        }
                    }
                    Divider()
                    Button(role: .destructive) { showDeleteConfirm = true } label: { Label("Delete", systemImage: "trash") }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showEditor) { AddEditCardView(card: card, startWith: nil) }
        .sheet(item: $passItem) { item in
            AddPassSheet(pass: item.pass).ignoresSafeArea()
        }
        .fullScreenCover(item: $fullScreenImage) { item in
            ZoomableImageView(image: item.image)
        }
        .confirmationDialog("Delete this card?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) { deleteCard() }
        } message: {
            Text("The card and its images will be removed from this iPhone. Passes already added to Wallet stay there until you remove them.")
        }
        .alert("Apple Wallet", isPresented: Binding(get: { walletError != nil }, set: { if !$0 { walletError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(walletError ?? "")
        }
    }

    // MARK: - Card

    private var flipCard: some View {
        ZStack {
            CardTileView(card: card, showsBack: false, showsOverlay: false)
                .opacity(showBack ? 0 : 1)
            CardTileView(card: card, showsBack: true, showsOverlay: false)
                .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
                .opacity(showBack ? 1 : 0)
        }
        .rotation3DEffect(.degrees(showBack ? 180 : 0), axis: (x: 0, y: 1, z: 0), perspective: 0.5)
        .onTapGesture {
            let name = showBack ? card.backImageName : card.frontImageName
            if let image = ImageStore.load(name) { fullScreenImage = IdentifiedImage(image: image) }
        }
        .accessibilityHint(Text("Double-tap to view full screen"))
    }

    private var sideToggle: some View {
        Picker("Side", selection: Binding(
            get: { showBack },
            set: { newValue in withAnimation(.spring(duration: 0.5)) { showBack = newValue } }
        )) {
            Text("Front").tag(false)
            Text("Back").tag(true)
        }
        .pickerStyle(.segmented)
    }

    // MARK: - Wallet

    private var walletSection: some View {
        VStack(spacing: 10) {
            if WalletService.canAddPasses {
                ZStack {
                    AddToWalletButton { Task { await addToWallet() } }
                        .frame(height: 50)
                        .disabled(isCreatingPass)
                        .opacity(isCreatingPass ? 0.4 : 1)
                    if isCreatingPass { ProgressView() }
                }
                Text("Adds a copy of this card to Apple Wallet. Adding it again updates the same pass.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            } else {
                Label("Apple Wallet isn't available on this device.", systemImage: "wallet.pass")
                    .foregroundStyle(.secondary)
            }
        }
    }

    @MainActor
    private func addToWallet() async {
        isCreatingPass = true
        defer { isCreatingPass = false }
        do {
            let snapshot = WalletService.Snapshot(card: card)
            let pass = try await WalletService.makePass(
                from: snapshot,
                includePhoto: walletIncludePhoto,
                includeBarcode: walletIncludeBarcode
            )
            passItem = PassItem(pass: pass)
        } catch {
            walletError = error.localizedDescription
        }
    }

    // MARK: - Details

    private var detailsSection: some View {
        VStack(spacing: 0) {
            infoRow("Type", value: card.category.localizedName, symbol: card.category.symbol)
            if !card.holderName.isEmpty { infoRow("Name", value: card.holderName, symbol: "person") }
            if !card.number.isEmpty {
                infoRow("Number", value: card.number, symbol: "number", copyable: true)
            }
            if !card.issuer.isEmpty { infoRow("Issuer", value: card.issuer, symbol: "building.columns") }
            if let issue = card.issueDate { infoRow("Issue date", value: issue.cardFormatted, symbol: "calendar") }
            if let expiry = card.expiryDate {
                HStack {
                    infoRow("Expiry date", value: expiry.cardFormatted, symbol: "calendar.badge.exclamationmark")
                    ExpiryBadge(status: card.expiryStatus).padding(.trailing, 12)
                }
            }
            if card.expiryDate != nil {
                infoRow("Reminder", value: ReminderService.label(for: card.reminderDaysBefore), symbol: "bell")
            }
        }
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    private func infoRow(_ title: LocalizedStringKey, value: String, symbol: String, copyable: Bool = false) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .frame(width: 24)
                .foregroundStyle(Color.accentColor)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.caption).foregroundStyle(.secondary)
                Text(value).font(.body).textSelection(.enabled)
            }
            Spacer()
            if copyable {
                Button {
                    UIPasteboard.general.setItems([[UIPasteboard.typeAutomatic: value]],
                                                  options: [.expirationDate: Date().addingTimeInterval(120), .localOnly: true])
                    copied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
                } label: {
                    Image(systemName: copied ? "checkmark" : "doc.on.doc")
                }
                .accessibilityLabel(Text("Copy"))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Notes").font(.caption).foregroundStyle(.secondary)
            Text(card.notes)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    private func deleteCard() {
        let target = card
        let id = card.id, front = card.frontImageName, back = card.backImageName
        dismiss()
        // Delete after the screen has closed so nothing renders a deleted object.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            ReminderService.cancel(cardID: id)
            ImageStore.delete(front)
            ImageStore.delete(back)
            context.delete(target)
            try? context.save()
        }
    }
}

struct IdentifiedImage: Identifiable {
    let id = UUID()
    let image: UIImage
}

struct ZoomableImageView: View {
    let image: UIImage
    @Environment(\.dismiss) private var dismiss
    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .scaleEffect(scale)
                .gesture(
                    MagnifyGesture()
                        .onChanged { scale = max(1, min(lastScale * $0.magnification, 5)) }
                        .onEnded { _ in lastScale = scale }
                )
                .onTapGesture(count: 2) {
                    withAnimation { scale = scale > 1 ? 1 : 2.5; lastScale = scale }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.largeTitle)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, .white.opacity(0.25))
            }
            .padding()
            .accessibilityLabel(Text("Close"))
        }
        .statusBarHidden()
    }
}
