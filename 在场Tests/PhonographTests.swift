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
            voiceAttachment: nil,
            confirmedAt: nil, deletedAt: nil, title: "中断的留声", mood: .quiet,
            observation: "生成过程中退出了应用", keyMoment: "重新打开时",
            imagePrompt: nil,
            reviewState: .generating, deliveryPlan: .oneHourLater,
            deliveryState: .notScheduled, imageData: nil,
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

    @Test("Confirmed card tracks delivery lifecycle")
    func confirmedCardTracksDeliveryLifecycle() async throws {
        let controller = MemoryController(imageGenerator: PhonographImmediateImageGenerator(), persistence: testPersistence())

        controller.makeDraft(
            title: "列车回声",
            mood: .tender,
            observation: "从车站回来的路上，想把那句没说完的话留住。",
            keyMoment: "车窗里的灯光",
            delivery: .bedtime
        )

        let draft = try #require(controller.drafts.first)
        controller.generateImage(for: draft)
        try await Task.sleep(for: .milliseconds(40))

        controller.attachVoiceAttachment(
            noteID: UUID(),
            filename: "test.m4a",
            duration: 3,
            createdAt: Date(),
            delivery: .focusEnd
        )
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

}

private func testPersistence() -> MemoryPersistence {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("phonograph-test-\(UUID().uuidString).json")
    return MemoryPersistence(fileURL: url)
}

private struct PhonographImmediateImageGenerator: MemoryImageGenerating {
    func generate(prompt: String) async throws -> Data {
        Data([0x89, 0x50, 0x4E, 0x47])
    }
}
