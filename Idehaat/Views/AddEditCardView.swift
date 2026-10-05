import SwiftUI
import SwiftData
import PhotosUI
import UniformTypeIdentifiers

struct AddEditCardView: View {
    let card: Card?
    let startWith: AddSource?

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    enum Side { case front, back }

    // Images
    @State private var front: UIImage?
    @State private var back: UIImage?
    @State private var frontChanged = false
    @State private var backChanged = false
    @State private var target: Side = .front

    // Pickers
    @State private var showScanner = false
    @State private var showPhotoPicker = false
    @State private var photoItem: PhotosPickerItem?
    @State private var showFileImporter = false

    // Fields
    @State private var category: CardCategory = .nationalID
    @State private var title = ""
    @State private var holderName = ""
    @State private var number = ""
    @State private var issuer = ""
    @State private var hasIssueDate = false
    @State private var issueDate = Date()
    @State private var hasExpiryDate = false
    @State private var expiryDate = Calendar.current.date(byAdding: .year, value: 1, to: .now) ?? .now
    @State private var reminderDays = 30
    @State private var colorHex = CardCategory.nationalID.defaultColorHex
    @State private var notes = ""

    // OCR
    @State private var suggestions = TextRecognizer.Suggestions()
    @State private var isReading = false

    @State private var didStart = false
    @State private var isSaving = false
    @State private var errorMessage: String?

    private var isNew: Bool { card == nil }

    var body: some View {
        NavigationStack {
            Form {
                imagesSection
                if isReading || !suggestions.isEmpty { suggestionsSection }
                detailsSection
                datesSection
                colorSection
                Section("Notes") {
                    TextField("Membership level, plate number, anything useful…", text: $notes, axis: .vertical)
                        .lineLimit(2...6)
                }
            }
            .navigationTitle(isNew ? Text("New card") : Text("Edit card"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await save() } }
                        .disabled(isSaving)
                        .fontWeight(.semibold)
                }
            }
            .fullScreenCover(isPresented: $showScanner) {
                DocumentScanner { pages in
                    showScanner = false
                    applyScanned(pages)
                } onCancel: {
                    showScanner = false
                }
                .ignoresSafeArea()
            }
            .photosPicker(isPresented: $showPhotoPicker, selection: $photoItem, matching: .images)
            .onChange(of: photoItem) { _, item in
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                        setImage(image, for: target)
                    }
                    photoItem = nil
                }
            }
            .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.image, .pdf]) { result in
                if case .success(let url) = result { importFile(url) }
            }
            .alert("Couldn't save", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("OK", role: .cancel) {}
            } message: { Text(errorMessage ?? "") }
            .onAppear(perform: start)
            .onChange(of: category) { old, new in
                if colorHex == old.defaultColorHex { colorHex = new.defaultColorHex }
            }
        }
        .interactiveDismissDisabled(isSaving)
    }

    // MARK: - Sections

    private var imagesSection: some View {
        Section {
            HStack(spacing: 12) {
                imageSlot(.front, image: front, label: Text("Front"))
                imageSlot(.back, image: back, label: Text("Back"))
            }
            .listRowInsets(EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12))
        } header: {
            Text("Card images")
        } footer: {
            Text("Tip: with the camera scanner you can scan the front and then the back in one go.")
        }
    }

    private func imageSlot(_ side: Side, image: UIImage?, label: Text) -> some View {
        Menu {
            if DocumentScanner.isAvailable {
                Button { target = side; showScanner = true } label: { Label("Scan with camera", systemImage: "camera.viewfinder") }
            }
            Button { target = side; showPhotoPicker = true } label: { Label("Choose from Photos", systemImage: "photo.on.rectangle") }
            Button { target = side; showFileImporter = true } label: { Label("Import from Files", systemImage: "folder") }
            if image != nil {
                Button(role: .destructive) { setImage(nil, for: side) } label: { Label("Remove image", systemImage: "trash") }
            }
        } label: {
            VStack(spacing: 6) {
                Color.clear
                    .aspectRatio(cardAspectRatio, contentMode: .fit)
                    .background {
                        if let image {
                            Image(uiImage: image).resizable().scaledToFill()
                        } else {
                            ZStack {
                                Color(.tertiarySystemFill)
                                Image(systemName: "plus.viewfinder").font(.title2).foregroundStyle(Color.accentColor)
                            }
                        }
                    }
                    .clipShape(CardShape())
                label.font(.caption).foregroundStyle(.secondary)
            }
        }
        .menuStyle(.button)
        .buttonStyle(.borderless)
    }

    private var suggestionsSection: some View {
        Section {
            if isReading {
                HStack { ProgressView(); Text("Reading the card…").foregroundStyle(.secondary) }
            }
            if !suggestions.numbers.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Tap a number to use it").font(.caption).foregroundStyle(.secondary)
                    FlowChips(items: suggestions.numbers) { value in
                        number = value
                    } label: { Text($0).monospacedDigit() }
                }
            }
            if !suggestions.dates.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Dates found on the card").font(.caption).foregroundStyle(.secondary)
                    ForEach(suggestions.dates, id: \.self) { date in
                        HStack {
                            Text(date.cardFormatted).monospacedDigit()
                            Spacer()
                            Button("Expiry") { hasExpiryDate = true; expiryDate = date }
                                .buttonStyle(.bordered).controlSize(.small)
                            Button("Issue") { hasIssueDate = true; issueDate = date }
                                .buttonStyle(.bordered).controlSize(.small)
                        }
                    }
                }
            }
        } header: {
            Label("Found on the card", systemImage: "text.viewfinder")
        } footer: {
            Text("Text is read on your iPhone only.")
        }
    }

    private var detailsSection: some View {
        Section("Details") {
            Picker("Type", selection: $category) {
                ForEach(CardCategory.allCases) { cat in
                    Label { Text(cat.title) } icon: { Image(systemName: cat.symbol) }.tag(cat)
                }
            }
            TextField("Card name (e.g. National ID, Gezira Club)", text: $title)
            TextField("Holder name", text: $holderName)
                .textContentType(.name)
            TextField("Card number", text: $number)
                .keyboardType(.asciiCapable)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.characters)
                .monospacedDigit()
            TextField("Issuer (e.g. Civil Registry, Traffic Dept.)", text: $issuer)
        }
    }

    private var datesSection: some View {
        Section {
            Toggle("Issue date", isOn: $hasIssueDate.animation())
            if hasIssueDate {
                DatePicker("Issued on", selection: $issueDate, displayedComponents: .date)
            }
            Toggle("Expiry date", isOn: $hasExpiryDate.animation())
            if hasExpiryDate {
                DatePicker("Expires on", selection: $expiryDate, displayedComponents: .date)
                Picker("Remind me", selection: $reminderDays) {
                    ForEach(ReminderService.options, id: \.self) { days in
                        Text(ReminderService.label(for: days)).tag(days)
                    }
                }
            }
        } header: {
            Text("Dates")
        }
    }

    private var colorSection: some View {
        Section("Wallet color") {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(CardPalette.colors, id: \.self) { hex in
                        Button { colorHex = hex } label: {
                            Circle()
                                .fill(Color(hex: hex))
                                .frame(width: 34, height: 34)
                                .overlay {
                                    if colorHex == hex {
                                        Image(systemName: "checkmark").font(.caption.bold()).foregroundStyle(.white)
                                    }
                                }
                                .overlay(Circle().stroke(Color.primary.opacity(colorHex == hex ? 0.5 : 0), lineWidth: 2).padding(-3))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 4)
            }
        }
    }

    // MARK: - Logic

    private func start() {
        guard !didStart else { return }
        didStart = true
        if let card {
            category = card.category
            title = card.title
            holderName = card.holderName
            number = card.number
            issuer = card.issuer
            hasIssueDate = card.issueDate != nil
            issueDate = card.issueDate ?? .now
            hasExpiryDate = card.expiryDate != nil
            expiryDate = card.expiryDate ?? expiryDate
            reminderDays = card.reminderDaysBefore
            colorHex = card.colorHex
            notes = card.notes
            front = ImageStore.load(card.frontImageName)
            back = ImageStore.load(card.backImageName)
        }
        target = .front
        guard let startWith, startWith != .manual else { return }
        // Wait for the sheet to finish appearing before presenting the picker.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            switch startWith {
            case .scan: showScanner = true
            case .photos: showPhotoPicker = true
            case .files: showFileImporter = true
            case .manual: break
            }
        }
    }

    private func applyScanned(_ pages: [UIImage]) {
        guard let first = pages.first else { return }
        if pages.count >= 2 {
            front = first; frontChanged = true
            back = pages[1]; backChanged = true
            readText()
        } else {
            setImage(first, for: target)
        }
    }

    private func setImage(_ image: UIImage?, for side: Side) {
        switch side {
        case .front: front = image; frontChanged = true
        case .back: back = image; backChanged = true
        }
        if image != nil { readText() }
    }

    private func importFile(_ url: URL) {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        var image: UIImage?
        if url.pathExtension.lowercased() == "pdf" {
            image = TextRecognizer.firstPageImage(ofPDF: url)
        } else if let data = try? Data(contentsOf: url) {
            image = UIImage(data: data)
        }
        if let image { setImage(image, for: target) }
    }

    private func readText() {
        let images = [front, back].compactMap { $0 }
        guard !images.isEmpty else { return }
        isReading = true
        Task {
            let found = await TextRecognizer.suggestions(from: images)
            suggestions = found
            isReading = false
            // Fill empty fields automatically with the best guess.
            if number.isEmpty, let best = found.numbers.first { number = best }
            if !hasExpiryDate, let latest = found.dates.first, latest > .now {
                hasExpiryDate = true
                expiryDate = latest
            }
        }
    }

    @MainActor
    private func save() async {
        isSaving = true
        defer { isSaving = false }
        let model = card ?? Card(category: category)
        do {
            if frontChanged {
                ImageStore.delete(model.frontImageName)
                model.frontImageName = try front.map { try ImageStore.save($0) }
            }
            if backChanged {
                ImageStore.delete(model.backImageName)
                model.backImageName = try back.map { try ImageStore.save($0) }
            }
        } catch {
            errorMessage = String(localized: "The image couldn't be saved. Make sure your iPhone has free space.")
            return
        }

        model.category = category
        model.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        model.holderName = holderName.trimmingCharacters(in: .whitespacesAndNewlines)
        model.number = number.trimmingCharacters(in: .whitespacesAndNewlines)
        model.issuer = issuer.trimmingCharacters(in: .whitespacesAndNewlines)
        model.issueDate = hasIssueDate ? noon(issueDate) : nil
        model.expiryDate = hasExpiryDate ? noon(expiryDate) : nil
        model.reminderDaysBefore = hasExpiryDate ? reminderDays : 0
        model.colorHex = colorHex
        model.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        model.updatedAt = .now

        if card == nil { context.insert(model) }
        do {
            try context.save()
        } catch {
            errorMessage = error.localizedDescription
            return
        }
        await ReminderService.schedule(for: model)
        dismiss()
    }

    private func noon(_ date: Date) -> Date {
        Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: date) ?? date
    }
}

/// Simple wrapping row of tappable chips.
struct FlowChips<ChipLabel: View>: View {
    let items: [String]
    let onTap: (String) -> Void
    let label: (String) -> ChipLabel

    init(items: [String], onTap: @escaping (String) -> Void, @ViewBuilder label: @escaping (String) -> ChipLabel) {
        self.items = items
        self.onTap = onTap
        self.label = label
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(items, id: \.self) { item in
                    Button { onTap(item) } label: {
                        label(item)
                            .font(.subheadline)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.accentColor.opacity(0.15), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
