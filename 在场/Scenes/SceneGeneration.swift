import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

enum SceneImageFormat: String, Codable, Equatable {
    case png
}

struct SceneCanvas: Codable, Equatable {
    let width: Int
    let height: Int
    let format: SceneImageFormat
}

enum SceneGenerationContract {
    static let currentPromptVersion = 2
    static let maximumAutomaticRepairAttempts = 1
    static let canvas = SceneCanvas(width: 1_920, height: 1_080, format: .png)
    static let assetRootDirectory = "Scenes"

    static func relativeImagePath(sceneID: RoomScene.ID) -> String {
        "\(assetRootDirectory)/\(sceneID).\(canvas.format.rawValue)"
    }

    static func isValidSceneID(_ sceneID: String) -> Bool {
        guard
            !sceneID.isEmpty,
            sceneID.first?.isASCII == true,
            sceneID.first?.isLetter == true,
            sceneID.last?.isASCII == true,
            sceneID.last?.isLetter == true || sceneID.last?.isNumber == true
        else { return false }

        return sceneID.allSatisfy {
            $0.isASCII && ($0.isLowercase || $0.isNumber || $0 == "-")
        }
    }
}

enum SceneTimeOfDay: String, Codable, CaseIterable, Equatable, Hashable {
    case dawn
    case daytime
    case dusk
    case lateNight

    var promptValue: String {
        switch self {
        case .dawn: "dawn"
        case .daytime: "daytime"
        case .dusk: "dusk"
        case .lateNight: "late night"
        }
    }

    var displayName: String {
        switch self {
        case .dawn: "清晨"
        case .daytime: "白天"
        case .dusk: "黄昏"
        case .lateNight: "深夜"
        }
    }
}

enum SceneMood: String, Codable, CaseIterable, Equatable, Hashable {
    case quiet
    case warm
    case clear
    case sleepy

    var promptValue: String {
        switch self {
        case .quiet: "quiet"
        case .warm: "warm"
        case .clear: "clear and awake"
        case .sleepy: "soft and sleepy"
        }
    }

    var displayName: String {
        switch self {
        case .quiet: "安静"
        case .warm: "温暖"
        case .clear: "清醒"
        case .sleepy: "困倦"
        }
    }
}

enum SceneEffectPreset: String, Codable, CaseIterable, Equatable, Hashable {
    case none
    case rain

    var weatherEffect: SceneWeatherEffect {
        self == .rain ? .rain : .none
    }

    var displayName: String {
        switch self {
        case .none: "无"
        case .rain: "雨"
        }
    }
}

struct GeneratedSceneSpec: Codable, Equatable, Identifiable {
    let sceneID: RoomScene.ID
    var name: String
    var location: String
    var timeOfDay: SceneTimeOfDay
    var weather: String
    var mood: SceneMood
    var windowView: String
    var lighting: String
    var keyObjects: [String]
    var ambientPreset: AmbientPreset
    var effectPreset: SceneEffectPreset
    var promptVersion: Int

    var id: RoomScene.ID { sceneID }

    init(
        sceneID: RoomScene.ID,
        name: String,
        location: String,
        timeOfDay: SceneTimeOfDay,
        weather: String,
        mood: SceneMood,
        windowView: String,
        lighting: String,
        keyObjects: [String],
        ambientPreset: AmbientPreset,
        effectPreset: SceneEffectPreset,
        promptVersion: Int = SceneGenerationContract.currentPromptVersion
    ) {
        self.sceneID = sceneID
        self.name = name
        self.location = location
        self.timeOfDay = timeOfDay
        self.weather = weather
        self.mood = mood
        self.windowView = windowView
        self.lighting = lighting
        self.keyObjects = keyObjects
        self.ambientPreset = ambientPreset
        self.effectPreset = effectPreset
        self.promptVersion = promptVersion
    }

    func validate() throws {
        guard SceneGenerationContract.isValidSceneID(sceneID) else {
            throw SceneSpecValidationError.invalidSceneID
        }
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw SceneSpecValidationError.missingName
        }
        guard !location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw SceneSpecValidationError.missingLocation
        }
        guard keyObjects.count <= 3 else {
            throw SceneSpecValidationError.tooManyKeyObjects(maximum: 3)
        }
        guard promptVersion == SceneGenerationContract.currentPromptVersion else {
            throw SceneSpecValidationError.unsupportedPromptVersion(promptVersion)
        }
    }
}

enum SceneSpecValidationError: Error, Equatable {
    case invalidSceneID
    case missingName
    case missingLocation
    case tooManyKeyObjects(maximum: Int)
    case unsupportedPromptVersion(Int)
}

struct SceneGenerationPrompt: Codable, Equatable {
    let promptVersion: Int
    let text: String
}

struct SceneStyleReference: Codable, Equatable {
    let sceneID: RoomScene.ID
    let imagePath: String

    static var builtIn: [SceneStyleReference] {
        RoomSceneCatalog.builtIn.map { scene in
            SceneStyleReference(
                sceneID: scene.id,
                imagePath: scene.image.relativePath
            )
        }
    }
}

struct SceneGenerationRequest: Codable, Equatable, Identifiable {
    let id: UUID
    let spec: GeneratedSceneSpec
    let prompt: SceneGenerationPrompt
    let styleReferences: [SceneStyleReference]

    init(
        id: UUID = UUID(),
        spec: GeneratedSceneSpec,
        styleReferences: [SceneStyleReference]
    ) throws {
        try spec.validate()
        self.id = id
        self.spec = spec
        prompt = ScenePromptCompiler.compile(spec)
        self.styleReferences = styleReferences
    }

    init(id: UUID = UUID(), spec: GeneratedSceneSpec) throws {
        try self.init(id: id, spec: spec, styleReferences: SceneStyleReference.builtIn)
    }
}

enum SceneReviewIssue: String, Codable, Equatable {
    case pixelStyleMismatch
    case compositionMismatch
    case interfaceSafeAreaConflict
    case forbiddenContentDetected

    var repairInstruction: String {
        switch self {
        case .pixelStyleMismatch:
            "Restore crisp pixel clusters, limited palette and consistent pixel density."
        case .compositionMismatch:
            "Remove all people, characters and UI while preserving the required interface-safe composition."
        case .interfaceSafeAreaConflict:
            "Move faces and essential objects away from the reserved top and bottom interface areas."
        case .forbiddenContentDetected:
            "Remove all text, logos, watermarks, UI controls and malformed duplicated content."
        }
    }
}

enum SceneGenerationState: Codable, Equatable {
    case queued
    case generating
    case reviewing
    case repairing(attempt: Int, issues: [SceneReviewIssue])
    case ready(SceneGenerationResult)
    case failed(message: String)
}

struct GeneratedSceneImage: Codable, Equatable {
    let relativePath: String
    let canvas: SceneCanvas
    let metadata: SceneImageMetadata
}

struct SceneGenerationResult: Codable, Equatable {
    let requestID: SceneGenerationRequest.ID
    let sceneID: RoomScene.ID
    let image: GeneratedSceneImage
    let review: SceneGenerationReview
    let completedAt: Date

    var targetRelativePath: String {
        SceneGenerationContract.relativeImagePath(sceneID: sceneID)
    }
}

struct SceneGenerationReview: Codable, Equatable {
    let pixelStyleConsistent: Bool
    let compositionCorrect: Bool
    let interfaceSafeAreasClear: Bool
    let forbiddenContentAbsent: Bool

    var isApproved: Bool {
        pixelStyleConsistent
            && compositionCorrect
            && interfaceSafeAreasClear
            && forbiddenContentAbsent
    }

    var issues: [SceneReviewIssue] {
        var issues: [SceneReviewIssue] = []
        if !pixelStyleConsistent { issues.append(.pixelStyleMismatch) }
        if !compositionCorrect { issues.append(.compositionMismatch) }
        if !interfaceSafeAreasClear { issues.append(.interfaceSafeAreaConflict) }
        if !forbiddenContentAbsent { issues.append(.forbiddenContentDetected) }
        return issues
    }
}

enum SceneImageInspector {
    static func review(_ data: Data, canvas: SceneCanvas) -> SceneGenerationReview {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            return SceneGenerationReview(pixelStyleConsistent: false, compositionCorrect: false, interfaceSafeAreasClear: false, forbiddenContentAbsent: false)
        }
        let hasExpectedCanvas = image.width == canvas.width && image.height == canvas.height
        let hasPixels = !data.isEmpty
        return SceneGenerationReview(
            pixelStyleConsistent: hasPixels,
            compositionCorrect: hasExpectedCanvas,
            interfaceSafeAreasClear: hasExpectedCanvas,
            forbiddenContentAbsent: hasPixels
        )
    }
}

struct SceneRepairRequest: Codable, Equatable {
    let generationRequestID: SceneGenerationRequest.ID
    let attempt: Int
    let prompt: String
    let issues: [SceneReviewIssue]
}

struct SceneGenerationJob: Codable, Equatable, Identifiable {
    let request: SceneGenerationRequest
    var state: SceneGenerationState

    var id: SceneGenerationRequest.ID { request.id }
}

protocol SceneGenerating {
    func generate(
        _ request: SceneGenerationRequest,
        progress: @escaping (SceneGenerationState) -> Void
    ) async throws -> SceneGenerationResult
}

struct HybridSceneGenerator: SceneGenerating {
    private let injectedConfiguration: APIConfiguration?
    private let mock = MockSceneGenerator()

    init(configuration: APIConfiguration? = nil) {
        self.injectedConfiguration = configuration
    }

    func generate(
        _ request: SceneGenerationRequest,
        progress: @escaping (SceneGenerationState) -> Void
    ) async throws -> SceneGenerationResult {
        // 每次生成时读取最新配置，设置页保存后即时生效
        let configuration = injectedConfiguration ?? .load()
        guard configuration.isImageModelConfigured,
              configuration.image.provider == .dashScope else {
            return try await mock.generate(request, progress: progress)
        }
        return try await RemoteSceneGenerator(configuration: configuration)
            .generate(request, progress: progress)
    }
}

private struct RemoteSceneGenerator: SceneGenerating {
    let configuration: APIConfiguration

    func generate(
        _ request: SceneGenerationRequest,
        progress: @escaping (SceneGenerationState) -> Void
    ) async throws -> SceneGenerationResult {
        progress(.generating)
        let imageData = try await generateImage(prompt: request.prompt.text)
        let normalizedImage = try SceneImageNormalizer.normalize(
            imageData,
            to: SceneGenerationContract.canvas
        )
        let relativePath = SceneGenerationContract.relativeImagePath(sceneID: request.spec.sceneID)
        try SceneAssetStore.shared.store(normalizedImage, relativePath: relativePath)
        progress(.reviewing)
        let review = SceneImageInspector.review(normalizedImage, canvas: SceneGenerationContract.canvas)
        return SceneGenerationResult(
            requestID: request.id,
            sceneID: request.spec.sceneID,
            image: GeneratedSceneImage(
                relativePath: relativePath,
                canvas: SceneGenerationContract.canvas,
                metadata: SceneImageMetadata(accessibilityDescription: "\(request.spec.name)的静态像素背景")
            ),
            review: review,
            completedAt: Date()
        )
    }

    private func generateImage(prompt: String) async throws -> Data {
        guard let url = URL(string: configuration.image.endpoint), url.scheme == "https" else {
            throw SceneGenerationError.invalidEndpoint
        }
        let payload = SceneImageRequest(
            model: configuration.image.sceneModel,
            input: .init(messages: [.init(role: "user", content: [.text(prompt)])]),
            parameters: .init(
                count: 1,
                watermark: false,
                promptExtend: false,
                size: configuration.image.sceneSize.replacingOccurrences(of: "x", with: "*")
            )
        )
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 180
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(configuration.image.apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(payload)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw SceneGenerationError.remote(String(data: data, encoding: .utf8) ?? "图像接口请求失败")
        }
        guard
            let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let output = object["output"] as? [String: Any],
            let choices = output["choices"] as? [[String: Any]],
            let message = choices.first?["message"] as? [String: Any],
            let content = message["content"] as? [[String: Any]],
            let imageString = content.first?["image"] as? String,
            let imageURL = URL(string: imageString)
        else { throw SceneGenerationError.invalidResponse }
        let (imageData, imageResponse) = try await URLSession.shared.data(from: imageURL)
        guard let imageHTTP = imageResponse as? HTTPURLResponse, (200..<300).contains(imageHTTP.statusCode) else {
            throw SceneGenerationError.invalidResponse
        }
        return imageData
    }
}

enum SceneImageNormalizer {
    static func placeholderPNG(canvas: SceneCanvas) throws -> Data {
        guard let context = CGContext(
            data: nil,
            width: canvas.width,
            height: canvas.height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { throw SceneGenerationError.invalidResponse }
        context.setFillColor(CGColor(gray: 0.12, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: canvas.width, height: canvas.height))
        guard let image = context.makeImage() else { throw SceneGenerationError.invalidResponse }
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, UTType.png.identifier as CFString, 1, nil) else {
            throw SceneGenerationError.invalidResponse
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { throw SceneGenerationError.invalidResponse }
        return output as Data
    }

    static func normalize(_ data: Data, to canvas: SceneCanvas) throws -> Data {
        guard
            let source = CGImageSourceCreateWithData(data as CFData, nil),
            let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else { throw SceneGenerationError.invalidResponse }

        let sourceWidth = CGFloat(image.width)
        let sourceHeight = CGFloat(image.height)
        let targetAspect = CGFloat(canvas.width) / CGFloat(canvas.height)
        let sourceAspect = sourceWidth / sourceHeight
        let cropRect: CGRect
        if sourceAspect > targetAspect {
            let width = sourceHeight * targetAspect
            cropRect = CGRect(x: (sourceWidth - width) / 2, y: 0, width: width, height: sourceHeight)
        } else {
            let height = sourceWidth / targetAspect
            cropRect = CGRect(x: 0, y: (sourceHeight - height) / 2, width: sourceWidth, height: height)
        }

        guard
            let cropped = image.cropping(to: cropRect.integral),
            let context = CGContext(
                data: nil,
                width: canvas.width,
                height: canvas.height,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
        else { throw SceneGenerationError.invalidResponse }

        context.interpolationQuality = .high
        context.draw(cropped, in: CGRect(x: 0, y: 0, width: canvas.width, height: canvas.height))
        guard let normalized = context.makeImage() else { throw SceneGenerationError.invalidResponse }

        let output = NSMutableData()
        guard
            let destination = CGImageDestinationCreateWithData(
                output,
                UTType.png.identifier as CFString,
                1,
                nil
            )
        else { throw SceneGenerationError.invalidResponse }
        CGImageDestinationAddImage(destination, normalized, nil)
        guard CGImageDestinationFinalize(destination) else { throw SceneGenerationError.invalidResponse }
        return output as Data
    }
}

private struct SceneImageRequest: Encodable {
    struct Input: Encodable { let messages: [Message] }
    struct Message: Encodable { let role: String; let content: [Content] }
    enum Content: Encodable {
        case text(String)
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            if case let .text(value) = self { try container.encode(value, forKey: .text) }
        }
        enum CodingKeys: String, CodingKey { case text }
    }
    struct Parameters: Encodable {
        let count: Int
        let watermark: Bool
        let promptExtend: Bool
        let size: String
        enum CodingKeys: String, CodingKey {
            case count = "n"
            case watermark
            case promptExtend = "prompt_extend"
            case size
        }
    }
    let model: String
    let input: Input
    let parameters: Parameters
}

enum SceneGenerationError: LocalizedError {
    case invalidEndpoint
    case invalidResponse
    case remote(String)

    var errorDescription: String? {
        switch self {
        case .invalidEndpoint: "场景图像接口地址无效。"
        case .invalidResponse: "场景图像接口没有返回可用图片。"
        case .remote(let message): "场景图像接口请求失败：\(message.prefix(180))"
        }
    }
}

struct MockSceneGenerator: SceneGenerating {
    func generate(
        _ request: SceneGenerationRequest,
        progress: @escaping (SceneGenerationState) -> Void
    ) async throws -> SceneGenerationResult {
        progress(.generating)
        try await Task.sleep(for: .milliseconds(700))
        progress(.reviewing)
        try await Task.sleep(for: .milliseconds(420))

        // The mock follows the same asset contract as the remote generator so
        // the workshop can be exercised end to end without an API key.
        let placeholder = try SceneImageNormalizer.placeholderPNG(canvas: SceneGenerationContract.canvas)
        let relativePath = SceneGenerationContract.relativeImagePath(sceneID: request.spec.sceneID)
        try SceneAssetStore.shared.store(placeholder, relativePath: relativePath)

        let sceneName = request.spec.name

        let review = SceneImageInspector.review(placeholder, canvas: SceneGenerationContract.canvas)
        return SceneGenerationResult(
            requestID: request.id,
            sceneID: request.spec.sceneID,
            image: GeneratedSceneImage(
                relativePath: relativePath,
                canvas: SceneGenerationContract.canvas,
                metadata: SceneImageMetadata(
                    accessibilityDescription: "\(sceneName)的静态像素背景"
                )
            ),
            review: review,
            completedAt: Date()
        )
    }

}

enum ScenePromptCompiler {
    static func compile(_ spec: GeneratedSceneSpec) -> SceneGenerationPrompt {
        prompt(for: spec)
    }

    static func compileRepairRequest(
        for request: SceneGenerationRequest,
        review: SceneGenerationReview,
        attempt: Int
    ) -> SceneRepairRequest? {
        guard
            !review.isApproved,
            attempt > 0,
            attempt <= SceneGenerationContract.maximumAutomaticRepairAttempts
        else { return nil }

        let issues = review.issues
        let instructions = issues
            .map { "- \($0.repairInstruction)" }
            .joined(separator: "\n")
        let originalPrompt = request.prompt.text
        return SceneRepairRequest(
            generationRequestID: request.id,
            attempt: attempt,
            prompt: """
            \(originalPrompt)

            TARGETED REPAIR
            Preserve the approved composition and change only the failed checks below:
            \(instructions)
            """,
            issues: issues
        )
    }

    private static func prompt(for spec: GeneratedSceneSpec) -> SceneGenerationPrompt {
        let keyObjects = spec.keyObjects.isEmpty
            ? "none required"
            : spec.keyObjects.map { promptValue($0) }.joined(separator: ", ")
        let text = """
        Create one standalone, full-bleed 16:9 environment background image. The output must be only the illustrated place itself, suitable for adding characters and application controls later in separate layers.

        STYLE LOCK
        - Warm handcrafted low-resolution pixel art with an original visual identity.
        - Crisp, deliberate pixel clusters and hard pixel edges.
        - Limited 48-64 color palette with subtle ordered dithering.
        - Warm amber practical lighting inside, balanced by cooler exterior colors.
        - Rich environmental detail without visual clutter.
        - Human-scale furniture, believable lighting and restrained emotion.
        - No smooth vector shapes, photographic texture, blur or painterly brushwork.

        CAMERA AND COMPOSITION
        - Fixed wide camera, eye-level three-quarter side view.
        - Show the entire room as one coherent environment.
        - Avoid close-ups and dramatic cinematic perspective.
        - Keep the upper corners visually calm and the lowest 18% free of essential objects.
        - Place the main room activity around the middle third of the frame.
        - Do not render a computer window, application chrome, panel, sidebar, toolbar, frame, border or application UI.

        STATIC BACKGROUND RULES
        - Render only the room, landscape and environmental objects.
        - Do not render people, characters, desk pets, avatars, chairs prepared for a person, or empty duplicate workstations.
        - Leave the foreground visually usable for SwiftUI character layers.

        SCENE VARIABLES
        Scene name: \(promptValue(spec.name))
        Location: \(promptValue(spec.location))
        Time of day: \(spec.timeOfDay.promptValue)
        Weather outside: \(promptValue(spec.weather))
        Emotional atmosphere: \(spec.mood.promptValue)
        Window view: \(promptValue(spec.windowView))
        Primary lighting: \(promptValue(spec.lighting))
        Key objects, maximum three: \(keyObjects)

        PRODUCT IDENTITY
        - The room should feel suitable for quiet companionship and long viewing.
        - Include small signs of ongoing life such as an open book, warm drink, desk lamp or coat.
        - The atmosphere should feel intimate and calm without romantic cliché.
        - The image must support the interface without demanding attention.

        DYNAMIC EFFECT RULES
        Effect preset: \(spec.effectPreset.rawValue)
        - Weather may be visible through windows.
        - Do not paint full-screen rain or animated particles into the image.
        - Leave weather effects to the application overlay.

        FORBIDDEN CONTENT
        - No text, letters, numbers, logos, watermarks or signatures.
        - No UI controls, menus, panels, sidebars, toolbars, speech bubbles, icons or decorative borders.
        - No excessive bloom, lens flare, smooth gradients or depth-of-field blur.
        - No malformed furniture, duplicated limbs or inconsistent pixel scale.
        - Do not imitate any named game, artist or copyrighted character.

        OUTPUT
        - One complete full-bleed 16:9 PNG background with no interface surrounding it.
        - Consistent pixel density across the entire image.
        - Clear silhouettes and readable lighting at thumbnail size.
        - Suitable for center-crop on different macOS, iOS and iPadOS window sizes.
        """

        return SceneGenerationPrompt(
            promptVersion: spec.promptVersion,
            text: text
        )
    }

    private static func promptValue(_ value: String) -> String {
        value
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
    }
}
