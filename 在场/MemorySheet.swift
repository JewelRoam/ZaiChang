import SwiftUI
#if !os(macOS)
import UIKit
#endif

struct MemorySheet: View {
    @ObservedObject var memory: MemoryController
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var observation = ""
    @State private var keyMoment = ""
    @State private var mood: MemoryMood = .warm
    @State private var delivery: MemoryDeliveryPlan = .activityEnd
    @State private var expandedHistoryID: MemoryDraft.ID?

    var body: some View {
        SheetContainer(eyebrow: "留声机", title: "把这一刻留下来", dismiss: dismiss) {
            VStack(alignment: .leading, spacing: 0) {
                currentFlow
                if !memory.history.isEmpty {
                    historySection
                        .padding(.top, 20)
                }
            }
        }
    }

    // MARK: - 上半部分：当前记录流程

    @ViewBuilder
    private var currentFlow: some View {
        if let draft = memory.drafts.first {
            switch draft.reviewState {
            case .ready:
                cardView(draft)
            case .archived:
                archivedDraftView(draft)
            default:
                draftFlow(draft)
            }
        } else {
            inputForm
        }
    }

    private var inputForm: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("记录文字、心情和事件记忆点").font(.system(size: 12, weight: .semibold))
            TextField("标题，例如：雨夜书桌", text: $title).textFieldStyle(.roundedBorder)
            Picker("心情", selection: $mood) { ForEach(MemoryMood.allCases) { Text($0.title).tag($0) } }.pickerStyle(.segmented)
            TextField("见闻：这一段发生了什么？", text: $observation, axis: .vertical).lineLimit(3...5).textFieldStyle(.roundedBorder)
            TextField("关键时刻：最想记住哪一秒？", text: $keyMoment, axis: .vertical).lineLimit(2...4).textFieldStyle(.roundedBorder)
            Button { memory.makeDraft(title: title.isEmpty ? "未命名的一刻" : title, mood: mood, observation: observation, keyMoment: keyMoment, delivery: delivery) } label: {
                Label("整理成记忆草稿", systemImage: "wand.and.stars").adaptiveFullWidthHitTarget(minHeight: 42)
            }.buttonStyle(.borderedProminent).disabled(observation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    private func draftFlow(_ draft: MemoryDraft) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("步骤 1 / 3 · AI 整理草稿", systemImage: "doc.text.magnifyingglass").font(.system(size: 12, weight: .semibold))
            TextField("标题", text: Binding(get: { draft.title }, set: { var x = draft; x.title = $0; memory.updateDraft(x) })).textFieldStyle(.roundedBorder)
            Text("心情：\(draft.mood.title)").foregroundStyle(Palette.muted)
            Text(draft.observation).font(.system(size: 12))
            Text("关键时刻：\(draft.keyMoment)").font(.system(size: 11)).foregroundStyle(Palette.muted)
            Button { memory.generateImage(for: draft) } label: { Label("确认草稿并生成图像", systemImage: "photo.artframe").adaptiveFullWidthHitTarget(minHeight: 42) }.buttonStyle(.borderedProminent).disabled(draft.observation.isEmpty || memory.generationState == .generating)
            if memory.generationState == .generating { ProgressView("正在生成统一风格图像…") }
            if case let .failed(message) = draft.reviewState { Text(message).foregroundStyle(.red); Button("重试") { memory.generateImage(for: draft) } }
            Button("重新记录") { memory.discardDraft(draft) }.buttonStyle(.bordered)
        }
    }

    private func cardView(_ card: MemoryDraft) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("步骤 2 / 3 · 记忆卡片已准备", systemImage: "checkmark.seal").font(.system(size: 12, weight: .semibold))
            memoryImage(card.imageData, maxHeight: 220)
            Text(card.title).font(.system(size: 18, weight: .semibold))
            Text(card.observation).font(.system(size: 12))
            Text("步骤 3 / 3 · 选择送达策略").font(.system(size: 12, weight: .semibold))
            ForEach(MemoryDeliveryPlan.allCases) { plan in Button { var x = card; x.deliveryPlan = plan; x.deliveryState = plan == .archiveOnly ? .notScheduled : .scheduled; memory.updateDraft(x) } label: { Label(plan.title, systemImage: card.deliveryPlan == plan ? "checkmark.circle.fill" : "circle").adaptiveFullWidthHitTarget(minHeight: 34) }.buttonStyle(ZaichangPlainButtonStyle()) }
            Button {
                memory.confirm(card)
            } label: {
                Label(
                    card.deliveryPlan == .archiveOnly ? "确认并保存到回忆" : "确认并进入待送达",
                    systemImage: "paperplane"
                )
                .adaptiveFullWidthHitTarget(minHeight: 42)
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private func archivedDraftView(_ draft: MemoryDraft) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("步骤 3 / 3 · 已归档草稿", systemImage: "archivebox").font(.system(size: 12, weight: .semibold))
            Text(draft.title).font(.system(size: 18, weight: .semibold))
            Text("这条草稿已保存为归档状态。")
                .font(.system(size: 12))
                .foregroundStyle(Palette.muted)
            Button("恢复草稿") {
                memory.restore(draft)
            }
            .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - 下半部分：历史记录

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Divider().overlay(Palette.line)

            HStack {
                Label("历史记忆", systemImage: "clock.arrow.circlepath")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Text("\(memory.history.count) 张")
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.muted)
            }
            .padding(.top, 14)

            ScrollView {
                VStack(spacing: 8) {
                    ForEach(memory.history) { card in
                        historyRow(card)
                    }
                }
            }
            .scrollBounceBehavior(.basedOnSize)
            .frame(maxHeight: 220)
        }
    }

    private func historyRow(_ card: MemoryDraft) -> some View {
        let isExpanded = expandedHistoryID == card.id

        return VStack(alignment: .leading, spacing: 8) {
            Button {
                expandedHistoryID = isExpanded ? nil : card.id
            } label: {
                HStack(spacing: 10) {
                    historyThumbnail(card.imageData)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(card.title)
                            .font(.system(size: 12, weight: .semibold))
                            .lineLimit(1)
                        HStack(spacing: 6) {
                            Text(card.mood.title)
                            Text("·")
                            Text(Self.dateText(card.createdAt))
                        }
                        .font(.system(size: 10))
                        .foregroundStyle(Palette.muted)
                    }

                    Spacer(minLength: 4)

                    stateBadge(card)

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Palette.muted)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(ZaichangPlainButtonStyle())
            .accessibilityLabel("\(card.title)，\(Self.stateText(card.reviewState))")

            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    memoryImage(card.imageData, maxHeight: 160)
                    if !card.observation.isEmpty {
                        Text(card.observation).font(.system(size: 11))
                    }
                    if !card.keyMoment.isEmpty {
                        Text("关键时刻：\(card.keyMoment)")
                            .font(.system(size: 10))
                            .foregroundStyle(Palette.muted)
                    }
                    Text("送达：\(card.deliveryPlan.title) · \(Self.deliveryText(card.deliveryState))")
                        .font(.system(size: 10))
                        .foregroundStyle(Palette.muted)

                    HStack(spacing: 8) {
                        if card.reviewState == .confirmed {
                            Button("归档") { memory.archive(card) }
                                .buttonStyle(.bordered)
                        } else if card.reviewState == .archived {
                            Button("恢复") { memory.restore(card) }
                                .buttonStyle(.bordered)
                        }
                        Button("删除", role: .destructive) {
                            if expandedHistoryID == card.id { expandedHistoryID = nil }
                            memory.deleteCard(card)
                        }
                        .buttonStyle(.bordered)
                    }
                    .font(.system(size: 11))
                }
                .padding(.leading, 2)
            }
        }
        .padding(10)
        .background(Palette.surface3)
        .overlay(RoundedRectangle(cornerRadius: 7).stroke(Palette.line))
        .clipShape(RoundedRectangle(cornerRadius: 7))
    }

    private func stateBadge(_ card: MemoryDraft) -> some View {
        Text(Self.stateText(card.reviewState))
            .font(.system(size: 9, weight: .semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(card.reviewState == .archived ? Palette.muted.opacity(0.22) : Palette.moss.opacity(0.24))
            .foregroundStyle(card.reviewState == .archived ? Palette.muted : Palette.moss)
            .clipShape(Capsule())
    }

    // MARK: - 共用小组件

    @ViewBuilder
    private func historyThumbnail(_ data: Data?) -> some View {
        if let data, let image = Self.platformImage(data) {
            image
                .resizable()
                .scaledToFill()
                .frame(width: 36, height: 36)
                .clipShape(RoundedRectangle(cornerRadius: 5))
        } else {
            RoundedRectangle(cornerRadius: 5)
                .fill(Palette.surface)
                .frame(width: 36, height: 36)
                .overlay(
                    Image(systemName: "photo")
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.muted)
                )
        }
    }

    @ViewBuilder
    private func memoryImage(_ data: Data?, maxHeight: CGFloat) -> some View {
        if let data, let image = Self.platformImage(data) {
            image
                .resizable()
                .scaledToFit()
                .frame(maxHeight: maxHeight)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }

    private static func platformImage(_ data: Data) -> Image? {
        #if os(macOS)
        guard let native = NSImage(data: data) else { return nil }
        return Image(nsImage: native)
        #else
        guard let native = UIImage(data: data) else { return nil }
        return Image(uiImage: native)
        #endif
    }

    private static func stateText(_ state: MemoryReviewState) -> String {
        switch state {
        case .draft: "草稿"
        case .ready: "待确认"
        case .confirmed: "已确认"
        case .archived: "已归档"
        case .failed: "失败"
        }
    }

    private static func deliveryText(_ state: MemoryDeliveryState) -> String {
        switch state {
        case .notScheduled: "未安排"
        case .scheduled: "待送达"
        case .delivered: "已送达"
        case .opened: "已打开"
        case .failed(let reason): "失败（\(reason)）"
        }
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_Hans_CN")
        formatter.dateFormat = "M月d日 HH:mm"
        return formatter
    }()

    private static func dateText(_ date: Date) -> String {
        dateFormatter.string(from: date)
    }
}
