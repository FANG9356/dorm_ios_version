import Foundation
import SwiftData

@MainActor
enum RoomTransferService {
    static func move(_ tenant: DormUser, to roomNumber: String, in context: ModelContext) throws {
        let destination = roomNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        let rooms = try context.fetch(FetchDescriptor<Room>())
        let tenants = try context.fetch(FetchDescriptor<DormUser>())
        guard rooms.contains(where: { !$0.isDeletedLocally && $0.roomNumber == destination }) else {
            throw TransferError.missingRoom
        }
        guard !tenants.contains(where: {
            $0.id != tenant.id && !$0.isDeletedLocally && $0.status != "ย้ายออกแล้ว" &&
            $0.roomNumber.trimmingCharacters(in: .whitespacesAndNewlines) == destination
        }) else { throw TransferError.occupiedRoom }

        let previous = tenant.roomNumber
        guard previous != destination else { return }
        try relinkPayments(for: tenant, from: previous, to: destination, in: context)
        tenant.roomNumber = destination
        tenant.lastUpdated = Date()
        tenant.isDirty = true
        context.insert(LocalSystemLog(action: "ย้ายห้อง", details: "\(tenant.firstName) \(tenant.lastName) จากห้อง \(previous) ไปห้อง \(destination)"))
        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }

    static func relinkPayments(for tenant: DormUser, from previous: String, to destination: String,
                               in context: ModelContext) throws {
        guard !previous.isEmpty, previous != destination else { return }
        let userID = stableLocalUserID(for: tenant)
        let payments = try context.fetch(FetchDescriptor<Payment>())
        for payment in payments where !payment.isDeletedLocally {
            let belongs = payment.userId > 0 ? payment.userId == userID : payment.roomNumber == previous
            guard belongs else { continue }
            // Preserve the room printed on a settled receipt, including the current month.
            payment.userId = userID
            if payment.paymentStatus != "paid" { payment.roomNumber = destination }
            payment.lastUpdated = Date()
            payment.isDirty = true
        }
    }

    enum TransferError: LocalizedError {
        case missingRoom, occupiedRoom
        var errorDescription: String? {
            switch self {
            case .missingRoom: return "ไม่พบห้องปลายทาง กรุณาเลือกห้องใหม่"
            case .occupiedRoom: return "ห้องนี้มีผู้พักหรือผู้จองแล้ว กรุณาเลือกห้องอื่น"
            }
        }
    }
}
