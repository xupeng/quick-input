import Foundation

enum NotionError: Error, Equatable {
    case unauthorized
    case rateLimited(retryAfter: Int)
    case badRequest(String)
    case networkError(String)
    case unknown(Int)
}

final class NotionService: Sendable {
    private let token: String
    private let databaseId: String
    private let session: URLSession
    private static let apiVersion = "2026-03-11"
    private static let baseURL = "https://api.notion.com/v1"

    init(token: String, databaseId: String, session: URLSession = .shared) {
        self.token = token
        self.databaseId = Self.normalizeDatabaseId(databaseId)
        self.session = session
    }

    static func normalizeDatabaseId(_ id: String) -> String {
        id.replacingOccurrences(of: "-", with: "")
    }

    func buildCreatePageRequest(title: String, markdown: String) -> URLRequest {
        var request = URLRequest(url: URL(string: "\(Self.baseURL)/pages")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(Self.apiVersion, forHTTPHeaderField: "Notion-Version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "parent": ["database_id": databaseId],
            "properties": [
                "title": [
                    "title": [["text": ["content": title]]]
                ]
            ],
            "markdown": markdown
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        return request
    }

    func createPage(title: String, markdown: String) async throws -> String {
        let request = buildCreatePageRequest(title: title, markdown: markdown)
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NotionError.networkError("Invalid response")
        }

        if httpResponse.statusCode == 200 {
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            return json?["id"] as? String ?? ""
        }

        throw Self.mapError(response: httpResponse, data: data)
    }

    static func mapError(response: HTTPURLResponse, data: Data) -> NotionError {
        switch response.statusCode {
        case 401:
            return .unauthorized
        case 429:
            let retryAfter = Int(response.value(forHTTPHeaderField: "Retry-After") ?? "1") ?? 1
            return .rateLimited(retryAfter: retryAfter)
        case 400:
            let message = String(data: data, encoding: .utf8) ?? "Bad request"
            return .badRequest(message)
        default:
            return .unknown(response.statusCode)
        }
    }
}
