import Foundation

class APIService {
    static let shared = APIService()
    
    // โดเมนที่เจาะอุโมงค์ Cloudflare ไว้ ทะลุเข้าเซิร์ฟเวอร์เราโดยตรง
    var baseURL = "https://api.dorminet.studio/api"
    
    // เก็บอีเมลล์ที่ใช้งานอยู่ปัจจุบัน
    var currentEmail: String?
    
    // เก็บ Token สำหรับยืนยันตัวตน
    var authToken: String? {
        get { UserDefaults.standard.string(forKey: "authToken") }
        set {
            if let newValue = newValue {
                UserDefaults.standard.set(newValue, forKey: "authToken")
            } else {
                UserDefaults.standard.removeObject(forKey: "authToken")
            }
        }
    }
    var userRole: String? {
        get { UserDefaults.standard.string(forKey: "userRole") }
        set {
            if let newValue = newValue {
                UserDefaults.standard.set(newValue, forKey: "userRole")
            } else {
                UserDefaults.standard.removeObject(forKey: "userRole")
            }
        }
    }

    func restoreSession(token: String, email: String? = nil, fallbackRole: String? = nil) {
        authToken = token
        currentEmail = email

        if let role = jwtStringClaim("role", from: token), !role.isEmpty {
            userRole = role
        } else if let fallbackRole, !fallbackRole.isEmpty {
            userRole = fallbackRole
        } else if userRole == nil {
            userRole = "admin"
        }

        if let adminID = jwtIntClaim("admin_id", from: token), adminID > 0 {
            UserDefaults.standard.set(adminID, forKey: "adminID")
        }
    }

    private func jwtStringClaim(_ key: String, from token: String) -> String? {
        jwtPayload(from: token)?[key] as? String
    }

    private func jwtIntClaim(_ key: String, from token: String) -> Int? {
        guard let value = jwtPayload(from: token)?[key] else { return nil }
        if let intValue = value as? Int { return intValue }
        if let numberValue = value as? NSNumber { return numberValue.intValue }
        if let doubleValue = value as? Double { return Int(doubleValue) }
        return nil
    }

    private func jwtPayload(from token: String) -> [String: Any]? {
        let parts = token.split(separator: ".")
        guard parts.count >= 2 else { return nil }

        var payload = String(parts[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        let padding = payload.count % 4
        if padding != 0 {
            payload += String(repeating: "=", count: 4 - padding)
        }

        guard let data = Data(base64Encoded: payload),
              let object = try? JSONSerialization.jsonObject(with: data),
              let dictionary = object as? [String: Any] else {
            return nil
        }
        return dictionary
    }
    
    func login(email: String, password: String) async throws -> (Bool, String?) {
        guard let url = URL(string: "\(baseURL)/auth/login") else { return (false, nil) }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body = ["email": email, "password": password]
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            return (false, nil)
        }
        
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let status = json["status"] as? String, status == "success" {
            self.currentEmail = email
            if let token = json["token"] as? String {
                self.authToken = token
            }
            let name = json["name"] as? String
            
            // Use role from server response
            if let role = json["role"] as? String {
                self.userRole = role
            } else {
                self.userRole = "admin" // Default fallback
            }
            if let adminId = json["admin_id"] as? Int {
                UserDefaults.standard.set(adminId, forKey: "adminID")
            }
            return (true, name)
        }
        
        return (false, nil)
    }
    
    func register(name: String, email: String, password: String, role: String? = nil) async throws -> (Bool, String?, String?) {
        guard let url = URL(string: "\(baseURL)/auth/register") else { return (false, nil, "Invalid URL") }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        var body = ["name": name, "email": email, "password": password]
        if let role = role {
            body["role"] = role
        }
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        var errorMessage: String? = nil
        
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let status = json["status"] as? String, status == "success" {
                self.currentEmail = email
                if let token = json["token"] as? String {
                    self.authToken = token
                }
                if let role = json["role"] as? String {
                    self.userRole = role
                }
                if let adminId = json["admin_id"] as? Int {
                    UserDefaults.standard.set(adminId, forKey: "adminID")
                }
                let returnedName = json["name"] as? String
                return (true, returnedName, nil)
            } else if let msg = json["message"] as? String {
                errorMessage = msg
            }
        } else if let plainTextMsg = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines), !plainTextMsg.isEmpty {
            errorMessage = plainTextMsg
        }
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            return (false, nil, errorMessage ?? "Registration failed")
        }
        
        return (false, nil, errorMessage ?? "Registration failed")
    }
    
    func fetchRooms() async throws -> Data {
        // ตัวอย่างการดึงข้อมูลห้องจาก Go Backend
        guard let url = URL(string: "\(baseURL)/rooms") else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        let (data, _) = try await URLSession.shared.data(for: request)
        return data
    }
    
    // เพิ่มฟังก์ชัน push/pull ข้อมูลอื่นๆ ได้ที่นี่
    
    // MARK: - Admin Management APIs
    
    func fetchAdmins() async throws -> [Admin] {
        guard let url = URL(string: "\(baseURL)/admins") else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        if httpResponse.statusCode != 200 {
            let errorMsg = String(data: data, encoding: .utf8) ?? "Unknown Error"
            throw NSError(domain: "", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Server Error: \(errorMsg)"])
        }
        
        do {
            let admins = try JSONDecoder().decode([Admin].self, from: data)
            return admins
        } catch {
            let jsonString = String(data: data, encoding: .utf8) ?? ""
            print("Decode Error: \(error)\nRaw JSON: \(jsonString)")
            throw error
        }
    }
    
    // MARK: - Dashboard APIs
    
    func fetchDashboardStats() async throws -> Data {
        return try await performGetRequest(path: "/dashboard-stats")
    }
    
    func fetchUsersData() async throws -> Data {
        return try await performGetRequest(path: "/users")
    }
    
    func fetchPaymentsData() async throws -> Data {
        return try await performGetRequest(path: "/payments")
    }
    
    func fetchLogsData() async throws -> Data {
        return try await performGetRequest(path: "/logs")
    }
    
    func fetchRoomTypesData() async throws -> Data {
        return try await performGetRequest(path: "/room-types")
    }
    
    func fetchMaintenancesData() async throws -> Data {
        return try await performGetRequest(path: "/maintenances")
    }

    func fetchLatestSyncSnapshot() async throws -> Data {
        return try await performGetRequest(path: "/sync/latest")
    }

    func fetchSyncMetadata() async throws -> Data {
        return try await performGetRequest(path: "/sync/meta")
    }

    func pushSyncSnapshot(payload: Data, deviceID: String) async throws -> Data {
        guard let url = URL(string: "\(baseURL)/sync/push") else { throw URLError(.badURL) }
        guard let payloadObject = try JSONSerialization.jsonObject(with: payload) as? [String: Any] else {
            throw URLError(.cannotParseResponse)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "payload": payloadObject,
            "device_id": deviceID,
            "client_updated_at": ISO8601DateFormatter().string(from: Date())
        ])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        if httpResponse.statusCode != 200 {
            let errorMsg = String(data: data, encoding: .utf8) ?? "Server Error"
            throw NSError(domain: "", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMsg])
        }
        return data
    }
    
    private func performGetRequest(path: String) async throws -> Data {
        guard let url = URL(string: "\(baseURL)\(path)") else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        if httpResponse.statusCode != 200 {
            throw NSError(domain: "", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Server Error"])
        }
        
        return data
    }
    
    func deleteAdmin(id: Int) async throws -> Bool {
        guard let url = URL(string: "\(baseURL)/admins/\(id)") else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        let (_, response) = try await URLSession.shared.data(for: request)
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
            return true
        }
        return false
    }
    
    func updateAdmin(id: Int, username: String, email: String, backupEmail: String = "", oldPassword: String? = nil, newPassword: String?) async throws -> Bool {
        guard let url = URL(string: "\(baseURL)/admins/\(id)") else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        var body: [String: Any] = [
            "username": username,
            "email": email,
            "backup_email": backupEmail
        ]
        if let newPassword = newPassword, !newPassword.isEmpty {
            body["new_password"] = newPassword
            if let oldPassword = oldPassword, !oldPassword.isEmpty {
                body["old_password"] = oldPassword
            }
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
            return true
        } else {
            let errorMsg = String(data: data, encoding: .utf8) ?? "Unknown Error"
            throw NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: errorMsg])
        }
    }
    
    func getLocalProfileImageURL(adminID: Int) -> URL? {
        let fileManager = FileManager.default
        if let docsDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
            let fileURL = docsDir.appendingPathComponent("profile_\(adminID).jpg")
            if fileManager.fileExists(atPath: fileURL.path) {
                return fileURL
            }
        }
        return nil
    }

    func saveProfileImageLocally(adminID: Int, imageData: Data) async throws -> Bool {
        let fileManager = FileManager.default
        guard let docsDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return false
        }
        
        let fileURL = docsDir.appendingPathComponent("profile_\(adminID).jpg")
        do {
            try imageData.write(to: fileURL)
            // Update token to refresh image across the app
            DispatchQueue.main.async {
                UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "profileImageUpdateToken")
            }
            return true
        } catch {
            print("Local save failed: \(error)")
            throw error
        }
    }
}

// MARK: - Models
struct Admin: Identifiable, Codable {
    let id: Int
    let username: String
    let role: String
    let email: String
    let profile_image: String?
    let backup_email: String?
    
    init(id: Int, username: String, role: String, email: String, profile_image: String? = nil, backup_email: String? = nil) {
        self.id = id
        self.username = username
        self.role = role
        self.email = email
        self.profile_image = profile_image
        self.backup_email = backup_email
    }
}
