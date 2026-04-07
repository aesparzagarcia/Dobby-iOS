//
//  DobbyHTTPClient.swift
//  Dobby
//

import Foundation
import os.log

enum HTTPClientError: Error {
    case invalidURL
    case statusCode(Int, Data?)
    case decoding(Error)
    case transport(Error)
}

/// Minimal JSON client for Dobby API (parity with Retrofit `DobbyApi` auth calls).
/// When `sessionStore` + `tokenRefresh` are set, authenticated requests retry once after `auth/refresh` on 401 (parity with Android `TokenRefreshInterceptor`).
struct DobbyHTTPClient: Sendable {
    private static let log = Logger(subsystem: "com.ares.Dobby", category: "HTTP")
    private static let headerAuthRetry = "X-Dobby-Auth-Retry"

    let baseURL: URL
    private let session: URLSession
    private let sessionStore: SessionStore?
    private let tokenRefresh: ConsumerTokenRefreshService?

    private var performs401Retry: Bool {
        sessionStore != nil && tokenRefresh != nil
    }

    init(
        baseURL: URL,
        session: URLSession = .shared,
        sessionStore: SessionStore? = nil,
        tokenRefresh: ConsumerTokenRefreshService? = nil
    ) {
        self.baseURL = baseURL
        self.session = session
        self.sessionStore = sessionStore
        self.tokenRefresh = tokenRefresh
    }

    private static func join(baseURL: URL, path: String) -> URL {
        var s = baseURL.absoluteString
        if !s.hasSuffix("/") { s += "/" }
        let p = path.hasPrefix("/") ? String(path.dropFirst()) : path
        return URL(string: s + p)!
    }

    private func shouldSkip401Refresh(for url: URL) -> Bool {
        let s = url.absoluteString
        return s.contains("auth/request-otp")
            || s.contains("auth/verify-otp")
            || s.contains("auth/complete-registration")
            || s.contains("/auth/refresh")
    }

    private func clearSessionAndNotify() {
        sessionStore?.clearSession()
        NotificationCenter.default.post(name: .dobbySessionExpired, object: nil)
    }

    /// After session was cleared elsewhere, in-flight requests often fail with `URLError.cancelled` — treat like auth failure and navigate to login.
    private func mapTransportError(_ error: Error) -> HTTPClientError {
        if let u = error as? URLError, u.code == .cancelled, let sessionStore, !sessionStore.isLoggedIn {
            NotificationCenter.default.post(name: .dobbySessionExpired, object: nil)
            return .statusCode(401, nil)
        }
        return .transport(error)
    }

    func post<Body: Encodable, Response: Decodable>(_ path: String, body: Body) async -> Result<Response, HTTPClientError> {
        let url = Self.join(baseURL: baseURL, path: path)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 25
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        do {
            request.httpBody = try JSONEncoder().encode(body)
        } catch {
            Self.log.error("encode failed: \(String(describing: error), privacy: .public)")
            return .failure(.transport(error))
        }
        Self.log.info("POST \(url.absoluteString, privacy: .public)")
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                Self.log.error("no HTTPURLResponse")
                return .failure(.statusCode(-1, data))
            }
            Self.log.info("response status=\(http.statusCode) bytes=\(data.count)")
            guard (200 ... 299).contains(http.statusCode) else {
                return .failure(.statusCode(http.statusCode, data))
            }
            do {
                let decoded = try JSONDecoder().decode(Response.self, from: data)
                return .success(decoded)
            } catch {
                Self.log.error("decode failed: \(String(describing: error), privacy: .public)")
                return .failure(.decoding(error))
            }
        } catch {
            Self.log.error("transport: \(String(describing: error), privacy: .public)")
            return .failure(.transport(error))
        }
    }

    /// Authenticated POST (e.g. `addresses` create).
    func post<Body: Encodable, Response: Decodable>(_ path: String, body: Body, bearerToken: String?) async -> Result<Response, HTTPClientError> {
        do {
            let bodyData = try JSONEncoder().encode(body)
            return await postAuthenticated(path: path, bodyData: bodyData, bearerToken: bearerToken, isAuthRetry: false)
        } catch {
            Self.log.error("encode failed: \(String(describing: error), privacy: .public)")
            return .failure(.transport(error))
        }
    }

    private func postAuthenticated<Response: Decodable>(
        path: String,
        bodyData: Data,
        bearerToken: String?,
        isAuthRetry: Bool
    ) async -> Result<Response, HTTPClientError> {
        let url = Self.join(baseURL: baseURL, path: path)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 25
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.httpBody = bodyData
        if isAuthRetry {
            request.setValue("1", forHTTPHeaderField: Self.headerAuthRetry)
        }
        if let t = bearerToken, !t.isEmpty {
            request.setValue("Bearer \(t)", forHTTPHeaderField: "Authorization")
        }
        Self.log.info("POST auth \(url.absoluteString, privacy: .public)")
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                return .failure(.statusCode(-1, data))
            }
            Self.log.info("POST auth status=\(http.statusCode) bytes=\(data.count)")

            if http.statusCode == 401 {
                if isAuthRetry {
                    clearSessionAndNotify()
                    return .failure(.statusCode(401, data))
                }
                if performs401Retry,
                   !shouldSkip401Refresh(for: url),
                   let tokenRefresh,
                   let sessionStore {
                    let requestAccess = bearerToken ?? sessionStore.accessToken() ?? ""
                    switch await tokenRefresh.coordinateAfter401(requestAccessToken: requestAccess) {
                    case .useAccess(let t), .newTokens(let t):
                        return await postAuthenticated(path: path, bodyData: bodyData, bearerToken: t, isAuthRetry: true)
                    case .noRefreshStored, .sessionInvalid:
                        clearSessionAndNotify()
                        return .failure(.statusCode(401, data))
                    case .transientFailure:
                        return .failure(.statusCode(401, data))
                    }
                }
                return .failure(.statusCode(401, data))
            }

            guard (200 ... 299).contains(http.statusCode) else {
                return .failure(.statusCode(http.statusCode, data))
            }
            do {
                let decoded = try JSONDecoder().decode(Response.self, from: data)
                return .success(decoded)
            } catch {
                Self.log.error("decode failed: \(String(describing: error), privacy: .public)")
                return .failure(.decoding(error))
            }
        } catch {
            Self.log.error("transport: \(String(describing: error), privacy: .public)")
            return .failure(mapTransportError(error))
        }
    }

    /// Authenticated GET (e.g. `app/home`, `app/ads`, `addresses`).
    func get<Response: Decodable>(_ path: String, bearerToken: String?) async -> Result<Response, HTTPClientError> {
        await getAuthenticated(path: path, bearerToken: bearerToken, isAuthRetry: false)
    }

    private func getAuthenticated<Response: Decodable>(path: String, bearerToken: String?, isAuthRetry: Bool) async -> Result<Response, HTTPClientError> {
        let url = Self.join(baseURL: baseURL, path: path)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 25
        if isAuthRetry {
            request.setValue("1", forHTTPHeaderField: Self.headerAuthRetry)
        }
        if let t = bearerToken, !t.isEmpty {
            request.setValue("Bearer \(t)", forHTTPHeaderField: "Authorization")
        }
        Self.log.info("GET \(url.absoluteString, privacy: .public)")
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                return .failure(.statusCode(-1, data))
            }
            Self.log.info("GET status=\(http.statusCode) bytes=\(data.count)")

            if http.statusCode == 401 {
                if isAuthRetry {
                    clearSessionAndNotify()
                    return .failure(.statusCode(401, data))
                }
                if performs401Retry,
                   !shouldSkip401Refresh(for: url),
                   let tokenRefresh,
                   let sessionStore {
                    let requestAccess = bearerToken ?? sessionStore.accessToken() ?? ""
                    switch await tokenRefresh.coordinateAfter401(requestAccessToken: requestAccess) {
                    case .useAccess(let t), .newTokens(let t):
                        return await getAuthenticated(path: path, bearerToken: t, isAuthRetry: true)
                    case .noRefreshStored, .sessionInvalid:
                        clearSessionAndNotify()
                        return .failure(.statusCode(401, data))
                    case .transientFailure:
                        return .failure(.statusCode(401, data))
                    }
                }
                return .failure(.statusCode(401, data))
            }

            guard (200 ... 299).contains(http.statusCode) else {
                return .failure(.statusCode(http.statusCode, data))
            }
            do {
                let decoded = try JSONDecoder().decode(Response.self, from: data)
                return .success(decoded)
            } catch {
                Self.log.error("GET decode failed: \(String(describing: error), privacy: .public)")
                return .failure(.decoding(error))
            }
        } catch {
            Self.log.error("GET transport: \(String(describing: error), privacy: .public)")
            return .failure(mapTransportError(error))
        }
    }

    /// Authenticated PATCH with no response body (e.g. `addresses/{id}/default`).
    func patch(_ path: String, bearerToken: String?) async -> Result<Void, HTTPClientError> {
        await patchAuthenticated(path: path, bearerToken: bearerToken, isAuthRetry: false)
    }

    private func patchAuthenticated(path: String, bearerToken: String?, isAuthRetry: Bool) async -> Result<Void, HTTPClientError> {
        let url = Self.join(baseURL: baseURL, path: path)
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.timeoutInterval = 25
        if isAuthRetry {
            request.setValue("1", forHTTPHeaderField: Self.headerAuthRetry)
        }
        if let t = bearerToken, !t.isEmpty {
            request.setValue("Bearer \(t)", forHTTPHeaderField: "Authorization")
        }
        Self.log.info("PATCH \(url.absoluteString, privacy: .public)")
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                return .failure(.statusCode(-1, nil))
            }
            Self.log.info("PATCH status=\(http.statusCode)")

            if http.statusCode == 401 {
                if isAuthRetry {
                    clearSessionAndNotify()
                    return .failure(.statusCode(401, data))
                }
                if performs401Retry,
                   !shouldSkip401Refresh(for: url),
                   let tokenRefresh,
                   let sessionStore {
                    let requestAccess = bearerToken ?? sessionStore.accessToken() ?? ""
                    switch await tokenRefresh.coordinateAfter401(requestAccessToken: requestAccess) {
                    case .useAccess(let t), .newTokens(let t):
                        return await patchAuthenticated(path: path, bearerToken: t, isAuthRetry: true)
                    case .noRefreshStored, .sessionInvalid:
                        clearSessionAndNotify()
                        return .failure(.statusCode(401, data))
                    case .transientFailure:
                        return .failure(.statusCode(401, data))
                    }
                }
                return .failure(.statusCode(401, data))
            }

            guard (200 ... 299).contains(http.statusCode) else {
                return .failure(.statusCode(http.statusCode, data))
            }
            return .success(())
        } catch {
            Self.log.error("PATCH transport: \(String(describing: error), privacy: .public)")
            return .failure(mapTransportError(error))
        }
    }
}

extension DobbyHTTPClient {
    func userFacingMessage(from error: HTTPClientError) -> String {
        switch error {
        case .invalidURL:
            return "No se pudo conectar con el servidor."
        case let .statusCode(code, data):
            if let data, let s = String(data: data, encoding: .utf8), !s.isEmpty {
                return s
            }
            return "Error del servidor (\(code))."
        case .decoding:
            return "Respuesta inválida del servidor."
        case .transport(let e):
            if let urlError = e as? URLError {
                switch urlError.code {
                case .notConnectedToInternet, .networkConnectionLost:
                    return "Sin conexión a internet."
                case .timedOut:
                    return "Tiempo de espera: no respondió tu Mac. En Info.plist pon la IP real (Terminal: ipconfig getifaddr en0), misma Wi‑Fi, API en 0.0.0.0:3001 y firewall abierto para ese puerto."
                case .cannotConnectToHost, .cannotFindHost:
                    return "No se pudo conectar: revisa API_BASE_URL, que la API esté en marcha y el puerto."
                default:
                    break
                }
            }
            return e.localizedDescription
        }
    }
}
