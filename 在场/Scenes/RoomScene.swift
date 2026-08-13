import Foundation

enum AmbientPreset: String, Codable, CaseIterable, Equatable, Hashable {
    case quiet
    case rain
    case forest
    case fireplace

    var displayName: String {
        switch self {
        case .quiet: "安静"
        case .rain: "雨声"
        case .forest: "林间鸟鸣"
        case .fireplace: "壁炉声"
        }
    }
}

enum SceneWeatherEffect: String, Codable, CaseIterable, Equatable, Hashable {
    case none
    case rain
}

enum ActivityColorTheme: String, Codable, Equatable {
    case midnightAmber
    case hearthWorkshop
    case morningAir
    case forestDawn
}

struct NormalizedScenePoint: Codable, Equatable {
    let x: Double
    let y: Double
}

struct ActivityTimerPolicy: Codable, Equatable {
    let focusMinutes: Int
    let restMinutes: Int

    static let standard = ActivityTimerPolicy(focusMinutes: 25, restMinutes: 10)
}

struct SceneImageMetadata: Codable, Equatable {
    let accessibilityDescription: String
}

struct SceneImageAsset: Codable, Equatable {
    let relativePath: String
    let metadata: SceneImageMetadata

    var accessibilityDescription: String { metadata.accessibilityDescription }
}

struct BaseActivityState: Codable, Equatable, Identifiable {
    typealias ID = String

    let id: ID
    let title: String
    let detail: String
    let backgroundDirection: String
    let colorTheme: ActivityColorTheme
    let ambientPresets: [AmbientPreset]
    let defaultAmbientPreset: AmbientPreset
    let availableEffects: [SceneWeatherEffect]
    let weatherEffect: SceneWeatherEffect
    let deskPetAnchor: NormalizedScenePoint
    let timerPolicy: ActivityTimerPolicy

    var background: SceneImageAsset {
        .packaged(
            sceneID: id,
            metadata: SceneImageMetadata(accessibilityDescription: "\(title)状态的静态像素背景")
        )
    }
}

extension SceneImageAsset {
    static func packaged(
        sceneID: RoomScene.ID,
        metadata: SceneImageMetadata
    ) -> SceneImageAsset {
        SceneImageAsset(
            relativePath: SceneGenerationContract.relativeImagePath(sceneID: sceneID),
            metadata: metadata
        )
    }
}

enum SceneOrigin: String, Codable, Equatable {
    case builtIn
    case generated
}

struct RoomScene: Codable, Equatable, Identifiable {
    typealias ID = String

    let id: ID
    let origin: SceneOrigin
    let name: String
    let eyebrow: String
    let headline: String
    let image: SceneImageAsset
    let ambientPreset: AmbientPreset
    let weatherEffect: SceneWeatherEffect
    let promptVersion: Int
    let activityState: BaseActivityState?

    init(
        id: ID,
        origin: SceneOrigin,
        name: String,
        eyebrow: String,
        headline: String,
        image: SceneImageAsset,
        ambientPreset: AmbientPreset,
        weatherEffect: SceneWeatherEffect,
        promptVersion: Int,
        activityState: BaseActivityState? = nil
    ) {
        self.id = id
        self.origin = origin
        self.name = name
        self.eyebrow = eyebrow
        self.headline = headline
        self.image = image
        self.ambientPreset = ambientPreset
        self.weatherEffect = weatherEffect
        self.promptVersion = promptVersion
        self.activityState = activityState
    }
}

/// Stores user-created scene metadata separately from bundled catalog content.
/// Image bytes live in `SceneAssetStore` and are referenced by relative path.
final class ScenePersistence {
    private let fileManager: FileManager
    private let fileURL: URL

    init(fileManager: FileManager = .default, fileURL: URL? = nil) {
        self.fileManager = fileManager
        self.fileURL = fileURL ?? AppStoragePaths.generatedScenesURL(fileManager: fileManager)
    }

    func load() -> [RoomScene] {
        guard let data = try? Data(contentsOf: fileURL),
              let scenes = try? JSONDecoder().decode([RoomScene].self, from: data) else { return [] }
        return scenes.filter { $0.origin == .generated && SceneGenerationContract.isValidSceneID($0.id) }
    }

    func save(_ scenes: [RoomScene]) throws {
        let directory = fileURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        try JSONEncoder().encode(scenes.filter { $0.origin == .generated }).write(to: fileURL, options: .atomic)
    }
}

enum RoomSceneCatalog {
    static let focus = BaseActivityState(
        id: "focus",
        title: "专注",
        detail: "把注意力放回眼前的一件事",
        backgroundDirection: "桌面、书本、屏幕、稳定的室内光线",
        colorTheme: .midnightAmber,
        ambientPresets: [.quiet, .rain],
        defaultAmbientPreset: .rain,
        availableEffects: [.none, .rain],
        weatherEffect: .rain,
        deskPetAnchor: NormalizedScenePoint(x: 0.82, y: 0.78),
        timerPolicy: .standard
    )

    static let make = BaseActivityState(
        id: "make",
        title: "创作",
        detail: "让想法在手边慢慢成形",
        backgroundDirection: "工作台、材料、纸张、局部暖光",
        colorTheme: .hearthWorkshop,
        ambientPresets: [.quiet, .fireplace],
        defaultAmbientPreset: .fireplace,
        availableEffects: [.none],
        weatherEffect: .none,
        deskPetAnchor: NormalizedScenePoint(x: 0.82, y: 0.78),
        timerPolicy: .standard
    )

    static let move = BaseActivityState(
        id: "move",
        title: "行动",
        detail: "起身，把计划变成动作",
        backgroundDirection: "训练空间、开阔地面、清爽的自然光",
        colorTheme: .morningAir,
        ambientPresets: [.quiet, .forest],
        defaultAmbientPreset: .quiet,
        availableEffects: [.none],
        weatherEffect: .none,
        deskPetAnchor: NormalizedScenePoint(x: 0.82, y: 0.80),
        timerPolicy: .standard
    )

    static let roam = BaseActivityState(
        id: "roam",
        title: "出走",
        detail: "去外面走一段，换一个视角",
        backgroundDirection: "林间道路、山野、车站或户外窗口",
        colorTheme: .forestDawn,
        ambientPresets: [.forest, .quiet],
        defaultAmbientPreset: .forest,
        availableEffects: [.none],
        weatherEffect: .none,
        deskPetAnchor: NormalizedScenePoint(x: 0.82, y: 0.80),
        timerPolicy: .standard
    )

    static let states: [BaseActivityState] = [focus, make, move, roam]

    static let focusScene = RoomScene(
        id: focus.id,
        origin: .builtIn,
        name: focus.title,
        eyebrow: "专注 · 雨夜书房",
        headline: "把注意力放回眼前",
        image: .packaged(
            sceneID: focus.id,
            metadata: SceneImageMetadata(
                accessibilityDescription: "专注状态的雨夜书房静态背景"
            )
        ),
        ambientPreset: focus.defaultAmbientPreset,
        weatherEffect: focus.weatherEffect,
        promptVersion: SceneGenerationContract.currentPromptVersion,
        activityState: focus
    )

    static let makeScene = RoomScene(
        id: make.id,
        origin: .builtIn,
        name: make.title,
        eyebrow: "创作 · 炉火工坊",
        headline: "让想法在手边成形",
        image: .packaged(
            sceneID: make.id,
            metadata: SceneImageMetadata(
                accessibilityDescription: "创作状态的暖光工作坊静态背景"
            )
        ),
        ambientPreset: make.defaultAmbientPreset,
        weatherEffect: make.weatherEffect,
        promptVersion: SceneGenerationContract.currentPromptVersion,
        activityState: make
    )

    static let moveScene = RoomScene(
        id: move.id,
        origin: .builtIn,
        name: move.title,
        eyebrow: "行动 · 晨光训练室",
        headline: "起身，把计划变成动作",
        image: .packaged(
            sceneID: move.id,
            metadata: SceneImageMetadata(
                accessibilityDescription: "行动状态的晨光训练空间静态背景"
            )
        ),
        ambientPreset: move.defaultAmbientPreset,
        weatherEffect: move.weatherEffect,
        promptVersion: SceneGenerationContract.currentPromptVersion,
        activityState: move
    )

    static let roamScene = RoomScene(
        id: roam.id,
        origin: .builtIn,
        name: roam.title,
        eyebrow: "出走 · 清晨山野小站",
        headline: "去外面走一段",
        image: .packaged(
            sceneID: roam.id,
            metadata: SceneImageMetadata(
                accessibilityDescription: "出走状态的清晨山野小站静态背景"
            )
        ),
        ambientPreset: roam.defaultAmbientPreset,
        weatherEffect: roam.weatherEffect,
        promptVersion: SceneGenerationContract.currentPromptVersion,
        activityState: roam
    )

    static let builtIn: [RoomScene] = [focusScene, makeScene, moveScene, roamScene]

    static func scene(for state: BaseActivityState) -> RoomScene {
        builtIn.first(where: { $0.activityState?.id == state.id }) ?? focusScene
    }

}
