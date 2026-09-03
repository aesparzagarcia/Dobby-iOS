//
//  LoadingRemoteImage.swift
//  Dobby
//

import ImageIO
import SwiftUI
import UIKit

/// Remote image with memory + disk cache (parity with Android Coil).
struct LoadingRemoteImage<Placeholder: View>: View {
    let urlString: String?
    var resolveAgainstApiBase: Bool = false
    var contentMode: ContentMode = .fill
    var placeholderBackground: Color = Color(.systemGray5)
    @ViewBuilder var placeholder: () -> Placeholder

    @State private var image: UIImage?
    @State private var failed = false

    init(
        urlString: String?,
        resolveAgainstApiBase: Bool = false,
        contentMode: ContentMode = .fill,
        placeholderBackground: Color = Color(.systemGray5),
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.urlString = urlString
        self.resolveAgainstApiBase = resolveAgainstApiBase
        self.contentMode = contentMode
        self.placeholderBackground = placeholderBackground
        self.placeholder = placeholder
    }

    private var resolvedURL: URL? {
        let raw = urlString?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let raw, !raw.isEmpty else { return nil }
        let resolved = resolveAgainstApiBase ? (AppConfiguration.fullImageURL(raw) ?? raw) : raw
        return URL(string: resolved)
    }

    var body: some View {
        ZStack {
            placeholderBackground
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else if resolvedURL == nil || failed {
                placeholder()
            } else {
                ProgressView()
                    .tint(DobbyBrandColor.primary)
            }
        }
        .task(id: resolvedURL) {
            await load()
        }
    }

    @MainActor
    private func load() async {
        guard let url = resolvedURL else {
            image = nil
            failed = false
            return
        }
        let maxPx = RemoteImageStore.maxPixelSize
        if let cached = RemoteImageStore.shared.cached(url: url, maxPixelSize: maxPx) {
            image = cached
            failed = false
            return
        }
        failed = false
        let loaded = await RemoteImageStore.shared.image(url: url, maxPixelSize: maxPx)
        guard !Task.isCancelled else { return }
        image = loaded
        failed = loaded == nil
    }
}

extension LoadingRemoteImage where Placeholder == EmptyView {
    init(
        urlString: String?,
        resolveAgainstApiBase: Bool = false,
        contentMode: ContentMode = .fill,
        placeholderBackground: Color = Color(.systemGray5)
    ) {
        self.init(
            urlString: urlString,
            resolveAgainstApiBase: resolveAgainstApiBase,
            contentMode: contentMode,
            placeholderBackground: placeholderBackground,
            placeholder: { EmptyView() }
        )
    }
}

/// Shared memory + HTTP disk cache so grids do not re-download on every redraw.
final class RemoteImageStore: @unchecked Sendable {
    static let shared = RemoteImageStore()

    static var maxPixelSize: CGFloat {
        let bounds = UIScreen.main.bounds
        return max(bounds.width, bounds.height) * UIScreen.main.scale
    }

    private let memory = NSCache<NSString, UIImage>()
    private let lock = NSLock()
    private var inflight: [String: Task<UIImage?, Never>] = [:]
    private let session: URLSession

    private init() {
        memory.countLimit = 200
        memory.totalCostLimit = 64 * 1024 * 1024
        let cache = URLCache(
            memoryCapacity: 32 * 1024 * 1024,
            diskCapacity: 256 * 1024 * 1024,
            diskPath: "DobbyRemoteImages"
        )
        let config = URLSessionConfiguration.default
        config.urlCache = cache
        config.requestCachePolicy = .returnCacheDataElseLoad
        config.timeoutIntervalForRequest = 30
        config.httpMaximumConnectionsPerHost = 6
        session = URLSession(configuration: config)
    }

    func cached(url: URL, maxPixelSize: CGFloat) -> UIImage? {
        memory.object(forKey: cacheKey(url: url, maxPixelSize: maxPixelSize))
    }

    func image(url: URL, maxPixelSize: CGFloat) async -> UIImage? {
        if let hit = cached(url: url, maxPixelSize: maxPixelSize) {
            return hit
        }
        let key = cacheKey(url: url, maxPixelSize: maxPixelSize) as String

        lock.lock()
        let task: Task<UIImage?, Never>
        if let existing = inflight[key] {
            task = existing
        } else {
            let created = Task {
                await self.fetchAndDecode(url: url, maxPixelSize: maxPixelSize)
            }
            inflight[key] = created
            task = created
        }
        lock.unlock()

        let result = await task.value
        lock.lock()
        inflight[key] = nil
        lock.unlock()
        return result
    }

    private func fetchAndDecode(url: URL, maxPixelSize: CGFloat) async -> UIImage? {
        var request = URLRequest(url: url)
        request.cachePolicy = .returnCacheDataElseLoad
        do {
            let (data, response) = try await session.data(for: request)
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                return nil
            }
            guard !data.isEmpty, let image = Self.downsample(data: data, maxPixelSize: maxPixelSize) else {
                return nil
            }
            let cost = Int(image.size.width * image.size.height * image.scale * image.scale * 4)
            memory.setObject(image, forKey: cacheKey(url: url, maxPixelSize: maxPixelSize), cost: cost)
            return image
        } catch {
            return nil
        }
    }

    private func cacheKey(url: URL, maxPixelSize: CGFloat) -> NSString {
        "\(url.absoluteString)#\(Int(maxPixelSize))" as NSString
    }

    private static func downsample(data: Data, maxPixelSize: CGFloat) -> UIImage? {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions) else {
            return UIImage(data: data)
        }
        let maxDim = max(maxPixelSize, 1)
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxDim,
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return UIImage(data: data)
        }
        return UIImage(cgImage: cgImage)
    }
}
