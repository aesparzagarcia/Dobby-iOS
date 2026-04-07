//
//  AddressDisplay.swift
//  Dobby
//

import Foundation

extension String {
    /// First two comma-separated parts (address + colony), matching Android `toAddressWithColonyOnly`.
    func addressWithColonyOnly() -> String {
        let parts = split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        switch parts.count {
        case 0: return self
        case 1: return String(parts[0])
        default: return parts.prefix(2).joined(separator: ", ")
        }
    }
}
