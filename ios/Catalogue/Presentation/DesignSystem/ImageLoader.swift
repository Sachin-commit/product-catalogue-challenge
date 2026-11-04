import UIKit

/// How views get images. Injected (not a singleton) so screens can be tested or
/// previewed without the network, and the caching strategy can change in one place.
@MainActor
protocol ImageLoading: AnyObject, Sendable {
    func image(for url: URL) async -> UIImage?
}

/// Loads and caches product images in memory. Images come from our backend
/// (`/api/v1/products/:id/image`), never from the product data source.
/// Concurrent requests for the same URL share one download.
@MainActor
final class ImageLoader: ImageLoading {
    private let cache = NSCache<NSURL, UIImage>()
    private var inFlight: [URL: Task<UIImage?, Never>] = [:]
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
        cache.countLimit = 200
    }

    func image(for url: URL) async -> UIImage? {
        if let cached = cache.object(forKey: url as NSURL) { return cached }
        if let existing = inFlight[url] { return await existing.value }

        let session = self.session
        let task = Task<UIImage?, Never> {
            guard
                let result = try? await session.data(from: url),
                (result.1 as? HTTPURLResponse)?.statusCode == 200,
                let image = UIImage(data: result.0)
            else { return nil }
            // Decode off the main thread so scrolling stays smooth.
            return await image.byPreparingForDisplay() ?? image
        }
        inFlight[url] = task
        let image = await task.value
        inFlight[url] = nil
        if let image { cache.setObject(image, forKey: url as NSURL) }
        return image
    }
}
