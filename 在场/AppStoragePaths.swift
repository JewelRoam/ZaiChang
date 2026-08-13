import Foundation

/// Centralizes app-scoped persistence locations.
enum AppStoragePaths {
    static let rootDirectoryName = "Zaichang"

    static func applicationSupportRoot(fileManager: FileManager = .default) -> URL {
        fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(rootDirectoryName, isDirectory: true)
    }

    static func memoriesURL(fileManager: FileManager = .default) -> URL {
        applicationSupportRoot(fileManager: fileManager).appendingPathComponent("memories.json")
    }

    static func voiceNotesURL(fileManager: FileManager = .default) -> URL {
        applicationSupportRoot(fileManager: fileManager).appendingPathComponent("voice-notes.json")
    }

    static func generatedScenesURL(fileManager: FileManager = .default) -> URL {
        applicationSupportRoot(fileManager: fileManager).appendingPathComponent("generated-scenes.json")
    }

    static func apiConfigurationURL(fileManager: FileManager = .default) -> URL {
        applicationSupportRoot(fileManager: fileManager).appendingPathComponent("api.yaml")
    }

    static func deskPetsDirectory(fileManager: FileManager = .default) -> URL {
        applicationSupportRoot(fileManager: fileManager).appendingPathComponent("DeskPets", isDirectory: true)
    }

    static func recordingsDirectory(fileManager: FileManager = .default) -> URL {
        applicationSupportRoot(fileManager: fileManager).appendingPathComponent("Recordings", isDirectory: true)
    }

    static func scenesDirectory(fileManager: FileManager = .default) -> URL {
        applicationSupportRoot(fileManager: fileManager).appendingPathComponent("Scenes", isDirectory: true)
    }

    /// UserDefaults keys owned by the app, cleared on a full data reset.
    static let userDefaultsKeys = ["dailyTodoCompletedAt"]

    /// Wipes persisted artifacts under `Application Support/Zaichang/` plus the
    /// app-owned UserDefaults keys. The API configuration file is intentionally
    /// preserved so a data reset does not clear the user's model/API settings.
    static func resetAllData(
        fileManager: FileManager = .default,
        userDefaults: UserDefaults = .standard
    ) {
        let root = applicationSupportRoot(fileManager: fileManager)
        let preserved = apiConfigurationURL(fileManager: fileManager).lastPathComponent

        if let contents = try? fileManager.contentsOfDirectory(atPath: root.path) {
            for item in contents where item != preserved {
                try? fileManager.removeItem(at: root.appendingPathComponent(item))
            }
        }
        for key in userDefaultsKeys {
            userDefaults.removeObject(forKey: key)
        }
    }
}
