import Foundation

struct MealImageStore {
    static func deleteLegacyImages() {
        let fileManager = FileManager.default
        guard let base = try? fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ) else { return }
        let directory = base.appendingPathComponent("MealImages", isDirectory: true)
        try? fileManager.removeItem(at: directory)
    }
}
