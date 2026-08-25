import SwiftUI
import SwiftData

struct RoomsTabView: View {
    @Binding var showingEditor: Bool
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Room.roomNumber) private var allRooms: [Room]
    @Query(sort: \DormUser.roomNumber) private var users: [DormUser]
    @State private var movingTenant: DormUser?

    private var rooms: [Room] {
        allRooms.filter { !$0.isDeletedLocally }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("ทะเบียนห้องพัก")
                        .font(.custom("SukhumvitSet-Bold", size: 24))
                    Text("ดูสถานะห้อง ประเภทห้อง และแก้ไขข้อมูลที่บันทึกไว้")
                        .font(.custom("SukhumvitSet-Text", size: 12))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            if rooms.isEmpty {
                emptyState
            } else {
                ForEach(rooms) { room in
                    RoomManagementRow(room: room, tenant: tenant(for: room)) {
                        movingTenant = tenant(for: room)
                    }
                }
            }
        }
        .padding(.top, 106)
        .padding(.horizontal, 20)
        .sheet(item: $movingTenant) { tenant in
            MoveTenantRoomSheet(tenant: tenant, rooms: vacantRooms(including: tenant.roomNumber)) { newRoomNumber in
                tenant.roomNumber = newRoomNumber
                tenant.isDirty = true
                tenant.lastUpdated = Date()
                saveAndPush()
            }
            .iphoneSheetStyle()
        }
    }

    private var emptyState: some View {
        GlassCard {
            VStack(spacing: 12) {
                Image(systemName: "door.left.hand.open")
                    .font(.system(size: 34))
                    .foregroundStyle(.secondary)
                Text("ยังไม่มีข้อมูลห้องพัก")
                    .font(.custom("SukhumvitSet-Medium", size: 14))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 28)
        }
    }

    private func saveAndPush() {
        do {
            try modelContext.save()
            Task {
                await SyncManager.shared.pushCurrentLocalState(modelContext: modelContext)
            }
        } catch {
            print("Room save error: \(error)")
        }
    }

    private var activeUsers: [DormUser] {
        users.filter { !$0.isDeletedLocally && $0.status != "ย้ายออกแล้ว" && !$0.roomNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    private func tenant(for room: Room) -> DormUser? {
        activeUsers.first { clean($0.roomNumber) == clean(room.roomNumber) }
    }

    private func vacantRooms(including currentRoomNumber: String) -> [Room] {
        let occupied = Set(activeUsers.map { clean($0.roomNumber) }.filter { $0 != clean(currentRoomNumber) })
        return rooms.filter { !occupied.contains(clean($0.roomNumber)) }
    }

    private func clean(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private struct RoomManagementRow: View {
    let room: Room
    let tenant: DormUser?
    let onMove: () -> Void

    var body: some View {
        GlassCard {
            HStack {
                Image(systemName: "door.left.hand.open")
                    .foregroundStyle(.indigo)
                VStack(alignment: .leading, spacing: 4) {
                    Text("ห้อง \(room.roomNumber)")
                        .font(.custom("SukhumvitSet-Bold", size: 15))
                    Text(room.roomType.isEmpty ? "ยังไม่ระบุประเภท" : room.roomType)
                        .font(.custom("SukhumvitSet-Text", size: 11))
                        .foregroundStyle(.secondary)
                    if let tenant {
                        Text("\(tenant.firstName) \(tenant.lastName)")
                            .font(.custom("SukhumvitSet-Text", size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                HStack(spacing: 6) {
                    Circle()
                        .fill(tenant == nil ? Color.green : Color.orange)
                        .frame(width: 7, height: 7)
                    Text(tenant == nil ? "ว่าง" : "มีผู้พัก")
                        .font(.custom("SukhumvitSet-Bold", size: 12))
                }
                .foregroundStyle(.secondary)
            }
        }
        .contextMenu {
            if tenant != nil {
                Button(action: onMove) {
                    Label("ย้ายห้อง", systemImage: "arrow.left.arrow.right")
                }
            }
        }
        .swipeActions(edge: .trailing) {
            if tenant != nil {
                Button(action: onMove) {
                    Label("ย้าย", systemImage: "arrow.left.arrow.right")
                }
                .tint(.orange)
            }
        }
    }
}

private struct MoveTenantRoomSheet: View {
    @Environment(\.dismiss) private var dismiss
    let tenant: DormUser
    let rooms: [Room]
    let onSave: (String) -> Void
    @State private var selectedRoom: String
    @State private var selectedDetent: PresentationDetent = .medium

    init(tenant: DormUser, rooms: [Room], onSave: @escaping (String) -> Void) {
        self.tenant = tenant
        self.rooms = rooms
        self.onSave = onSave
        _selectedRoom = State(initialValue: tenant.roomNumber)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("ลูกบ้าน") {
                    Text("\(tenant.firstName) \(tenant.lastName)")
                    Text("ห้องปัจจุบัน \(tenant.roomNumber)")
                        .foregroundStyle(.secondary)
                }

                Section("ย้ายไปห้อง") {
                    Picker("ห้อง", selection: $selectedRoom) {
                        ForEach(rooms) { room in
                            Text("ห้อง \(room.roomNumber) • \(room.roomType)").tag(room.roomNumber)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
            .navigationTitle("ย้ายห้อง")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("ยกเลิก") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("บันทึก") {
                        onSave(selectedRoom)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(selectedRoom.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.medium, .large], selection: $selectedDetent)
        .presentationDragIndicator(.visible)
    }
}
