import Foundation
import SwiftUI
import Combine
import SwiftData

struct APIDashboardStats: Codable {
    var total_residents: Int
    var empty_rooms: Int
    var income_this_month: Double
    var billing_cycle_income: Double
    var pending_bills: Int
}

struct APIUser: Codable, Identifiable {
    var id: Int
    var prefix: String?
    var first_name: String?
    var last_name: String?
    var room_number: String?
    var status: String?
    var national_id: String?
    var phone: String?
    var address: String?
    var move_in_date: String?
    var contract_end_date: String?
    var deposit: Double?
    var booking_status: String?
    var booking_end_date: String?
    var payment_method: String?
    var payment_channel: String?
    var installment_months: Int?
    var installment_amount: Double?
    var indefinite_contract: Int?
    var booking_slips: [String]?
    var additional_appliances: String?
    var additional_appliance_fee: Double?
    var additional_details: String?

    init(
        id: Int,
        prefix: String? = nil,
        first_name: String? = nil,
        last_name: String? = nil,
        room_number: String? = nil,
        status: String? = nil,
        national_id: String? = nil,
        phone: String? = nil,
        address: String? = nil,
        move_in_date: String? = nil,
        contract_end_date: String? = nil,
        deposit: Double? = nil,
        booking_status: String? = nil,
        booking_end_date: String? = nil,
        payment_method: String? = nil,
        payment_channel: String? = nil,
        installment_months: Int? = nil,
        installment_amount: Double? = nil,
        indefinite_contract: Int? = nil,
        booking_slips: [String]? = nil,
        additional_appliances: String? = nil,
        additional_appliance_fee: Double? = nil,
        additional_details: String? = nil
    ) {
        self.id = id
        self.prefix = prefix
        self.first_name = first_name
        self.last_name = last_name
        self.room_number = room_number
        self.status = status
        self.national_id = national_id
        self.phone = phone
        self.address = address
        self.move_in_date = move_in_date
        self.contract_end_date = contract_end_date
        self.deposit = deposit
        self.booking_status = booking_status
        self.booking_end_date = booking_end_date
        self.payment_method = payment_method
        self.payment_channel = payment_channel
        self.installment_months = installment_months
        self.installment_amount = installment_amount
        self.indefinite_contract = indefinite_contract
        self.booking_slips = booking_slips
        self.additional_appliances = additional_appliances
        self.additional_appliance_fee = additional_appliance_fee
        self.additional_details = additional_details
    }
}

struct APIPayment: Codable, Identifiable {
    var id: Int
    var user_id: Int?
    var month: String?
    var payment_status: String?
    var amount: Double?
    var payment_date: String?
}

struct APIRoom: Codable {
    var room_number: String?
    var room_type: String?
}

struct APIRoomType: Codable {
    var name: String?
    var price: Double?
}

struct APIMaintenance: Codable, Identifiable {
    var id: Int
    var status: String?
}

struct APILog: Codable, Identifiable {
    var id: Int
    var action: String?
    var admin: String?
    var timestamp: String?
}

struct MoveInStat: Identifiable {
    let id = UUID()
    let name: String
    let monthKey: String
    let newResidents: Int
}

struct FinancialStat: Identifiable {
    let id = UUID()
    let month: String
    let name: String
    let income: Double
    let pending: Double
}

@MainActor
class DashboardViewModel: ObservableObject {
    @Published var stats = APIDashboardStats(total_residents: 0, empty_rooms: 0, income_this_month: 0, billing_cycle_income: 0, pending_bills: 0)
    
    @Published var moveInStats: [MoveInStat] = []
    @Published var financialStats: [FinancialStat] = []
    
    @Published var pendingMaints: Int = 0
    @Published var inProgressMaints: Int = 0
    @Published var completedMaints: Int = 0
    
    @Published var depositThisMonth: Double = 0
    
    @Published var pendingUsers: [APIUser] = []
    @Published var expiringContracts: [APIUser] = []
    @Published var recentLogs: [APILog] = []
    
    @Published var isLoading = true
    @Published var errorMessage: String?

    func fetchLocalData(modelContext: ModelContext) {
        isLoading = true
        errorMessage = nil

        do {
            let users = try modelContext.fetch(FetchDescriptor<DormUser>())
            let rooms = try modelContext.fetch(FetchDescriptor<Room>())
            let payments = try modelContext.fetch(FetchDescriptor<Payment>())
            let maintenances = try modelContext.fetch(FetchDescriptor<Maintenance>())

            let activeUsers = users.filter { $0.status == "กำลังพักอาศัย" }
            let currentMonth = monthKey(for: Date())
            let currentPayments = payments.filter { $0.month == currentMonth }
            let received = currentPayments.filter { $0.paymentStatus == "paid" }.reduce(0) { $0 + $1.paidAmount }
            let pending = currentPayments.filter { $0.paymentStatus != "paid" }

            stats = APIDashboardStats(
                total_residents: activeUsers.count,
                empty_rooms: max(rooms.count - activeUsers.count, 0),
                income_this_month: received,
                billing_cycle_income: currentPayments.reduce(0) { $0 + $1.amount },
                pending_bills: pending.count
            )
            pendingUsers = activeUsers.filter { user in
                !currentPayments.contains { payment in
                    payment.userId == (user.serverId ?? Int(truncatingIfNeeded: user.id.hashValue)) && payment.paymentStatus == "paid"
                }
            }.map { user in
                APIUser(id: user.serverId ?? Int(truncatingIfNeeded: user.id.hashValue), prefix: user.prefix, first_name: user.firstName, last_name: user.lastName, room_number: user.roomNumber, status: user.status, phone: user.phone, move_in_date: user.moveInDate, booking_end_date: user.bookingEndDate, payment_method: user.paymentMethod, payment_channel: user.paymentChannel, installment_months: user.installmentMonths, installment_amount: user.installmentAmount, booking_slips: user.bookingSlips)
            }
            pendingMaints = maintenances.filter { $0.status == "รอดำเนินการ" }.count
            inProgressMaints = maintenances.filter { $0.status == "กำลังดำเนินการ" || $0.status == "กำลังซ่อม" }.count
            completedMaints = maintenances.filter { $0.status == "เสร็จสิ้น" }.count
            depositThisMonth = users.filter { $0.moveInDate.hasPrefix(currentMonth) }.reduce(0) { $0 + $1.deposit }
            financialStats = financialStatsFrom(payments: payments)
            moveInStats = moveInStatsFrom(users: users)
        } catch {
            errorMessage = "ไม่สามารถโหลดข้อมูลจากเครื่องได้"
        }

        isLoading = false
    }

    private func monthKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: date)
    }

    private func financialStatsFrom(payments: [Payment]) -> [FinancialStat] {
        let grouped = Dictionary(grouping: payments, by: { $0.month })
        return grouped.keys.sorted().suffix(6).map { month in
            let monthPayments = grouped[month] ?? []
            return FinancialStat(month: month, name: month, income: monthPayments.filter { $0.paymentStatus == "paid" }.reduce(0) { $0 + $1.paidAmount }, pending: monthPayments.filter { $0.paymentStatus != "paid" }.reduce(0) { $0 + $1.amount })
        }
    }

    private func moveInStatsFrom(users: [DormUser]) -> [MoveInStat] {
        let grouped = Dictionary(grouping: users.filter { !$0.moveInDate.isEmpty }, by: { String($0.moveInDate.prefix(7)) })
        return grouped.keys.sorted().suffix(6).map { month in
            MoveInStat(name: month, monthKey: month, newResidents: grouped[month]?.count ?? 0)
        }
    }
    
    func fetchAllData() async {
        isLoading = true
        errorMessage = nil
        
        do {
            async let statsData = APIService.shared.fetchDashboardStats()
            async let usersData = APIService.shared.fetchUsersData()
            async let paymentsData = APIService.shared.fetchPaymentsData()
            async let roomsData = APIService.shared.fetchRooms()
            async let roomTypesData = APIService.shared.fetchRoomTypesData()
            async let logsData = APIService.shared.fetchLogsData()
            async let maintenancesData = APIService.shared.fetchMaintenancesData()
            
            let (dStats, dUsers, dPayments, dRooms, dRoomTypes, dLogs, dMaints) = try await (statsData, usersData, paymentsData, roomsData, roomTypesData, logsData, maintenancesData)
            
            let decoder = JSONDecoder()
            let parsedStats = try? decoder.decode(APIDashboardStats.self, from: dStats)
            let users = (try? decoder.decode([APIUser].self, from: dUsers)) ?? []
            let payments = (try? decoder.decode([APIPayment].self, from: dPayments)) ?? []
            let rooms = (try? decoder.decode([APIRoom].self, from: dRooms)) ?? []
            let roomTypes = (try? decoder.decode([APIRoomType].self, from: dRoomTypes)) ?? []
            let logs = (try? decoder.decode([APILog].self, from: dLogs)) ?? []
            let maintenances = (try? decoder.decode([APIMaintenance].self, from: dMaints)) ?? []
            
            if let ps = parsedStats {
                self.stats = ps
            }
            
            // Maintenance stats
            self.pendingMaints = maintenances.filter { $0.status == "รอดำเนินการ" }.count
            self.inProgressMaints = maintenances.filter { $0.status == "กำลังดำเนินการ" || $0.status == "กำลังซ่อม" }.count
            self.completedMaints = maintenances.filter { $0.status == "เสร็จสิ้น" }.count
            
            self.recentLogs = Array(logs.prefix(10))
            
            // Process Users & Payments
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM"
            let currentMonthString = dateFormatter.string(from: Date())
            
            let activeUsers = users.filter { $0.status == "กำลังพักอาศัย" }
            
            // Pending Bills
            let unpaid = activeUsers.filter { u in
                !payments.contains(where: { p in
                    p.user_id == u.id && p.month == currentMonthString && p.payment_status == "paid"
                })
            }
            self.pendingUsers = unpaid.sorted { ($0.room_number ?? "") < ($1.room_number ?? "") }
            
            // Expiring Contracts
            let dfFull = DateFormatter()
            dfFull.dateFormat = "yyyy-MM-dd"
            let upcoming = activeUsers.filter { $0.contract_end_date != nil && $0.contract_end_date != "" }
                .sorted {
                    let d1 = dfFull.date(from: $0.contract_end_date!) ?? Date.distantFuture
                    let d2 = dfFull.date(from: $1.contract_end_date!) ?? Date.distantFuture
                    return d1 < d2
                }
            self.expiringContracts = Array(upcoming.prefix(5))
            
            // Monthly Move-in & Deposit
            var monthlyMoveIn: [String: (Int, Double)] = [:]
            var currentDeposit: Double = 0
            
            for u in users {
                guard let moveIn = u.move_in_date, u.status != "ยกเลิก", u.status != "ย้ายออกแล้ว", moveIn.count >= 7 else { continue }
                let monthKey = String(moveIn.prefix(7))
                
                let dep = u.deposit ?? 0
                if monthlyMoveIn[monthKey] == nil {
                    monthlyMoveIn[monthKey] = (0, 0)
                }
                monthlyMoveIn[monthKey]!.0 += 1
                monthlyMoveIn[monthKey]!.1 += dep
                
                if monthKey == currentMonthString {
                    currentDeposit += dep
                }
            }
            self.depositThisMonth = currentDeposit
            
            // Sort Move-In Stats
            let sortedMoveInKeys = monthlyMoveIn.keys.sorted().suffix(6)
            self.moveInStats = sortedMoveInKeys.map { key in
                let parts = key.split(separator: "-")
                var name = key
                if parts.count == 2, let m = Int(parts[1]), let y = Int(parts[0]) {
                    let monthNames = ["ม.ค.", "ก.พ.", "มี.ค.", "เม.ย.", "พ.ค.", "มิ.ย.", "ก.ค.", "ส.ค.", "ก.ย.", "ต.ค.", "พ.ย.", "ธ.ค."]
                    if m >= 1 && m <= 12 {
                        name = "\(monthNames[m-1]) \(y % 100)"
                    }
                }
                return MoveInStat(name: name, monthKey: key, newResidents: monthlyMoveIn[key]!.0)
            }
            
            // Financial Trends
            var payStats: [String: (Double, Double)] = [:]
            let cal = Calendar.current
            let now = Date()
            
            for i in (0...5).reversed() {
                if let pastDate = cal.date(byAdding: .month, value: -i, to: now) {
                    let mKey = dateFormatter.string(from: pastDate)
                    payStats[mKey] = (0, 0)
                }
            }
            
            for p in payments {
                let amt = p.amount ?? 0
                if amt > 0 {
                    if p.payment_status == "paid" {
                        var dateKey = p.month ?? "Unknown"
                        if let pd = p.payment_date, pd.count >= 7 {
                            dateKey = String(pd.prefix(7))
                        }
                        if payStats[dateKey] == nil { payStats[dateKey] = (0, 0) }
                        payStats[dateKey]!.0 += amt
                    } else {
                        let mKey = p.month ?? "Unknown"
                        if payStats[mKey] == nil { payStats[mKey] = (0, 0) }
                        payStats[mKey]!.1 += amt
                    }
                }
            }
            
            let sortedPayKeys = payStats.keys.sorted().suffix(6)
            self.financialStats = sortedPayKeys.map { key in
                let parts = key.split(separator: "-")
                var name = key
                if parts.count == 2, let m = Int(parts[1]), let y = Int(parts[0]) {
                    let monthNames = ["ม.ค.", "ก.พ.", "มี.ค.", "เม.ย.", "พ.ค.", "มิ.ย.", "ก.ค.", "ส.ค.", "ก.ย.", "ต.ค.", "พ.ย.", "ธ.ค."]
                    if m >= 1 && m <= 12 {
                        name = "\(monthNames[m-1]) \(y % 100)"
                    }
                }
                return FinancialStat(month: key, name: name, income: payStats[key]!.0, pending: payStats[key]!.1)
            }
            
        } catch {
            print("Dashboard Fetch Error: \(error)")
            self.errorMessage = "ไม่สามารถโหลดข้อมูลได้"
        }
        
        self.isLoading = false
    }
}
