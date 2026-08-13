import Foundation
import SwiftUI

struct MemoryDraftingResult: Equatable {
    let title: String
    let mood: MemoryMood
    let observation: String
    let keyMoment: String
    let keywords: [String]
    let timeHint: String
    let summary: String

    init(
        title: String,
        mood: MemoryMood,
        observation: String,
        keyMoment: String,
        keywords: [String]? = nil,
        date: Date = Date()
    ) {
        self.title = Self.normalized(title)
        self.mood = mood
        self.observation = Self.normalized(observation)
        self.keyMoment = Self.normalized(keyMoment)
        self.keywords = keywords ?? Self.extractKeywords(
            from: [self.title, self.observation, self.keyMoment].joined(separator: " ")
        )
        self.timeHint = Self.timeHint(for: date)
        self.summary = [self.title, mood.title, self.keyMoment]
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }

    var searchCorpus: String {
        [title, observation, keyMoment, keywords.joined(separator: " ")]
            .joined(separator: " ")
            .lowercased()
    }

    private static func normalized(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func extractKeywords(from corpus: String) -> [String] {
        let separators = CharacterSet(charactersIn: " ,，。！？!?；;:、\n\t/|")
        let extracted = corpus
            .components(separatedBy: separators)
            .map { normalized($0) }
            .filter { $0.count >= 2 }
        return Array(NSOrderedSet(array: extracted)).compactMap { $0 as? String }
    }

    private static func timeHint(for date: Date) -> String {
        let hour = Calendar.current.component(.hour, from: date)
        switch hour {
        case 5..<11: return "清晨"
        case 11..<14: return "午后"
        case 14..<18: return "傍晚"
        case 18..<23: return "夜色"
        default: return "深夜"
        }
    }
}

struct MemoryCardPromptResult: Equatable {
    let templateID: String
    let templateName: String
    let prompt: String
    let preview: String
}

struct MemoryMetadataSuggestion: Equatable {
    let tags: [String]
    let bgm: String
    let deliveryNote: String
}

struct MemoryCardSeed: Identifiable, Equatable {
    let id: UUID
    let title: String
    let mood: MemoryMood
    let observation: String
    let keyMoment: String
    let deliveryPlan: MemoryDeliveryPlan
    let deliveryState: MemoryDeliveryState
    let reviewState: MemoryReviewState
    let templateID: String
    let createdAt: Date
}

struct MemoryCardTemplate: Identifiable, Equatable {
    let id: String
    let name: String
    let subtitle: String
    let tagline: String
    let assetName: String
    let keywords: [String]
    let moodHints: [MemoryMood]
    let symbol: String
    let accentHex: String
    let surfaceHex: String
    let promptSeed: String
    let tags: [String]
    let bgm: String
    let deliveryHint: String
    let fallbackWeight: Int
    let frameStyle: MemoryCardFrameStyle
    let textureStyle: MemoryCardTextureStyle
    let highlightStyle: MemoryCardHighlightStyle

    var accentColor: Color { Color(hex: accentHex) }
    var surfaceColor: Color { Color(hex: surfaceHex) }
}

enum MemoryCardFrameStyle: String {
    case rounded
    case cassette
    case portrait
    case postcard
}

enum MemoryCardTextureStyle: String {
    case grain
    case scanlines
    case paper
    case tiled
}

enum MemoryCardHighlightStyle: String {
    case glow
    case stripe
    case corner
    case radial
}

struct MemoryCardTemplatePool {
    let templates: [MemoryCardTemplate] = [
        MemoryCardTemplate(
            id: "rainy-desk",
            name: "雨夜书桌",
            subtitle: "台灯下的一小段停顿",
            tagline: "把夜里的细节轻轻放好。",
            assetName: "rainy_desk",
            keywords: ["雨夜", "书桌", "台灯", "咖啡", "窗边", "夜读", "安静"],
            moodHints: [.quiet, .tender],
            symbol: "cloud.rain",
            accentHex: "#6E93AD",
            surfaceHex: "#243843",
            promptSeed: "warm pixel memory card with window rain, desk lamp glow, paper edges and quiet room",
            tags: ["雨夜", "专注", "留白"],
            bgm: "雨声循环",
            deliveryHint: "适合在活动结束后送达",
            fallbackWeight: 3,
            frameStyle: .cassette,
            textureStyle: .scanlines,
            highlightStyle: .glow
        ),
        MemoryCardTemplate(
            id: "soft-walk",
            name: "晚风散步",
            subtitle: "走路时也能被记住的句子",
            tagline: "风很轻，话也很轻。",
            assetName: "late_return",
            keywords: ["散步", "晚风", "路灯", "街道", "步行", "散心"],
            moodHints: [.warm, .bright, .tender],
            symbol: "figure.walk",
            accentHex: "#7D9C74",
            surfaceHex: "#273429",
            promptSeed: "warm pixel memory card with evening street lights, slow walk and soft breeze",
            tags: ["晚风", "路灯", "散步"],
            bgm: "微风钢琴",
            deliveryHint: "适合对方下次结束专注后再看",
            fallbackWeight: 2,
            frameStyle: .postcard,
            textureStyle: .paper,
            highlightStyle: .stripe
        ),
        MemoryCardTemplate(
            id: "desk-focus",
            name: "灯下专注",
            subtitle: "桌面还亮着，事情已经整理好",
            tagline: "把认真过的一段，变成可回看的卡片。",
            assetName: "focus_hour",
            keywords: ["专注", "完成", "代码", "工作", "写作", "整理", "任务"],
            moodHints: [.quiet, .bright],
            symbol: "lamp.desk",
            accentHex: "#D6A055",
            surfaceHex: "#3A2D1C",
            promptSeed: "warm pixel memory card with desk lamp, notebook, keyboard and a finished task feeling",
            tags: ["专注", "完成", "收尾"],
            bgm: "木质节拍",
            deliveryHint: "适合立即保存或活动结束后送达",
            fallbackWeight: 4,
            frameStyle: .rounded,
            textureStyle: .grain,
            highlightStyle: .corner
        ),
        MemoryCardTemplate(
            id: "train-echo",
            name: "列车回声",
            subtitle: "路过的站台和没有说完的话",
            tagline: "让经过的那一站留下一点回声。",
            assetName: "subway_window",
            keywords: ["车站", "列车", "返程", "黄昏", "告别", "路上", "旅行"],
            moodHints: [.tender, .warm],
            symbol: "tram.fill",
            accentHex: "#7691B8",
            surfaceHex: "#263241",
            promptSeed: "warm pixel memory card with train carriage window, station lights and a sense of return",
            tags: ["返程", "站台", "回声"],
            bgm: "车窗低鸣",
            deliveryHint: "适合在指定时间再打开",
            fallbackWeight: 2,
            frameStyle: .portrait,
            textureStyle: .tiled,
            highlightStyle: .radial
        ),
        MemoryCardTemplate(
            id: "shared-memory",
            name: "共同回忆",
            subtitle: "只保存，不发送",
            tagline: "这张卡片先放进共同的抽屉。",
            assetName: "weekend_sorting",
            keywords: ["回忆", "保存", "归档", "共同", "收藏", "抽屉"],
            moodHints: [.warm, .quiet, .tender],
            symbol: "archivebox",
            accentHex: "#B68763",
            surfaceHex: "#34271F",
            promptSeed: "warm pixel memory card with archive drawer, shared keepsake and soft paper texture",
            tags: ["归档", "收藏", "共同回忆"],
            bgm: "抽屉木纹",
            deliveryHint: "仅保存到共同回忆，不自动送达",
            fallbackWeight: 5,
            frameStyle: .rounded,
            textureStyle: .paper,
            highlightStyle: .glow
        ),
        MemoryCardTemplate(
            id: "little-break",
            name: "午后小停顿",
            subtitle: "桌面上的水杯和暂时放下的心事",
            tagline: "给今天留一点呼吸。",
            assetName: "after_work",
            keywords: ["午后", "休息", "停顿", "茶", "水杯", "窗光", "放松"],
            moodHints: [.bright, .warm, .tender],
            symbol: "cup.and.saucer",
            accentHex: "#D18D7F",
            surfaceHex: "#38231E",
            promptSeed: "warm pixel memory card with tea cup, window light and a calm afternoon pause",
            tags: ["午后", "休息", "呼吸"],
            bgm: "轻薄木琴",
            deliveryHint: "适合在今天结束前送达",
            fallbackWeight: 3,
            frameStyle: .cassette,
            textureStyle: .grain,
            highlightStyle: .stripe
        )
    ]

    func template(id: String?) -> MemoryCardTemplate? {
        guard let id else { return nil }
        return templates.first { $0.id == id }
    }

    func selectTemplate(for draft: MemoryDraftingResult, preferredTemplateID: String? = nil) -> MemoryCardTemplate {
        if let preferred = template(id: preferredTemplateID) {
            return preferred
        }

        let scored = templates.map { template in
            (template, score(template: template, draft: draft))
        }
        let bestScore = scored.map(\.1).max() ?? 0
        let candidates = scored
            .filter { $0.1 == bestScore }
            .map(\.0)
        if bestScore > 0 {
            return candidates.randomElement() ?? templates.first!
        }

        let totalWeight = templates.reduce(0) { $0 + max($1.fallbackWeight, 1) }
        let roll = Int.random(in: 0..<max(totalWeight, 1))
        var running = 0
        for template in templates {
            running += max(template.fallbackWeight, 1)
            if roll < running { return template }
        }
        return templates.first!
    }

    func previewTemplates(for draft: MemoryDraftingResult, limit: Int = 3) -> [MemoryCardTemplate] {
        templates
            .map { ($0, score(template: $0, draft: draft)) }
            .sorted {
                if $0.1 == $1.1 {
                    return $0.0.fallbackWeight > $1.0.fallbackWeight
                }
                return $0.1 > $1.1
            }
            .prefix(limit)
            .map(\.0)
    }

    func compilePrompt(for draft: MemoryDraftingResult, template: MemoryCardTemplate) -> MemoryCardPromptResult {
        let prompt = """
        \(template.promptSeed)
        Scene focus: \(draft.summary)
        Mood: \(draft.mood.title)
        Observation: \(draft.observation)
        Key moment: \(draft.keyMoment)
        """
        let preview = "\(template.name) · \(draft.timeHint) · \(template.tagline)"
        return MemoryCardPromptResult(
            templateID: template.id,
            templateName: template.name,
            prompt: prompt,
            preview: preview
        )
    }

    func suggestMetadata(for draft: MemoryDraftingResult, template: MemoryCardTemplate) -> MemoryMetadataSuggestion {
        let tags = Array(NSOrderedSet(array: template.tags + draft.keywords.prefix(2).map { String($0) }))
            .compactMap { $0 as? String }
        let bgm = "\(template.bgm) · \(draft.timeHint)"
        let deliveryNote = "\(template.deliveryHint)，当前情绪偏向：\(draft.mood.title)"
        return MemoryMetadataSuggestion(tags: tags, bgm: bgm, deliveryNote: deliveryNote)
    }

    func fallbackTemplates(limit: Int = 4) -> [MemoryCardTemplate] {
        templates.prefix(limit).map { $0 }
    }

    func seedCards() -> [MemoryCardSeed] {
        [
            MemoryCardSeed(
                id: UUID(uuidString: "E5C00000-0000-0000-0000-000000000001")!,
                title: "雨夜书桌",
                mood: .quiet,
                observation: "台灯亮着的时候，窗外的雨刚好把房间衬得很静。",
                keyMoment: "指尖停在键盘上的那一秒",
                deliveryPlan: .activityEnd,
                deliveryState: .delivered,
                reviewState: .confirmed,
                templateID: "rainy-desk",
                createdAt: Date().addingTimeInterval(-3 * 60 * 60)
            ),
            MemoryCardSeed(
                id: UUID(uuidString: "E5C00000-0000-0000-0000-000000000002")!,
                title: "晚风散步",
                mood: .tender,
                observation: "路灯一盏一盏往后退，话没说完也没关系。",
                keyMoment: "转过街角时那阵风",
                deliveryPlan: .nextFocusEnd,
                deliveryState: .scheduled,
                reviewState: .confirmed,
                templateID: "soft-walk",
                createdAt: Date().addingTimeInterval(-7 * 60 * 60)
            ),
            MemoryCardSeed(
                id: UUID(uuidString: "E5C00000-0000-0000-0000-000000000003")!,
                title: "午后小停顿",
                mood: .bright,
                observation: "刚把桌面收干净，水杯放下后，心也跟着轻了一点。",
                keyMoment: "阳光落在杯壁上的斑点",
                deliveryPlan: .scheduled,
                deliveryState: .opened,
                reviewState: .archived,
                templateID: "little-break",
                createdAt: Date().addingTimeInterval(-11 * 60 * 60)
            ),
            MemoryCardSeed(
                id: UUID(uuidString: "E5C00000-0000-0000-0000-000000000004")!,
                title: "列车回声",
                mood: .warm,
                observation: "车窗里倒映着站台的灯，像把一句话留在路上。",
                keyMoment: "车门合上的那一下",
                deliveryPlan: .scheduled,
                deliveryState: .scheduled,
                reviewState: .confirmed,
                templateID: "train-echo",
                createdAt: Date().addingTimeInterval(-15 * 60 * 60)
            ),
            MemoryCardSeed(
                id: UUID(uuidString: "E5C00000-0000-0000-0000-000000000005")!,
                title: "共同回忆",
                mood: .warm,
                observation: "这段先放进共同抽屉，等以后翻出来再看。",
                keyMoment: "确认保存后的那一刻",
                deliveryPlan: .archiveOnly,
                deliveryState: .notScheduled,
                reviewState: .confirmed,
                templateID: "shared-memory",
                createdAt: Date().addingTimeInterval(-19 * 60 * 60)
            ),
            MemoryCardSeed(
                id: UUID(uuidString: "E5C00000-0000-0000-0000-000000000006")!,
                title: "灯下专注",
                mood: .bright,
                observation: "桌上的事情都整理完了，最后只剩下把心情收好。",
                keyMoment: "屏幕熄下去前的最后一眼",
                deliveryPlan: .activityEnd,
                deliveryState: .opened,
                reviewState: .archived,
                templateID: "desk-focus",
                createdAt: Date().addingTimeInterval(-24 * 60 * 60)
            )
        ]
    }

    private func score(template: MemoryCardTemplate, draft: MemoryDraftingResult) -> Int {
        let corpus = draft.searchCorpus
        var total = 0
        if corpus.contains(template.name.lowercased()) { total += 6 }
        if corpus.contains(template.subtitle.lowercased()) { total += 2 }
        if template.moodHints.contains(draft.mood) { total += 3 }
        for keyword in template.keywords where corpus.contains(keyword.lowercased()) {
            total += 4
        }
        for keyword in draft.keywords where template.keywords.contains(where: { $0.contains(keyword) || keyword.contains($0) }) {
            total += 2
        }
        return total
    }
}

extension MemoryDraftingResult {
    init(draft: MemoryDraft) {
        self.init(
            title: draft.title,
            mood: draft.mood,
            observation: draft.observation,
            keyMoment: draft.keyMoment,
            date: draft.createdAt
        )
    }
}

extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")
        let value = UInt64(cleaned, radix: 16) ?? 0
        let red, green, blue: Double
        switch cleaned.count {
        case 6:
            red = Double((value & 0xFF0000) >> 16) / 255
            green = Double((value & 0x00FF00) >> 8) / 255
            blue = Double(value & 0x0000FF) / 255
        default:
            red = 0.5
            green = 0.5
            blue = 0.5
        }
        self.init(red: red, green: green, blue: blue)
    }
}
