import Foundation
import SwiftData

@Model
final class Card {
    @Attribute(.unique) var id: UUID
    var title: String
    var categoryRaw: String
    var holderName: String
    var number: String
    var issuer: String
    var issueDate: Date?
    var expiryDate: Date?
    var notes: String
    var colorHex: String
    var frontImageName: String?
    var backImageName: String?
    /// 0 = no reminder
    var reminderDaysBefore: Int
    var isFavorite: Bool
    var createdAt: Date
    var updatedAt: Date
    /// Stable serial so re-adding to Wallet updates the same pass.
    var walletSerial: String

    init(
        title: String = "",
        category: CardCategory = .nationalID,
        holderName: String = "",
        number: String = "",
        issuer: String = "",
        issueDate: Date? = nil,
        expiryDate: Date? = nil,
        notes: String = "",
        colorHex: String? = nil,
        frontImageName: String? = nil,
        backImageName: String? = nil,
        reminderDaysBefore: Int = 30
    ) {
        self.id = UUID()
        self.title = title
        self.categoryRaw = category.rawValue
        self.holderName = holderName
        self.number = number
        self.issuer = issuer
        self.issueDate = issueDate
        self.expiryDate = expiryDate
        self.notes = notes
        self.colorHex = colorHex ?? category.defaultColorHex
        self.frontImageName = frontImageName
        self.backImageName = backImageName
        self.reminderDaysBefore = reminderDaysBefore
        self.isFavorite = false
        self.createdAt = .now
        self.updatedAt = .now
        self.walletSerial = UUID().uuidString
    }

    var category: CardCategory {
        get { CardCategory(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }

    var displayTitle: String {
        title.trimmingCharacters(in: .whitespaces).isEmpty ? category.localizedName : title
    }

    var maskedNumber: String {
        let digits = number.trimmingCharacters(in: .whitespaces)
        guard digits.count > 4 else { return digits }
        return "•••• " + String(digits.suffix(4))
    }

    var daysUntilExpiry: Int? {
        guard let expiryDate else { return nil }
        let cal = Calendar.current
        return cal.dateComponents([.day], from: cal.startOfDay(for: .now), to: cal.startOfDay(for: expiryDate)).day
    }

    var expiryStatus: ExpiryStatus {
        guard let days = daysUntilExpiry else { return .none }
        if days < 0 { return .expired }
        if days <= 30 { return .soon(days) }
        return .valid
    }
}

enum ExpiryStatus: Equatable {
    case none, valid, soon(Int), expired

    var needsAttention: Bool {
        switch self {
        case .soon, .expired: return true
        default: return false
        }
    }
}
