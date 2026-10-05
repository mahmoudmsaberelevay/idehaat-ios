import SwiftUI
import SwiftData

enum AddSource: String, Identifiable {
    case scan, photos, files, manual
    var id: String { rawValue }
}

struct HomeView: View {
    @Query(sort: [SortDescriptor(\Card.updatedAt, order: .reverse)]) private var cards: [Card]
    @State private var search = ""
    @State private var filter: CardCategory?
    @State private var addSource: AddSource?
    @State private var showSettings = false

    private var filtered: [Card] {
        cards.filter { card in
            (filter == nil || card.category == filter) &&
            (search.isEmpty
             || card.displayTitle.localizedCaseInsensitiveContains(search)
             || card.holderName.localizedCaseInsensitiveContains(search)
             || card.number.contains(search)
             || card.issuer.localizedCaseInsensitiveContains(search))
        }
    }

    private var attention: [Card] {
        cards.filter { $0.expiryStatus.needsAttention }
            .sorted { ($0.daysUntilExpiry ?? 0) < ($1.daysUntilExpiry ?? 0) }
    }

    private struct CategoryGroup: Identifiable {
        let category: CardCategory
        let cards: [Card]
        var id: String { category.rawValue }
    }

    private var grouped: [CategoryGroup] {
        CardCategory.allCases.compactMap { cat in
            let items = filtered.filter { $0.category == cat }
            return items.isEmpty ? nil : CategoryGroup(category: cat, cards: items)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if cards.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 22) {
                            categoryChips

                            if filter == nil && search.isEmpty && !attention.isEmpty {
                                attentionSection
                            }

                            ForEach(grouped) { group in
                                VStack(alignment: .leading, spacing: 12) {
                                    Label(group.category.localizedName, systemImage: group.category.symbol)
                                        .font(.headline)
                                        .foregroundStyle(.secondary)
                                    ForEach(group.cards) { card in
                                        NavigationLink(value: card) {
                                            CardTileView(card: card)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }

                            if grouped.isEmpty {
                                ContentUnavailableView.search(text: search)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 40)
                    }
                    .searchable(text: $search, prompt: Text("Search cards"))
                }
            }
            .navigationTitle("Idehaat")
            .navigationDestination(for: Card.self) { CardDetailView(card: $0) }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showSettings = true } label: { Image(systemName: "gearshape") }
                        .accessibilityLabel(Text("Settings"))
                }
                ToolbarItem(placement: .topBarTrailing) { addMenu }
            }
            .sheet(item: $addSource) { source in
                AddEditCardView(card: nil, startWith: source)
            }
            .sheet(isPresented: $showSettings) { SettingsView() }
        }
    }

    private var addMenu: some View {
        Menu {
            if DocumentScanner.isAvailable {
                Button { addSource = .scan } label: { Label("Scan with camera", systemImage: "camera.viewfinder") }
            }
            Button { addSource = .photos } label: { Label("Choose from Photos", systemImage: "photo.on.rectangle") }
            Button { addSource = .files } label: { Label("Import from Files", systemImage: "folder") }
            Button { addSource = .manual } label: { Label("Add without image", systemImage: "square.and.pencil") }
        } label: {
            Image(systemName: "plus.circle.fill").font(.title3)
        }
        .accessibilityLabel(Text("Add card"))
    }

    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip(title: Text("All"), symbol: "square.grid.2x2", selected: filter == nil) { filter = nil }
                ForEach(CardCategory.allCases) { cat in
                    if cards.contains(where: { $0.category == cat }) {
                        chip(title: Text(cat.title), symbol: cat.symbol, selected: filter == cat) {
                            filter = filter == cat ? nil : cat
                        }
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func chip(title: Text, symbol: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label { title } icon: { Image(systemName: symbol) }
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(selected ? Color.accentColor : Color(.secondarySystemBackground), in: Capsule())
                .foregroundStyle(selected ? Color.white : Color.primary)
        }
        .buttonStyle(.plain)
    }

    private var attentionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Needs attention", systemImage: "bell.badge")
                .font(.headline)
                .foregroundStyle(.orange)
            ForEach(attention) { card in
                NavigationLink(value: card) {
                    HStack {
                        Image(systemName: card.category.symbol)
                            .frame(width: 32, height: 32)
                            .background(Color(hex: card.colorHex), in: RoundedRectangle(cornerRadius: 8))
                            .foregroundStyle(.white)
                        VStack(alignment: .leading) {
                            Text(card.displayTitle).font(.subheadline.weight(.semibold))
                            if let date = card.expiryDate {
                                Text("Expires \(date.cardFormatted)").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        ExpiryBadge(status: card.expiryStatus)
                    }
                    .padding(10)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "rectangle.stack.badge.plus")
                .font(.system(size: 64))
                .foregroundStyle(Color.accentColor)
            Text("Keep all your cards in one place")
                .font(.title2.weight(.bold))
                .multilineTextAlignment(.center)
            Text("IDs, driving and car licenses, club cards and subscriptions — scanned, protected with Face ID, and ready for Apple Wallet.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            VStack(spacing: 12) {
                if DocumentScanner.isAvailable {
                    Button { addSource = .scan } label: {
                        Label("Scan a card", systemImage: "camera.viewfinder").frame(maxWidth: .infinity).padding(.vertical, 6)
                    }
                    .buttonStyle(.borderedProminent)
                }
                Button { addSource = .photos } label: {
                    Label("Upload a photo", systemImage: "photo").frame(maxWidth: .infinity).padding(.vertical, 6)
                }
                .buttonStyle(.bordered)
            }
            .padding(.top, 8)
            Spacer()
        }
        .padding(32)
    }
}
