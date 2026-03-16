import Testing
import Foundation
@testable import Quick_Input

@Suite("NotionService Tests")
struct NotionServiceTests {
    @Test("builds correct URLRequest")
    func buildRequest() throws {
        let service = NotionService(token: "test-token", databaseId: "abc-123")
        let request = service.buildCreatePageRequest(title: "Test", markdown: "# Test\nContent")

        #expect(request.url?.absoluteString == "https://api.notion.com/v1/pages")
        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer test-token")
        #expect(request.value(forHTTPHeaderField: "Notion-Version") == "2026-03-11")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")

        let body = try JSONSerialization.jsonObject(with: request.httpBody!) as! [String: Any]
        let parent = body["parent"] as! [String: String]
        #expect(parent["database_id"] == "abc123")
        #expect(body["markdown"] as? String == "# Test\nContent")
    }

    @Test("maps HTTP 429 to rateLimited error")
    func rateLimitedError() {
        let response = HTTPURLResponse(
            url: URL(string: "https://api.notion.com")!,
            statusCode: 429, httpVersion: nil,
            headerFields: ["Retry-After": "2"]
        )!
        let error = NotionService.mapError(response: response, data: Data())
        if case .rateLimited(let retryAfter) = error {
            #expect(retryAfter == 2)
        } else {
            Issue.record("Expected rateLimited error")
        }
    }

    @Test("maps HTTP 401 to unauthorized error")
    func unauthorizedError() {
        let response = HTTPURLResponse(
            url: URL(string: "https://api.notion.com")!,
            statusCode: 401, httpVersion: nil, headerFields: nil
        )!
        let error = NotionService.mapError(response: response, data: Data())
        #expect(error == .unauthorized)
    }

    @Test("normalizes database ID format")
    func normalizeDatabaseId() {
        #expect(NotionService.normalizeDatabaseId("abc12345-6789-0abc-def0-123456789abc") ==
                "abc1234567890abcdef0123456789abc")
        let plain = "abc1234567890abcdef0123456789abc"
        #expect(NotionService.normalizeDatabaseId(plain) == plain)
    }
}
