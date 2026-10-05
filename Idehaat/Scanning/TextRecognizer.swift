import UIKit
import Vision
import PDFKit

/// Reads text on the card (on-device, nothing leaves the phone) and suggests numbers and dates.
enum TextRecognizer {
    struct Suggestions: Equatable {
        var numbers: [String] = []
        var dates: [Date] = []
        var isEmpty: Bool { numbers.isEmpty && dates.isEmpty }
    }

    static func recognizeLines(in image: UIImage) async -> [String] {
        guard let cgImage = image.cgImage else { return [] }
        let orientation = image.cgOrientation
        return await Task.detached(priority: .userInitiated) { () -> [String] in
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = false
            let wanted = ["ar-SA", "en-US"]
            if let supported = try? request.supportedRecognitionLanguages() {
                let langs = wanted.filter { supported.contains($0) }
                if !langs.isEmpty { request.recognitionLanguages = langs }
            }
            let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation)
            do { try handler.perform([request]) } catch { return [] }
            return request.results?.compactMap { $0.topCandidates(1).first?.string } ?? []
        }.value
    }

    static func suggestions(from images: [UIImage]) async -> Suggestions {
        var lines: [String] = []
        for image in images { lines += await recognizeLines(in: image) }
        return parse(lines)
    }

    static func parse(_ lines: [String]) -> Suggestions {
        var result = Suggestions()
        let text = lines.joined(separator: "\n").westernDigits

        // Numbers: runs of 5+ digits (spaces/dashes allowed inside), e.g. 14-digit Egyptian national ID.
        if let regex = try? NSRegularExpression(pattern: "(?<![0-9])[0-9](?:[0-9 \\-]{3,24})[0-9](?![0-9])") {
            let ns = text as NSString
            for match in regex.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
                let raw = ns.substring(with: match.range)
                let compact = raw.filter(\.isNumber)
                guard compact.count >= 5, compact.count <= 20 else { continue }
                if looksLikeDate(raw) { continue }
                if !result.numbers.contains(compact) { result.numbers.append(compact) }
            }
        }
        result.numbers.sort { $0.count > $1.count }
        result.numbers = Array(result.numbers.prefix(4))

        // Dates: dd/mm/yyyy, yyyy/mm/dd (with / - . separators)
        let patterns = [
            "(?<![0-9])([0-3]?[0-9])[/\\-.]([01]?[0-9])[/\\-.]((?:19|20)[0-9]{2})(?![0-9])",
            "(?<![0-9])((?:19|20)[0-9]{2})[/\\-.]([01]?[0-9])[/\\-.]([0-3]?[0-9])(?![0-9])",
        ]
        let cal = Calendar(identifier: .gregorian)
        for (index, pattern) in patterns.enumerated() {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let ns = text as NSString
            for m in regex.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
                let parts = (1...3).map { Int(ns.substring(with: m.range(at: $0))) ?? 0 }
                let (d, mo, y) = index == 0 ? (parts[0], parts[1], parts[2]) : (parts[2], parts[1], parts[0])
                var comps = DateComponents()
                comps.year = y; comps.month = mo; comps.day = d; comps.hour = 12
                guard (1...12).contains(mo), (1...31).contains(d), let date = cal.date(from: comps) else { continue }
                if !result.dates.contains(where: { cal.isDate($0, inSameDayAs: date) }) { result.dates.append(date) }
            }
        }
        result.dates.sort(by: >)
        return result
    }

    private static func looksLikeDate(_ s: String) -> Bool {
        s.range(of: "^[0-9]{1,4}[\\-.][0-9]{1,2}[\\-.][0-9]{1,4}$", options: .regularExpression) != nil
    }

    /// Renders the first page of a PDF (e.g. a scanned card exported as PDF).
    static func firstPageImage(ofPDF url: URL) -> UIImage? {
        guard let document = PDFDocument(url: url), let page = document.page(at: 0) else { return nil }
        let bounds = page.bounds(for: .mediaBox)
        let scale = 2400 / max(bounds.width, bounds.height)
        return page.thumbnail(of: CGSize(width: bounds.width * scale, height: bounds.height * scale), for: .mediaBox)
    }
}

extension UIImage {
    var cgOrientation: CGImagePropertyOrientation {
        switch imageOrientation {
        case .up: return .up
        case .down: return .down
        case .left: return .left
        case .right: return .right
        case .upMirrored: return .upMirrored
        case .downMirrored: return .downMirrored
        case .leftMirrored: return .leftMirrored
        case .rightMirrored: return .rightMirrored
        @unknown default: return .up
        }
    }
}
