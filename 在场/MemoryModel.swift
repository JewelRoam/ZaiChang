import Foundation
import Combine

enum MemoryMood: String, CaseIterable, Codable, Identifiable {
    case warm, quiet, bright, tender
    var id: String { rawValue }
    var title: String {
        switch self { case .warm: "温暖"; case .quiet: "安静"; case .bright: "明亮"; case .tender: "柔软" }
    }
}

enum MemoryReviewState: Equatable, Codable { case draft, ready, confirmed, archived, failed(String) }
enum MemoryGenerationState: Equatable { case idle, generating }
enum MemoryDeliveryState: Equatable, Codable { case notScheduled, scheduled, delivered, opened, failed(String) }
enum MemoryDeliveryPlan: String, CaseIterable, Codable, Identifiable {
    case activityEnd, nextFocusEnd, scheduled, archiveOnly
    var id: String { rawValue }
    var title: String {
        switch self { case .activityEnd: "活动结束后送达"; case .nextFocusEnd: "对方下次结束专注后"; case .scheduled: "指定日期与时间"; case .archiveOnly: "仅保存到共同回忆" }
    }
}

struct MemoryDraft: Identifiable, Equatable, Codable {
    let id: UUID
    var title: String
    var mood: MemoryMood
    var observation: String
    var keyMoment: String
    var reviewState: MemoryReviewState
    var deliveryPlan: MemoryDeliveryPlan
    var deliveryState: MemoryDeliveryState
    var imageData: Data?
    var voiceNoteID: UUID?
    var createdAt: Date

}

protocol MemoryImageGenerating { func generate(prompt: String) async throws -> Data }

struct MockMemoryImageGenerator: MemoryImageGenerating {
    func generate(prompt: String) async throws -> Data {
        try await Task.sleep(for: .milliseconds(450))
        return Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=")!
    }
}

struct HybridMemoryImageGenerator: MemoryImageGenerating {
    private let configuration: APIConfiguration
    init(configuration: APIConfiguration = .load()) { self.configuration = configuration }
    func generate(prompt: String) async throws -> Data {
        guard configuration.isImageModelConfigured else { return try await MockMemoryImageGenerator().generate(prompt: prompt) }
        switch configuration.image.provider {
        case .openAI:
            guard let base = URL(string: configuration.image.baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + "/images/generations") else { throw MemoryImageError.invalidEndpoint }
            var request = URLRequest(url: base); request.httpMethod = "POST"; request.timeoutInterval = 90
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(configuration.image.apiKey)", forHTTPHeaderField: "Authorization")
            request.httpBody = try JSONSerialization.data(withJSONObject: ["model": configuration.image.model, "prompt": prompt, "size": configuration.image.size, "n": 1])
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { throw MemoryImageError.requestFailed }
            guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any], let items = object["data"] as? [[String: Any]], let urlString = items.first?["url"] as? String, let url = URL(string: urlString) else { throw MemoryImageError.invalidResponse }
            let (image, _) = try await URLSession.shared.data(from: url); return image
        case .dashScope:
            return try await MockMemoryImageGenerator().generate(prompt: prompt)
        }
    }
}

enum MemoryImageError: LocalizedError { case invalidEndpoint, requestFailed, invalidResponse
    var errorDescription: String? { switch self { case .invalidEndpoint: "图片生成地址无效"; case .requestFailed: "图片生成请求失败"; case .invalidResponse: "图片服务返回无效结果" } }
}

@MainActor
final class MemoryController: ObservableObject {
    @Published private(set) var drafts: [MemoryDraft] = []
    @Published private(set) var cards: [MemoryDraft] = []
    @Published private(set) var generationState: MemoryGenerationState = .idle
    private let imageGenerator: any MemoryImageGenerating
    private let persistence: MemoryPersistence
    private var pendingVoiceNoteID: UUID?
    private var task: Task<Void, Never>?

    init(imageGenerator: (any MemoryImageGenerating)? = nil, persistence: MemoryPersistence) {
        self.imageGenerator = imageGenerator ?? HybridMemoryImageGenerator()
        self.persistence = persistence
        let stored = persistence.load()
        drafts = stored.drafts
        cards = stored.cards
    }
    convenience init(imageGenerator: (any MemoryImageGenerating)? = nil) {
        self.init(imageGenerator: imageGenerator, persistence: MemoryPersistence())
    }
    deinit { task?.cancel() }

    func makeDraft(title: String, mood: MemoryMood, observation: String, keyMoment: String, delivery: MemoryDeliveryPlan) {
        let draft = MemoryDraft(id: UUID(), title: title.trimmingCharacters(in: .whitespacesAndNewlines), mood: mood, observation: observation.trimmingCharacters(in: .whitespacesAndNewlines), keyMoment: keyMoment.trimmingCharacters(in: .whitespacesAndNewlines), reviewState: .draft, deliveryPlan: delivery, deliveryState: .notScheduled, imageData: nil, voiceNoteID: pendingVoiceNoteID, createdAt: Date())
        pendingVoiceNoteID = nil
        drafts = [draft] + drafts
        persist()
    }

    func updateDraft(_ draft: MemoryDraft) { drafts.removeAll { $0.id == draft.id }; drafts.insert(draft, at: 0); persist() }
    func discardDraft(_ draft: MemoryDraft) { drafts.removeAll { $0.id == draft.id }; persist() }

    func attachVoiceNote(_ id: UUID) {
        guard let draft = drafts.first else { pendingVoiceNoteID = id; return }
        var updated = draft
        updated.voiceNoteID = id
        updateDraft(updated)
    }

    func generateImage(for draft: MemoryDraft) {
        guard draft.reviewState.isEditableDraftState else { return }
        task?.cancel()
        generationState = .generating
        var working = draft
        let generator = imageGenerator
        task = Task { @MainActor [weak self] in
            do {
                let prompt = "温暖像素风记忆卡片，无文字无人物肖像，场景：\(draft.observation)。关键时刻：\(draft.keyMoment)。情绪：\(draft.mood.title)。"
                working.imageData = try await generator.generate(prompt: prompt)
                working.reviewState = .ready
                self?.updateDraft(working)
                self?.generationState = .idle
            } catch {
                working.reviewState = .failed(error.localizedDescription)
                self?.updateDraft(working)
                self?.generationState = .idle
            }
        }
    }

    func confirm(_ draft: MemoryDraft) {
        guard draft.reviewState == .ready, draft.imageData != nil else { return }
        var card = draft; card.reviewState = .confirmed
        card.deliveryState = card.deliveryPlan == .archiveOnly ? .notScheduled : .scheduled
        cards = [card] + cards
        drafts.removeAll { $0.id == draft.id }
        persist()
    }

    func archive(_ card: MemoryDraft) {
        guard card.reviewState == .confirmed else { return }
        var copy = card
        copy.reviewState = .archived
        updateCard(copy)
    }

    func restore(_ card: MemoryDraft) {
        guard card.reviewState == .archived else { return }
        var copy = card
        copy.reviewState = .confirmed
        updateCard(copy)
    }

    func markDelivered(_ card: MemoryDraft) { updateCard(card) }
    func updateCard(_ card: MemoryDraft) { cards.removeAll { $0.id == card.id }; cards.insert(card, at: 0); persist() }

    /// 已确认和已归档的记忆卡片，按创建时间从新到旧排列，供历史列表展示。
    var history: [MemoryDraft] {
        cards.sorted { $0.createdAt > $1.createdAt }
    }

    func deleteCard(_ card: MemoryDraft) {
        cards.removeAll { $0.id == card.id }
        persist()
    }

    private func persist() {
        try? persistence.save(drafts: drafts, cards: cards)
    }
}

struct MemoryStore: Codable {
    let drafts: [MemoryDraft]
    let cards: [MemoryDraft]
}

final class MemoryPersistence {
    private let fileURL: URL
    init(fileManager: FileManager = .default) {
        fileURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Zaichang", isDirectory: true)
            .appendingPathComponent("memories.json")
    }
    func load() -> MemoryStore {
        guard let data = try? Data(contentsOf: fileURL), let store = try? JSONDecoder().decode(MemoryStore.self, from: data) else {
            return MemoryStore(drafts: [], cards: [])
        }
        return store
    }
    func save(drafts: [MemoryDraft], cards: [MemoryDraft]) throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try JSONEncoder().encode(MemoryStore(drafts: drafts, cards: cards)).write(to: fileURL, options: .atomic)
    }
}

private extension MemoryReviewState {
    var isEditableDraftState: Bool {
        switch self {
        case .draft, .failed:
            return true
        case .ready, .confirmed, .archived:
            return false
        }
    }
}
