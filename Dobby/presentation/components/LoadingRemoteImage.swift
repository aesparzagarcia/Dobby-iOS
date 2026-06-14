//
//  LoadingRemoteImage.swift
//  Dobby
//

import SwiftUI

/// Remote image with configurable placeholder background and spinner while loading.
struct LoadingRemoteImage<Placeholder: View>: View {
    let urlString: String?
    var resolveAgainstApiBase: Bool = false
    var contentMode: ContentMode = .fill
    var placeholderBackground: Color = Color(.systemGray5)
    @ViewBuilder var placeholder: () -> Placeholder

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
