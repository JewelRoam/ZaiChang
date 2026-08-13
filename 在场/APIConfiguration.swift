import Foundation

/// The local configuration contract shared by AI features. The development
/// installer places secrets in this app's Application Support container; they
/// are intentionally never bundled with the app.
struct APIConfiguration: Equatable {
    enum Provider: String {
        case openAI = "openai"
        case dashScope = "dashscope"
    }

    struct TextModel: Equatable {
        var provider: Provider = .openAI
        var apiKey = ""
        var baseURL = ""
        var model = ""

        var isConfigured: Bool {
            provider == .openAI
                && !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && !baseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && !model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    struct ImageModel: Equatable {
        var provider: Provider = .dashScope
        var apiKey = ""
        var baseURL = ""
        var endpoint = "https://dashscope.aliyuncs.com/api/v1/services/aigc/multimodal-generation/generation"
        var model = "qwen-image-edit-plus"
        var size = "1024x1024"
        var sceneModel = "qwen-image-3.0"
        var sceneSize = "1664x928"

        var isConfigured: Bool {
            guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
            switch provider {
            case .openAI: return !baseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            case .dashScope: return !endpoint.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
        }
    }

    struct Matting: Equatable {
        enum Provider: String {
            case disabled
            case removeBG = "removebg"
        }

        var provider: Provider = .disabled
        var apiKey = ""
        var endpoint = "https://api.remove.bg/v1.0/removebg"

        var isConfigured: Bool {
            provider == .removeBG
                && !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && !endpoint.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    var text = TextModel()
    var image = ImageModel()
    var matting = Matting()

    var isTextModelConfigured: Bool { text.isConfigured }
    var isImageModelConfigured: Bool { image.isConfigured }

    static var defaultURL: URL {
        if let override = ProcessInfo.processInfo.environment["ZAICHANG_API_CONFIG"], !override.isEmpty {
            return URL(fileURLWithPath: override)
        }
        return AppStoragePaths.apiConfigurationURL()
    }

    static func load() -> APIConfiguration {
        let urls = [defaultURL, Bundle.main.url(forResource: "api.example", withExtension: "yaml")].compactMap { $0 }
        for url in urls {
            guard let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
            return from(yaml: text)
        }
        return APIConfiguration()
    }

    static func from(yaml: String) -> APIConfiguration {
        var configuration = APIConfiguration()
        let values = YAMLScalarParser.parse(yaml)

        configuration.text.provider = provider(values["text.provider"]) ?? configuration.text.provider
        configuration.text.apiKey = values["text.api_key"] ?? configuration.text.apiKey
        configuration.text.baseURL = values["text.base_url"] ?? configuration.text.baseURL
        configuration.text.model = values["text.model"] ?? configuration.text.model

        configuration.image.provider = provider(values["image.provider"]) ?? configuration.image.provider
        configuration.image.apiKey = values["image.api_key"] ?? configuration.image.apiKey
        configuration.image.baseURL = values["image.base_url"] ?? configuration.image.baseURL
        configuration.image.endpoint = values["image.endpoint"] ?? configuration.image.endpoint
        configuration.image.model = values["image.model"] ?? configuration.image.model
        configuration.image.size = values["image.size"] ?? configuration.image.size
        configuration.image.sceneModel = values["image.scene_model"] ?? configuration.image.sceneModel
        configuration.image.sceneSize = values["image.scene_size"] ?? configuration.image.sceneSize

        if let value = values["matting.provider"], let provider = Matting.Provider(rawValue: value.lowercased()) {
            configuration.matting.provider = provider
        }
        configuration.matting.apiKey = values["matting.api_key"] ?? configuration.matting.apiKey
        configuration.matting.endpoint = values["matting.endpoint"] ?? configuration.matting.endpoint

        return configuration
    }

    private static func provider(_ value: String?) -> Provider? {
        value.flatMap { Provider(rawValue: $0.lowercased()) }
    }
}

/// Small YAML scalar reader for this deliberately scalar-only configuration.
private enum YAMLScalarParser {
    static func parse(_ source: String) -> [String: String] {
        var result: [String: String] = [:]
        var sections: [Int: String] = [:]
        for rawLine in source.components(separatedBy: .newlines) {
            let line = rawLine.replacingOccurrences(of: "\t", with: "  ")
            let withoutComment = stripComment(line)
            guard !withoutComment.trimmingCharacters(in: .whitespaces).isEmpty else { continue }
            let indent = withoutComment.prefix { $0 == " " }.count
            let content = withoutComment.trimmingCharacters(in: .whitespaces)
            guard let separator = content.firstIndex(of: ":") else { continue }
            let key = String(content[..<separator]).trimmingCharacters(in: .whitespaces)
            let value = String(content[content.index(after: separator)...]).trimmingCharacters(in: .whitespaces)
            if value.isEmpty {
                sections[indent] = key
                sections = sections.filter { $0.key <= indent }
                continue
            }
            let parent = sections.keys.filter { $0 < indent }.max().flatMap { sections[$0] }
            let normalizedKey = parent.map { "\($0).\(key)" } ?? key
            result[key] = unquote(value)
            result[normalizedKey] = unquote(value)
        }
        return result
    }

    private static func stripComment(_ line: String) -> String {
        var quoted = false
        for (index, character) in line.enumerated() {
            if character == "\"" || character == "'" { quoted.toggle() }
            if character == "#" && !quoted { return String(line.prefix(index)) }
        }
        return line
    }

    private static func unquote(_ value: String) -> String {
        guard value.count >= 2 else { return value }
        if (value.first == "\"" && value.last == "\"") || (value.first == "'" && value.last == "'") {
            return String(value.dropFirst().dropLast())
        }
        return value
    }
}
