import Foundation

struct FocusSessionConfiguration: Equatable {
    static let allowedDurations = [15, 25, 45, 60]

    let durationMinutes: Int
    let taskIDs: [FocusTask.ID]
    let customTaskTitle: String?
    let sceneID: RoomScene.ID?

    init(durationMinutes: Int, taskID: FocusTask.ID) {
        self.init(durationMinutes: durationMinutes, taskIDs: [taskID])
    }

    init(
        durationMinutes: Int,
        taskIDs: [FocusTask.ID] = [],
        customTaskTitle: String? = nil,
        sceneID: RoomScene.ID? = nil
    ) {
        self.durationMinutes = durationMinutes
        self.taskIDs = taskIDs
        self.customTaskTitle = customTaskTitle
        self.sceneID = sceneID
    }

    var taskID: FocusTask.ID? { taskIDs.first }
}

struct FocusSession: Equatable, Identifiable {
    let id: UUID
    let roomID: DeskRoom.ID
    let taskIDs: [FocusTask.ID]
    let customTaskTitle: String?
    let durationSeconds: Int
    let sceneID: RoomScene.ID
    let startedAt: Date

    init(
        id: UUID,
        roomID: DeskRoom.ID,
        taskIDs: [FocusTask.ID],
        customTaskTitle: String?,
        durationSeconds: Int,
        sceneID: RoomScene.ID,
        startedAt: Date
    ) {
        self.id = id
        self.roomID = roomID
        self.taskIDs = taskIDs
        self.customTaskTitle = customTaskTitle
        self.durationSeconds = durationSeconds
        self.sceneID = sceneID
        self.startedAt = startedAt
    }

    var taskID: FocusTask.ID? { taskIDs.first }
}

enum ActivityEndReason: Equatable {
    case timerCompleted
    case manuallyEnded
}

struct ActivityEndedEvent: Equatable, Identifiable {
    let id: UUID
    let sessionID: FocusSession.ID
    let reason: ActivityEndReason
    let endedAt: Date
}

enum FocusSessionServiceError: Error, Equatable {
    case invalidDuration
    case noScenes
}

protocol FocusSessionServicing {
    func startSession(
        roomID: DeskRoom.ID,
        configuration: FocusSessionConfiguration,
        candidateScenes: [RoomScene]
    ) throws -> FocusSession

    func endSession(_ session: FocusSession, reason: ActivityEndReason) -> ActivityEndedEvent
}

struct MockFocusSessionService: FocusSessionServicing {
    private let sceneSelector: ([RoomScene]) -> RoomScene?

    init(sceneSelector: @escaping ([RoomScene]) -> RoomScene? = { $0.randomElement() }) {
        self.sceneSelector = sceneSelector
    }

    func startSession(
        roomID: DeskRoom.ID,
        configuration: FocusSessionConfiguration,
        candidateScenes: [RoomScene]
    ) throws -> FocusSession {
        guard FocusSessionConfiguration.allowedDurations.contains(configuration.durationMinutes) else {
            throw FocusSessionServiceError.invalidDuration
        }
        guard !candidateScenes.isEmpty else {
            throw FocusSessionServiceError.noScenes
        }
        guard let scene = configuration.sceneID.flatMap({ selectedID in
            candidateScenes.first { $0.id == selectedID }
        }) ?? sceneSelector(candidateScenes) else {
            throw FocusSessionServiceError.noScenes
        }

        return FocusSession(
            id: UUID(),
            roomID: roomID,
            taskIDs: configuration.taskIDs,
            customTaskTitle: configuration.customTaskTitle,
            durationSeconds: configuration.durationMinutes * 60,
            sceneID: scene.id,
            startedAt: Date()
        )
    }

    func endSession(_ session: FocusSession, reason: ActivityEndReason) -> ActivityEndedEvent {
        ActivityEndedEvent(
            id: UUID(),
            sessionID: session.id,
            reason: reason,
            endedAt: Date()
        )
    }
}
