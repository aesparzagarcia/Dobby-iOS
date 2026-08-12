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

    /// First comma-separated part (street + number), matching Android `toStreetAndNumberOnly`.
    func streetAndNumberOnly() -> String {
        let parts = split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        if let first = parts.first, !first.isEmpty {
            return first
        }
        return trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Replaces street+colony (first two parts) keeping city/state/country — Android `withEditedStreetAndColony`.
    func withEditedStreetAndColony(_ editedStreetAndColony: String) -> String {
        let edited = editedStreetAndColony.trimmingCharacters(in: .whitespacesAndNewlines)
        if edited.isEmpty {
            return trimmingCharacters(in: .whitespacesAndNewlines)
        }
        let rest = split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .dropFirst(2)
        if rest.isEmpty {
            return edited
        }
        return "\(edited), \(rest.joined(separator: ", "))"
    }
}
