import Foundation

struct MealImageStore {
    private let fileManager = FileManager.default

    func save(_ data: Data, id: UUID) throws -> String {
        let directory = try imagesDirectory()
        let filename = "\(id.uuidString).jpg"
        let url = directory.appendingPathComponent(filename)
        try data.write(to: url, options: [.atomic, .completeFileProtection])
        return filename
    }

    func data(for filename: String?) -> Data? {
        guard let filename,
              let directory = try? imagesDirectory() else { return nil }
        return try? Data(contentsOf: directory.appendingPathComponent(filename))
    }

    func delete(_ filename: String?) {
        guard let filename,
              let directory = try? imagesDirectory() else { return }
        try? fileManager.removeItem(at: directory.appendingPathComponent(filename))
    }

    private func imagesDirectory() throws -> URL {
        let base = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = base.appendingPathComponent("MealImages", isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}
