//
//  LoadingRemoteImage.swift
//  Dobby
//

import SwiftUI

/// Remote image with gray placeholder and spinner while loading.
struct LoadingRemoteImage<Placeholder: View>: View {
    let urlString: String?
    var resolveAgainstApiBase: Bool = false
    var contentMode: ContentMode = .fill
    @ViewBuilder var placeholder: () -> Placeholder

    init(
        urlString: String?,
        resolveAgainstApiBase: Bool = false,
        contentMode: ContentMode = .fill,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.urlString = urlString
        self.resolveAgainstApiBase = resolveAgainstApiBase
        self.contentMode = contentMode
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
            Color(.systemGray5)
            if let url = resolvedURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: contentMode)
                    case .failure:
                        placeholder()
                    case .empty:
                        ProgressView()
                            .tint(DobbyBrandColor.primary)
                    @unknown default:
                        placeholder()
                    }
                }
            } else {
                placeholder()
            }
        }
    }
}

extension LoadingRemoteImage where Placeholder == EmptyView {
    init(
        urlString: String?,
        resolveAgainstApiBase: Bool = false,
        contentMode: ContentMode = .fill
    ) {
        self.init(
            urlString: urlString,
            resolveAgainstApiBase: resolveAgainstApiBase,
            contentMode: contentMode,
            placeholder: { EmptyView() }
        )
    }
}
