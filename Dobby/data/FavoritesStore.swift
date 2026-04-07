//
//  FavoritesStore.swift
//  Dobby
//
//  Observable facade over `FavoritesLocalStore` for SwiftUI (parity with Android `FavoritesRepository` flows).
//

import Foundation

@MainActor
@Observable
final class FavoritesStore {
    private let local: FavoritesLocalStore

    private(set) var products: [FavoriteProduct] = []

    init(local: FavoritesLocalStore) {
        self.local = local
        refresh()
    }

    func refresh() {
        products = local.loadAll()
    }

    func isFavorite(productId: String) -> Bool {
        products.contains { $0.productId == productId }
    }

    func toggle(from route: ProductDetailRoute) {
        let fp = FavoriteProduct(
            productId: route.id,
            name: route.name,
            price: route.price,
            imageUrl: route.imageUrl,
            rate: route.rate,
            hasPromotion: route.hasPromotion,
            discount: route.discount
        )
        local.toggle(fp)
        refresh()
    }
}
