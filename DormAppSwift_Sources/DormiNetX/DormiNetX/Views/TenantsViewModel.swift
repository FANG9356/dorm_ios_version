import Foundation
import SwiftUI
import Combine
import SwiftData

@MainActor
class TenantsViewModel: ObservableObject {
    @Published var users: [APIUser] = []
    @Published var searchText: String = ""
    @Published var activeTab: String = "all"  // all, active, booking, inactive
    @Published var sortBy: String = "room_asc"
    @Published var isLoading: Bool = true
    @Published var errorMessage: String?
    
    var filteredUsers: [APIUser] {
        var result = users
        
        // Filter by tab
        switch activeTab {
        case "active":
            result = result.filter { $0.status == "กำลังพักอาศัย" }
        case "booking":
            result = result.filter { $0.status == "จอง" }
        case "inactive":
            result = result.filter { $0.status == "ย้ายออกแล้ว" }
        default:
            break
        }
        
        // Filter by search
        if !searchText.isEmpty {
            let term = searchText.lowercased()
            result = result.filter { user in
                (user.room_number ?? "").lowercased().contains(term) ||
                (user.first_name ?? "").lowercased().contains(term) ||
                (user.last_name ?? "").lowercased().contains(term) ||
                (user.phone ?? "").contains(term)
            }
        }
        
        // Sort
        switch sortBy {
        case "room_asc":
            result.sort { ($0.room_number ?? "") < ($1.room_number ?? "") }
        case "room_desc":
            result.sort { ($0.room_number ?? "") > ($1.room_number ?? "") }
        case "status_active":
            result.sort { a, b in
                if a.status == b.status { return (a.room_number ?? "") < (b.room_number ?? "") }
                return a.status == "กำลังพักอาศัย"
            }
        case "status_inactive":
            result.sort { a, b in
                if a.status == b.status { return (a.room_number ?? "") < (b.room_number ?? "") }
                return a.status == "ย้ายออกแล้ว"
            }
        default:
            break
        }
        
        return result
    }
    
    var allCount: Int { users.count }
    var activeCount: Int { users.filter { $0.status == "กำลังพักอาศัย" }.count }
    var bookingCount: Int { users.filter { $0.status == "จอง" }.count }
    var inactiveCount: Int { users.filter { $0.status == "ย้ายออกแล้ว" }.count }
    
    func fetchUsers(modelContext: ModelContext? = nil) async {
        isLoading = true
        errorMessage = nil
        if let modelContext {
            do {
                let localUsers = try modelContext.fetch(FetchDescriptor<DormUser>())
                self.users = localUsers.map { user in
                    APIUser(
                        id: user.serverId ?? Int(truncatingIfNeeded: user.id.hashValue),
                        prefix: user.prefix,
                        first_name: user.firstName,
                        last_name: user.lastName,
                        room_number: user.roomNumber,
                        status: user.status,
                        national_id: user.nationalID,
                        phone: user.phone,
                        address: user.address,
                        move_in_date: user.moveInDate,
                        contract_end_date: user.contractEndDate,
                        deposit: user.deposit,
                        booking_status: user.bookingStatus,
                        booking_end_date: user.bookingEndDate,
                        payment_method: user.paymentMethod,
                        payment_channel: user.paymentChannel,
                        installment_months: user.installmentMonths,
                        installment_amount: user.installmentAmount,
                        indefinite_contract: user.indefiniteContract,
                        booking_slips: user.bookingSlips,
                        additional_appliances: user.additionalAppliances,
                        additional_appliance_fee: user.additionalApplianceFee,
                        additional_details: user.additionalDetails
                    )
                }
            } catch {
                self.errorMessage = "ไม่สามารถโหลดข้อมูลลูกบ้านในเครื่องได้"
            }
            isLoading = false
            return
        }
        do {
            let data = try await APIService.shared.fetchUsersData()
            let decoded = try JSONDecoder().decode([APIUser].self, from: data)
            self.users = decoded
        } catch {
            print("TenantsViewModel fetch error: \(error)")
            self.errorMessage = "ไม่สามารถโหลดข้อมูลลูกบ้านได้"
        }
        isLoading = false
    }
    
    func deleteUser(id: Int, modelContext: ModelContext? = nil) async -> Bool {
        if let modelContext {
            do {
                let localUsers = try modelContext.fetch(FetchDescriptor<DormUser>())
                if let user = localUsers.first(where: { ($0.serverId ?? Int(truncatingIfNeeded: $0.id.hashValue)) == id }) {
                    user.isDeletedLocally = true
                    user.isDirty = true
                    user.lastUpdated = Date()
                    try modelContext.save()
                    await SyncManager.shared.autoPushLocalChanges(modelContext: modelContext)
                    users.removeAll { $0.id == id }
                    return true
                }
            } catch {
                print("Delete local user error: \(error)")
            }
            return false
        }
        guard let url = URL(string: "\(APIService.shared.baseURL)/users?id=\(id)") else { return false }
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        if let token = APIService.shared.authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, http.statusCode == 200 {
                users.removeAll { $0.id == id }
                return true
            }
        } catch {
            print("Delete user error: \(error)")
        }
        return false
    }
    
    func formatPhone(_ phone: String?) -> String {
        guard let p = phone, p.count == 10 else { return phone ?? "-" }
        return "\(p.prefix(3))-\(p.dropFirst(3).prefix(3))-\(p.suffix(4))"
    }
    
    func statusColor(_ status: String?) -> Color {
        switch status {
        case "กำลังพักอาศัย": return .green
        case "จอง": return .orange
        case "ย้ายออกแล้ว": return .red
        default: return .gray
        }
    }
    
    func statusIcon(_ status: String?) -> String {
        switch status {
        case "กำลังพักอาศัย": return "checkmark.circle.fill"
        case "จอง": return "clock.fill"
        case "ย้ายออกแล้ว": return "arrow.right.circle.fill"
        default: return "questionmark.circle"
        }
    }
}
