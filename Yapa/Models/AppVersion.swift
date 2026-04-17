import Foundation

public struct AppVersionInfo {
    public let marketingVersion: String
    public let buildNumber: String

    public init(marketingVersion: String, buildNumber: String) {
        self.marketingVersion = marketingVersion
        self.buildNumber = buildNumber
    }

    static let current = AppVersionInfo(
        marketingVersion: Bundle.main.shortVersionString,
        buildNumber: Bundle.main.buildNumberString
    )

    var displayString: String {
        "v\(marketingVersion) (build \(buildNumber))"
    }
}

private extension Bundle {
    var shortVersionString: String {
        object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
    }

    var buildNumberString: String {
        object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
    }
}
