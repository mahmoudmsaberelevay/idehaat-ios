import UIKit

enum ImageStore {
    private static let cache = NSCache<NSString, UIImage>()
    private static let maxDimension: CGFloat = 2400

    enum StoreError: Error { case encodingFailed }

    static func url(for name: String) -> URL {
        Vault.imagesDirectory.appendingPathComponent(name)
    }

    /// Saves an image with full file protection and returns its file name.
    static func save(_ image: UIImage) throws -> String {
        let prepared = image.downscaled(maxDimension: maxDimension)
        guard let data = prepared.jpegData(compressionQuality: 0.85) else { throw StoreError.encodingFailed }
        let name = UUID().uuidString + ".jpg"
        try data.write(to: url(for: name), options: [.atomic, .completeFileProtection])
        cache.setObject(prepared, forKey: name as NSString)
        return name
    }

    static func load(_ name: String?) -> UIImage? {
        guard let name, !name.isEmpty else { return nil }
        if let cached = cache.object(forKey: name as NSString) { return cached }
        guard let data = try? Data(contentsOf: url(for: name)), let image = UIImage(data: data) else { return nil }
        cache.setObject(image, forKey: name as NSString)
        return image
    }

    static func delete(_ name: String?) {
        guard let name, !name.isEmpty else { return }
        cache.removeObject(forKey: name as NSString)
        try? FileManager.default.removeItem(at: url(for: name))
    }

    static func clearCache() { cache.removeAllObjects() }
}

extension UIImage {
    /// Fixes orientation and limits size so stored files stay small.
    func downscaled(maxDimension: CGFloat) -> UIImage {
        let longest = max(size.width, size.height)
        let scale = longest > maxDimension ? maxDimension / longest : 1
        let target = CGSize(width: (size.width * scale).rounded(), height: (size.height * scale).rounded())
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: target))
        }
    }
}
