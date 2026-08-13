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
}
