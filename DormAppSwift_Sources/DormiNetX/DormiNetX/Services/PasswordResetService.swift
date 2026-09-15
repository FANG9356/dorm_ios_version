import Foundation

@MainActor
struct PasswordResetService {
    var baseURL: String
    var transport: (URLRequest) async throws -> (Data, URLResponse)

    init(
        baseURL: String? = nil,
        transport: @escaping (URLRequest) async throws -> (Data, URLResponse) = {
            try await URLSession.shared.data(for: $0)
        }
    ) {
        self.baseURL = baseURL ?? APIService.shared.baseURL
        self.transport = transport
    }

    func requestCode(email: String) async throws {
        try await post("forgot-password", body: ["email": normalized(email)])
    }

    func reset(email: String, code: String, password: String) async throws {
        guard code.utf8.count == 6, code.utf8.allSatisfy({ (48...57).contains($0) }) else {
            throw Failure("กรุณากรอกรหัสยืนยัน 6 หลัก")
        }
        guard password.count >= 8, password.utf8.count <= 72 else {
            throw Failure("รหัสผ่านต้องมีอย่างน้อย 8 ตัวอักษร และไม่เกิน 72 ไบต์")
        }
        try await post("reset-password", body: [
            "email": normalized(email), "otp": code, "new_password": password
        ])
    }

    private func normalized(_ email: String) -> String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func post(_ path: String, body: [String: String]) async throws {
        guard let url = URL(string: baseURL)?.appendingPathComponent(path) else {
            throw Failure("ไม่พบที่อยู่เซิร์ฟเวอร์")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)
        let data: Data
        let response: URLResponse
        do { (data, response) = try await transport(request) }
        catch { throw Failure("เชื่อมต่อเซิร์ฟเวอร์ไม่ได้ กรุณาตรวจสอบอินเทอร์เน็ตแล้วลองใหม่") }
        guard let response = response as? HTTPURLResponse else {
            throw Failure("การตอบกลับจากเซิร์ฟเวอร์ไม่ถูกต้อง")
        }
        let result = try? JSONDecoder().decode(Reply.self, from: data)
        guard response.statusCode == 200, result?.message?.isEmpty == false, result?.error == nil else {
            if response.statusCode == 429 {
                throw Failure("ทำรายการเกินจำนวนครั้งที่กำหนด กรุณารอ 15 นาทีแล้วลองใหม่")
            }
            throw Failure(result?.error ?? "ทำรายการไม่สำเร็จ กรุณาลองใหม่ภายหลัง")
        }
    }

    private struct Reply: Decodable {
        var message: String?
        var error: String?
    }

    struct Failure: LocalizedError {
        let message: String
        init(_ message: String) { self.message = message }
        var errorDescription: String? { message }
    }
}
