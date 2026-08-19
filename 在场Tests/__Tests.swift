//
//  __Tests.swift
//  在场Tests
//
//  Created by 郑恩嵘 on 2026/8/10.
//

import Foundation
import ImageIO
import Testing
#if os(macOS)
import AppKit
#endif
@testable import 在场

@Suite("在场 AppModel")
struct AppModelTests {
@Test("应用数据路径统一到同一个根目录")
    func appStoragePathsShareRoot() {
        let memories = AppStoragePaths.memoriesURL()
        let scenes = AppStoragePaths.generatedScenesURL()
        let api = AppStoragePaths.apiConfigurationURL()
        let deskPets = AppStoragePaths.deskPetsDirectory()
        let recordings = AppStoragePaths.recordingsDirectory()

        let root = AppStoragePaths.applicationSupportRoot().path
        #expect(memories.path.hasPrefix(root))
        #expect(scenes.path.hasPrefix(root))
        #expect(api.path.hasPrefix(root))
        #expect(deskPets.path.hasPrefix(root))
        #expect(recordings.path.hasPrefix(root))
    }


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

    @Test("同桌状态不会改变静态背景资源")
    @MainActor
    func deskOccupancySelectsSceneAsset() {
        let model = AppModel()

        #expect(model.selectedSceneImage.relativePath == "Scenes/focus.png")

        model.leaveDesk()

        #expect(model.selectedSceneImage.relativePath == "Scenes/focus.png")
        model.selectScene(RoomSceneCatalog.roamScene)
        #expect(model.selectedSceneImage.relativePath == "Scenes/roam.png")
        #expect(model.selectedScene.weatherEffect == .none)

        model.updateDeskPartner(nil)

        #expect(model.selectedSceneImage.relativePath == "Scenes/roam.png")
        #expect(model.selectedScene.weatherEffect == .none)
    }

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

    @Test("不支持天气的基础状态不会启用天气叠加层")
    @MainActor
    func unsupportedWeatherEffectStaysDisabled() {
        let model = AppModel()

        model.selectScene(RoomSceneCatalog.moveScene)
        let previousValue = model.weatherEffectsEnabled
        model.toggleWeather()

        #expect(!model.supportsWeatherEffects)
        #expect(model.weatherEffectsEnabled == previousValue)
    }

    @Test("非专注状态暂停计时，回到专注后继续")
    @MainActor
    func presenceControlsTimer() {
        let model = AppModel()

        model.setPresence(.away)
        #expect(model.presence == .away)
        #expect(!model.timerRunning)

        model.setPresence(.focus)
        #expect(model.presence == .focus)
        #expect(model.timerRunning)
    }

    @Test("天气与声音开关拥有单一 Swift 状态源")
    @MainActor
    func roomTogglesUpdateModel() {
        let model = AppModel()

        model.toggleWeather()
        model.toggleAmbient()

        #expect(!model.weatherEffectsEnabled)
        #expect(model.ambientEnabled)
    }

    @Test("任务完成数来自任务模型")
    @MainActor
    func taskCompletionIsDerived() {
        let model = AppModel()
        let pendingTask = model.tasks[1]

        model.toggleTask(pendingTask.id)

        #expect(model.completedTaskCount == 2)
        #expect(model.tasks[1].isCompleted)
    }

    @Test("可以新增本次在场要做的事")
    @MainActor
    func addingTaskNormalizesTitle() {
        let model = AppModel()

        let added = model.addTask(title: "  写完演示说明  ")

        #expect(added)
        #expect(model.tasks.first?.title == "写完演示说明")
        #expect(model.tasks.first?.isCompleted == false)
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

    @Test("桌上事项支持改名和删除")
    @MainActor
    func renamingAndDeletingTask() {
        let model = AppModel()
        let taskID = model.tasks[1].id

        #expect(model.renameTask(taskID, title: "完善方案最后两页"))
        #expect(model.tasks[1].title == "完善方案最后两页")

        model.deleteTask(taskID)

        #expect(!model.tasks.contains { $0.id == taskID })
        #expect(model.tasks.count == 2)
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

    @Test("移动端进入后台时停止环境声")
    @MainActor
    func mobileBackgroundStopsAmbientAudio() {
        let audio = AmbientAudioSpy()
        let model = AppModel(ambientAudio: audio)

        model.activateAudio()
        model.enterMobileBackground()

        #expect(audio.commands == [
            .start(.rain, false),
            .stop,
        ])
    }

    @Test("声音开关只驱动原生音频引擎")
    @MainActor
    func nativeAmbientToggle() {
        let audio = AmbientAudioSpy()
        let model = AppModel(ambientAudio: audio)
        model.activateAudio()

        model.toggleAmbient()
        model.toggleAmbient()

        #expect(audio.commands == [
            .start(.rain, false),
            .enabled(true),
            .enabled(false),
        ])
    }

    @Test("同桌邀请码只去除首尾空格且任意非空值有效")
    @MainActor
    func deskCodeFormatting() {
        let model = AppModel()

        #expect(model.formatDeskCode("  任意邀请码  ") == "任意邀请码")
        #expect(model.isValidDeskCode("demo"))
        #expect(!model.isValidDeskCode("   "))
    }

    @Test("应用启动时未连接房间且计时未开始")
    @MainActor
    func startsDisconnected() {
        let model = AppModel()

        #expect(model.currentDeskRoom == nil)
        #expect(model.deskActionTitle == "加入同桌")
        #expect(!model.timerRunning)
        #expect(model.remainingSeconds == 25 * 60)
    }

    @Test("创建房间后进入等待状态")
    @MainActor
    func creatingDeskWaitsForPartner() async throws {
        let model = AppModel()

        model.createDeskRoom()
        try await waitUntil { model.currentDeskRoom != nil }

        #expect(model.currentDeskRoom != nil)
        #expect(model.currentDeskPartner == nil)
        #expect(model.currentDeskRoom?.code == "DEMO-ROOM")
        #expect(model.deskActionTitle == "邀请同桌")
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

    @Test("房间内开始建议进入独立的专注设置")
    @MainActor
    func focusSuggestionInDeskRoomOpensConfiguration() throws {
        let model = AppModel()
        model.deskSession = .connected(.preview())
        model.resetTimer()
        let suggestion = try #require(model.activeSuggestion)

        model.performSuggestion(suggestion.id)

        #expect(model.activeSheet == .start)
        #expect(!model.timerRunning)
        #expect(model.activeFocusSession == nil)
    }

    @Test("关闭建议后普通状态更新不会使它重复出现")
    @MainActor
    func dismissedSuggestionStaysDismissed() throws {
        let model = AppModel()
        model.resetTimer()
        let suggestion = try #require(model.activeSuggestion)

        model.dismissSuggestion(suggestion.id)
        model.toggleWeather()

        #expect(model.activeSuggestion == nil)
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

    @Test("没有同桌房间也可以开始专注")
    @MainActor
    func focusDoesNotRequireDeskRoom() throws {
        let model = AppModel()
        let task = try #require(model.tasks.first { !$0.isCompleted })

        #expect(model.startFocus(durationMinutes: 25, taskID: task.id))
        #expect(model.activeFocusSession?.roomID == nil)
        #expect(model.timerRunning)
    }

    @Test("空房中手动结束只产生一次事件并建议休息")
    @MainActor
    func manuallyEndingFocusIsIdempotent() async throws {
        let model = AppModel()
        model.createDeskRoom()
        try await waitUntil { model.currentDeskRoom != nil }
        let task = try #require(model.tasks.first { !$0.isCompleted })
        #expect(model.startFocus(durationMinutes: 25, taskID: task.id))

        model.manuallyEndFocusSession()
        let event = try #require(model.lastActivityEndedEvent)
        model.manuallyEndFocusSession()

        #expect(event.reason == .manuallyEnded)
        #expect(model.lastActivityEndedEvent == event)
        #expect(model.activeSuggestion?.primaryOption.action == .beginRest)
        #expect(model.activeFocusSession == nil)
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

    @Test("活动 Todo 不可删除以保留手动结束入口")
    @MainActor
    func activeFocusTaskCannotBeDeleted() async throws {
        let model = AppModel()
        model.createDeskRoom()
        try await waitUntil { model.currentDeskRoom != nil }
        let task = try #require(model.tasks.first { !$0.isCompleted })
        #expect(model.startFocus(durationMinutes: 25, taskID: task.id))

        model.deleteTask(task.id)

        #expect(model.activeFocusTask?.id == task.id)
        #expect(model.activeFocusSession != nil)
    }

    @Test("离开同桌房间不会结束正在进行的专注")
    @MainActor
    func leavingDeskKeepsActiveSession() async throws {
        let model = AppModel()
        model.createDeskRoom()
        try await waitUntil { model.currentDeskRoom != nil }
        let task = try #require(model.tasks.first { !$0.isCompleted })
        #expect(model.startFocus(durationMinutes: 25, taskID: task.id))
        let session = try #require(model.activeFocusSession)

        model.leaveDesk()

        #expect(model.currentDeskRoom == nil)
        #expect(model.lastActivityEndedEvent == nil)
        #expect(model.activeFocusSession == session)
        #expect(model.timerRunning)
    }

    @Test("专注中手动切换场景不改变会话或剩余时间")
    @MainActor
    func switchingSceneKeepsFocusState() async throws {
        let model = AppModel()
        model.createDeskRoom()
        try await waitUntil { model.currentDeskRoom != nil }
        let task = try #require(model.tasks.first { !$0.isCompleted })
        #expect(model.startFocus(durationMinutes: 25, taskID: task.id))
        let session = try #require(model.activeFocusSession)
        let remainingSeconds = model.remainingSeconds

        model.selectScene(RoomSceneCatalog.roamScene)

        #expect(model.activeFocusSession == session)
        #expect(model.remainingSeconds == remainingSeconds)
        #expect(model.selectedSceneID == RoomSceneCatalog.roamScene.id)
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

@Suite("场景生成契约")
@MainActor
struct SceneGenerationContractTests {

    @Test("四个内置状态场景资源完整且可渲染")
    func builtInSceneCatalogIsComplete() {
        let scenes = RoomSceneCatalog.builtIn

        #expect(scenes.count == 4)
        #expect(Set(scenes.map(\.id)).count == scenes.count)
        #expect(Set(scenes.map(\.image.relativePath)).count == scenes.count)

        for scene in scenes {
            let relativePath = scene.image.relativePath as NSString
            let fileName = (relativePath.lastPathComponent as NSString).deletingPathExtension
            let fileExtension = (relativePath.lastPathComponent as NSString).pathExtension
            let imageURL = Bundle.main.url(forResource: fileName, withExtension: fileExtension)
            let source = imageURL.flatMap { CGImageSourceCreateWithURL($0 as CFURL, nil) }
            let properties = source.flatMap {
                CGImageSourceCopyPropertiesAtIndex($0, 0, nil) as? [CFString: Any]
            }

            #expect(source != nil, "缺少内置场景资源：\(scene.image.relativePath)")
            #expect(properties?[kCGImagePropertyPixelWidth] as? Int == 1_920)
            #expect(properties?[kCGImagePropertyPixelHeight] as? Int == 1_080)
        }
    }

    @Test("内置场景与生成场景使用同一资源包路径")
    func packagedScenePathsAreStable() {
        #expect(SceneGenerationContract.canvas == SceneCanvas(width: 1_920, height: 1_080, format: .png))
        #expect(RoomSceneCatalog.builtIn.allSatisfy { SceneGenerationContract.isValidSceneID($0.id) })
        #expect(RoomSceneCatalog.states.map(\.id) == ["focus", "make", "move", "roam"])
        #expect(RoomSceneCatalog.builtIn.map(\.id) == RoomSceneCatalog.states.map(\.id))

        let scene = RoomSceneCatalog.focusScene
        #expect(scene.image.relativePath == "Scenes/focus.png")
        #expect(scene.activityState?.ambientPresets == [.quiet, .rain])
        #expect(RoomSceneCatalog.make.ambientPresets == [.quiet, .fireplace])
        #expect(RoomSceneCatalog.move.availableEffects == [.none])
        #expect(RoomSceneCatalog.roam.defaultAmbientPreset == .forest)
    }

    @Test("场景规格拒绝不安全 ID 和超过三个关键物件")
    func generatedSceneSpecValidatesContract() {
        let invalidIDSpec = GeneratedSceneSpec(
            sceneID: "雨夜书房",
            name: sampleSpec.name,
            location: sampleSpec.location,
            timeOfDay: sampleSpec.timeOfDay,
            weather: sampleSpec.weather,
            mood: sampleSpec.mood,
            windowView: sampleSpec.windowView,
            lighting: sampleSpec.lighting,
            keyObjects: sampleSpec.keyObjects,
            ambientPreset: sampleSpec.ambientPreset,
            effectPreset: sampleSpec.effectPreset
        )

        #expect(throws: SceneSpecValidationError.invalidSceneID) {
            try invalidIDSpec.validate()
        }

        var crowdedSpec = sampleSpec
        crowdedSpec.keyObjects = ["book", "lamp", "tea", "radio"]
        #expect(throws: SceneSpecValidationError.tooManyKeyObjects(maximum: 3)) {
            try crowdedSpec.validate()
        }
    }

    private var sampleSpec: GeneratedSceneSpec {
        GeneratedSceneSpec(
            sceneID: "snowy-train",
            name: "雪夜列车",
            location: "a private sleeper train compartment",
            timeOfDay: .lateNight,
            weather: "snow falling outside",
            mood: .warm,
            windowView: "dark mountains and distant station lights",
            lighting: "two warm reading lamps",
            keyObjects: ["open book", "tea cup", "wool coat"],
            ambientPreset: .quiet,
            effectPreset: .none
        )
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

    @Test("生成场景元数据可以从本地存储恢复")
    func generatedSceneMetadataPersists() throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("zaichang-scenes-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: fileURL) }
        let persistence = ScenePersistence(fileURL: fileURL)
        let scene = RoomScene(
            id: "scene-restored",
            origin: .generated,
            name: "恢复测试",
            eyebrow: "黄昏 · 晴朗",
            headline: "在这里待一会儿",
            image: .packaged(sceneID: "scene-restored", metadata: SceneImageMetadata(accessibilityDescription: "测试")),
            ambientPreset: .quiet,
            weatherEffect: .none,
            promptVersion: SceneGenerationContract.currentPromptVersion
        )
        try persistence.save([scene])
        #expect(persistence.load() == [scene])
    }

    @Test("自然语言描述会形成可编辑的结构化场景")
    func mockDrafterCreatesEditableSpec() throws {
        let spec = MockSceneSpecDrafter().draft(
            from: "雨夜的旧阁楼书房，两个人隔着一盏台灯安静工作。"
        )

        #expect(spec.name == "雨夜阁楼")
        #expect(spec.effectPreset == .rain)
        #expect(spec.ambientPreset == .rain)
        #expect(spec.keyObjects.count == 3)
        #expect(SceneGenerationContract.isValidSceneID(spec.sceneID))
        try spec.validate()
    }

    @Test("自由描述不会套用无关的预设场景细节")
    func freeFormDescriptionStartsWithBlankDetails() {
        let spec = MockSceneSpecDrafter().draft(
            from: "一间面向湖面的玻璃屋，清晨一起整理旅行照片。"
        )

        #expect(spec.name.isEmpty)
        #expect(spec.location.isEmpty)
        #expect(spec.weather.isEmpty)
        #expect(spec.windowView.isEmpty)
        #expect(spec.lighting.isEmpty)
        #expect(spec.keyObjects.isEmpty)
        #expect(spec.ambientPreset == .quiet)
        #expect(spec.effectPreset == .none)
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

    @Test("保存生成场景后加入列表并立即选中")
    func savingGeneratedSceneUpdatesAppModel() {
        let model = AppModel(sceneGenerator: ImmediateSceneGenerator())
        let sceneID = "scene-testroom"
        let scene = RoomScene(
            id: sceneID,
            origin: .generated,
            name: "测试房间",
            eyebrow: "深夜 · 晴朗",
            headline: "在测试房间慢慢待一会儿",
            image: .packaged(
                sceneID: sceneID,
                metadata: SceneImageMetadata(accessibilityDescription: "测试房间静态背景")
            ),
            ambientPreset: .quiet,
            weatherEffect: .none,
            promptVersion: SceneGenerationContract.currentPromptVersion
        )

        model.saveGeneratedScene(scene)

        #expect(model.scenes.last == scene)
        #expect(model.selectedSceneID == sceneID)
        #expect(model.selectedScene.origin == .generated)
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

    @Test("创建空房，加入房间时 Mock 同桌")
    func roomPartnerDependsOnEntryFlow() async throws {
        let service = MockDeskRoomService()

        let created = try await service.createRoom()
        let joined = try await service.joinRoom(inviteCode: "  任意邀请码  ")

        #expect(created.id == joined.id)
        #expect(created.partner == nil)
        #expect(joined.partner == .ahe)
        #expect(joined.code == "任意邀请码")
    }

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

    @Test("使用合法配置创建同桌关联会话")
    func startsSession() throws {
        let taskID = UUID()
        let roomID = UUID()
        let service = MockFocusSessionService()

        let session = try service.startSession(
            roomID: roomID,
            configuration: FocusSessionConfiguration(durationMinutes: 25, taskID: taskID)
        )

        #expect(session.roomID == roomID)
        #expect(session.taskID == taskID)
        #expect(session.durationSeconds == 25 * 60)
    }

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

    @Test("两种结束方式保留对应原因")
    func endReasons() throws {
        let service = MockFocusSessionService()
        let session = try service.startSession(
            roomID: UUID(),
            configuration: FocusSessionConfiguration(durationMinutes: 25, taskID: UUID())
        )

        #expect(service.endSession(session, reason: .timerCompleted).reason == .timerCompleted)
        #expect(service.endSession(session, reason: .manuallyEnded).reason == .manuallyEnded)
    }
}
