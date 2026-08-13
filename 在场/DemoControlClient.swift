import Foundation

struct DemoControlCommand: Decodable {
    enum Kind: String, Decodable {
        case advanceTime
        case receiveNudge
    }

    let type: Kind
    let seconds: Int?
}

struct DemoControlClient {
    private static let environmentKey = "ZAICHANG_DEMO_CONTROL_URL"

    private let nextCommandURL: URL

    init?(environment: [String: String] = ProcessInfo.processInfo.environment) {
        guard
            let rawURL = environment[Self.environmentKey],
            let baseURL = URL(string: rawURL),
            ["http", "https"].contains(baseURL.scheme?.lowercased() ?? ""),
            baseURL.host != nil
        else { return nil }

        nextCommandURL = baseURL
            .appendingPathComponent("commands")
            .appendingPathComponent("next")
    }

    func run(handle: @escaping @MainActor (DemoControlCommand) -> Void) async {
        while !Task.isCancelled {
            do {
                var request = URLRequest(url: nextCommandURL)
                request.cachePolicy = .reloadIgnoringLocalCacheData
                request.timeoutInterval = 2
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let response = response as? HTTPURLResponse else {
                    try await Task.sleep(for: .seconds(1))
                    continue
                }
                if response.statusCode == 200 {
                    handle(try JSONDecoder().decode(DemoControlCommand.self, from: data))
                } else if response.statusCode != 204 {
                    try await Task.sleep(for: .seconds(1))
                }
            } catch is CancellationError {
                return
            } catch {
                try? await Task.sleep(for: .seconds(1))
            }

            try? await Task.sleep(for: .milliseconds(250))
        }
    }
}
