//
//  ActivityViewController.swift
//  CapsizedVault
//
//  Created by Dmitrij on 14/01/2026.
//

import Foundation
import SwiftUI
import LinkPresentation

// MARK: - Activity item source that injects a custom share-sheet preview image

private final class ActivityItemWithPreview: NSObject, UIActivityItemSource {
    private let item: Any
    private let previewImage: UIImage

    init(item: Any, previewImage: UIImage) {
        self.item = item
        self.previewImage = previewImage
    }

    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        return item
    }

    func activityViewController(_ activityViewController: UIActivityViewController,
                                itemForActivityType activityType: UIActivity.ActivityType?) -> Any? {
        return item
    }

    func activityViewControllerLinkMetadata(_ activityViewController: UIActivityViewController) -> LPLinkMetadata? {
        let metadata = LPLinkMetadata()
        metadata.title = "QR Code"
        metadata.imageProvider = NSItemProvider(object: previewImage)
        metadata.iconProvider  = NSItemProvider(object: previewImage)
        return metadata
    }
}

// MARK: - Activity View Controller Wrapper

struct ActivityViewController: UIViewControllerRepresentable {
    let activityItems: [Any]
    let applicationActivities: [UIActivity]? = nil
    /// When set, the share sheet preview shows this image instead of the app icon.
    var previewImage: UIImage? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let items: [Any]
        if let preview = previewImage, let first = activityItems.first {
            // Wrap the first item with the preview image; keep remaining items as-is.
            items = [ActivityItemWithPreview(item: first, previewImage: preview)]
                + Array(activityItems.dropFirst())
        } else {
            items = activityItems
        }
        return UIActivityViewController(activityItems: items,
                                        applicationActivities: applicationActivities)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
