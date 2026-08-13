import SwiftUI
#if os(macOS)
import AppKit
#elseif os(iOS) || os(visionOS)
import UIKit
#endif

#if os(macOS)
typealias SceneNativeImage = NSImage
#elseif os(iOS) || os(visionOS)
typealias SceneNativeImage = UIImage
#endif

enum SceneImageFitMode {
    /// 铺满窗口，裁掉溢出部分（缩略图、生成结果预览）
    case fill
    /// 完整展示图片，比例不匹配时用同图放大模糊铺底（主场景舞台）
    case fitBlurred
}

struct BundledSceneImage: View {
    let relativePath: String
    var fitMode: SceneImageFitMode = .fill

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
#if os(macOS) || os(iOS) || os(visionOS)
        if let image = SceneImageCache.shared.image(for: relativePath) {
            switch fitMode {
            case .fill:
                sceneImage(image)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
            case .fitBlurred:
                GeometryReader { geo in
                    ZStack {
                        backdrop(image)
                        sceneImage(image)
                            .resizable()
                            .scaledToFit()
                            .frame(width: geo.size.width, height: geo.size.height)
                    }
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
                }
                .allowsHitTesting(false)
            }
        } else {
            fallback
        }
#else
        fallback
#endif
    }

#if os(macOS) || os(iOS) || os(visionOS)
    @ViewBuilder
    private func backdrop(_ image: SceneNativeImage) -> some View {
        if reduceTransparency {
            Color(red: 0.07, green: 0.08, blue: 0.11)
        } else {
            GeometryReader { geo in
                sceneImage(image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
                    .blur(radius: 36, opaque: true)
                    .overlay(Color.black.opacity(0.34))
            }
            .accessibilityHidden(true)
        }
    }

    private func sceneImage(_ image: SceneNativeImage) -> Image {
#if os(macOS)
        Image(nsImage: image)
#else
        Image(uiImage: image)
#endif
    }
#endif

    private var fallback: some View {
        ZStack {
            Color(red: 0.10, green: 0.13, blue: 0.18)
            Image(systemName: "photo").foregroundStyle(Palette.muted)
        }
    }
}

#if os(macOS) || os(iOS) || os(visionOS)
/// 场景图解码缓存。SwiftUI 的 `body` 在窗口缩放时会高频重算，
/// 且模糊铺底会复用同一张图，直接从磁盘解码会明显掉帧。
@MainActor
final class SceneImageCache {
    static let shared = SceneImageCache()

    private var entries: [String: (stamp: Date?, image: SceneNativeImage)] = [:]

    func image(for relativePath: String) -> SceneNativeImage? {
        guard let url = SceneImageLocator.url(for: relativePath) else { return nil }
        let stamp = try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate

        if let entry = entries[relativePath], entry.stamp == stamp {
            return entry.image
        }

        guard let image = Self.decode(url) else { return nil }
        entries[relativePath] = (stamp, image)
        return image
    }

    private static func decode(_ url: URL) -> SceneNativeImage? {
#if os(macOS)
        NSImage(contentsOf: url)
#else
        (try? Data(contentsOf: url)).flatMap(UIImage.init(data:))
#endif
    }
}
#endif

enum SceneImageLocator {
    /// 查找顺序：用户生成图 → Bundle 根目录 → Bundle 子目录 → Bundle 兜底
    static func url(for relativePath: String) -> URL? {
        if let userURL = SceneAssetStore.shared.url(for: relativePath),
           FileManager.default.fileExists(atPath: userURL.path) {
            return userURL
        }

        let resourceURL = Bundle.main.resourceURL
        let bundledPath = resourceURL?.appendingPathComponent(relativePath)

        if let bundledPath, FileManager.default.fileExists(atPath: bundledPath.path) {
            return bundledPath
        }

        let path = relativePath as NSString
        let directory = path.deletingLastPathComponent
        let fileName = (path.lastPathComponent as NSString).deletingPathExtension
        let fileExtension = (path.lastPathComponent as NSString).pathExtension
        if let nestedURL = Bundle.main.url(
            forResource: fileName,
            withExtension: fileExtension,
            subdirectory: directory
        ) {
            return nestedURL
        }
        return Bundle.main.url(forResource: fileName, withExtension: fileExtension)
    }
}

final class SceneAssetStore {
    static let shared = SceneAssetStore()

    private let fileManager = FileManager.default

    private var rootURL: URL {
        AppStoragePaths.scenesDirectory(fileManager: fileManager)
    }

    func url(for relativePath: String) -> URL? {
        guard relativePath.hasPrefix("Scenes/"), !relativePath.contains("..") else { return nil }
        return rootURL.appendingPathComponent(String(relativePath.dropFirst("Scenes/".count)))
    }

    func store(_ data: Data, relativePath: String) throws {
        guard let url = url(for: relativePath) else { throw CocoaError(.fileNoSuchFile) }
        try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
    }
}
