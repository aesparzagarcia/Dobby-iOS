//
//  DeliveryServiceArea.swift
//  Dobby
//
//  Zona desde `service_area.kml` (primer anillo de coordenadas). Comentarios XML se eliminan antes de parsear.
//  Solo se bloquea por “KML mal” si no hay ninguna etiqueta de coordenadas (p. ej. solo NetworkLink).
//

import CoreLocation
import Foundation

enum DeliveryServiceArea {
    static let outsideMessage =
        "Esta ubicación está fuera del área de entrega. Mueve el pin dentro del polígono permitido."

    static let misconfiguredKmlMessage =
        "service_area.kml no incluye coordenadas embebidas del polígono. My Maps a veces exporta solo un enlace: añade un Polygon con su lista de coordenadas o copia el ejemplo del repositorio."

    static let invalidPolygonMessage =
        "No se pudo leer el polígono en service_area.kml. Revisa el formato (lon,lat por punto) o copia el ejemplo del repositorio."

    static let outsideLimitsLabel = "Fuera de los límites"
    static let configFixLabel = "Revisa área de entrega"

    private static let rawBundledXml: String? = {
        guard let url = Bundle.main.url(forResource: "service_area", withExtension: "kml"),
              let data = try? Data(contentsOf: url),
              let xml = String(data: data, encoding: .utf8),
              !xml.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else { return nil }
        return xml
    }()

    private static let processedXml: String = {
        guard let raw = rawBundledXml else { return "" }
        let trimmed = raw.hasPrefix("\u{FEFF}") ? String(raw.dropFirst()) : raw
        return stripXmlComments(trimmed).trimmingCharacters(in: .whitespacesAndNewlines)
    }()

    private static let hasKmlRoot: Bool = {
        processedXml.range(of: "<kml", options: .caseInsensitive) != nil
    }()

    private static let hasCoordinatesTagInGeometry: Bool = {
        processedXml.range(of: "<coordinates", options: .caseInsensitive) != nil
    }()

    private static let kmlBundledButNoCoordinatesTag: Bool = {
        hasKmlRoot && !hasCoordinatesTagInGeometry
    }()

    private static let ring: [CLLocationCoordinate2D] = {
        guard !processedXml.isEmpty else { return [] }
        return parseFirstCoordinateRing(from: processedXml)
    }()

    private static let polygonUnusable: Bool = {
        hasCoordinatesTagInGeometry && ring.count < 3
    }()

    /// Solo “sin geometría en el archivo”. Un parseo fallido no bloquea toda la app.
    static let isConfigBlockingSaves: Bool = kmlBundledButNoCoordinatesTag

    static var hasValidEnforcedPolygon: Bool { ring.count >= 3 }

    static func contains(latitude: Double, longitude: Double) -> Bool {
        if ring.count >= 3 {
            let open = openRing(ring)
            guard open.count >= 3 else { return true }
            return pointInPolygon(lat: latitude, lon: longitude, vertices: open)
        }
        if kmlBundledButNoCoordinatesTag {
            return false
        }
        return true
    }

    static func denialMessage() -> String {
        if kmlBundledButNoCoordinatesTag { return misconfiguredKmlMessage }
        if polygonUnusable { return invalidPolygonMessage }
        return outsideMessage
    }

    private static func stripXmlComments(_ xml: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: #"<!--[\s\S]*?-->"#, options: []) else {
            return xml
        }
        let range = NSRange(xml.startIndex..<xml.endIndex, in: xml)
        return regex.stringByReplacingMatches(in: xml, options: [], range: range, withTemplate: "")
    }

    private static func parseFirstCoordinateRing(from xml: String) -> [CLLocationCoordinate2D] {
        guard let startRange = xml.range(of: "<coordinates", options: .caseInsensitive) else { return [] }
        let afterTag = xml[startRange.upperBound...]
        guard let gt = afterTag.firstIndex(of: ">") else { return [] }
        let contentStart = afterTag.index(after: gt)
        let tail = afterTag[contentStart...]
        guard let closeRange = tail.range(of: "</coordinates>", options: .caseInsensitive) else { return [] }
        let inner = String(tail[..<closeRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        if inner.isEmpty { return [] }

        if let pts = parseLonLatOrder(inner, lonFirst: true), pts.count >= 3 { return closeRing(pts) }
        if let pts = parseLonLatOrder(inner, lonFirst: false), pts.count >= 3 { return closeRing(pts) }
        return []
    }

    private static func parseLonLatOrder(_ inner: String, lonFirst: Bool) -> [CLLocationCoordinate2D]? {
        var points: [CLLocationCoordinate2D] = []
        for token in inner.split(whereSeparator: { $0.isWhitespace || $0.isNewline }) {
            let parts = token.split(separator: ",")
            guard parts.count >= 2,
                  let a = Double(parts[0]),
                  let b = Double(parts[1])
            else { continue }
            let lat: Double
            let lon: Double
            if lonFirst {
                lon = a
                lat = b
            } else {
                lat = a
                lon = b
            }
            guard lat >= -90, lat <= 90, lon >= -180, lon <= 180 else { continue }
            points.append(CLLocationCoordinate2D(latitude: lat, longitude: lon))
        }
        return points.count >= 3 ? points : nil
    }

    private static func closeRing(_ points: [CLLocationCoordinate2D]) -> [CLLocationCoordinate2D] {
        var out = points
        let first = out[0]
        let last = out[out.count - 1]
        if first.latitude != last.latitude || first.longitude != last.longitude {
            out.append(first)
        }
        return out
    }

    /// Ray-casting con el último vértice duplicado del anillo cerrado puede fallar; PolyUtil en Android tolera ambos.
    private static func openRing(_ vertices: [CLLocationCoordinate2D]) -> [CLLocationCoordinate2D] {
        guard vertices.count >= 2 else { return vertices }
        let first = vertices[0]
        let last = vertices[vertices.count - 1]
        if first.latitude == last.latitude && first.longitude == last.longitude {
            return Array(vertices.dropLast())
        }
        return vertices
    }

    private static func pointInPolygon(lat: Double, lon: Double, vertices: [CLLocationCoordinate2D]) -> Bool {
        var inside = false
        var j = vertices.count - 1
        for i in vertices.indices {
            let yi = vertices[i].latitude
            let xi = vertices[i].longitude
            let yj = vertices[j].latitude
            let xj = vertices[j].longitude
            if abs(yj - yi) < 1e-12 {
                j = i
                continue
            }
            let intersect = (yi > lat) != (yj > lat) &&
                lon < (xj - xi) * (lat - yi) / (yj - yi + 0.0) + xi
            if intersect { inside.toggle() }
            j = i
        }
        return inside
    }
}
