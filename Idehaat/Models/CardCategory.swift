import SwiftUI

enum CardCategory: String, CaseIterable, Identifiable, Codable {
    case nationalID
    case drivingLicense
    case carLicense
    case clubMembership
    case subscription
    case insurance
    case workID
    case other

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .nationalID: return "National ID"
        case .drivingLicense: return "Driving License"
        case .carLicense: return "Car License"
        case .clubMembership: return "Club Membership"
        case .subscription: return "Subscription"
        case .insurance: return "Insurance"
        case .workID: return "Work ID"
        case .other: return "Other"
        }
    }

    var localizedName: String { String(localized: title) }

    var symbol: String {
        switch self {
        case .nationalID: return "person.text.rectangle"
        case .drivingLicense: return "steeringwheel"
        case .carLicense: return "car.fill"
        case .clubMembership: return "figure.tennis"
        case .subscription: return "star.circle"
        case .insurance: return "cross.case"
        case .workID: return "briefcase"
        case .other: return "rectangle.on.rectangle"
        }
    }

    var defaultColorHex: String {
        switch self {
        case .nationalID: return "#1C2840"
        case .drivingLicense: return "#206E82"
        case .carLicense: return "#2E5E8C"
        case .clubMembership: return "#2E7D4F"
        case .subscription: return "#4B3F72"
        case .insurance: return "#8B1E3F"
        case .workID: return "#3A3A3C"
        case .other: return "#5E6A71"
        }
    }
}

enum CardPalette {
    static let colors: [String] = [
        "#1C2840", "#206E82", "#2E5E8C", "#2E7D4F",
        "#4B3F72", "#8B1E3F", "#A0522D", "#9A7B1C",
        "#3A3A3C", "#5E6A71",
    ]
}
