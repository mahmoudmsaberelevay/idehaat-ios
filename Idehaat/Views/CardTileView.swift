import SwiftUI

/// A card drawn at real ID-1 proportions: the scanned photo if there is one, otherwise a colored card.
struct CardTileView: View {
    let card: Card
    var showsBack = false
    var showsOverlay = true

    var body: some View {
        let image = ImageStore.load(showsBack ? card.backImageName : card.frontImageName)
        Color.clear
            .aspectRatio(cardAspectRatio, contentMode: .fit)
            .overlay { face(image: image) }
            .clipShape(CardShape())
            .overlay(alignment: .topTrailing) {
                if showsOverlay { ExpiryBadge(status: card.expiryStatus).padding(10) }
            }
            .overlay(CardShape().stroke(.white.opacity(0.12), lineWidth: 1))
            .shadow(color: .black.opacity(0.18), radius: 10, y: 6)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(Text("\(card.displayTitle), \(card.category.localizedName)"))
    }

    @ViewBuilder
    private func face(image: UIImage?) -> some View {
        ZStack(alignment: .bottomLeading) {
            if let image {
                Color.clear.background {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                }
            } else {
                PlaceholderCardFace(card: card, isBack: showsBack)
            }

            if showsOverlay, image != nil {
                LinearGradient(colors: [.clear, .black.opacity(0.65)], startPoint: .center, endPoint: .bottom)
                VStack(alignment: .leading, spacing: 2) {
                    Text(card.displayTitle)
                        .font(.headline)
                    if !card.number.isEmpty {
                        Text(card.maskedNumber)
                            .font(.subheadline.monospacedDigit())
                            .opacity(0.85)
                    }
                }
                .foregroundStyle(.white)
                .padding(14)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
    }
}

struct PlaceholderCardFace: View {
    let card: Card
    var isBack = false

    var body: some View {
        let base = Color(hex: card.colorHex)
        ZStack(alignment: .topLeading) {
            LinearGradient(colors: [base, base.opacity(0.75)], startPoint: .topLeading, endPoint: .bottomTrailing)
            Image(systemName: card.category.symbol)
                .font(.system(size: 120, weight: .thin))
                .foregroundStyle(.white.opacity(0.08))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .offset(x: 20, y: 20)

            VStack(alignment: .leading, spacing: 6) {
                Label(card.category.localizedName, systemImage: card.category.symbol)
                    .font(.caption.weight(.semibold))
                    .opacity(0.8)
                Spacer()
                if isBack {
                    Text("No back image").font(.subheadline).opacity(0.7)
                } else {
                    Text(card.displayTitle).font(.title3.weight(.bold))
                    if !card.holderName.isEmpty { Text(card.holderName).font(.subheadline) }
                    if !card.number.isEmpty {
                        Text(card.maskedNumber).font(.subheadline.monospacedDigit()).opacity(0.85)
                    }
                }
            }
            .foregroundStyle(.white)
            .padding(16)
        }
    }
}

struct ExpiryBadge: View {
    let status: ExpiryStatus

    var body: some View {
        switch status {
        case .expired:
            badge(Text("Expired"), color: .red, symbol: "exclamationmark.triangle.fill")
        case .soon(let days):
            badge(days == 0 ? Text("Expires today") : Text("\(days) days left"), color: .orange, symbol: "clock.fill")
        default:
            EmptyView()
        }
    }

    private func badge(_ text: Text, color: Color, symbol: String) -> some View {
        Label { text } icon: { Image(systemName: symbol) }
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.9), in: Capsule())
            .foregroundStyle(.white)
    }
}
