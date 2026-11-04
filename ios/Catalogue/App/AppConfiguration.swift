import Foundation

/// Build-time configuration, read from Info.plist, which gets it from Config/Catalogue.xcconfig.
struct AppConfiguration: Sendable {
    let apiBaseURL: URL

    static func load(from bundle: Bundle = .main) -> AppConfiguration {
        guard
            let value = bundle.object(forInfoDictionaryKey: "APIBaseURL") as? String,
            let url = URL(string: value),
            url.scheme == "http" || url.scheme == "https"
        else {
            preconditionFailure("APIBaseURL is missing or invalid. Set API_BASE_URL in ios/Config/Catalogue.xcconfig.")
        }
        return AppConfiguration(apiBaseURL: url)
    }
}
