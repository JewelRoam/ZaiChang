import Foundation
import Combine

// MARK: - Generation State

enum DeskPetGenerationState: Equatable {
    case idle
    case photoSelected
    case generating
    case ready
    case failed(String)
}

enum DeskPetNudgeFeedbackKind: Equatable {
    case sent
    case received
    case unavailable

    var animatesDeskPet: Bool {
        self != .unavailable
    }
}

struct DeskPetNudgeFeedback: Equatable, Identifiable {
    let id = UUID()
    let message: String
    let kind: DeskPetNudgeFeedbackKind
}

enum DeskPetPersistenceError: LocalizedError {
    case saveFailed(String)
    case removeFailed(String)
    var errorDescription: String? {
        switch self {
        case .saveFailed(let message): "桌宠保存失败：\(message)"
        case .removeFailed(let message): "桌宠缓存清理失败：\(message)"
        }
    }
}

// MARK: - Base Class

/// 桌宠数据基类，所有桌宠类型继承此类
class DeskPetBase: Equatable, Identifiable, ObservableObject {
    let id: UUID
    let imageData: Data
    @Published var isEnabled: Bool

    init(id: UUID = UUID(), imageData: Data, isEnabled: Bool = false) {
        self.id = id
        self.imageData = imageData
        self.isEnabled = isEnabled
    }

    static func == (lhs: DeskPetBase, rhs: DeskPetBase) -> Bool {
        lhs.id == rhs.id && lhs.imageData == rhs.imageData && lhs.isEnabled == rhs.isEnabled
    }
}

/// 好友桌宠，从好友照片生成
final class FriendDeskPet: DeskPetBase {
    let partnerID: DeskPartner.ID
    let partnerName: String
    let sourceImageData: Data

    init(
        id: UUID = UUID(),
        partnerID: DeskPartner.ID,
        partnerName: String,
        sourceImageData: Data,
        generatedImageData: Data,
        isEnabled: Bool = false
    ) {
        self.partnerID = partnerID
        self.partnerName = partnerName
        self.sourceImageData = sourceImageData
        super.init(id: id, imageData: generatedImageData, isEnabled: isEnabled)
    }

    static func == (lhs: FriendDeskPet, rhs: FriendDeskPet) -> Bool {
        lhs.id == rhs.id &&
        lhs.partnerID == rhs.partnerID &&
        lhs.imageData == rhs.imageData &&
        lhs.isEnabled == rhs.isEnabled
    }
}

// MARK: - Legacy Compatibility

/// 保持现有 API 兼容，将逐步迁移
struct DeskPetProfile: Equatable, Identifiable {
    let id: UUID
    let partnerID: DeskPartner.ID
    let partnerName: String
    let sourceImageData: Data
    let generatedImageData: Data
    var isEnabled: Bool

    init(id: UUID, partnerID: DeskPartner.ID, partnerName: String, sourceImageData: Data, generatedImageData: Data, isEnabled: Bool) {
        self.id = id
        self.partnerID = partnerID
        self.partnerName = partnerName
        self.sourceImageData = sourceImageData
        self.generatedImageData = generatedImageData
        self.isEnabled = isEnabled
    }

    init(from pet: FriendDeskPet) {
        self.id = pet.id
        self.partnerID = pet.partnerID
        self.partnerName = pet.partnerName
        self.sourceImageData = pet.sourceImageData
        self.generatedImageData = pet.imageData
        self.isEnabled = pet.isEnabled
    }
}

private struct PersistedDeskPetRecord: Codable, Equatable {
    static let currentVersion = 1

    let version: Int
    let id: UUID
    let partnerID: UUID
    let partnerName: String
    let generatedImageFilename: String
    var isEnabled: Bool
}

/// Persists only the generated desk-pet asset and the metadata needed to restore it.
/// The selected friend photo is intentionally kept session-only.
final class DeskPetPersistence {
    private let fileManager: FileManager
    private let directoryURL: URL

    init(
        directoryURL: URL? = nil,
        fileManager: FileManager = .default
    ) {
        self.fileManager = fileManager
        self.directoryURL = directoryURL ?? Self.defaultDirectory(fileManager: fileManager)
    }

    func load() -> DeskPetProfile? {
        let recordURL = directoryURL.appendingPathComponent("profile.json")
        guard
            let recordData = try? Data(contentsOf: recordURL),
            let record = try? JSONDecoder().decode(PersistedDeskPetRecord.self, from: recordData),
            record.version == PersistedDeskPetRecord.currentVersion,
            let imageData = try? Data(
                contentsOf: directoryURL.appendingPathComponent(record.generatedImageFilename)
            ),
            !imageData.isEmpty
        else { return nil }

        return DeskPetProfile(
            id: record.id,
            partnerID: record.partnerID,
            partnerName: record.partnerName,
            sourceImageData: Data(),
            generatedImageData: imageData,
            isEnabled: record.isEnabled
        )
    }

    func save(_ profile: DeskPetProfile) throws {
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)

        let imageFilename = "generated-\(profile.id.uuidString).png"
        let imageURL = directoryURL.appendingPathComponent(imageFilename)
        let recordURL = directoryURL.appendingPathComponent("profile.json")
        let record = PersistedDeskPetRecord(
            version: PersistedDeskPetRecord.currentVersion,
            id: profile.id,
            partnerID: profile.partnerID,
            partnerName: profile.partnerName,
            generatedImageFilename: imageFilename,
            isEnabled: profile.isEnabled
        )

        try profile.generatedImageData.write(to: imageURL, options: .atomic)
        try JSONEncoder().encode(record).write(to: recordURL, options: .atomic)
        try removeObsoleteImages(except: imageFilename)
    }

    func remove() throws {
        guard fileManager.fileExists(atPath: directoryURL.path) else { return }
        try fileManager.removeItem(at: directoryURL)
    }

    private func removeObsoleteImages(except filename: String) throws {
        guard let files = try? fileManager.contentsOfDirectory(atPath: directoryURL.path) else { return }
        for file in files where file.hasPrefix("generated-") && file.hasSuffix(".png") && file != filename {
            try fileManager.removeItem(at: directoryURL.appendingPathComponent(file))
        }
    }

    private static func defaultDirectory(fileManager: FileManager) -> URL {
        AppStoragePaths.deskPetsDirectory(fileManager: fileManager)
    }
}

protocol DeskPetGenerating {
    func generate(photoData: Data, partnerName: String) async throws -> Data
}

/// MVP implementation: keeps the generation boundary real while returning the
/// selected photo. A production generator can later call an image-edit API here.
struct MockDeskPetGenerator: DeskPetGenerating {
    func generate(photoData: Data, partnerName: String) async throws -> Data {
        try await Task.sleep(for: .milliseconds(500))
        guard !photoData.isEmpty else { throw DeskPetError.invalidPhoto }
        return photoData
    }
}

struct HybridDeskPetGenerator: DeskPetGenerating {
    private let configuration: APIConfiguration
    private let mock = MockDeskPetGenerator()

    init(configuration: APIConfiguration = .load()) {
        self.configuration = configuration
    }

    func generate(photoData: Data, partnerName: String) async throws -> Data {
        guard configuration.isImageModelConfigured else {
            return try await mock.generate(photoData: photoData, partnerName: partnerName)
        }
        let generated = try await RemoteDeskPetGenerator(configuration: configuration)
            .generate(photoData: photoData, partnerName: partnerName)

        // 抠图，确保透明背景
        return try await RemoteMattingClient(configuration: configuration.matting)
            .removeBackground(from: generated)
    }
}

private struct RemoteMattingClient {
    let configuration: APIConfiguration.Matting

    func removeBackground(from imageData: Data) async throws -> Data {
        guard let url = URL(string: configuration.endpoint),
              let scheme = url.scheme,
              ["http", "https"].contains(scheme),
              url.host() != nil else {
            throw DeskPetError.invalidEndpoint
        }

        let boundary = "Boundary-\(UUID().uuidString)"
        var body = Data()
        appendField(&body, boundary: boundary, name: "size", value: "auto")
        appendField(&body, boundary: boundary, name: "format", value: "png")
        body.append(Data("--\(boundary)\r\nContent-Disposition: form-data; name=\"image_file\"; filename=\"desk-pet.png\"\r\nContent-Type: image/png\r\n\r\n".utf8))
        body.append(imageData)
        body.append(Data("\r\n--\(boundary)--\r\n".utf8))

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue(configuration.apiKey, forHTTPHeaderField: "X-Api-Key")
        request.httpBody = body
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode), !data.isEmpty else {
            throw DeskPetError.invalidResponse
        }
        return data
    }

    private func appendField(_ body: inout Data, boundary: String, name: String, value: String) {
        body.append(Data("--\(boundary)\r\nContent-Disposition: form-data; name=\"\(name)\"\r\n\r\n\(value)\r\n".utf8))
    }
}

struct RemoteDeskPetGenerator: DeskPetGenerating {
    let configuration: APIConfiguration

    func generate(photoData: Data, partnerName: String) async throws -> Data {
        switch configuration.image.provider {
        case .dashScope:
            return try await generateDashScope(photoData: photoData, partnerName: partnerName)
        case .openAI:
            return try await generateOpenAI(photoData: photoData, partnerName: partnerName)
        }
    }

    private func generateDashScope(photoData: Data, partnerName: String) async throws -> Data {
        let payload = DashScopeRequest(
            model: configuration.image.model,
            input: .init(messages: [.init(role: "user", content: [
                .image("data:image/png;base64,\(photoData.base64EncodedString())"),
                .text(Self.prompt(for: partnerName))
            ])]),
            parameters: .init(
                count: 1,
                watermark: false,
                promptExtend: true,
                size: configuration.image.size.replacingOccurrences(of: "x", with: "*")
            )
        )
        var request = URLRequest(url: try endpointURL(configuration.image.endpoint))
        request.httpMethod = "POST"
        request.timeoutInterval = 90
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(configuration.image.apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(payload)
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)
        guard let image = try await extractImage(from: data) else { throw DeskPetError.invalidResponse }
        return image
    }

    private func generateOpenAI(photoData: Data, partnerName: String) async throws -> Data {
        let url = try endpointURL(configuration.image.baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + "/images/edits")
        let boundary = "Boundary-\(UUID().uuidString)"
        var body = Data()
        appendMultipart(&body, boundary: boundary, name: "model", value: configuration.image.model)
        appendMultipart(&body, boundary: boundary, name: "prompt", value: Self.prompt(for: partnerName))
        appendMultipart(&body, boundary: boundary, name: "size", value: configuration.image.size)
        appendMultipart(&body, boundary: boundary, name: "image", filename: "friend-photo.png", mimeType: "image/png", data: photoData)
        body.append(Data("--\(boundary)--\r\n".utf8))

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 90
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(configuration.image.apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = body
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)
        guard let image = try await extractImage(from: data) else { throw DeskPetError.invalidResponse }
        return image
    }

    private static func prompt(for name: String) -> String {
        "把照片中的人物生成一个适合放在桌边的完整 Q 版桌宠。保留\(name)的发型、发色、服装配色和标志性配饰，头部略大、四肢短小，温暖柔和的像素插画风格，正面站立，透明或干净的单色背景，不要文字、水印、边框、其他人物或 UI。"
    }

    private func endpointURL(_ value: String) throws -> URL {
        guard let url = URL(string: value), url.scheme == "https" || url.scheme == "http" else {
            throw DeskPetError.invalidEndpoint
        }
        return url
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let detail = String(data: data, encoding: .utf8)?.prefix(180) ?? "请求失败"
            throw DeskPetError.remote(String(detail))
        }
    }

    private func extractImage(from data: Data) async throws -> Data? {
        let object = try JSONSerialization.jsonObject(with: data)
        if let base64 = findString(in: object, keys: ["b64_json", "base64", "image_base64"]) {
            return Data(base64Encoded: base64)
        }
        if let urlString = findString(in: object, keys: ["url", "image", "image_url"]), let url = URL(string: urlString) {
            let (downloaded, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                throw DeskPetError.invalidResponse
            }
            return downloaded
        }
        return nil
    }

    private func findString(in value: Any, keys: Set<String>) -> String? {
        if let dictionary = value as? [String: Any] {
            for (key, value) in dictionary {
                if keys.contains(key), let string = value as? String { return string }
                if let nested = findString(in: value, keys: keys) { return nested }
            }
        } else if let array = value as? [Any] {
            for item in array { if let nested = findString(in: item, keys: keys) { return nested } }
        }
        return nil
    }

    private func appendMultipart(_ body: inout Data, boundary: String, name: String, value: String) {
        body.append(Data("--\(boundary)\r\nContent-Disposition: form-data; name=\"\(name)\"\r\n\r\n\(value)\r\n".utf8))
    }

    private func appendMultipart(_ body: inout Data, boundary: String, name: String, filename: String, mimeType: String, data: Data) {
        body.append(Data("--\(boundary)\r\nContent-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\nContent-Type: \(mimeType)\r\n\r\n".utf8))
        body.append(data)
        body.append(Data("\r\n".utf8))
    }
}

private struct DashScopeRequest: Encodable {
    struct Input: Encodable { let messages: [Message] }
    struct Message: Encodable { let role: String; let content: [Content] }
    enum Content: Encodable {
        case image(String)
        case text(String)
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            switch self {
            case .image(let value): try container.encode(value, forKey: .image)
            case .text(let value): try container.encode(value, forKey: .text)
            }
        }
        enum CodingKeys: String, CodingKey { case image, text }
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

private extension DeskPetError {
    static var invalidEndpoint: DeskPetError { .failed("API 地址无效") }
    static var invalidResponse: DeskPetError { .failed("图像接口没有返回可用图片") }
    static func remote(_ message: String) -> DeskPetError { .failed("图像接口请求失败：\(message)") }
}

enum DeskPetError: LocalizedError {
    case invalidPhoto
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .invalidPhoto: "这张照片暂时无法生成桌宠。"
        case .failed(let message): message
        }
    }
}

@MainActor
final class DeskPetController: ObservableObject {
    @Published private(set) var state: DeskPetGenerationState = .idle
    @Published private(set) var partnerProfile: DeskPetProfile?
    @Published var isFloating: Bool = false
    @Published private(set) var nudgeFeedback: DeskPetNudgeFeedback?
    /// The built-in "own" pet's center in scene-local coordinates. `nil` uses the default anchor.
    @Published private(set) var ownScenePosition: CGPoint?
    /// The partner pet's center in scene-local coordinates. `nil` uses the default anchor.
    @Published private(set) var partnerScenePosition: CGPoint?
    /// Only a pet owned by the partner in the current room may enter the scene or desktop.
    @Published private(set) var activePartnerID: DeskPartner.ID?
    /// The partner pet's rendered size in the scene. The floating window reuses it so the
    /// pet keeps the exact same size when the window is miniaturized.
    @Published private(set) var partnerPetSize: CGFloat?

    private let generator: any DeskPetGenerating
    private let persistence: DeskPetPersistence
    private var pendingPhotoData: Data?
    private var pendingPartner: DeskPartner?
    private var generationTask: Task<Void, Never>?
    private var nudgeFeedbackTask: Task<Void, Never>?

    init(generator: any DeskPetGenerating) {
        self.generator = generator
        self.persistence = DeskPetPersistence()
        restorePersistedProfile()
    }

    init(
        generator: any DeskPetGenerating,
        persistence: DeskPetPersistence
    ) {
        self.generator = generator
        self.persistence = persistence
        restorePersistedProfile()
    }

    convenience init() {
        self.init(generator: HybridDeskPetGenerator())
    }

    /// The generated profile belongs to the desk partner. It is the only
    /// profile allowed to participate in nudge interactions or leave the app window.
    var activePartnerProfile: DeskPetProfile? {
        guard let partnerProfile, partnerProfile.isEnabled else { return nil }
        guard partnerProfile.partnerID == activePartnerID else { return nil }
        return partnerProfile
    }

    /// Only the partner profile can detach from the app window.
    var floatingProfile: DeskPetProfile? { activePartnerProfile }

    @available(*, deprecated, renamed: "activePartnerProfile")
    var profile: DeskPetProfile? { partnerProfile }

    @available(*, deprecated, renamed: "activePartnerProfile")
    var activeProfile: DeskPetProfile? { activePartnerProfile }

    var hasSelectedPhoto: Bool { pendingPhotoData != nil }
    var selectedPhotoData: Data? { pendingPhotoData }

    func setActivePartner(_ partner: DeskPartner?) {
        let nextID = partner?.id
        guard activePartnerID != nextID else { return }
        activePartnerID = nextID
        partnerScenePosition = nil
        if nextID == nil { dismissNudgeFeedback() }
    }

    func moveOwnPet(to position: CGPoint) {
        ownScenePosition = position
    }

    func movePartnerPet(to position: CGPoint) {
        partnerScenePosition = position
    }

    func updatePartnerPetSize(_ size: CGFloat) {
        guard partnerPetSize != size else { return }
        partnerPetSize = size
    }

    func prepare(for partner: DeskPartner?) {
        guard let partner else {
            clear()
            return
        }
        if partnerProfile?.partnerID == partner.id {
            pendingPartner = partner
            if state == .idle { state = .ready }
            return
        }
        if pendingPartner?.id != partner.id || partnerProfile?.partnerID != partner.id {
            clear()
        }
    }

    func selectPhoto(_ data: Data, for partner: DeskPartner) {
        generationTask?.cancel()
        try? persistence.remove()
        pendingPhotoData = data
        pendingPartner = partner
        partnerProfile = nil
        partnerScenePosition = nil
        dismissNudgeFeedback()
        state = .photoSelected
    }

    func generate() {
        guard let pendingPhotoData, let pendingPartner else { return }
        generationTask?.cancel()
        state = .generating

        let generator = self.generator
        generationTask = Task { @MainActor [weak self] in
            do {
                let generated = try await generator.generate(
                    photoData: pendingPhotoData,
                    partnerName: pendingPartner.name
                )
                guard let self, !Task.isCancelled else { return }
                let generatedProfile = DeskPetProfile(
                    id: UUID(),
                    partnerID: pendingPartner.id,
                    partnerName: pendingPartner.name,
                    sourceImageData: pendingPhotoData,
                    generatedImageData: generated,
                    isEnabled: true
                )
                partnerProfile = generatedProfile
                do {
                    try persistence.save(generatedProfile)
                } catch {
                    state = .failed(DeskPetPersistenceError.saveFailed(error.localizedDescription).localizedDescription)
                    return
                }
                partnerProfile?.isEnabled = true
                state = .ready
            } catch is CancellationError {
                // Replacing a photo or leaving the room cancels the old job.
            } catch {
                guard let self, !Task.isCancelled else { return }
                state = .failed(error.localizedDescription)
                dismissNudgeFeedback()
            }
        }
    }

    func presentNudgeFeedback(message: String, kind: DeskPetNudgeFeedbackKind) {
        nudgeFeedbackTask?.cancel()
        let feedback = DeskPetNudgeFeedback(message: message, kind: kind)
        nudgeFeedback = feedback
        nudgeFeedbackTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(1_600))
            guard !Task.isCancelled, self?.nudgeFeedback?.id == feedback.id else { return }
            self?.nudgeFeedback = nil
        }
    }

    func dismissNudgeFeedback() {
        nudgeFeedbackTask?.cancel()
        nudgeFeedbackTask = nil
        nudgeFeedback = nil
    }

    func clear() {
        generationTask?.cancel()
        generationTask = nil
        dismissNudgeFeedback()
        pendingPhotoData = nil
        pendingPartner = nil
        partnerProfile = nil
        ownScenePosition = nil
        partnerScenePosition = nil
        state = .idle
        try? persistence.remove()
    }

    private func restorePersistedProfile() {
        guard let restored = persistence.load() else { return }
        partnerProfile = restored
        state = .ready
    }

    private func persistCurrentProfile() {
        guard let partnerProfile else { return }
        do {
            try persistence.save(partnerProfile)
        } catch {
            state = .failed(DeskPetPersistenceError.saveFailed(error.localizedDescription).localizedDescription)
        }
    }

    deinit {
        generationTask?.cancel()
        nudgeFeedbackTask?.cancel()
    }
}
