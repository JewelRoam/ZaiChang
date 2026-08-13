import SwiftUI

struct MemoryArchiveView: View {
    @ObservedObject var memory: MemoryController
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let cards = memory.cards.filter { $0.reviewState == .confirmed || $0.reviewState == .archived }
        SheetContainer(eyebrow: "记忆", title: "共同回忆", dismiss: dismiss, maxWidth: 760) {
            if cards.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("还没有收藏").font(.system(size: 18, weight: .semibold))
                    Text("确认后的记忆会像一本册子一样放在这里。")
                        .font(.system(size: 12)).foregroundStyle(Palette.muted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 20)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        header(cards: cards)
                        LazyVGrid(
                            columns: [GridItem(.adaptive(minimum: 170, maximum: 220), spacing: 18, alignment: .top)],
                            spacing: 18
                        ) {
                            ForEach(cards) { card in archiveCard(card) }
                        }
                    }
                    .padding(.bottom, 12)
                }
                .frame(height: 560)
            }
        }
    }

    private func header(cards: [MemoryDraft]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text("收藏册")
                    .font(.system(size: 18, weight: .semibold))
                Text("\(cards.count) 条回忆")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Palette.muted)
            }
            Text("像翻开一本会发光的相册，每一页都只保留最重要的那一刻。")
                .font(.system(size: 12))
                .foregroundStyle(Palette.muted)
        }
        .padding(.horizontal, 2)
    }

    private func archiveCard(_ card: MemoryDraft) -> some View {
        let template = MemoryCardTemplatePool().template(id: card.imageTemplateID)
        return VStack(alignment: .leading, spacing: 10) {
            ZStack(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Palette.surface2)
                if let template, let art = MemoryCardArtwork.image(for: template.assetName) {
                    art
                        .resizable()
                        .scaledToFit()
                        .padding(10)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                LinearGradient(
                    colors: [Color.clear, Color.black.opacity(0.32)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))

                VStack(alignment: .leading, spacing: 4) {
                    Text(status(card))
                        .font(.system(size: 10, weight: .semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Palette.amber.opacity(0.92), in: Capsule())
                    Text(card.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .shadow(radius: 4, y: 1)
                }
                .padding(10)
            }
            .aspectRatio(2 / 3, contentMode: .fit)

            VStack(alignment: .leading, spacing: 7) {
                Text(card.observation)
                    .font(.system(size: 11))
                    .lineLimit(2)
                Text("关键时刻：\(card.keyMoment)")
                    .font(.system(size: 10))
                    .foregroundStyle(Palette.muted)
                if let voice = card.voiceAttachment {
                    Text("语音附件：\(voice.duration.formatted(.number.precision(.fractionLength(0)))) 秒")
                        .font(.system(size: 10))
                        .foregroundStyle(Palette.muted)
                }
                if let confirmedAt = card.confirmedAt {
                    Text(confirmedAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.system(size: 10))
                        .foregroundStyle(Palette.muted)
                }
            }
            .padding(.horizontal, 2)

            HStack(spacing: 8) {
                if card.reviewState == .archived {
                    Button("恢复") { memory.restore(card) }.buttonStyle(.bordered)
                } else {
                    Button("归档") { memory.archive(card) }.buttonStyle(.bordered)
                }
                if card.deliveryState == .delivered {
                    Button("已打开") { memory.markOpened(card) }.buttonStyle(.bordered)
                }
            }
            .font(.system(size: 10))
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Palette.surface2)
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(Palette.line.opacity(0.8), lineWidth: 1))
        )
    }

    private func status(_ card: MemoryDraft) -> String {
        switch card.reviewState { case .archived: "已归档"; default: deliveryLabel(card.deliveryState) }
    }

    private func deliveryLabel(_ state: MemoryDeliveryState) -> String {
        switch state {
        case .notScheduled: "仅保存"
        case .scheduled: "待送达"
        case .delivered: "已送达"
        case .opened: "已打开"
        case .failed: "送达失败"
        }
    }
}
