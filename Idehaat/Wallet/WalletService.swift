import UIKit
import PassKit

/// Turns a card into an Apple Wallet pass.
/// The pass is signed by your pass server (Apple requires a signed pass); the server stores nothing.
enum WalletService {
    static let includePhotoKey = "walletIncludePhoto"
    static let includeBarcodeKey = "walletIncludeBarcode"

    enum WalletError: LocalizedError {
        case walletUnavailable
        case notConfigured
        case server(Int)
        case network
        case invalidPass

        var errorDescription: String? {
            switch self {
            case .walletUnavailable: return String(localized: "Apple Wallet isn't available on this device.")
            case .notConfigured: return String(localized: "The Wallet server isn't set up yet. Add its URL and key in AppConfig.swift.")
            case .server(let code): return String(localized: "The Wallet server returned an error (\(code)). Please try again.")
            case .network: return String(localized: "Couldn't reach the Wallet server. Check your internet connection.")
            case .invalidPass: return String(localized: "The pass couldn't be read. Check the server certificates.")
            }
        }
    }

    /// Plain snapshot of a card, safe to use off the main thread.
    struct Snapshot {
        var serial: String
        var title: String
        var categoryName: String
        var holderName: String
        var number: String
        var issuer: String
        var notes: String
        var expiry: Date?
        var colorHex: String
        var frontImage: UIImage?

        @MainActor
        init(card: Card) {
            serial = card.walletSerial
            title = card.displayTitle
            categoryName = card.category.localizedName
            holderName = card.holderName
            number = card.number
            issuer = card.issuer
            notes = card.notes
            expiry = card.expiryDate
            colorHex = card.colorHex
            frontImage = ImageStore.load(card.frontImageName)
        }
    }

    private struct PassRequest: Encodable {
        var serialNumber: String
        var title: String
        var categoryName: String
        var holderName: String
        var number: String
        var issuer: String
        var notes: String
        var expiryDate: String?
        var backgroundColor: String
        var foregroundColor: String
        var labelColor: String
        var barcodeMessage: String?
        var labels: [String: String]
        var disclaimer: String
        var images: [String: String]
    }

    static var canAddPasses: Bool { PKAddPassesViewController.canAddPasses() && PKPassLibrary.isPassLibraryAvailable() }

    static func makePass(from snapshot: Snapshot, includePhoto: Bool, includeBarcode: Bool) async throws -> PKPass {
        guard canAddPasses else { throw WalletError.walletUnavailable }
        guard AppConfig.isWalletConfigured else { throw WalletError.notConfigured }

        var images: [String: String] = [:]
        if includePhoto, let front = snapshot.frontImage {
            let bg = UIColor(hex: snapshot.colorHex)
            for (name, scale) in [("strip.png", 1.0), ("strip@2x.png", 2.0), ("strip@3x.png", 3.0)] {
                if let data = PassImageRenderer.strip(card: front, background: bg, scale: scale) {
                    images[name] = data.base64EncodedString()
                }
            }
        }

        let number = snapshot.number.trimmingCharacters(in: .whitespaces)
        let body = PassRequest(
            serialNumber: snapshot.serial,
            title: snapshot.title,
            categoryName: snapshot.categoryName,
            holderName: snapshot.holderName,
            number: number,
            issuer: snapshot.issuer,
            notes: snapshot.notes,
            expiryDate: snapshot.expiry?.walletExpiryString,
            backgroundColor: snapshot.colorHex,
            foregroundColor: "#FFFFFF",
            labelColor: "#DCE6EA",
            barcodeMessage: includeBarcode && !number.isEmpty ? number : nil,
            labels: [
                "expiry": String(localized: "EXPIRES"),
                "holder": String(localized: "NAME"),
                "number": String(localized: "NUMBER"),
                "issuer": String(localized: "ISSUER"),
                "category": String(localized: "TYPE"),
                "notes": String(localized: "NOTES"),
                "disclaimerTitle": String(localized: "NOTE"),
            ],
            disclaimer: String(localized: "This pass is a personal copy created with Idehaat. It is not an official document and does not replace the original card."),
            images: images
        )

        var request = URLRequest(url: AppConfig.passServerURL)
        request.httpMethod = "POST"
        request.timeoutInterval = 90
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(AppConfig.passServerAPIKey, forHTTPHeaderField: "X-API-Key")
        request.httpBody = try JSONEncoder().encode(body)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw WalletError.network
        }
        guard let http = response as? HTTPURLResponse else { throw WalletError.network }
        guard http.statusCode == 200 else { throw WalletError.server(http.statusCode) }
        do {
            return try PKPass(data: data)
        } catch {
            throw WalletError.invalidPass
        }
    }
}

enum PassImageRenderer {
    /// Store-card strip is 375 × 123 pt. The card photo is fitted inside with rounded corners.
    static func strip(card: UIImage, background: UIColor, scale: CGFloat) -> Data? {
        let size = CGSize(width: 375 * scale, height: 123 * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let image = UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            background.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))

            let inset = 10 * scale
            let maxH = size.height - inset * 2
            let maxW = size.width - inset * 2
            let ratio = card.size.width / max(card.size.height, 1)
            var h = maxH
            var w = h * ratio
            if w > maxW { w = maxW; h = w / ratio }
            let rect = CGRect(x: (size.width - w) / 2, y: (size.height - h) / 2, width: w, height: h)
            let path = UIBezierPath(roundedRect: rect, cornerRadius: 6 * scale)

            ctx.cgContext.saveGState()
            ctx.cgContext.setShadow(offset: CGSize(width: 0, height: 2 * scale), blur: 6 * scale,
                                    color: UIColor.black.withAlphaComponent(0.35).cgColor)
            UIColor.white.setFill()
            path.fill()
            ctx.cgContext.restoreGState()

            path.addClip()
            card.draw(in: rect)
        }
        return image.pngData()
    }
}
