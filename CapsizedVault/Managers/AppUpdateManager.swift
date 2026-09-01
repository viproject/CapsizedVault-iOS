import Foundation
import Combine

class AppUpdateManager: ObservableObject {

    static let shared = AppUpdateManager()

    // Replace with your actual endpoint that returns the JSON described below
    // Expected JSON format:
//     {
//         "latestVersion": "1.2.0",
//         "minimumVersion": "1.0.0",
//         "updateURL": "https://apps.apple.com/app/lanza-wallet/id...",
//         "message": "A new version is available."
//     }
    private let versionCheckURL = URL(string: "https://capsized.io/version.json")!

    enum UpdateState: Equatable {
        case none
        case optionalUpdate(version: String, message: String?, url: URL)
        case forceUpdate(version: String, message: String?, url: URL)
    }

    @Published var updateState: UpdateState = .none

    private var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }

    func checkForUpdate() async {
        do {
            var request = URLRequest(url: versionCheckURL)
            request.cachePolicy = .reloadIgnoringLocalCacheData

            let (data, _) = try await URLSession.shared.data(for: request)
            let info = try JSONDecoder().decode(VersionInfo.self, from: data)

            guard let updateURL = URL(string: info.updateURL) else { return }

            let current = currentVersion

            #if DEBUG
            print("[AppUpdate] current: \(current), minimum: \(info.minimumVersion), latest: \(info.latestVersion)")
            #endif

            if compareVersions(current, isLessThan: info.minimumVersion) {
                await MainActor.run {
                    updateState = .forceUpdate(
                        version: info.latestVersion,
                        message: info.message,
                        url: updateURL
                    )
                }
            } else if compareVersions(current, isLessThan: info.latestVersion) {
                await MainActor.run {
                    updateState = .optionalUpdate(
                        version: info.latestVersion,
                        message: info.message,
                        url: updateURL
                    )
                }
            }
        } catch {
            #if DEBUG
            print("[AppUpdate] check failed: \(error)")
            #endif
        }
    }

    private func compareVersions(_ a: String, isLessThan b: String) -> Bool {
        let aParts = a.split(separator: ".").compactMap { Int($0) }
        let bParts = b.split(separator: ".").compactMap { Int($0) }

        for i in 0..<max(aParts.count, bParts.count) {
            let aVal = i < aParts.count ? aParts[i] : 0
            let bVal = i < bParts.count ? bParts[i] : 0
            if aVal < bVal { return true }
            if aVal > bVal { return false }
        }
        return false
    }
}

private struct VersionInfo: Decodable {
    let latestVersion: String
    let minimumVersion: String
    let updateURL: String
    let message: String?
}
