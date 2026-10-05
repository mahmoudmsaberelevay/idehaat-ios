import Foundation

/// All app data (database + card images) lives in one protected folder on the device.
/// It is never synced. By default it is also excluded from iCloud/computer backups.
enum Vault {
    static let includeInBackupKey = "includeInBackup"

    static var directory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("Vault", isDirectory: true)
    }

    static var imagesDirectory: URL { directory.appendingPathComponent("Images", isDirectory: true) }
    static var storeURL: URL { directory.appendingPathComponent("Idehaat.store") }

    static func prepare() {
        let fm = FileManager.default
        let attributes: [FileAttributeKey: Any] = [.protectionKey: FileProtectionType.completeUnlessOpen]
        try? fm.createDirectory(at: imagesDirectory, withIntermediateDirectories: true, attributes: attributes)
        try? fm.setAttributes(attributes, ofItemAtPath: directory.path)
        try? fm.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: imagesDirectory.path)
        applyBackupPreference()
    }

    static var includeInBackup: Bool {
        get { UserDefaults.standard.bool(forKey: includeInBackupKey) }
        set {
            UserDefaults.standard.set(newValue, forKey: includeInBackupKey)
            applyBackupPreference()
        }
    }

    static func applyBackupPreference() {
        var url = directory
        var values = URLResourceValues()
        values.isExcludedFromBackup = !includeInBackup
        try? url.setResourceValues(values)
    }
}
