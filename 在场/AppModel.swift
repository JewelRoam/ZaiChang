import Combine
import Foundation

enum PresenceMode: String, CaseIterable, Identifiable {
    case focus
    case quiet
    case rest = "break"
    case away

    var id: String { rawValue }

    var title: String {
        switch self {
        case .focus: "专注中"
        case .quiet: "安静待着"
        case .rest: "休息一下"
        case .away: "离开一会"
        }
    }

    var detail: String {
        switch self {
        case .focus: "灯会一直亮着"
        case .quiet: "暂停所有提醒"
        case .rest: "给自己十分钟"
        case .away: "保留桌上的灯"
        }
    }

    var symbol: String {
        switch self {
        case .focus: "lamp.desk"
        case .quiet: "moon.stars"
        case .rest: "cup.and.saucer"
        case .away: "door.left.hand.open"
        }
    }

    /// 用户可以在界面上主动切换的状态。`quiet` 和 `rest` 仍保留在模型里
    /// 供渲染和历史数据使用，但不再作为可选项呈现。
    static let selectable: [PresenceMode] = [.focus, .away]
}

struct FocusTask: Identifiable {
    let id = UUID()
    var title: String
    var isCompleted: Bool
}

enum PresenceSuggestionAction: Equatable {
    case beginFocus
    case resumeFocus
    case inviteDeskMate
    case openVoiceRecorder
    case beginRest
}

enum PresenceSuggestionContext: Equatable {
    case waitingForPartner(roomID: DeskRoom.ID)
    case timerReset
    case focusCompleted(partnerID: DeskPartner.ID?)
    case partnerReady(roomID: DeskRoom.ID)
    case focusPaused
    case dailyTodoCompleted(day: String)
}

private enum PresenceSuggestionCategory: Hashable {
    case waitingForPartner
    case timerReset
    case focusCompleted
    case partnerReady
    case focusPaused
    case dailyTodoCompleted
}

struct PresenceSuggestionOption: Equatable {
    let title: String
    let action: PresenceSuggestionAction
}

struct PresenceSuggestion: Identifiable, Equatable {
    let id: UUID
    let message: String
    let primaryOption: PresenceSuggestionOption
    let secondaryOption: PresenceSuggestionOption?
    let context: PresenceSuggestionContext

    init(
        id: UUID = UUID(),
        message: String,
        primaryOption: PresenceSuggestionOption,
        secondaryOption: PresenceSuggestionOption? = nil,
        context: PresenceSuggestionContext
    ) {
        self.id = id
        self.message = message
        self.primaryOption = primaryOption
        self.secondaryOption = secondaryOption
        self.context = context
    }
}

private struct ScheduledPresenceSuggestion {
    let dueAt: Date
    let suggestion: PresenceSuggestion
}

private extension PresenceSuggestionContext {
    var category: PresenceSuggestionCategory {
        switch self {
        case .waitingForPartner: .waitingForPartner
        case .timerReset: .timerReset
        case .focusCompleted: .focusCompleted
        case .partnerReady: .partnerReady
        case .focusPaused: .focusPaused
        case .dailyTodoCompleted: .dailyTodoCompleted
        }
    }
}

private extension PresenceSuggestionCategory {
    var priority: Int {
        switch self {
        case .focusCompleted: 6
        case .dailyTodoCompleted: 5
        case .partnerReady: 4
        case .focusPaused: 3
        case .timerReset: 2
        case .waitingForPartner: 1
        }
    }
}

enum AppSheet: String, Identifiable {
    case desk
    case voice
    case phonograph
    case memoryArchive
    case scenes
    case sceneWorkshop
    case context

    var id: String { rawValue }
}

struct DeskPartner: Equatable, Identifiable {
    let id: UUID
    let name: String
    let character: String
    let focusSeconds: Int

    static let ahe = DeskPartner(
        id: UUID(uuidString: "A11E0000-0000-0000-0000-000000000001")!,
        name: "阿禾",
        character: "禾",
        focusSeconds: 18 * 60 + 6
    )

    var focusText: String {
        String(format: "%02d:%02d", focusSeconds / 60, focusSeconds % 60)
    }
}

struct DeskRoom: Equatable, Identifiable {
    let id: UUID
    let code: String
    let createdAt: Date
    let expiresAt: Date
    var partner: DeskPartner?

    static func preview(now: Date = Date()) -> DeskRoom {
        DeskRoom(
            id: UUID(uuidString: "DE5C0000-0000-0000-0000-000000000001")!,
            code: "YUZU-2048",
            createdAt: now.addingTimeInterval(-18 * 60),
            expiresAt: now.addingTimeInterval(30 * 60),
            partner: .ahe
        )
    }
}

enum DeskSessionState: Equatable {
    case disconnected
    case joining(code: String)
    case connected(DeskRoom)
}

enum NudgeAvailability: Equatable {
    case available
    case noPartner
    case coolingDown(remainingSeconds: Int)

    var unavailableMessage: String? {
        switch self {
        case .available:
            nil
        case .noPartner:
            "加入同桌房间后才能拍一拍"
        case .coolingDown(let remainingSeconds):
            "刚刚拍过，\(remainingSeconds) 秒后再试"
        }
    }
}

@MainActor
final class AppModel: ObservableObject {
    static let maximumTaskCount = 5
    static let maximumTaskTitleLength = 30
    static let nudgeCooldownSeconds: TimeInterval = 10

    @Published private(set) var scenes = RoomSceneCatalog.builtIn
    @Published private(set) var selectedSceneID = RoomSceneCatalog.focusScene.id
    @Published var presence: PresenceMode = .focus
    @Published var weatherEffectsEnabled = true
    @Published var ambientEnabled = false
    @Published var remainingSeconds = 25 * 60
    @Published var timerRunning = false
    @Published var presenceSeconds = 42 * 60
    @Published var activeSheet: AppSheet?
    @Published var toastMessage: String?
    @Published var deskSession: DeskSessionState = .disconnected {
        didSet { deskPet.setActivePartner(currentDeskPartner) }
    }
    @Published var deskErrorMessage: String?
    @Published private(set) var activeSuggestion: PresenceSuggestion?
    @Published private(set) var activeFocusSession: FocusSession?
    @Published private(set) var lastActivityEndedEvent: ActivityEndedEvent?
    @Published var tasks = [
        FocusTask(title: "整理首页文案", isCompleted: true),
        FocusTask(title: "补齐方案最后两页", isCompleted: false),
        FocusTask(title: "给阿禾回一段留声", isCompleted: false),
    ]
    @Published private(set) var dailyTodoCompletedAt: Date?

    let voiceRecorder: VoiceRecorderController
    let memory: MemoryController
    let deskPet: DeskPetController
    let sceneGenerator: any SceneGenerating
    private let scenePersistence: ScenePersistence
    private let todoDefaults: UserDefaults

    private let ambientAudio: AmbientAudioControlling
    private let deskRoomService: any DeskRoomServicing
    private let focusSessionService: any FocusSessionServicing
    private var audioActivated = false
    private var timerTask: Task<Void, Never>?
    private var timerEndDate: Date?
    private var focusSessionStarted = false
    private var toastTask: Task<Void, Never>?
    private var deskJoinTask: Task<Void, Never>?
    private var lastNudgeSentAt: Date?
    private var scheduledSuggestions: [PresenceSuggestionCategory: ScheduledPresenceSuggestion] = [:]
    private var suggestionCandidates: [PresenceSuggestionCategory: PresenceSuggestion] = [:]
    private var dailyTodoSuggestedDays: Set<String> = []

    init(
        ambientAudio: AmbientAudioControlling? = nil,
        sceneGenerator: (any SceneGenerating)? = nil,
        deskPetGenerator: (any DeskPetGenerating)? = nil,
        deskRoomService: (any DeskRoomServicing)? = nil,
        focusSessionService: (any FocusSessionServicing)? = nil
    ) {
        scenePersistence = ScenePersistence()
        todoDefaults = .standard
        let persistedGeneratedScenes = scenePersistence.load()
        scenes = RoomSceneCatalog.builtIn + persistedGeneratedScenes
        let storedTodoDate = todoDefaults.object(forKey: "dailyTodoCompletedAt") as? Date
        dailyTodoCompletedAt = storedTodoDate.flatMap { Self.currentDayKey(now: $0) == Self.currentDayKey() ? $0 : nil }
        let audio = ambientAudio ?? AmbientAudioEngine()
        self.ambientAudio = audio
        self.deskRoomService = deskRoomService ?? MockDeskRoomService()
        self.focusSessionService = focusSessionService ?? MockFocusSessionService()
        self.sceneGenerator = sceneGenerator ?? HybridSceneGenerator()
        deskPet = DeskPetController(generator: deskPetGenerator ?? HybridDeskPetGenerator())
        voiceRecorder = VoiceRecorderController(ambientAudio: audio)
        memory = MemoryController()
        timerTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                self?.tick()
            }
        }
    }

    deinit {
        timerTask?.cancel()
        toastTask?.cancel()
        deskJoinTask?.cancel()
    }

    var timerText: String { Self.formatDuration(remainingSeconds) }
    var presenceText: String { "\(presenceSeconds / 60) 分钟" }
    var completedTaskCount: Int { tasks.filter(\.isCompleted).count }
    var canAddTask: Bool { tasks.count < Self.maximumTaskCount }
    var incompleteTasks: [FocusTask] { tasks.filter { !$0.isCompleted } }
    var orderedTasks: [FocusTask] {
        tasks.filter { !$0.isCompleted } + tasks.filter(\.isCompleted)
    }
    var shareableDeskCode: String { currentDeskRoom?.code ?? deskRoomService.demoInviteCode }
    private var allTasksCompleted: Bool { !tasks.isEmpty && tasks.allSatisfy(\.isCompleted) }

    var currentDeskRoom: DeskRoom? {
        guard case let .connected(room) = deskSession else { return nil }
        return room
    }

    var currentDeskPartner: DeskPartner? { currentDeskRoom?.partner }
    var activeFocusTask: FocusTask? {
        guard let taskID = activeFocusSession?.taskIDs.first else { return nil }
        return tasks.first { $0.id == taskID }
    }

    var activeFocusTasks: [FocusTask] {
        guard let taskIDs = activeFocusSession?.taskIDs else { return [] }
        return taskIDs.compactMap { taskID in tasks.first { $0.id == taskID } }
    }

    var activeFocusSummary: String? {
        let titles = activeFocusTasks.map(\.title) + [activeFocusSession?.customTaskTitle].compactMap { $0 }
        return titles.isEmpty ? nil : titles.joined(separator: " · ")
    }
    var deskActionTitle: String { currentDeskRoom == nil ? "加入同桌" : "邀请同桌" }

    func nudgeAvailability(at now: Date = Date()) -> NudgeAvailability {
        guard currentDeskPartner != nil else { return .noPartner }
        if let lastNudgeSentAt {
            let remaining = Self.nudgeCooldownSeconds - now.timeIntervalSince(lastNudgeSentAt)
            if remaining > 0 {
                return .coolingDown(remainingSeconds: Int(ceil(remaining)))
            }
        }
        return .available
    }

    func nudgeDeskMate(at now: Date = Date()) {
        let availability = nudgeAvailability(at: now)
        guard case .available = availability, let partner = currentDeskPartner else {
            if let message = availability.unavailableMessage {
                deskPet.presentNudgeFeedback(message: message, kind: .unavailable)
            }
            return
        }

        lastNudgeSentAt = now
        deskPet.presentNudgeFeedback(
            message: "已拍一拍\(partner.name)",
            kind: .sent
        )
    }

    func handleDemoControlCommand(_ command: DemoControlCommand) {
        switch command.type {
        case .advanceTime:
            guard let seconds = command.seconds else { return }
            advanceDemoTime(by: seconds)
        case .receiveNudge:
            receiveDemoNudge()
        }
    }

    private func advanceDemoTime(by seconds: Int) {
        guard seconds > 0 else { return }
        let interval = TimeInterval(seconds)

        if let timerEndDate {
            self.timerEndDate = timerEndDate.addingTimeInterval(-interval)
        }
        if let lastNudgeSentAt {
            self.lastNudgeSentAt = lastNudgeSentAt.addingTimeInterval(-interval)
        }
        scheduledSuggestions = scheduledSuggestions.mapValues { scheduled in
            ScheduledPresenceSuggestion(
                dueAt: scheduled.dueAt.addingTimeInterval(-interval),
                suggestion: scheduled.suggestion
            )
        }
        if timerRunning {
            presenceSeconds += min(seconds, remainingSeconds)
            updateRemainingTime()
            if remainingSeconds == 0 {
                completeFocusSession()
                return
            }
        }
        refreshSuggestions()
    }

    private func receiveDemoNudge() {
        guard let partner = currentDeskPartner else {
            showToast("当前没有同桌，无法模拟收到拍一拍")
            return
        }
        deskPet.presentNudgeFeedback(
            message: "\(partner.name)拍了拍你",
            kind: .received
        )
        if deskPet.partnerProfile?.isEnabled != true {
            showToast("\(partner.name)拍了拍你")
        }
    }

    var selectedScene: RoomScene {
        scenes.first(where: { $0.id == selectedSceneID }) ?? RoomSceneCatalog.focusScene
    }

    var selectedSceneImage: SceneImageAsset {
        selectedScene.image
    }

    var availableAmbientPresets: [AmbientPreset] {
        selectedScene.activityState?.ambientPresets ?? AmbientPreset.allCases
    }

    var supportsWeatherEffects: Bool {
        selectedScene.activityState?.availableEffects.contains(where: { $0 != .none })
            ?? (selectedScene.weatherEffect != .none)
    }

    func selectAmbientPreset(_ preset: AmbientPreset) {
        guard availableAmbientPresets.contains(preset) else { return }
        guard let index = scenes.firstIndex(where: { $0.id == selectedSceneID }) else { return }
        let scene = scenes[index]
        scenes[index] = RoomScene(
            id: scene.id,
            origin: scene.origin,
            name: scene.name,
            eyebrow: scene.eyebrow,
            headline: scene.headline,
            image: scene.image,
            ambientPreset: preset,
            weatherEffect: scene.weatherEffect,
            promptVersion: scene.promptVersion,
            activityState: scene.activityState
        )
        if audioActivated {
            ambientAudio.setPreset(preset)
        }
        showToast("已换成\(preset.displayName)")
    }

    func selectScene(_ scene: RoomScene) {
        guard scenes.contains(where: { $0.id == scene.id }) else { return }
        selectedSceneID = scene.id
        if audioActivated {
            ambientAudio.setPreset(scene.ambientPreset)
        }
        showToast("已换到\(scene.name)")
    }

    func saveGeneratedScene(_ scene: RoomScene) {
        guard scene.origin == .generated else { return }
        scenes.removeAll { $0.id == scene.id }
        scenes.append(scene)
        do {
            try scenePersistence.save(scenes.filter { $0.origin == .generated })
        } catch {
            showToast("场景已加入本次使用，但保存失败")
        }
        selectedSceneID = scene.id
        if audioActivated {
            ambientAudio.setPreset(scene.ambientPreset)
        }
        showToast("\(scene.name)已经点亮")
    }

    func activateAudio() {
        guard !audioActivated else { return }
        audioActivated = true
        ambientAudio.start(preset: selectedScene.ambientPreset, enabled: ambientEnabled)
    }

    func deactivateAudio() {
        guard audioActivated else { return }
        audioActivated = false
        ambientAudio.stop()
    }

    func enterMobileBackground() {
        if voiceRecorder.isRecording {
            voiceRecorder.finishRecording()
        } else {
            voiceRecorder.stopPlayback()
        }
        deactivateAudio()
    }

    func setPresence(_ mode: PresenceMode) {
        presence = mode
        if mode == .focus {
            resumeTimer()
        } else {
            pauseTimer(shouldObserveLongPause: true)
        }
        showToast("状态已切换为“\(mode.title)”")
    }

    func toggleTimer() {
        timerRunning ? pauseTimer(shouldObserveLongPause: true) : resumeTimer()
        showToast(timerRunning ? "继续这一段" : "计时已暂停")
    }

    func resetTimer() {
        if activeFocusSession != nil {
            endFocusSession(reason: .manuallyEnded)
            return
        }

        cancelSuggestions(in: .focusPaused)
        remainingSeconds = 25 * 60
        timerRunning = false
        timerEndDate = nil
        focusSessionStarted = false
        offerSuggestion(PresenceSuggestion(
            message: "计时器已经准备好，要从一段完整的 25 分钟重新开始吗？",
            primaryOption: PresenceSuggestionOption(title: "开始这一段", action: .beginFocus),
            context: .timerReset
        ))
    }

    func beginFocusSession() {
        presence = .focus
        remainingSeconds = 25 * 60
        timerRunning = true
        timerEndDate = Date().addingTimeInterval(TimeInterval(remainingSeconds))
        markOwnFocusStarted()
        showToast("台灯已亮起，25 分钟从现在开始")
    }

    @discardableResult
    func beginDeskFocus(durationMinutes: Int, taskID: FocusTask.ID) -> Bool {
        beginDeskFocus(durationMinutes: durationMinutes, taskIDs: [taskID], customTaskTitle: nil, sceneID: nil)
    }

    @discardableResult
    func beginDeskFocus(
        durationMinutes: Int,
        taskIDs: Set<FocusTask.ID>,
        customTaskTitle rawCustomTaskTitle: String?,
        sceneID: RoomScene.ID?
    ) -> Bool {
        let selectableTaskIDs = Set(incompleteTasks.map(\.id))
        guard let room = currentDeskRoom,
              taskIDs.isSubset(of: selectableTaskIDs),
              sceneID.map({ selectedID in scenes.contains(where: { $0.id == selectedID }) }) ?? true else { return false }
        let customTaskTitle = rawCustomTaskTitle?.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedCustomTaskTitle = customTaskTitle?.isEmpty == false ? customTaskTitle : nil

        do {
            let session = try focusSessionService.startSession(
                roomID: room.id,
                configuration: FocusSessionConfiguration(
                    durationMinutes: durationMinutes,
                    taskIDs: Array(taskIDs),
                    customTaskTitle: normalizedCustomTaskTitle,
                    sceneID: sceneID
                ),
                candidateScenes: scenes
            )
            guard let scene = scenes.first(where: { $0.id == session.sceneID }) else { return false }

            activeFocusSession = session
            lastActivityEndedEvent = nil
            presence = .focus
            remainingSeconds = session.durationSeconds
            timerRunning = true
            timerEndDate = Date().addingTimeInterval(TimeInterval(session.durationSeconds))
            selectScene(scene)
            markOwnFocusStarted()
            showToast("已经开始 \(durationMinutes) 分钟专注")
            return true
        } catch {
            showToast("暂时无法开始这一段")
            return false
        }
    }

    func toggleWeather() {
        guard supportsWeatherEffects else { return }
        weatherEffectsEnabled.toggle()
        showToast(weatherEffectsEnabled ? "窗外天气已打开" : "窗外天气已关闭")
    }

    func toggleAmbient() {
        ambientEnabled.toggle()
        if audioActivated {
            ambientAudio.setEnabled(ambientEnabled)
        }
        let soundName = selectedScene.ambientPreset.displayName
        showToast(ambientEnabled ? "\(soundName)已打开" : "\(soundName)已关闭")
    }

    func toggleTask(_ taskID: FocusTask.ID) {
        guard let index = tasks.firstIndex(where: { $0.id == taskID }) else { return }
        let wasCompleted = allTasksCompleted
        tasks[index].isCompleted.toggle()
        if tasks[index].isCompleted {
            showToast("这件事已经收好了")
            if allTasksCompleted, dailyTodoCompletedAt == nil {
                dailyTodoCompletedAt = Date()
                todoDefaults.set(dailyTodoCompletedAt, forKey: "dailyTodoCompletedAt")
            }
        } else {
            dailyTodoCompletedAt = nil
            todoDefaults.removeObject(forKey: "dailyTodoCompletedAt")
        }
        handleDailyTodoCompletionTransition(wasCompleted: wasCompleted)
    }

    @discardableResult
    func addTask(title rawTitle: String) -> Bool {
        guard canAddTask else {
            showToast("桌上最多放 \(Self.maximumTaskCount) 件事")
            return false
        }
        let title = normalizedTaskTitle(rawTitle)
        guard !title.isEmpty else { return false }
        guard !containsTask(named: title) else {
            showToast("这件事已经在桌上了")
            return false
        }

        tasks.insert(FocusTask(title: title, isCompleted: false), at: 0)
        invalidateDailyTodoSuggestionIfNeeded()
        showToast("已经放到桌上")
        return true
    }

    @discardableResult
    func renameTask(_ taskID: FocusTask.ID, title rawTitle: String) -> Bool {
        guard let index = tasks.firstIndex(where: { $0.id == taskID }) else { return false }
        let title = normalizedTaskTitle(rawTitle)
        guard !title.isEmpty else { return false }
        guard !containsTask(named: title, excluding: taskID) else {
            showToast("这件事已经在桌上了")
            return false
        }

        tasks[index].title = title
        return true
    }

    func deleteTask(_ taskID: FocusTask.ID) {
        guard activeFocusSession?.taskIDs.contains(taskID) != true else { return }
        tasks.removeAll { $0.id == taskID }
        invalidateDailyTodoSuggestionIfNeeded()
    }

    func formatDeskCode(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func isValidDeskCode(_ value: String) -> Bool {
        !formatDeskCode(value).isEmpty
    }

    func joinDesk(code rawCode: String) {
        let code = formatDeskCode(rawCode)
        guard isValidDeskCode(code) else {
            deskErrorMessage = "请输入同桌邀请码。"
            return
        }

        deskJoinTask?.cancel()
        resetNudgeSession()
        cancelSuggestions(in: .waitingForPartner, .partnerReady)
        deskErrorMessage = nil
        deskSession = .joining(code: code)
        refreshSuggestions()
        deskJoinTask = Task { @MainActor [weak self] in
            guard !Task.isCancelled, let self else { return }
            do {
                let room = try await deskRoomService.joinRoom(inviteCode: code)
                guard !Task.isCancelled else { return }
                deskSession = .connected(room)
                schedulePartnerReadySuggestion(for: room)
                refreshSuggestions()
                showToast("已经和阿禾坐到一起")
            } catch {
                deskSession = .disconnected
                deskErrorMessage = "暂时无法加入房间，请重试。"
                refreshSuggestions()
            }
        }
    }

    func createDeskRoom() {
        deskJoinTask?.cancel()
        resetNudgeSession()
        cancelSuggestions(in: .waitingForPartner, .partnerReady)
        deskErrorMessage = nil
        deskSession = .joining(code: "DEMO-ROOM")
        refreshSuggestions()
        deskJoinTask = Task { @MainActor [weak self] in
            guard !Task.isCancelled, let self else { return }
            do {
                let room = try await deskRoomService.createRoom()
                guard !Task.isCancelled else { return }
                deskSession = .connected(room)
                scheduleWaitingSuggestion(for: room)
                refreshSuggestions()
                showToast("Demo 房间已经准备好")
            } catch {
                deskSession = .disconnected
                deskErrorMessage = "暂时无法创建房间，请重试。"
                refreshSuggestions()
            }
        }
    }

    func updateDeskPartner(_ partner: DeskPartner?) {
        guard case var .connected(room) = deskSession else { return }
        if room.partner?.id != partner?.id { resetNudgeSession() }
        room.partner = partner
        deskSession = .connected(room)
        if partner != nil {
            cancelSuggestions(in: .waitingForPartner)
            schedulePartnerReadySuggestion(for: room)
        } else {
            cancelSuggestions(in: .partnerReady)
            deskPet.clear()
        }
        refreshSuggestions()
    }

    func cancelDeskJoin() {
        deskJoinTask?.cancel()
        resetNudgeSession()
        cancelSuggestions(in: .waitingForPartner, .partnerReady)
        deskSession = .disconnected
        deskErrorMessage = nil
        refreshSuggestions()
    }

    func copyDeskCode() {
        let code = shareableDeskCode
        cancelSuggestions(in: .waitingForPartner)
        refreshSuggestions()
        ClipboardClient.writeText(code)
        showToast("同桌码 \(code) 已复制")
    }

    func leaveDesk() {
        deskJoinTask?.cancel()
        resetNudgeSession()
        cancelSuggestions(in: .waitingForPartner, .partnerReady)
        deskSession = .disconnected
        deskPet.clear()
        deskErrorMessage = nil
        if activeFocusSession != nil {
            endFocusSession(reason: .manuallyEnded)
        } else {
            timerRunning = false
            timerEndDate = nil
            focusSessionStarted = false
        }
        refreshSuggestions()
        showToast("已经离开同桌房间")
    }

    private func resetNudgeSession() {
        lastNudgeSentAt = nil
        deskPet.dismissNudgeFeedback()
    }

    func performSuggestion(
        _ suggestionID: PresenceSuggestion.ID,
        action selectedAction: PresenceSuggestionAction? = nil
    ) {
        guard let suggestion = activeSuggestion, suggestion.id == suggestionID else { return }
        let action = selectedAction ?? suggestion.primaryOption.action
        guard
            action == suggestion.primaryOption.action
                || action == suggestion.secondaryOption?.action
        else { return }
        suggestionCandidates[suggestion.context.category] = nil
        activeSuggestion = nil

        switch action {
        case .beginFocus:
            if currentDeskRoom == nil {
                beginFocusSession()
            } else {
                activeSheet = .desk
            }
        case .resumeFocus:
            resumeTimer()
            showToast("继续这一段")
        case .inviteDeskMate:
            copyDeskCode()
        case .openVoiceRecorder:
            activeSheet = .voice
        case .beginRest:
            setPresence(.away)
        }
        refreshSuggestions()
    }

    func dismissSuggestion(_ suggestionID: PresenceSuggestion.ID) {
        guard let suggestion = activeSuggestion, suggestion.id == suggestionID else { return }
        suggestionCandidates[suggestion.context.category] = nil
        refreshSuggestions()
    }

    func showToast(_ message: String) {
        toastTask?.cancel()
        toastMessage = message
        toastTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2.2))
            guard !Task.isCancelled else { return }
            await MainActor.run { self?.toastMessage = nil }
        }
    }

    private func resumeTimer() {
        guard remainingSeconds > 0 else { return }
        timerRunning = true
        timerEndDate = Date().addingTimeInterval(TimeInterval(remainingSeconds))
        markOwnFocusStarted()
    }

    private func pauseTimer(shouldObserveLongPause: Bool) {
        let wasRunning = timerRunning
        updateRemainingTime()
        timerRunning = false
        timerEndDate = nil
        cancelSuggestions(in: .timerReset)
        if presence != .focus {
            cancelSuggestions(in: .focusPaused)
        } else if wasRunning, shouldObserveLongPause, remainingSeconds > 0 {
            schedulePausedSuggestion()
        }
        refreshSuggestions()
    }

    private func tick() {
        refreshSuggestions()
        guard timerRunning else { return }
        presenceSeconds += 1
        updateRemainingTime()
        if remainingSeconds == 0 {
            completeFocusSession()
        }
    }

    func completeFocusSession() {
        cancelSuggestions(in: .focusPaused, .timerReset)
        if activeFocusSession != nil {
            endFocusSession(reason: .timerCompleted)
            return
        }

        remainingSeconds = 0
        timerRunning = false
        timerEndDate = nil
        focusSessionStarted = false

        if let partner = currentDeskPartner {
            offerSuggestion(PresenceSuggestion(
                message: "这一段已经完成。要给\(partner.name)留一句话吗？",
                primaryOption: PresenceSuggestionOption(title: "打开留声机", action: .openVoiceRecorder),
                context: .focusCompleted(partnerID: partner.id)
            ))
            memory.makeDraft(
                title: "\(partner.name)这一段",
                mood: .warm,
                observation: "这一段活动已经结束，适合把刚刚发生的细节留下来。",
                keyMoment: "结束时的那一刻",
                delivery: .activityEnd,
                sourceEvent: .activityEnded,
                sourceActivityID: nil,
                creatorName: "我",
                participantNames: [partner.name],
                visibility: .shared,
                resourceReferences: lastActivityEndedEvent.map { [MemoryResourceReference(kind: "activityEndedEvent", value: $0.id.uuidString)] } ?? []
            )
        } else {
            offerSuggestion(PresenceSuggestion(
                message: "这一段已经完成，先休息一会儿。",
                primaryOption: PresenceSuggestionOption(title: "休息一下", action: .beginRest),
                context: .focusCompleted(partnerID: nil)
            ))
            memory.makeDraft(
                title: "这一段活动",
                mood: .quiet,
                observation: "这一段活动已经结束。",
                keyMoment: "结束时的那一刻",
                delivery: .activityEnd,
                sourceEvent: .activityEnded,
                sourceActivityID: nil,
                creatorName: "我",
                participantNames: [],
                visibility: .shared,
                resourceReferences: lastActivityEndedEvent.map { [MemoryResourceReference(kind: "activityEndedEvent", value: $0.id.uuidString)] } ?? []
            )
        }
    }

    func manuallyEndFocusSession() {
        endFocusSession(reason: .manuallyEnded)
    }

    private func endFocusSession(reason: ActivityEndReason) {
        guard let session = activeFocusSession else { return }
        activeFocusSession = nil
        remainingSeconds = 0
        timerRunning = false
        timerEndDate = nil
        focusSessionStarted = false
        cancelSuggestions(in: .focusPaused, .timerReset)
        lastActivityEndedEvent = focusSessionService.endSession(session, reason: reason)
        memory.deliverCards(for: .activityEnded, activityID: session.id)

        if let partner = currentDeskPartner {
            offerSuggestion(PresenceSuggestion(
                message: "这一段已经完成。要给\(partner.name)留一句话吗？",
                primaryOption: PresenceSuggestionOption(title: "打开留声机", action: .openVoiceRecorder),
                context: .focusCompleted(partnerID: partner.id)
            ))
        } else {
            offerSuggestion(PresenceSuggestion(
                message: "这一段已经完成，先休息一会儿。",
                primaryOption: PresenceSuggestionOption(title: "休息一下", action: .beginRest),
                context: .focusCompleted(partnerID: nil)
            ))
        }
    }

    private func scheduleWaitingSuggestion(for room: DeskRoom) {
        cancelSuggestions(in: .waitingForPartner)
        guard !focusSessionStarted else { return }
        scheduleSuggestion(
            PresenceSuggestion(
                message: "房间还在等人。你可以先开始一小段专注，或者把同桌码发给想邀请的人。",
                primaryOption: PresenceSuggestionOption(title: "开始 25 分钟", action: .beginFocus),
                secondaryOption: PresenceSuggestionOption(title: "邀请同桌", action: .inviteDeskMate),
                context: .waitingForPartner(roomID: room.id)
            ),
            after: 5 * 60
        )
    }

    private func schedulePartnerReadySuggestion(for room: DeskRoom?) {
        cancelSuggestions(in: .partnerReady)
        guard let room, let partner = room.partner else { return }
        guard !focusSessionStarted else { return }
        scheduleSuggestion(
            PresenceSuggestion(
                message: "\(partner.name)已经坐下。要一起开始一段专注吗？",
                primaryOption: PresenceSuggestionOption(title: "一起开始", action: .beginFocus),
                context: .partnerReady(roomID: room.id)
            ),
            after: 30
        )
    }

    private func schedulePausedSuggestion() {
        cancelSuggestions(in: .focusPaused)
        scheduleSuggestion(
            PresenceSuggestion(
                message: "已经暂停了一会儿。要从剩下的时间继续吗？",
                primaryOption: PresenceSuggestionOption(title: "继续", action: .resumeFocus),
                context: .focusPaused
            ),
            after: 5 * 60
        )
    }

    private func markOwnFocusStarted() {
        focusSessionStarted = true
        cancelSuggestions(
            in: .timerReset,
            .focusPaused,
            .waitingForPartner,
            .partnerReady
        )
        refreshSuggestions()
    }

    private func handleDailyTodoCompletionTransition(wasCompleted: Bool) {
        guard !wasCompleted, allTasksCompleted else {
            invalidateDailyTodoSuggestionIfNeeded()
            return
        }

        let day = Self.currentDayKey()
        guard !dailyTodoSuggestedDays.contains(day) else { return }
        dailyTodoSuggestedDays.insert(day)
        memory.makeDraft(
            title: "今日留声机",
            mood: .bright,
            observation: "今天的 Todo 已全部完成，可以把今天收尾成一张回忆卡。",
            keyMoment: "今天全部完成的那一刻",
            delivery: .archiveOnly,
            sourceEvent: .dailyTodoCompleted,
            creatorName: "我",
            participantNames: [],
            visibility: .shared
        )
        offerSuggestion(PresenceSuggestion(
            message: "今天放在桌上的事都完成了。要用留声机记下今天吗？",
            primaryOption: PresenceSuggestionOption(title: "打开留声机", action: .openVoiceRecorder),
            context: .dailyTodoCompleted(day: day)
        ))
    }

    private func invalidateDailyTodoSuggestionIfNeeded() {
        guard !allTasksCompleted else { return }
        cancelSuggestions(in: .dailyTodoCompleted)
        refreshSuggestions()
    }

    private func offerSuggestion(_ suggestion: PresenceSuggestion) {
        let category = suggestion.context.category
        scheduledSuggestions[category] = nil
        suggestionCandidates[category] = suggestion
        refreshSuggestions()
    }

    private func scheduleSuggestion(_ suggestion: PresenceSuggestion, after seconds: TimeInterval) {
        let category = suggestion.context.category
        suggestionCandidates[category] = nil
        scheduledSuggestions[category] = ScheduledPresenceSuggestion(
            dueAt: Date().addingTimeInterval(seconds),
            suggestion: suggestion
        )
        refreshSuggestions()
    }

    private func cancelSuggestions(in categories: PresenceSuggestionCategory...) {
        for category in categories {
            scheduledSuggestions[category] = nil
            suggestionCandidates[category] = nil
        }
    }

    private func refreshSuggestions(now: Date = Date()) {
        let dueSuggestions = scheduledSuggestions.filter { $0.value.dueAt <= now }
        for (category, scheduled) in dueSuggestions {
            scheduledSuggestions[category] = nil
            suggestionCandidates[category] = scheduled.suggestion
        }
        suggestionCandidates = suggestionCandidates.filter { isSuggestionValid($0.value) }
        activeSuggestion = suggestionCandidates.values.max {
            $0.context.category.priority < $1.context.category.priority
        }
    }

    private func isSuggestionValid(_ suggestion: PresenceSuggestion) -> Bool {
        switch suggestion.context {
        case .waitingForPartner(let roomID):
            guard
                let room = currentDeskRoom,
                room.id == roomID,
                room.partner == nil,
                !focusSessionStarted,
                room.expiresAt > Date()
            else { return false }
            return true

        case .timerReset:
            return !timerRunning && remainingSeconds == 25 * 60

        case .focusCompleted(let partnerID):
            guard !timerRunning, remainingSeconds == 0 else { return false }
            return currentDeskPartner?.id == partnerID

        case .partnerReady(let roomID):
            return currentDeskRoom?.id == roomID
                && currentDeskPartner != nil
                && !focusSessionStarted
                && !timerRunning

        case .focusPaused:
            return focusSessionStarted
                && presence == .focus
                && !timerRunning
                && remainingSeconds > 0

        case .dailyTodoCompleted(let day):
            return dailyTodoSuggestedDays.contains(day)
                && day == Self.currentDayKey()
                && allTasksCompleted
        }
    }

    private static func currentDayKey(now: Date = Date(), calendar: Calendar = .current) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: now)
        return String(
            format: "%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
    }

    private func updateRemainingTime() {
        guard let timerEndDate else { return }
        remainingSeconds = max(0, Int(ceil(timerEndDate.timeIntervalSinceNow)))
    }

    private func normalizedTaskTitle(_ rawTitle: String) -> String {
        let trimmed = rawTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        return String(trimmed.prefix(Self.maximumTaskTitleLength))
    }

    private func containsTask(named title: String, excluding taskID: FocusTask.ID? = nil) -> Bool {
        tasks.contains {
            $0.id != taskID && $0.title.localizedCaseInsensitiveCompare(title) == .orderedSame
        }
    }

    private static func formatDuration(_ seconds: Int) -> String {
        String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}
