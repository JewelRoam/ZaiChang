import Foundation
import SwiftUI

// MARK: - Context Panel

struct ContextPanelView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var recorder: VoiceRecorderController
    @State private var isAddingTask = false
    @State private var newTaskTitle = ""
    @State private var editingTaskID: FocusTask.ID?
    @State private var editingTaskTitle = ""
    @FocusState private var taskEditorFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 0) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("此刻").eyebrowStyle()
                            Text("今晚的节奏").font(.system(size: 18, weight: .semibold))
                        }
                        Spacer()
                    }

                    VStack(spacing: 12) {
                        HStack(alignment: .firstTextBaseline) {
                            Text("已在场").font(.system(size: 11)).foregroundStyle(Palette.muted)
                            Spacer()
                            Text(model.presenceText).font(.system(size: 20, weight: .semibold)).monospacedDigit()
                        }
                        HStack(spacing: 4) {
                            ForEach(0..<8, id: \.self) { index in
                                Capsule().fill(index < 5 ? Palette.amber : Color.white.opacity(0.14)).frame(height: 6)
                            }
                        }
                        HStack {
                            Label("连续 6 晚", systemImage: "flame.fill")
                                .foregroundStyle(Color(red: 0.85, green: 0.70, blue: 0.48))
                            Spacer()
                            Text("目标 60 分钟")
                        }
                        .font(.system(size: 10))
                        .foregroundStyle(Palette.muted)
                    }
                    .padding(.vertical, 20)
                    .panelDivider()

                    VStack(spacing: 4) {
                        HStack {
                            Text("放在桌上的事").font(.system(size: 14, weight: .semibold))
                            Spacer()
                            Text("\(model.completedTaskCount) / \(model.tasks.count)")
                                .font(.system(size: 11)).foregroundStyle(Palette.muted)
                            Button(action: beginAddingTask) {
                                Image(systemName: "plus")
                                    .font(.system(size: 11, weight: .semibold))
                                    .adaptiveHitTarget(minWidth: 28, minHeight: 28)
                            }
                            .buttonStyle(ZaichangPlainButtonStyle())
                            .disabled(!model.canAddTask)
                            .opacity(model.canAddTask ? 1 : 0.4)
                            .help(model.canAddTask ? "新增桌上事项" : "桌上最多放 \(AppModel.maximumTaskCount) 件事")
                            .accessibilityLabel("新增桌上事项")
                        }
                        .padding(.bottom, 7)

                        if isAddingTask {
                            taskEditor(
                                title: $newTaskTitle,
                                placeholder: "要做的一件事",
                                confirm: commitNewTask,
                                cancel: cancelAddingTask
                            )
                        }

                        if model.tasks.isEmpty && !isAddingTask {
                            Text("桌上还没有要做的事")
                                .font(.system(size: 10))
                                .foregroundStyle(Palette.muted)
                                .frame(maxWidth: .infinity, minHeight: 40, alignment: .leading)
                        }

                        ForEach(model.orderedTasks) { task in
                            if editingTaskID == task.id {
                                taskEditor(
                                    title: $editingTaskTitle,
                                    placeholder: "事项名称",
                                    confirm: commitTaskRename,
                                    cancel: cancelTaskRename
                                )
                            } else {
                                taskRow(task)
                            }
                        }
                    }
                    .padding(.vertical, 18)
                    .panelDivider()

                    HStack(spacing: 10) {
                        Image(systemName: "record.circle")
                            .font(.system(size: 20))
                            .foregroundStyle(Palette.amber)
                            .frame(width: 38, height: 38)
                            .background(Color(red: 0.42, green: 0.29, blue: 0.20))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        VStack(alignment: .leading, spacing: 3) {
                            if let note = recorder.savedNotes.first {
                                Text("最近保存的留声").font(.system(size: 9)).foregroundStyle(Palette.muted)
                                Text(note.delivery.title).font(.system(size: 11, weight: .semibold))
                                Text("你 · \(durationText(note.duration))").font(.system(size: 9)).foregroundStyle(Palette.muted)
                            } else {
                                Text("一段留声等待播放").font(.system(size: 9)).foregroundStyle(Palette.muted)
                                Text("“等你忙完再听”").font(.system(size: 11, weight: .semibold))
                                Text("阿禾 · 00:18").font(.system(size: 9)).foregroundStyle(Palette.muted)
                            }
                        }
                        Spacer()
                        Button {
                            if let note = recorder.savedNotes.first {
                                recorder.togglePlayback(note)
                            } else {
                                model.showToast("这段示例留声还没有音频文件")
                            }
                        } label: {
                            Image(systemName: recorder.savedNotes.first.map(recorder.isPlaying) == true ? "pause.fill" : "play.fill")
                                .foregroundStyle(Color(red: 0.18, green: 0.14, blue: 0.10))
                                .adaptiveHitTarget(minWidth: 32, minHeight: 32)
                                .background(Palette.amber)
                                .clipShape(Circle())
                        }
                        .buttonStyle(ZaichangPlainButtonStyle())
                        .accessibilityLabel(recorder.savedNotes.first.map(recorder.isPlaying) == true ? "暂停最近留声" : "播放最近留声")
                        .help(recorder.savedNotes.first.map(recorder.isPlaying) == true ? "暂停最近留声" : "播放最近留声")
                    }
                    .padding(11)
                    .background(Color(red: 0.15, green: 0.14, blue: 0.12))
                    .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color(red: 0.27, green: 0.23, blue: 0.19)))
                    .clipShape(RoundedRectangle(cornerRadius: 7))
                    .padding(.top, 18)
                }
                .padding(.horizontal, 20)
                .padding(.top, 22)
            }

            HStack(spacing: 8) {
                PanelButton(title: model.deskActionTitle, symbol: "person.2", isProminent: false) { model.activeSheet = .desk }
                PanelButton(title: "留一句话", symbol: "mic", isProminent: true) { model.activeSheet = .voice }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
        }
        .background(Color(red: 0.115, green: 0.122, blue: 0.137))
    }

    private func durationText(_ duration: TimeInterval) -> String {
        let seconds = Int(duration.rounded(.down))
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }

    private func taskRow(_ task: FocusTask) -> some View {
        HStack(spacing: 8) {
            Button { model.toggleTask(task.id) } label: {
                Image(systemName: task.isCompleted ? "checkmark.square.fill" : "square")
                    .foregroundStyle(task.isCompleted ? Palette.moss : Palette.muted)
                    .adaptiveHitTarget(minWidth: 24, minHeight: 30)
            }
            .buttonStyle(ZaichangPlainButtonStyle())
            .accessibilityLabel(task.isCompleted ? "标记为未完成" : "标记为已完成")

            Text(task.title)
                .font(.system(size: 13))
                .foregroundStyle(task.isCompleted ? Palette.muted : Palette.ink)
                .strikethrough(task.isCompleted)
                .lineLimit(2)
            Spacer(minLength: 4)

            Menu {
                Button("改名", systemImage: "pencil") {
                    beginTaskRename(task)
                }
                Button("删除", systemImage: "trash", role: .destructive) {
                    model.deleteTask(task.id)
                }
            } label: {
                Image(systemName: "ellipsis")
                    .adaptiveHitTarget(minWidth: 28, minHeight: 30)
            }
            .menuIndicator(.hidden)
            .buttonStyle(ZaichangPlainButtonStyle())
            .accessibilityLabel("\(task.title)的更多操作")
        }
        .frame(minHeight: InteractionMetrics.minimumHitDimension)
    }

    private func taskEditor(
        title: Binding<String>,
        placeholder: String,
        confirm: @escaping () -> Void,
        cancel: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 6) {
            TextField(placeholder, text: title)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .focused($taskEditorFocused)
                .submitLabel(.done)
                .onSubmit(confirm)
                .onChange(of: title.wrappedValue) { _, newValue in
                    if newValue.count > AppModel.maximumTaskTitleLength {
                        title.wrappedValue = String(newValue.prefix(AppModel.maximumTaskTitleLength))
                    }
                }

            Button(action: confirm) {
                Image(systemName: "checkmark")
                    .adaptiveHitTarget(minWidth: 26, minHeight: 28)
            }
            .buttonStyle(ZaichangPlainButtonStyle())
            .disabled(title.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .accessibilityLabel("确认")

            Button(action: cancel) {
                Image(systemName: "xmark")
                    .adaptiveHitTarget(minWidth: 26, minHeight: 28)
            }
            .buttonStyle(ZaichangPlainButtonStyle())
            .accessibilityLabel("取消")
        }
        .padding(.horizontal, 8)
        .frame(minHeight: max(38, InteractionMetrics.minimumHitDimension))
        .background(Palette.surface3)
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.white.opacity(0.14)))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func beginAddingTask() {
        guard model.canAddTask else { return }
        editingTaskID = nil
        editingTaskTitle = ""
        newTaskTitle = ""
        isAddingTask = true
        focusTaskEditor()
    }

    private func commitNewTask() {
        guard model.addTask(title: newTaskTitle) else { return }
        newTaskTitle = ""
        isAddingTask = false
        taskEditorFocused = false
    }

    private func cancelAddingTask() {
        newTaskTitle = ""
        isAddingTask = false
        taskEditorFocused = false
    }

    private func beginTaskRename(_ task: FocusTask) {
        isAddingTask = false
        newTaskTitle = ""
        editingTaskID = task.id
        editingTaskTitle = task.title
        focusTaskEditor()
    }

    private func commitTaskRename() {
        guard let editingTaskID else { return }
        guard model.renameTask(editingTaskID, title: editingTaskTitle) else { return }
        cancelTaskRename()
    }

    private func cancelTaskRename() {
        editingTaskID = nil
        editingTaskTitle = ""
        taskEditorFocused = false
    }

    private func focusTaskEditor() {
        Task { @MainActor in
            await Task.yield()
            taskEditorFocused = true
        }
    }
}

struct ContextSheet: View {
    @ObservedObject var model: AppModel
    @ObservedObject var recorder: VoiceRecorderController
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .topTrailing) {
            ContextPanelView(model: model, recorder: recorder)
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .adaptiveHitTarget(minWidth: 32, minHeight: 32)
            }
            .buttonStyle(ZaichangPlainButtonStyle())
            .padding(.top, 12)
            .padding(.trailing, 14)
            .accessibilityLabel("关闭")
        }
        .adaptiveSheetFrame()
        .background(Palette.surface2)
        .foregroundStyle(Palette.ink)
#if os(macOS)
        .frame(minHeight: 520)
#else
        .frame(maxHeight: .infinity)
#endif
        .adaptiveSheetPresentation()
    }
}
