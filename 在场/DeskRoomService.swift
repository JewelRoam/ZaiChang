import Foundation

enum DeskRoomServiceError: Error, Equatable {
    case emptyInviteCode
}

protocol DeskRoomServicing {
    var demoInviteCode: String { get }
    func createRoom() async throws -> DeskRoom
    func joinRoom(inviteCode: String) async throws -> DeskRoom
}

struct MockDeskRoomService: DeskRoomServicing {
    let demoInviteCode = "DEMO-ROOM"
    private let roomID = UUID(uuidString: "DE5C0000-0000-0000-0000-000000000001")!

    func createRoom() async throws -> DeskRoom {
        room(code: "DEMO-ROOM", partner: nil)
    }

    func joinRoom(inviteCode: String) async throws -> DeskRoom {
        let code = inviteCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !code.isEmpty else { throw DeskRoomServiceError.emptyInviteCode }
        return room(code: code, partner: .ahe)
    }

    private func room(code: String, partner: DeskPartner?) -> DeskRoom {
        let now = Date()
        return DeskRoom(
            id: roomID,
            code: code,
            createdAt: now,
            expiresAt: now.addingTimeInterval(30 * 60),
            partner: partner
        )
    }
}
