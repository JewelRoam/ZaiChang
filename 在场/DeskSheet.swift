import Foundation
import SwiftUI

// MARK: - Desk

struct DeskSheet: View {
    @ObservedObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var code = ""
    @State private var leaveConfirmationPresented = false
    @State private var selectedDurationMinutes = 25
    @State private var selectedTaskIDs = Set<FocusTask.ID>()
    @State private var customTaskTitle = ""
    @State private var selectedSceneID: RoomScene.ID?
    @FocusState private var codeFieldFocused: Bool

    var body: some View {
        SheetContainer(eyebrow: "同桌", title: sheetTitle, dismiss: dismiss) {
            switch model.deskSession {
            case .disconnected:
                disconnectedContent
            case let .joining(code):
                joiningContent(code: code)
            case let .connected(room):
                connectedContent(room: room)
            }
        }
        .confirmationDialog(
            "离开当前同桌房间？",
            isPresented: $leaveConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button("离开房间", role: .destructive) {
                model.leaveDesk()
            }
            Button("继续同桌", role: .cancel) {}
        } message: {
            Text("对方会看到你已经离开，保存过的留声与共同记忆会继续保留。")
        }
    }

    private var sheetTitle: String {
        switch model.deskSession {
        case .disconnected: "找一张桌子坐下"
        case .joining: "正在寻找这张桌子"
        case let .connected(room): room.partner == nil ? "房间已经准备好" : "今晚有人和你同桌"
        }
    }

    private var disconnectedContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("输入同桌码").font(.system(size: 12, weight: .semibold))
                Text("加入对方已经点亮的房间。")
                    .font(.system(size: 10))
                    .foregroundStyle(Palette.muted)
            }

            HStack(spacing: 8) {
                TextField("输入任意邀请码", text: $code)
                    .textFieldStyle(.plain)
                    .font(.system(size: 18, weight: .semibold, design: .monospaced))
                    .focused($codeFieldFocused)
                    .onSubmit(joinDesk)
                    .onChange(of: code) { _, newValue in
                        let formatted = model.formatDeskCode(newValue)
                        if formatted != newValue { code = formatted }
                        model.deskErrorMessage = nil
                    }

                Button {
                    if let pastedCode = ClipboardClient.readText() {
                        code = model.formatDeskCode(pastedCode)
                    }
                } label: {
                    Image(systemName: "doc.on.clipboard")
                        .adaptiveHitTarget(minWidth: 34, minHeight: 34)
                }
                .buttonStyle(ZaichangPlainButtonStyle())
                .help("粘贴同桌码")
                .accessibilityLabel("粘贴同桌码")
            }
            .padding(.horizontal, 12)
            .frame(height: 48)
            .background(Palette.surface3)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(codeFieldStroke))
            .clipShape(RoundedRectangle(cornerRadius: 6))

            if let message = model.deskErrorMessage {
                Label(message, systemImage: "exclamationmark.circle")
                    .font(.system(size: 10))
                    .foregroundStyle(Color(red: 0.90, green: 0.52, blue: 0.46))
            }

            PanelButton(title: "加入房间", symbol: "arrow.right", isProminent: true, action: joinDesk)
                .disabled(!model.isValidDeskCode(code))
                .opacity(model.isValidDeskCode(code) ? 1 : 0.45)

            HStack(spacing: 12) {
                Rectangle().fill(Palette.line).frame(height: 1)
                Text("或").font(.system(size: 9)).foregroundStyle(Palette.muted)
                Rectangle().fill(Palette.line).frame(height: 1)
            }
            .padding(.vertical, 2)

            PanelButton(title: "创建一个房间", symbol: "plus", isProminent: false) {
                model.createDeskRoom()
            }
        }
        .padding(.vertical, 8)
        .onAppear { codeFieldFocused = true }
    }

    private func joiningContent(code: String) -> some View {
        VStack(spacing: 14) {
            ProgressView().controlSize(.small).tint(Palette.amber)
            Text(code)
                .font(.system(size: 20, weight: .semibold, design: .monospaced))
            Text("正在确认房间状态")
                .font(.system(size: 10))
                .foregroundStyle(Palette.muted)
            Button {
                model.cancelDeskJoin()
            } label: {
                Text("取消")
                    .adaptiveHitTarget()
            }
                .buttonStyle(.bordered)
                .font(.system(size: 11, weight: .medium))
        }
        .frame(maxWidth: .infinity, minHeight: 220)
    }

    private func connectedContent(room: DeskRoom) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 22) {
                PersonBadge(
                    character: "知",
                    name: "你",
                    detail: "\(model.presence.title) · \(model.timerText)",
                    color: Color(red: 0.34, green: 0.28, blue: 0.24)
                )

                HStack(spacing: 6) {
                    Rectangle().fill(Color.white.opacity(0.15)).frame(height: 1)
                    Image(systemName: "lamp.desk").foregroundStyle(Palette.amber)
                    Rectangle().fill(Color.white.opacity(0.15)).frame(height: 1)
                }
                .frame(width: 96)

                if let partner = room.partner {
                    PersonBadge(
                        character: partner.character,
                        name: partner.name,
                        detail: "专注中 · \(partner.focusText)",
                        color: Color(red: 0.24, green: 0.31, blue: 0.34)
                    )
                } else {
                    WaitingPartnerBadge()
                }
            }
            .padding(.vertical, 20)

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(room.partner == nil ? "把同桌码发给想邀请的人" : "今晚的同桌码")
                        .font(.system(size: 10))
                        .foregroundStyle(Palette.muted)
                    Text(room.code)
                        .font(.system(size: 20, weight: .semibold, design: .monospaced))
                    Text("约 \(remainingMinutes(for: room)) 分钟后失效")
                        .font(.system(size: 9))
                        .foregroundStyle(Palette.muted)
                }
                Spacer()
                PanelButton(title: "复制", symbol: "doc.on.doc", isProminent: false) {
                    model.copyDeskCode()
                }
                .frame(width: 90)
            }
            .padding(.vertical, 18)
            .overlay(alignment: .top) { Divider().overlay(Palette.line) }
            .overlay(alignment: .bottom) { Divider().overlay(Palette.line) }

            if model.activeFocusSession == nil {
                focusConfiguration
            }

            DeskPetSection(controller: model.deskPet, partner: room.partner)

            Button {
                leaveConfirmationPresented = true
            } label: {
                Label("离开房间", systemImage: "rectangle.portrait.and.arrow.right")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color(red: 0.90, green: 0.52, blue: 0.46))
                    .adaptiveFullWidthHitTarget(minHeight: 38)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color(red: 0.62, green: 0.31, blue: 0.29).opacity(0.7))
                    )
            }
            .buttonStyle(ZaichangPlainButtonStyle())
            .padding(.top, 18)
        }
    }

    private var focusConfiguration: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("准备这一段专注")
                .font(.system(size: 12, weight: .semibold))
            Text("时长、Todo 和场景都可以按你的当下状态选择。")
                .font(.system(size: 10))
                .foregroundStyle(Palette.muted)

            Picker("专注时长", selection: $selectedDurationMinutes) {
                ForEach(FocusSessionConfiguration.allowedDurations, id: \.self) { minutes in
                    Text("\(minutes) 分钟").tag(minutes)
                }
            }
            .pickerStyle(.segmented)

            VStack(alignment: .leading, spacing: 6) {
                Text("今日 Todo（可多选）").font(.system(size: 10, weight: .semibold)).foregroundStyle(Palette.muted)
                ForEach(model.incompleteTasks) { task in
                    Button {
                        if selectedTaskIDs.contains(task.id) { selectedTaskIDs.remove(task.id) } else { selectedTaskIDs.insert(task.id) }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: selectedTaskIDs.contains(task.id) ? "checkmark.square.fill" : "square")
                            Text(task.title).lineLimit(1)
                            Spacer()
                        }
                        .font(.system(size: 11))
                        .foregroundStyle(selectedTaskIDs.contains(task.id) ? Palette.amberSoft : Palette.ink)
                        .padding(.vertical, 5)
                    }
                    .buttonStyle(ZaichangPlainButtonStyle())
                    .accessibilityLabel("选择 Todo：\(task.title)")
                }
                TextField("Others（可选）", text: $customTaskTitle)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 11))
                    .accessibilityLabel("Others")
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("选择场景").font(.system(size: 10, weight: .semibold)).foregroundStyle(Palette.muted)
                Picker("场景", selection: $selectedSceneID) {
                    Text("请选择场景").tag(RoomScene.ID?.none)
                    ForEach(RoomSceneCatalog.builtIn) { scene in Text(scene.name).tag(Optional(scene.id)) }
                }
                .pickerStyle(.menu)
            }

            PanelButton(title: "开始这一段专注", symbol: "play.fill", isProminent: true) { startFocus() }
                .disabled(selectedSceneID == nil)
                .opacity(selectedSceneID == nil ? 0.45 : 1)
        }
        .padding(.vertical, 18)
        .overlay(alignment: .bottom) { Divider().overlay(Palette.line) }
    }

    private var codeFieldStroke: Color {
        model.deskErrorMessage == nil ? Color.white.opacity(0.16) : Color(red: 0.72, green: 0.36, blue: 0.31)
    }

    private func joinDesk() {
        guard model.isValidDeskCode(code) else { return }
        model.joinDesk(code: code)
    }

    private func startFocus() {
        guard let selectedSceneID,
              model.beginDeskFocus(durationMinutes: selectedDurationMinutes, taskIDs: selectedTaskIDs, customTaskTitle: customTaskTitle, sceneID: selectedSceneID) else { return }
        dismiss()
    }

    private func remainingMinutes(for room: DeskRoom) -> Int {
        max(1, Int(ceil(room.expiresAt.timeIntervalSinceNow / 60)))
    }
}

private struct WaitingPartnerBadge: View {
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "person.badge.plus")
                .font(.system(size: 17))
                .foregroundStyle(Palette.muted)
                .frame(width: 54, height: 54)
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 7))
            Text("等待加入").font(.system(size: 12, weight: .semibold))
            Text("房间已点亮").font(.system(size: 10)).foregroundStyle(Palette.muted)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct PersonBadge: View {
    let character: String
    let name: String
    let detail: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Text(character)
                .font(.system(size: 16, weight: .bold))
                .frame(width: 54, height: 54)
                .background(color)
                .clipShape(RoundedRectangle(cornerRadius: 7))
            Text(name).font(.system(size: 12, weight: .semibold))
            Text(detail).font(.system(size: 10)).foregroundStyle(Palette.muted)
        }
        .frame(maxWidth: .infinity)
    }
}
