//
//  __Tests.swift
//  在场Tests
//
//  Created by 郑恩嵘 on 2026/8/10.
//

import Foundation
import Testing
#if os(macOS)
import AppKit
#endif
@testable import 在场

@Suite("在场 AppModel")
struct AppModelTests {
    @Test("记忆草稿生命周期与生成运行态彼此独立")
    @MainActor
    func memoryDraftLifecycleIsUnified() async throws {
        let controller = MemoryController(imageGenerator: ImmediateMemoryImageGenerator())

        controller.makeDraft(
            title: "雨夜书桌",
            mood: .quiet,
            observation: "一起完成了一段专注",
            keyMoment: "两盏灯同时亮着",
            delivery: .oneHourLater
        )

        let draft = try #require(controller.drafts.first)
        #expect(draft.reviewState == .draft)
        #expect(controller.generationState == .idle)

        controller.generateImage(for: draft)
        #expect(controller.generationState == .generating)
        #expect(controller.drafts.first?.reviewState == .generating)

        try await Task.sleep(for: .milliseconds(20))
        #expect(controller.generationState == .idle)
        #expect(controller.drafts.first?.reviewState == .ready)

        let ready = try #require(controller.drafts.first)
        controller.confirm(ready)
        #expect(controller.cards.first?.reviewState == .confirmed)
    }

    @Test("好友照片桌宠会经过选择、生成和启用状态")
    @MainActor
    func deskPetLifecycle() async throws {
        let controller = DeskPetController(generator: ImmediateDeskPetGenerator())

        controller.selectPhoto(Data([0x01, 0x02]), for: .ahe)
        #expect(controller.state == .photoSelected)
        #expect(controller.hasSelectedPhoto)

        controller.generate()
        try await Task.sleep(for: .milliseconds(20))

        #expect(controller.state == .ready)
        #expect(controller.partnerProfile?.partnerName == "阿禾")
        #expect(controller.activePartnerProfile == nil)

        controller.setActivePartner(.ahe)
        #expect(controller.activePartnerProfile?.partnerID == DeskPartner.ahe.id)

        controller.clear()
        #expect(controller.state == .idle)
        #expect(controller.activePartnerProfile == nil)
    }

    @Test("桌宠生成结果会持久化并在下次启动恢复")
    @MainActor
    func deskPetPersistsGeneratedProfile() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("desk-pet-\(UUID().uuidString)", isDirectory: true)
        let persistence = DeskPetPersistence(directoryURL: directory)
        let generatedData = Data([0x89, 0x50, 0x4E, 0x47])

        let controller = DeskPetController(
            generator: ImmediateDeskPetGenerator(result: generatedData),
            persistence: persistence
        )
        controller.selectPhoto(Data([0x01]), for: .ahe)
        controller.generate()
        try await Task.sleep(for: .milliseconds(20))
        controller.setActivePartner(.ahe)

        let restored = DeskPetController(
            generator: ImmediateDeskPetGenerator(),
            persistence: persistence
        )
        #expect(restored.partnerProfile?.partnerID == DeskPartner.ahe.id)
        #expect(restored.partnerProfile?.generatedImageData == generatedData)
        #expect(restored.partnerProfile?.isEnabled == true)

        restored.clear()
        #expect(persistence.load() == nil)
    }

#if os(macOS)
    @Test("主窗口最小化时桌宠进入浮动状态，窗口关闭时清理")
    @MainActor
    func floatingDeskPetTracksWindowLifecycle() async throws {
        let controller = DeskPetController(generator: ImmediateDeskPetGenerator())
        controller.selectPhoto(Data([0x01, 0x02]), for: .ahe)
        controller.generate()
        try await Task.sleep(for: .milliseconds(20))
        controller.setActivePartner(.ahe)

        let window = NSWindow(
            contentRect: NSRect(x: 100, y: 100, width: 1_200, height: 760),
            styleMask: [.titled, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        let floatingWindow = FloatingDeskPetWindow()
        floatingWindow.attach(to: window, controller: controller, onDoubleTap: {})

        NotificationCenter.default.post(
            name: NSWindow.willMiniaturizeNotification,
            object: window
        )
        #expect(controller.isFloating)

        NotificationCenter.default.post(
            name: NSWindow.willCloseNotification,
            object: window
        )
        #expect(!controller.isFloating)
    }
#endif

    @Test("切换场景会更新渲染所需的场景资源")
    @MainActor
    func selectingSceneUpdatesRendererInputs() {
        let model = AppModel()
        let initialID = model.selectedScene.id
        let initialPath = model.selectedSceneImage.relativePath

        model.selectScene(RoomSceneCatalog.makeScene)

        #expect(initialID != model.selectedScene.id)
        #expect(initialPath != model.selectedSceneImage.relativePath)
        #expect(model.selectedScene.id == RoomSceneCatalog.makeScene.id)
        #expect(model.selectedSceneImage.relativePath == "Scenes/make.png")
    }

    }

    }

    @Test("桌上事项拒绝重复内容并限制为五项")
    @MainActor
    func taskListEnforcesConstraints() {
        let model = AppModel()

        #expect(!model.addTask(title: "整理首页文案"))
        #expect(model.addTask(title: "确认演示流程"))
        #expect(model.addTask(title: "整理答辩问题"))
        #expect(!model.addTask(title: "第六件事"))
        #expect(model.tasks.count == AppModel.maximumTaskCount)
        #expect(!model.canAddTask)
    }

    }

    @Test("原生环境声随 App 生命周期和场景切换更新")
    @MainActor
    func nativeAmbientTracksLifecycleAndTheme() {
        let audio = AmbientAudioSpy()
        let model = AppModel(ambientAudio: audio)

        model.activateAudio()
        model.selectScene(RoomSceneCatalog.roamScene)
        model.deactivateAudio()

        #expect(audio.commands == [
            .start(.rain, false),
            .preset(.forest),
            .stop,
        ])
    }

    }

    }

    }

    }

    }

    @Test("任意邀请码加入同一个固定 Demo 房间")
    @MainActor
    func joiningDeskAcceptsAnyCode() async throws {
        let model = AppModel()

        model.joinDesk(code: " hello-room ")
        try await waitUntil { model.currentDeskRoom != nil }

        #expect(model.currentDeskRoom?.id == DeskRoom.preview().id)
        #expect(model.currentDeskRoom?.code == "hello-room")
        #expect(model.currentDeskPartner == .ahe)
    }

    @Test("重置计时器后生成可执行建议且不重复 Toast")
    @MainActor
    func resettingTimerCreatesSuggestion() {
        let model = AppModel()

        model.resetTimer()

        #expect(model.remainingSeconds == 25 * 60)
        #expect(!model.timerRunning)
        #expect(model.activeSuggestion?.message == "计时器已经准备好，要从一段完整的 25 分钟重新开始吗？")
        #expect(model.activeSuggestion?.primaryOption.action == .beginFocus)
        #expect(model.toastMessage == nil)
    }

    @Test("执行开始建议后进入独立的专注设置")
    @MainActor
    func performingFocusSuggestionOpensStartSheet() throws {
        let model = AppModel()
        model.resetTimer()
        let suggestion = try #require(model.activeSuggestion)

        model.performSuggestion(suggestion.id)

        #expect(model.activeSuggestion == nil)
        #expect(model.activeSheet == .start)
        #expect(!model.timerRunning)
        #expect(model.remainingSeconds == 25 * 60)
    }

    }

    }

    @Test("专注结束且有同桌时建议打开留声机页")
    @MainActor
    func focusCompletionWithPartnerSuggestsVoiceRecorder() throws {
        let model = AppModel()
        model.deskSession = .connected(.preview())

        model.completeFocusSession()
        let suggestion = try #require(model.activeSuggestion)

        #expect(suggestion.message == "这一段已经完成。要给阿禾留一句话吗？")
        #expect(suggestion.primaryOption.action == .openPhonograph)
        #expect(model.toastMessage == nil)

        model.performSuggestion(suggestion.id)

        #expect(model.activeSuggestion == nil)
        #expect(model.activeSheet == .phonograph)
    }

    @Test("专注结束且没有同桌时建议休息")
    @MainActor
    func focusCompletionWithoutPartnerSuggestsRest() throws {
        let model = AppModel()

        model.completeFocusSession()
        let suggestion = try #require(model.activeSuggestion)

        #expect(suggestion.message == "这一段已经完成，先休息一会儿。")
        #expect(suggestion.primaryOption.action == .beginRest)

        model.performSuggestion(suggestion.id)

        #expect(model.activeSuggestion == nil)
        #expect(model.presence == .away)
    }

    @Test("开始专注会同步 Todo 和时长且不改变场景")
    @MainActor
    func startingFocusUpdatesState() async throws {
        let model = AppModel()
        model.createDeskRoom()
        try await waitUntil { model.currentDeskRoom != nil }
        let task = try #require(model.tasks.first { !$0.isCompleted })

        #expect(model.startFocus(durationMinutes: 45, taskID: task.id))
        #expect(model.activeFocusTask?.id == task.id)
        #expect(model.remainingSeconds == 45 * 60)
        #expect(model.timerRunning)
        #expect(model.activeFocusSession?.roomID == model.currentDeskRoom?.id)
        #expect(model.selectedSceneID == RoomSceneCatalog.focusScene.id)
    }

    }

    }

    @Test("有同桌时计时结束产生对应事件并引导留声机页")
    @MainActor
    func timerCompletionEndsActiveSession() async throws {
        let model = AppModel()
        model.joinDesk(code: "demo")
        try await waitUntil { model.currentDeskRoom != nil }
        let task = try #require(model.tasks.first { !$0.isCompleted })
        #expect(model.startFocus(durationMinutes: 15, taskID: task.id))

        model.completeFocusSession()

        #expect(model.lastActivityEndedEvent?.reason == .timerCompleted)
        #expect(model.activeSuggestion?.primaryOption.action == .openPhonograph)
        #expect(model.activeSheet == nil)
        #expect(model.activeFocusSession == nil)
    }

    @Test("专注中重置计时器按手动结束处理")
    @MainActor
    func resettingDeskFocusEndsActiveSession() async throws {
        let model = AppModel()
        model.createDeskRoom()
        try await waitUntil { model.currentDeskRoom != nil }
        let task = try #require(model.tasks.first { !$0.isCompleted })
        #expect(model.startFocus(durationMinutes: 25, taskID: task.id))

        model.resetTimer()

        #expect(model.lastActivityEndedEvent?.reason == .manuallyEnded)
        #expect(model.activeSuggestion?.primaryOption.action == .beginRest)
        #expect(model.activeFocusSession == nil)
    }

    }

    }

    }

    @MainActor
    private func waitUntil(
        _ condition: @escaping @MainActor () -> Bool
    ) async throws {
        for _ in 0..<50 {
            if condition() { return }
            try await Task.sleep(for: .milliseconds(10))
        }
        Issue.record("等待异步状态更新超时")
    }
}

private struct ImmediateMemoryImageGenerator: MemoryImageGenerating {
    func generate(prompt: String) async throws -> Data {
        Data([0x89, 0x50, 0x4E, 0x47])
    }
}

private struct ImmediateDeskPetGenerator: DeskPetGenerating {
    let result: Data?

    init(result: Data? = nil) { self.result = result }

    func generate(photoData: Data, partnerName: String) async throws -> Data {
        result ?? photoData
    }
}

@Suite("场景工坊流程")
@MainActor
struct SceneWorkshopTests {

    @Test("未配置图像服务时场景生图会明确失败")
    func hybridSceneGenerationRequiresConfiguration() async throws {
        let spec = GeneratedSceneSpec(
            sceneID: "scene-persisted",
            name: "测试场景",
            location: "安静的木屋",
            timeOfDay: .dusk,
            weather: "晴朗",
            mood: .warm,
            windowView: "树林",
            lighting: "壁炉",
            keyObjects: ["书本"],
            ambientPreset: .quiet,
            effectPreset: .none
        )
        let request = try SceneGenerationRequest(spec: spec, styleReferences: [])
        let generator = HybridSceneGenerator(configuration: .from(yaml: ""))
        await #expect(throws: SceneGenerationError.self) {
            _ = try await generator.generate(request) { _ in }
        }
    }

    }

    @Test("工坊完整推进到经过审查的单背景预览")
    func workshopProducesReviewedPreview() async throws {
        let workshop = SceneWorkshopModel(generator: ImmediateSceneGenerator())
        workshop.descriptionText = "雪夜列车包厢，两个人安静看书。"

        workshop.draftSpec()
        #expect(workshop.step == .configure)
        #expect(workshop.spec?.name == "雪夜列车")

        workshop.generate()
        for _ in 0..<50 where workshop.step != .preview {
            try await Task.sleep(for: .milliseconds(10))
        }

        let result = try #require(workshop.result)
        #expect(workshop.step == .preview)
        #expect(result.review.isApproved)
        #expect(result.image.relativePath == SceneGenerationContract.relativeImagePath(sceneID: result.sceneID))
        #expect(result.image.relativePath.hasPrefix("Scenes/"))

        let scene = try #require(workshop.generatedScene())
        #expect(scene.origin == .generated)
        #expect(scene.image.relativePath == result.image.relativePath)
    }

    }
}

@MainActor
private struct ImmediateSceneGenerator: SceneGenerating {
    func generate(
        _ request: SceneGenerationRequest,
        progress: @escaping (SceneGenerationState) -> Void
    ) async throws -> SceneGenerationResult {
        progress(.generating)
        progress(.reviewing)

        let template = RoomSceneCatalog.makeScene
        return SceneGenerationResult(
            requestID: request.id,
            sceneID: request.spec.sceneID,
            image: GeneratedSceneImage(
                relativePath: SceneGenerationContract.relativeImagePath(sceneID: request.spec.sceneID),
                canvas: SceneGenerationContract.canvas,
                metadata: template.image.metadata
            ),
            review: SceneGenerationReview(
                pixelStyleConsistent: true,
                compositionCorrect: true,
                interfaceSafeAreasClear: true,
                forbiddenContentAbsent: true
            ),
            completedAt: Date()
        )
    }
}

private enum AmbientCommand: Equatable {
    case start(AmbientPreset, Bool)
    case preset(AmbientPreset)
    case enabled(Bool)
    case muted(Bool)
    case stop
}

@MainActor
private final class AmbientAudioSpy: AmbientAudioControlling {
    private(set) var currentPreset: AmbientPreset = .rain
    private(set) var isEnabled = true
    private(set) var commands: [AmbientCommand] = []

    func start(preset: AmbientPreset, enabled: Bool) {
        currentPreset = preset
        isEnabled = enabled
        commands.append(.start(preset, enabled))
    }

    func setPreset(_ preset: AmbientPreset) {
        currentPreset = preset
        commands.append(.preset(preset))
    }

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        commands.append(.enabled(enabled))
    }

    func setTemporarilyMuted(_ muted: Bool) {
        commands.append(.muted(muted))
    }

    func stop() {
        commands.append(.stop)
    }
}

@Suite("同桌房间服务")
struct DeskRoomServiceTests {

    @Test("空邀请码被拒绝")
    func rejectsEmptyCode() async {
        let service = MockDeskRoomService()

        await #expect(throws: DeskRoomServiceError.emptyInviteCode) {
            try await service.joinRoom(inviteCode: "   ")
        }
    }
}

@Suite("专注会话服务")
struct FocusSessionServiceTests {

    @Test("非法时长被拒绝")
    func rejectsInvalidInput() {
        let service = MockFocusSessionService()

        #expect(throws: FocusSessionServiceError.invalidDuration) {
            try service.startSession(
                roomID: UUID(),
                configuration: FocusSessionConfiguration(durationMinutes: 30, taskID: UUID())
            )
        }
    }

}
