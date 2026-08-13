import Foundation
import Testing
@testable import 在场

@Suite("Phonograph")
@MainActor
struct PhonographTests {

    @Test("Interrupted generation is recovered on launch")
    func interruptedGenerationIsRecoveredOnLaunch() throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("phonograph-recovery-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: fileURL) }
        let persistence = MemoryPersistence(fileURL: fileURL)
        let interrupted = MemoryDraft(
            id: UUID(), sourceActivityID: nil, sourceEvent: .manual, creatorName: "我",
            participantNames: [], visibility: .shared, resourceReferences: [],
            confirmedAt: nil, deletedAt: nil, title: "中断的留声", mood: .quiet,
            observation: "生成过程中退出了应用", keyMoment: "重新打开时",
            imageTemplateID: nil, imageTemplateName: nil, imagePrompt: nil,
            suggestedTags: [], suggestedBGM: nil, suggestedDeliveryNote: nil,
            reviewState: .generating, deliveryPlan: .activityEnd,
            deliveryState: .notScheduled, imageData: nil, voiceNoteID: nil,
            createdAt: Date()
        )
        try persistence.save(drafts: [interrupted], cards: [])

        let controller = MemoryController(
            imageGenerator: PhonographImmediateImageGenerator(),
            persistence: persistence
        )

        #expect(controller.drafts.first?.reviewState == .draft)
        #expect(persistence.load().drafts.first?.reviewState == .draft)
    }

    @Test("Template pool matches phonograph context")
    func templatePoolMatchesDraftContext() {
        let pool = MemoryCardTemplatePool()
        let draft = MemoryDraftingResult(
            title: "雨夜书桌",
            mood: .quiet,
            observation: "今晚在台灯下把代码整理完了，窗外一直在下雨。",
            keyMoment: "窗边的雨声和桌面那盏灯",
            keywords: []
        )

        let template = pool.selectTemplate(for: draft)

        #expect(template.id == "rainy-desk" || template.id == "desk-focus")
        #expect(!pool.previewTemplates(for: draft).isEmpty)
    }

    @Test("Draft generation stores template, prompt, and metadata")
    func memoryDraftCarriesMockGenerationArtifacts() async throws {
        let controller = MemoryController(imageGenerator: PhonographImmediateImageGenerator(), persistence: MemoryPersistence())

        controller.makeDraft(
            title: "雨夜书桌",
            mood: .quiet,
            observation: "今晚在台灯下把代码整理完了，窗外一直在下雨。",
            keyMoment: "窗边的雨声和桌面那盏灯",
            delivery: .activityEnd
        )

        let draft = try #require(controller.drafts.first)
        controller.generateImage(for: draft)

        try await Task.sleep(for: .milliseconds(40))

        let ready = try #require(controller.drafts.first)
        #expect(ready.reviewState == .ready)
        #expect(ready.imageTemplateID != nil)
        #expect(ready.imageTemplateName != nil)
        #expect(ready.imagePrompt?.isEmpty == false)
        #expect(ready.suggestedTags.isEmpty == false)
        #expect(ready.suggestedBGM != nil)
        #expect(ready.suggestedDeliveryNote != nil)
    }

    @Test("Confirmed card tracks delivery lifecycle")
    func confirmedCardTracksDeliveryLifecycle() async throws {
        let controller = MemoryController(imageGenerator: PhonographImmediateImageGenerator(), persistence: MemoryPersistence())

        controller.makeDraft(
            title: "列车回声",
            mood: .tender,
            observation: "从车站回来的路上，想把那句没说完的话留住。",
            keyMoment: "车窗里的灯光",
            delivery: .scheduled
        )

        let draft = try #require(controller.drafts.first)
        controller.generateImage(for: draft)
        try await Task.sleep(for: .milliseconds(40))

        let ready = try #require(controller.drafts.first)
        controller.confirm(ready)

        let card = try #require(controller.cards.first)
        #expect(card.reviewState == .confirmed)
        #expect(card.deliveryState == .scheduled)

        controller.markDelivered(card)
        let delivered = try #require(controller.cards.first)
        #expect(delivered.deliveryState == .delivered)

        controller.markOpened(delivered)
        let opened = try #require(controller.cards.first)
        #expect(opened.deliveryState == .opened)
    }

    @Test("Delivery plan sync reflects strategy")
    func deliveryPlanSyncReflectsStrategy() async throws {
        let controller = MemoryController(imageGenerator: PhonographImmediateImageGenerator(), persistence: MemoryPersistence())

        controller.makeDraft(
            title: "午后小停顿",
            mood: .bright,
            observation: "杯子放下的时候，桌面终于安静了一点。",
            keyMoment: "放下水杯的那一秒",
            delivery: .scheduled
        )

        let draft = try #require(controller.drafts.first)
        controller.generateImage(for: draft, preferredTemplateID: "little-break")
        try await Task.sleep(for: .milliseconds(40))

        let ready = try #require(controller.drafts.first)
        controller.confirm(ready)

        let card = try #require(controller.cards.first)
        #expect(card.deliveryState == .scheduled)

        controller.syncDeliveryState(for: card)
        let synced = try #require(controller.cards.first)
        #expect(synced.deliveryState == .delivered)
    }

    @Test("Archive view source should only expose confirmed cards")
    func archiveSourceShouldOnlyExposeConfirmedCards() async throws {
        let controller = MemoryController(imageGenerator: PhonographImmediateImageGenerator(), persistence: MemoryPersistence())

        controller.makeDraft(
            title: "雨夜书桌",
            mood: .quiet,
            observation: "台灯和雨声一起落下来。",
            keyMoment: "雨打在窗上那一刻",
            delivery: .archiveOnly
        )

        let draft = try #require(controller.drafts.first)
        controller.generateImage(for: draft, preferredTemplateID: "rainy-desk")
        try await Task.sleep(for: .milliseconds(40))

        let ready = try #require(controller.drafts.first)
        controller.confirm(ready)

        #expect(controller.cards.allSatisfy { $0.reviewState == .confirmed })
    }
}

private struct PhonographImmediateImageGenerator: MemoryImageGenerating {
    func generate(prompt: String) async throws -> Data {
        Data([0x89, 0x50, 0x4E, 0x47])
    }
}
