//
//  FavoritesLocalStore.swift
//  Dobby
//
//  Local persistence for favorite products (parity with Android `FavoritesRepositoryImpl` + `FavoriteProductDao`).
//

import Foundation
import SwiftData

@MainActor
final class FavoritesLocalStore {
    private let context: ModelContext

    init(container: ModelContainer) {
        context = ModelContext(container)
    }

    /// Newest first — matches Android `ORDER BY createdAt DESC`.
    func loadAll() -> [FavoriteProduct] {
        var descriptor = FetchDescriptor<FavoriteProductPersistedEntity>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        guard let entities = try? context.fetch(descriptor) else {
            return []
        }
        return entities.map { $0.toFavoriteProduct() }
    }

    func isFavorite(productId: String) -> Bool {
        var descriptor = FetchDescriptor<FavoriteProductPersistedEntity>(
            predicate: #Predicate { $0.productId == productId }
        )
        descriptor.fetchLimit = 1
        guard let list = try? context.fetch(descriptor) else { return false }
        return !list.isEmpty
    }

    func toggle(_ product: FavoriteProduct) {
        if isFavorite(productId: product.productId) {
            remove(productId: product.productId)
        } else {
            insert(product)
        }
    }

    private func insert(_ product: FavoriteProduct) {
        context.insert(FavoriteProductPersistedEntity(from: product))
        try? context.save()
    }

    private func remove(productId: String) {
        var descriptor = FetchDescriptor<FavoriteProductPersistedEntity>(
            predicate: #Predicate { $0.productId == productId }
        )
        guard let rows = try? context.fetch(descriptor) else { return }
        for row in rows {
            context.delete(row)
        }
        try? context.save()
    }
}
