import StoreKit
import UIKit

final class ReviewManager {
    static let shared = ReviewManager()

    private let firstLaunchKey = "reviewManager.firstLaunchDate"
    private let lastRequestKey  = "reviewManager.lastRequestDate"
    private let minimumInterval: TimeInterval = 3 * 24 * 60 * 60  // 3 days

    private init() {
        if UserDefaults.standard.object(forKey: firstLaunchKey) == nil {
            UserDefaults.standard.set(Date(), forKey: firstLaunchKey)
        }
    }

    func requestReviewIfEligible() {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }) else { return }

        #if !DEBUG
        let now = Date()
        let defaults = UserDefaults.standard

        // Rule 1: at least 3 days since first launch
        guard let firstLaunch = defaults.object(forKey: firstLaunchKey) as? Date,
              now.timeIntervalSince(firstLaunch) >= minimumInterval else { return }

        // Rule 2: at least 3 days since last request
        if let lastRequest = defaults.object(forKey: lastRequestKey) as? Date,
           now.timeIntervalSince(lastRequest) < minimumInterval { return }

        defaults.set(now, forKey: lastRequestKey)
        #endif

        SKStoreReviewController.requestReview(in: scene)
    }
}
