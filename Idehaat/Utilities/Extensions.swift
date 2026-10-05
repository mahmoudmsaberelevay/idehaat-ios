import SwiftUI
import UIKit

extension Color {
    init(hex: String) {
        self.init(uiColor: UIColor(hex: hex))
    }
}

extension UIColor {
    convenience init(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        var value: UInt64 = 0
        Scanner(string: s).scanHexInt64(&value)
        if s.count != 6 { value = 0x1C2840 }
        self.init(
            red: CGFloat((value >> 16) & 0xFF) / 255,
            green: CGFloat((value >> 8) & 0xFF) / 255,
            blue: CGFloat(value & 0xFF) / 255,
            alpha: 1
        )
    }
}

extension Date {
    var cardFormatted: String {
        formatted(.dateTime.day().month(.abbreviated).year())
    }

    /// ISO string at 23:59:59 UTC of the same calendar day — used for Wallet expiry.
    var walletExpiryString: String {
        let comps = Calendar.current.dateComponents([.year, .month, .day], from: self)
        return String(format: "%04d-%02d-%02dT23:59:59Z", comps.year ?? 2000, comps.month ?? 1, comps.day ?? 1)
    }
}

extension String {
    /// Converts Arabic-Indic and Persian digits to Western digits.
    var westernDigits: String {
        var out = ""
        for ch in self {
            if let v = ch.unicodeScalars.first?.value {
                switch v {
                case 0x0660...0x0669: out.append(Character(UnicodeScalar(v - 0x0660 + 48)!))
                case 0x06F0...0x06F9: out.append(Character(UnicodeScalar(v - 0x06F0 + 48)!))
                default: out.append(ch)
                }
            } else {
                out.append(ch)
            }
        }
        return out
    }
}

struct CardShape: Shape {
    func path(in rect: CGRect) -> Path {
        RoundedRectangle(cornerRadius: rect.width * 0.045, style: .continuous).path(in: rect)
    }
}

/// ID-1 card ratio (credit card / national ID): 85.6 × 54 mm
let cardAspectRatio: CGFloat = 1.586
