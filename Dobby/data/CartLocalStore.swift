//
//  CartLocalStore.swift
//  Dobby
//
//  Local persistence for cart rows (parity with Android `CartRepositoryImpl` + `CartDao`).
//

import Foundation
import SwiftData

/// Shared SwiftData stack for the cart — use the same instance as `.modelContainer` in `RootView`.
enum CartSwiftDataStack {
    static let sharedContainer: ModelContainer = {
        let schema = Schema([
            CartPersistedEntity.self,
            FavoriteProductPersistedEntity.self,
        ])
        let config = ModelConfiguration("cart.store")
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Cart ModelContainer failed: \(error)")
        }
    }()
}

@MainActor
final class CartLocalStore {
    private let context: ModelContext

    init(container: ModelContainer) {
        context = ModelContext(container)
    }

    /// Loads all rows ordered by `productId` (same idea as `SELECT * FROM cart ORDER BY productId`).
    func loadLines() -> [CartLineItem] {
        let descriptor = FetchDescriptor<CartPersistedEntity>(
            sortBy: [SortDescriptor(\.productId)]
        )
        guard let entities = try? context.fetch(descriptor) else {
            return []
        }
        return entities.map { $0.toCartLineItem() }
    }

    /// Replaces persisted cart with the in-memory list (small cart — simple and consistent).
    func persist(lines: [CartLineItem]) {
        do {
            let descriptor = FetchDescriptor<CartPersistedEntity>()
            let existing = try context.fetch(descriptor)
            for row in existing {
                context.delete(row)
            }
            for line in lines {
                context.insert(CartPersistedEntity(from: line))
            }
            try context.save()
        } catch {
            assertionFailure("Cart persist failed: \(error)")
        }
    }
}
