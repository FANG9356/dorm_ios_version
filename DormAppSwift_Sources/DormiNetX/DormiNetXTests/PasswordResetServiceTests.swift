import XCTest
@testable import DormiNetX

@MainActor
final class PasswordResetServiceTests: XCTestCase {
    func testRequestNormalizesEmailAndDoesNotSendSession() async throws {
        var captured: URLRequest?
        let service = PasswordResetService(baseURL: "https://test.invalid/api") { request in
            captured = request
            return (Data(#"{"message":"accepted"}"#.utf8), self.response(request, status: 200))
        }
        try await service.requestCode(email: "  Fang@Example.com \n")
        let request = try XCTUnwrap(captured)
        XCTAssertEqual(request.url?.path, "/api/forgot-password")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
        let body = try JSONDecoder().decode([String: String].self, from: XCTUnwrap(request.httpBody))
        XCTAssertEqual(body, ["email": "fang@example.com"])
    }

    func testResetSendsOTPAndPasswordToResetEndpoint() async throws {
        var captured: URLRequest?
        let service = PasswordResetService(baseURL: "https://test.invalid/api") { request in
            captured = request
            return (Data(#"{"message":"reset"}"#.utf8), self.response(request, status: 200))
        }
        try await service.reset(email: "Fang@example.com", code: "012345", password: "NewPassword9!")
        let request = try XCTUnwrap(captured)
        XCTAssertEqual(request.url?.path, "/api/reset-password")
        let body = try JSONDecoder().decode([String: String].self, from: XCTUnwrap(request.httpBody))
        XCTAssertEqual(body, ["email": "fang@example.com", "otp": "012345", "new_password": "NewPassword9!"])
    }

    func testInvalidCodesAndPasswordsNeverSendRequest() async {
        var requests = 0
        let service = PasswordResetService(baseURL: "https://test.invalid/api") { request in
            requests += 1
            return (Data(), self.response(request, status: 200))
        }
        for (code, password) in [("12345", "password9"), ("abcdef", "password9"), ("123456", "short"), ("123456", String(repeating: "a", count: 73))] {
            do {
                try await service.reset(email: "test@example.com", code: code, password: password)
                XCTFail("Invalid reset data accepted")
            } catch {}
        }
        XCTAssertEqual(requests, 0)
    }

    func testRateLimitAndMalformedSuccessAreNotReportedAsSuccess() async {
        for (status, data) in [(429, Data()), (200, Data("<html>bad gateway</html>".utf8)), (401, Data(#"{"error":"expired"}"#.utf8)), (200, Data(#"{"message":"ok","error":"failure"}"#.utf8))] {
            let service = PasswordResetService(baseURL: "https://test.invalid/api") { request in
                (data, self.response(request, status: status))
            }
            do {
                try await service.requestCode(email: "test@example.com")
                XCTFail("Unexpected successful response")
            } catch {
                if status == 429 { XCTAssertTrue(error.localizedDescription.contains("15")) }
            }
        }
    }

    private func response(_ request: URLRequest, status: Int) -> HTTPURLResponse {
        HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
    }
}
