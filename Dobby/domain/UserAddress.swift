//
//  UserAddress.swift
//  Dobby
//
//  Parity with Android `com.ares.ewe.domain.model.UserAddress`.
//

import Foundation

struct UserAddress: Identifiable, Hashable, Sendable {
    let id: String
    let label: String
    let description: String?
    let address: String
    let lat: Double
    let lng: Double
    let isDefault: Bool
    let isActive: Bool
}
