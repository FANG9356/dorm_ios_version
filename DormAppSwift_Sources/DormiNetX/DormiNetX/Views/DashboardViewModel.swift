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
    
    // Sync Metadata
    var isDirty: Bool? = false
    var isDeletedLocally: Bool? = false

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
        self.isDirty = false
        self.isDeletedLocally = false
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

struct MaintenanceCounts: Equatable {
    let pending: Int
    let inProgress: Int
    let completed: Int

    var total: Int { pending + inProgress + completed }
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
            updateLocalData(users: users, rooms: rooms, payments: payments, maintenances: maintenances)
        } catch {
            errorMessage = String(localized: "ไม่สามารถโหลดข้อมูลจากเครื่องได้")
            isLoading = false
        }
    }

    func updateLocalData(users rawUsers: [DormUser], rooms rawRooms: [Room], payments rawPayments: [Payment], maintenances rawMaintenances: [Maintenance]) {
        isLoading = true
        errorMessage = nil

        let users = rawUsers.filter { !$0.isDeletedLocally }
        let rooms = rawRooms.filter { !$0.isDeletedLocally }
        let payments = rawPayments.filter { !$0.isDeletedLocally }
        let maintenances = rawMaintenances.filter { !$0.isDeletedLocally }
        let activeUsers = users.filter { $0.status == "กำลังพักอาศัย" }
        let currentMonth = monthKey(for: Date())
        let currentPayments = payments.filter { BillingCycle.normalizedMonthKey($0.month) == currentMonth }
        let received = currentPayments.filter { $0.paymentStatus == "paid" }.reduce(0) { $0 + ($1.paidAmount ?? 0.0) }
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
                payment.userId == stableLocalUserID(for: user) && payment.paymentStatus == "paid"
            }
        }.map { user in
            APIUser(id: stableLocalUserID(for: user), prefix: user.prefix, first_name: user.firstName, last_name: user.lastName, room_number: user.roomNumber, status: user.status, phone: user.phone, move_in_date: user.moveInDate, booking_end_date: user.bookingEndDate, payment_method: user.paymentMethod, payment_channel: user.paymentChannel, installment_months: user.installmentMonths, installment_amount: user.installmentAmount, booking_slips: user.bookingSlips)
        }
        applyMaintenanceCounts(Self.maintenanceCounts(for: maintenances.map { $0.status }))
        depositThisMonth = users.filter {
            BillingCycle.normalizedMonthKey(String($0.moveInDate.prefix(7))) == currentMonth
        }.reduce(0) { $0 + $1.deposit }
        financialStats = financialStatsFrom(payments: payments)
        moveInStats = moveInStatsFrom(users: users)
        isLoading = false
    }

    private func monthKey(for date: Date) -> String {
        AppDate.monthKey(from: date)
    }

    static func maintenanceCounts(for statuses: [String?]) -> MaintenanceCounts {
        var pending = 0
        var inProgress = 0
        var completed = 0

        for rawStatus in statuses {
            switch rawStatus?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "" {
            case "", "รอดำเนินการ":
                pending += 1
            case "เสร็จสิ้น":
                completed += 1
            default:
                // Includes กำลังดำเนินการ, กำลังติดต่อช่าง, กำลังซ่อม,
                // รอตรวจสอบชำระเงิน and any future non-final workflow state.
                inProgress += 1
            }
        }
        return MaintenanceCounts(pending: pending, inProgress: inProgress, completed: completed)
    }

    private func applyMaintenanceCounts(_ counts: MaintenanceCounts) {
        pendingMaints = counts.pending
        inProgressMaints = counts.inProgress
        completedMaints = counts.completed
    }

    private func financialStatsFrom(payments: [Payment]) -> [FinancialStat] {
        let grouped = Dictionary(grouping: payments) {
            BillingCycle.normalizedMonthKey($0.month) ?? $0.month
        }
        return grouped.keys.sorted().suffix(6).map { month in
            let monthPayments = grouped[month] ?? []
            return FinancialStat(month: month, name: AppDate.thaiShortMonth(month), income: monthPayments.filter { $0.paymentStatus == "paid" }.reduce(0) { $0 + ($1.paidAmount ?? 0.0) }, pending: monthPayments.filter { $0.paymentStatus != "paid" }.reduce(0) { $0 + $1.amount })
        }
    }

    private func moveInStatsFrom(users: [DormUser]) -> [MoveInStat] {
        let grouped = Dictionary(grouping: users.filter { !$0.moveInDate.isEmpty }) {
            BillingCycle.normalizedMonthKey(String($0.moveInDate.prefix(7))) ?? String($0.moveInDate.prefix(7))
        }
        return grouped.keys.sorted().suffix(6).map { month in
            MoveInStat(name: AppDate.thaiShortMonth(month), monthKey: month, newResidents: grouped[month]?.count ?? 0)
        }
    }
    
    func fetchAllData() async {
        isLoading = true
        errorMessage = nil
        
        do {
            async let statsData = APIService.shared.fetchDashboardStats()
            async let usersData = APIService.shared.fetchUsersData()
            async let paymentsData = APIService.shared.fetchPaymentsData()
            async let logsData = APIService.shared.fetchLogsData()
            async let maintenancesData = APIService.shared.fetchMaintenancesData()
            
            let (dStats, dUsers, dPayments, dLogs, dMaints) = try await (statsData, usersData, paymentsData, logsData, maintenancesData)
            
            let decoder = JSONDecoder()
            let parsedStats = try? decoder.decode(APIDashboardStats.self, from: dStats)
            let users = (try? decoder.decode([APIUser].self, from: dUsers)) ?? []
            let payments = (try? decoder.decode([APIPayment].self, from: dPayments)) ?? []
            let logs = (try? decoder.decode([APILog].self, from: dLogs)) ?? []
            let maintenances = (try? decoder.decode([APIMaintenance].self, from: dMaints)) ?? []
            
            if let ps = parsedStats {
                self.stats = ps
            }
            
            // Maintenance stats
            self.applyMaintenanceCounts(Self.maintenanceCounts(for: maintenances.map(\.status)))
            
            self.recentLogs = Array(logs.prefix(10))
            
            // Process Users & Payments
            let dateFormatter = DateFormatter()
            dateFormatter.locale = Locale(identifier: "en_US_POSIX")
            dateFormatter.calendar = Calendar(identifier: .gregorian)
            dateFormatter.timeZone = TimeZone(identifier: "Asia/Bangkok")
            dateFormatter.dateFormat = "yyyy-MM"
            let currentMonthString = dateFormatter.string(from: Date())
            
            let activeUsers = users.filter { $0.status == "กำลังพักอาศัย" }
            
            // Pending Bills
            let unpaid = activeUsers.filter { u in
                !payments.contains(where: { p in
                    p.user_id == u.id && BillingCycle.normalizedMonthKey(p.month ?? "") == currentMonthString && p.payment_status == "paid"
                })
            }
            self.pendingUsers = unpaid.sorted { ($0.room_number ?? "") < ($1.room_number ?? "") }
            
            // Expiring Contracts
            let upcoming = activeUsers.filter { $0.contract_end_date != nil && $0.contract_end_date != "" }
                .sorted {
                    let d1 = AppDate.date(fromStorageDate: $0.contract_end_date ?? "") ?? Date.distantFuture
                    let d2 = AppDate.date(fromStorageDate: $1.contract_end_date ?? "") ?? Date.distantFuture
                    return d1 < d2
                }
            self.expiringContracts = Array(upcoming.prefix(5))
            
            // Monthly Move-in & Deposit
            var monthlyMoveIn: [String: (Int, Double)] = [:]
            var currentDeposit: Double = 0
            
            for u in users {
                guard let moveIn = u.move_in_date, u.status != "ยกเลิก", u.status != "ย้ายออกแล้ว", moveIn.count >= 7 else { continue }
                guard let monthKey = BillingCycle.normalizedMonthKey(String(moveIn.prefix(7))) else { continue }
                
                let dep = u.deposit ?? 0
                monthlyMoveIn[monthKey, default: (0, 0)].0 += 1
                monthlyMoveIn[monthKey, default: (0, 0)].1 += dep
                
                if monthKey == currentMonthString {
                    currentDeposit += dep
                }
            }
            self.depositThisMonth = currentDeposit
            
            // Sort Move-In Stats
            let sortedMoveInKeys = monthlyMoveIn.keys.sorted().suffix(6)
            self.moveInStats = sortedMoveInKeys.map { key in
                MoveInStat(name: AppDate.thaiShortMonth(key), monthKey: key, newResidents: monthlyMoveIn[key]?.0 ?? 0)
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
                        var dateKey = BillingCycle.normalizedMonthKey(p.month ?? "") ?? "Unknown"
                        if let pd = p.payment_date, pd.count >= 7 {
                            dateKey = BillingCycle.normalizedMonthKey(String(pd.prefix(7))) ?? dateKey
                        }
                        payStats[dateKey, default: (0, 0)].0 += amt
                    } else {
                        let mKey = BillingCycle.normalizedMonthKey(p.month ?? "") ?? "Unknown"
                        payStats[mKey, default: (0, 0)].1 += amt
                    }
                }
            }
            
            let sortedPayKeys = payStats.keys.sorted().suffix(6)
            self.financialStats = sortedPayKeys.map { key in
                FinancialStat(month: key, name: AppDate.thaiShortMonth(key), income: payStats[key]?.0 ?? 0, pending: payStats[key]?.1 ?? 0)
            }
            
        } catch {
            print("Dashboard Fetch Error: \(error)")
            self.errorMessage = String(localized: "ไม่สามารถโหลดข้อมูลได้")
        }
        
        self.isLoading = false
    }
}
