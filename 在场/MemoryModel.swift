import Foundation
import Combine

enum MemoryMood: String, CaseIterable, Codable, Identifiable {
    case warm, quiet, bright, tender
    var id: String { rawValue }
    static var selectableCases: [MemoryMood] { [.warm, .quiet, .bright] }
    var title: String {
        switch self {
        case .warm: "温暖"
        case .quiet: "安静"
        case .bright: "明亮"
        case .tender: "柔软"
        }
    }
}

enum MemoryReviewState: Equatable, Codable {
    case draft, generating, ready, confirmed, archived, failed(String)
}

enum MemoryGenerationState: Equatable { case idle, generating }

enum MemoryDeliveryState: Equatable, Codable {
    case notScheduled, scheduled, delivered, opened, failed(String)
}

enum MemorySourceEvent: String, CaseIterable, Codable, Identifiable {
    case manual
    case activityEnded
    case dailyTodoCompleted

    var id: String { rawValue }
}

enum MemoryVisibility: String, CaseIterable, Codable, Identifiable {
    case shared
    case privateOnly

    var id: String { rawValue }
}

struct MemoryResourceReference: Identifiable, Equatable, Codable {
    let id: UUID
    var kind: String
    var value: String

    init(id: UUID = UUID(), kind: String, value: String) {
        self.id = id
        self.kind = kind
        self.value = value
    }
}

struct MemoryVoiceAttachment: Identifiable, Equatable, Codable {
    let id: UUID
    var noteID: UUID
    var filename: String
    var duration: TimeInterval
    var createdAt: Date
    var delivery: VoiceDelivery

    init(
        id: UUID = UUID(),
        noteID: UUID,
        filename: String,
        duration: TimeInterval,
        createdAt: Date,
        delivery: VoiceDelivery
    ) {
        self.id = id
        self.noteID = noteID
        self.filename = filename
        self.duration = duration
        self.createdAt = createdAt
        self.delivery = delivery
    }
}

enum MemoryDeliveryPlan: String, CaseIterable, Codable, Identifiable {
    case activityEnd, nextFocusEnd, scheduled, archiveOnly
    var id: String { rawValue }
    var title: String {
        switch self {
        case .activityEnd: "活动结束后送达"
        case .nextFocusEnd: "对方下次结束专注后"
        case .scheduled: "指定日期与时间"
        case .archiveOnly: "仅保存到共同回忆"
        }
    }
    var detail: String {
        switch self {
        case .activityEnd: "这段活动结束后送达"
        case .nextFocusEnd: "对方下一次专注结束后送达"
        case .scheduled: "先保存，之后由你决定时间"
        case .archiveOnly: "只保存，不发送"
        }
    }
}

struct MemoryDraft: Identifiable, Equatable, Codable {
    let id: UUID
    var sourceActivityID: UUID?
    var sourceEvent: MemorySourceEvent
    var creatorName: String
    var participantNames: [String]
    var visibility: MemoryVisibility
    var resourceReferences: [MemoryResourceReference]
    var voiceAttachment: MemoryVoiceAttachment?
    var confirmedAt: Date?
    var deletedAt: Date?
    var title: String
    var mood: MemoryMood
    var observation: String
    var keyMoment: String
    var imageTemplateID: String?
    var imageTemplateName: String?
    var imagePrompt: String?
    var suggestedTags: [String]
    var suggestedBGM: String?
    var suggestedDeliveryNote: String?
    var reviewState: MemoryReviewState
    var deliveryPlan: MemoryDeliveryPlan
    var deliveryState: MemoryDeliveryState
    var imageData: Data?
    var voiceNoteID: UUID?
    var createdAt: Date
}

extension MemoryDraft {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        sourceActivityID = try c.decodeIfPresent(UUID.self, forKey: .sourceActivityID)
        sourceEvent = try c.decodeIfPresent(MemorySourceEvent.self, forKey: .sourceEvent) ?? .manual
        creatorName = try c.decodeIfPresent(String.self, forKey: .creatorName) ?? "我"
        participantNames = try c.decodeIfPresent([String].self, forKey: .participantNames) ?? []
        visibility = try c.decodeIfPresent(MemoryVisibility.self, forKey: .visibility) ?? .shared
        resourceReferences = try c.decodeIfPresent([MemoryResourceReference].self, forKey: .resourceReferences) ?? []
        voiceAttachment = try c.decodeIfPresent(MemoryVoiceAttachment.self, forKey: .voiceAttachment)
        confirmedAt = try c.decodeIfPresent(Date.self, forKey: .confirmedAt)
        deletedAt = try c.decodeIfPresent(Date.self, forKey: .deletedAt)
        title = try c.decode(String.self, forKey: .title)
        mood = try c.decode(MemoryMood.self, forKey: .mood)
        observation = try c.decode(String.self, forKey: .observation)
        keyMoment = try c.decode(String.self, forKey: .keyMoment)
        imageTemplateID = try c.decodeIfPresent(String.self, forKey: .imageTemplateID)
        imageTemplateName = try c.decodeIfPresent(String.self, forKey: .imageTemplateName)
        imagePrompt = try c.decodeIfPresent(String.self, forKey: .imagePrompt)
        suggestedTags = try c.decodeIfPresent([String].self, forKey: .suggestedTags) ?? []
        suggestedBGM = try c.decodeIfPresent(String.self, forKey: .suggestedBGM)
        suggestedDeliveryNote = try c.decodeIfPresent(String.self, forKey: .suggestedDeliveryNote)
        reviewState = try c.decode(MemoryReviewState.self, forKey: .reviewState)
        deliveryPlan = try c.decode(MemoryDeliveryPlan.self, forKey: .deliveryPlan)
        deliveryState = try c.decode(MemoryDeliveryState.self, forKey: .deliveryState)
        imageData = try c.decodeIfPresent(Data.self, forKey: .imageData)
        voiceNoteID = try c.decodeIfPresent(UUID.self, forKey: .voiceNoteID)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
    }
    private enum CodingKeys: String, CodingKey {
        case id, sourceActivityID, sourceEvent, creatorName, participantNames, visibility,
             resourceReferences, confirmedAt, deletedAt, title, mood, observation, keyMoment,
             imageTemplateID, imageTemplateName, imagePrompt, suggestedTags, suggestedBGM,
             suggestedDeliveryNote, voiceAttachment, reviewState, deliveryPlan, deliveryState, imageData,
             voiceNoteID, createdAt
    }
}

protocol MemoryImageGenerating { func generate(prompt: String) async throws -> Data }

struct MockMemoryImageGenerator: MemoryImageGenerating {
    func generate(prompt: String) async throws -> Data {
        try await Task.sleep(for: .milliseconds(120))
        return Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=")!
    }
}

struct HybridMemoryImageGenerator: MemoryImageGenerating {
    func generate(prompt: String) async throws -> Data { try await MockMemoryImageGenerator().generate(prompt: prompt) }
}

@MainActor
final class MemoryController: ObservableObject {
    @Published private(set) var drafts: [MemoryDraft] = []
    @Published private(set) var cards: [MemoryDraft] = []
    @Published private(set) var generationState: MemoryGenerationState = .idle
    private let imageGenerator: any MemoryImageGenerating
    private let persistence: MemoryPersistence
    private let templatePool = MemoryCardTemplatePool()
    private var pendingVoiceNoteID: UUID?
    private var task: Task<Void, Never>?

    init(imageGenerator: (any MemoryImageGenerating)? = nil, persistence: MemoryPersistence? = nil) {
        self.imageGenerator = imageGenerator ?? HybridMemoryImageGenerator()
        self.persistence = persistence ?? MemoryPersistence()
        let stored = self.persistence.load()
        // Generation is an in-memory task; a persisted generating draft cannot
        // resume after relaunch, so make it reviewable again.
        var didRecoverInterruptedGeneration = false
        drafts = stored.drafts.map { draft in
            guard draft.reviewState == .generating else { return draft }
            didRecoverInterruptedGeneration = true
            var recovered = draft
            recovered.reviewState = .draft
            return recovered
        }
        cards = stored.cards
        if didRecoverInterruptedGeneration {
            try? self.persistence.save(drafts: drafts, cards: cards)
        }
    }
    deinit { task?.cancel() }

    /// Clears all drafts and cards in memory and cancels any in-flight generation.
    /// The persisted store file is removed by the app-wide data reset.
    func resetAll() {
        task?.cancel()
        task = nil
        pendingVoiceNoteID = nil
        drafts = []
        cards = []
        generationState = .idle
    }

    func makeDraft(
        title: String,
        mood: MemoryMood,
        observation: String,
        keyMoment: String,
        delivery: MemoryDeliveryPlan,
        sourceEvent: MemorySourceEvent = .manual,
        sourceActivityID: UUID? = nil,
        creatorName: String = "我",
        participantNames: [String] = [],
        visibility: MemoryVisibility = .shared,
        resourceReferences: [MemoryResourceReference] = [],
        voiceAttachment: MemoryVoiceAttachment? = nil,
        confirmedAt: Date? = nil,
        deletedAt: Date? = nil
    ) {
        let draft = MemoryDraft(
            id: UUID(),
            sourceActivityID: sourceActivityID,
            sourceEvent: sourceEvent,
            creatorName: creatorName,
            participantNames: participantNames,
            visibility: visibility,
            resourceReferences: resourceReferences,
            voiceAttachment: voiceAttachment,
            confirmedAt: confirmedAt,
            deletedAt: deletedAt,
            title: title.trimmed,
            mood: mood,
            observation: observation.trimmed,
            keyMoment: keyMoment.trimmed,
            imageTemplateID: nil,
            imageTemplateName: nil,
            imagePrompt: nil,
            suggestedTags: [],
            suggestedBGM: nil,
            suggestedDeliveryNote: nil,
            reviewState: .draft,
            deliveryPlan: delivery,
            deliveryState: .notScheduled,
            imageData: nil,
            voiceNoteID: pendingVoiceNoteID,
            createdAt: Date()
        )
        pendingVoiceNoteID = nil
        drafts.insert(draft, at: 0)
        persist()
    }

    func updateDraft(_ draft: MemoryDraft) { replace(&drafts, with: draft); persist() }
    func discardDraft(_ draft: MemoryDraft) { drafts.removeAll { $0.id == draft.id }; persist() }
    func attachVoiceNote(_ id: UUID) {
        guard var draft = drafts.first else { pendingVoiceNoteID = id; return }
        draft.voiceNoteID = id; updateDraft(draft)
    }

    func updateVoiceAttachment(
        noteID: UUID,
        filename: String,
        duration: TimeInterval,
        createdAt: Date,
        delivery: VoiceDelivery
    ) {
        guard var draft = drafts.first else { return }
        draft.voiceAttachment = MemoryVoiceAttachment(
            noteID: noteID,
            filename: filename,
            duration: duration,
            createdAt: createdAt,
            delivery: delivery
        )
        updateDraft(draft)
    }

    func prepareCard(for draft: MemoryDraft, preferredTemplateID: String? = nil) {
        guard draft.reviewState == .draft || draft.reviewState.isFailed else { return }
        var working = draft
        working.reviewState = .generating
        updateDraft(working)
        generationState = .generating
        task?.cancel()
        task = Task { [weak self] in
            do {
                let result = MemoryDraftingResult(draft: working)
                let template = self?.templatePool.selectTemplate(for: result, preferredTemplateID: preferredTemplateID)
                guard let self, let template else { return }
                let prompt = self.templatePool.compilePrompt(for: result, template: template)
                let metadata = self.templatePool.suggestMetadata(for: result, template: template)
                let data = try await self.imageGenerator.generate(prompt: prompt.prompt)
                guard !Task.isCancelled else { return }
                var ready = working
                ready.imageTemplateID = template.id; ready.imageTemplateName = template.name
                ready.imagePrompt = prompt.prompt; ready.suggestedTags = metadata.tags
                ready.suggestedBGM = metadata.bgm; ready.suggestedDeliveryNote = metadata.deliveryNote
                ready.imageData = data; ready.reviewState = .ready
                self.generationState = .idle; self.updateDraft(ready)
            } catch {
                guard let self, !Task.isCancelled else { return }
                var failed = working
                failed.reviewState = .failed(error.localizedDescription)
                self.generationState = .idle; self.updateDraft(failed)
            }
        }
    }

    func generateImage(for draft: MemoryDraft, preferredTemplateID: String? = nil) {
        prepareCard(for: draft, preferredTemplateID: preferredTemplateID)
    }

    func cancelPreparation(for draft: MemoryDraft) {
        task?.cancel()
        task = nil
        generationState = .idle
        guard draft.reviewState == .generating else { return }
        var recovered = draft
        recovered.reviewState = .draft
        updateDraft(recovered)
    }

    func confirm(_ draft: MemoryDraft) {
        guard draft.reviewState == .ready, draft.imageTemplateID != nil else { return }
        var card = draft
        card.reviewState = .confirmed
        card.confirmedAt = Date()
        if let voiceNoteID = card.voiceNoteID,
           !card.resourceReferences.contains(where: { $0.kind == "voiceNote" && $0.value == voiceNoteID.uuidString }) {
            card.resourceReferences.append(.init(kind: "voiceNote", value: voiceNoteID.uuidString))
        }
        if card.voiceAttachment != nil,
           !card.resourceReferences.contains(where: { $0.kind == "voiceAttachment" }) {
            card.resourceReferences.append(.init(kind: "voiceAttachment", value: "recording"))
        }
        if let templateID = card.imageTemplateID,
           !card.resourceReferences.contains(where: { $0.kind == "imageTemplate" && $0.value == templateID }) {
            card.resourceReferences.append(.init(kind: "imageTemplate", value: templateID))
        }
        card.deliveryState = deliveryState(for: card)
        cards.insert(card, at: 0)
        drafts.removeAll { $0.id == draft.id }
        persist()
    }
    func archive(_ card: MemoryDraft) { updateCard(card, review: .archived) }
    func restore(_ card: MemoryDraft) { updateCard(card, review: .confirmed) }
    func markDelivered(_ card: MemoryDraft) { updateCard(card.withDeliveryState(.delivered)) }
    func markOpened(_ card: MemoryDraft) { var x = card; x.deliveryState = .opened; updateCard(x) }
    func advanceDeliveryState(for card: MemoryDraft) {
        var x = card
        switch card.deliveryState { case .notScheduled: x.deliveryState = .scheduled; case .scheduled: x.deliveryState = .delivered; case .delivered: x.deliveryState = .opened; default: return }
        updateCard(x)
    }
    func syncDeliveryState(for card: MemoryDraft) {
        updateCard(card.withDeliveryState(card.deliveryPlan == .archiveOnly ? .notScheduled : .delivered))
    }
    func deliverCards(for event: MemorySourceEvent, activityID: UUID? = nil, now: Date = Date()) {
        for card in cards where card.reviewState == .confirmed {
            guard card.deliveryState == .scheduled || card.deliveryState == .notScheduled else { continue }
            switch card.deliveryPlan {
            case .activityEnd:
                guard event == .activityEnded else { continue }
                if activityID == nil || card.sourceActivityID == activityID || card.sourceActivityID == nil {
                    var updated = card
                    updated.deliveryState = .delivered
                    updated.confirmedAt = updated.confirmedAt ?? now
                    updateCard(updated)
                }
            case .nextFocusEnd:
                guard event == .activityEnded else { continue }
                var updated = card
                updated.deliveryState = .delivered
                updateCard(updated)
            case .scheduled:
                continue
            case .archiveOnly:
                continue
            }
        }
    }
    func updateCard(_ card: MemoryDraft) { replace(&cards, with: card); persist() }

    private func updateCard(_ card: MemoryDraft, review: MemoryReviewState) { var x = card; x.reviewState = review; updateCard(x) }
    private func replace(_ list: inout [MemoryDraft], with item: MemoryDraft) { list.removeAll { $0.id == item.id }; list.insert(item, at: 0) }
    private func persist() { try? persistence.save(drafts: drafts, cards: cards) }

    /// 已确认和已归档的记忆卡片，按创建时间从新到旧排列，供历史列表展示。
    var history: [MemoryDraft] {
        cards.sorted { $0.createdAt > $1.createdAt }
    }

    func deleteCard(_ card: MemoryDraft) {
        cards.removeAll { $0.id == card.id }
        persist()
    }

    private func deliveryState(for card: MemoryDraft) -> MemoryDeliveryState {
        switch card.deliveryPlan {
        case .archiveOnly:
            return .notScheduled
        case .activityEnd:
            return card.sourceEvent == .activityEnded ? .delivered : .scheduled
        case .nextFocusEnd:
            return .scheduled
        case .scheduled:
            return .scheduled
        }
    }
}

private extension String { var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) } }
private extension MemoryReviewState { var isFailed: Bool { if case .failed = self { return true }; return false } }
private extension MemoryDraft {
    func withDeliveryState(_ state: MemoryDeliveryState) -> MemoryDraft {
        var copy = self
        copy.deliveryState = state
        return copy
    }
}

struct MemoryStore: Codable { let drafts: [MemoryDraft]; let cards: [MemoryDraft] }

final class MemoryPersistence {
    private let fileURL: URL
    init(fileURL: URL) { self.fileURL = fileURL }
    init(fileManager: FileManager = .default) {
        fileURL = AppStoragePaths.memoriesURL(fileManager: fileManager)
    }
    func load() -> MemoryStore {
        guard let data = try? Data(contentsOf: fileURL), let store = try? JSONDecoder().decode(MemoryStore.self, from: data) else { return MemoryStore(drafts: [], cards: []) }
        return store
    }
    func save(drafts: [MemoryDraft], cards: [MemoryDraft]) throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try JSONEncoder().encode(MemoryStore(drafts: drafts, cards: cards)).write(to: fileURL, options: .atomic)
    }
}
