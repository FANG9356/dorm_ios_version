import SwiftUI
import SwiftData

struct MaintenanceTabView: View {
    @Binding var showingEditor: Bool
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Maintenance.lastUpdated, order: .reverse) private var allMaintenances: [Maintenance]
    @Query(sort: \Room.roomNumber) private var allRooms: [Room]
    @State private var editingMaintenance: Maintenance?
    @State private var deletingMaintenance: Maintenance?

    private var maintenances: [Maintenance] {
        allMaintenances.filter { !$0.isDeletedLocally }
    }

    private var rooms: [Room] {
        allRooms.filter { !$0.isDeletedLocally }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("งานซ่อมที่ต้องติดตาม")
                        .font(.custom("SukhumvitSet-Bold", size: 24))
                    Text("บันทึกปัญหา ค่าใช้จ่าย และสถานะของแต่ละห้อง")
                        .font(.custom("SukhumvitSet-Text", size: 12))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            if maintenances.isEmpty {
                GlassCard {
                    VStack(spacing: 12) {
                        Image(systemName: "wrench.and.screwdriver.fill")
                            .font(.system(size: 34))
                            .foregroundStyle(.secondary)
                        Text("ยังไม่มีรายการแจ้งซ่อม")
                            .font(.custom("SukhumvitSet-Medium", size: 14))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 28)
                }
            } else {
                ForEach(maintenances) { maintenance in
                    MaintenanceRow(
                        maintenance: maintenance,
                        onStatus: { updateStatus(maintenance, to: $0) },
                        onEdit: { editingMaintenance = maintenance },
                        onDelete: { deletingMaintenance = maintenance }
                    )
                }
            }
        }
        .padding(.top, 106)
        .padding(.horizontal, 20)
        .sheet(isPresented: $showingEditor) {
            MaintenanceEditor(rooms: rooms) { draft in
                draft.isDirty = true
                draft.lastUpdated = Date()
                modelContext.insert(draft)
                saveAndPush()
            }
            .iphoneSheetStyle()
        }
        .sheet(item: $editingMaintenance) { maintenance in
            MaintenanceEditor(maintenance: maintenance, rooms: rooms) { draft in
                maintenance.roomNumber = draft.roomNumber
                maintenance.issue = draft.issue
                maintenance.status = draft.status
                maintenance.cost = draft.cost
                maintenance.paymentMethod = draft.paymentMethod
                maintenance.slipPath = draft.slipPath
                maintenance.issueImage = draft.issueImage
                maintenance.lastUpdated = Date()
                maintenance.isDirty = true
                saveAndPush()
            }
            .iphoneSheetStyle()
        }
        .confirmationDialog("ลบรายการแจ้งซ่อมนี้หรือไม่", isPresented: deleteDialogBinding) {
            Button("ลบรายการห้อง \(deletingMaintenance?.roomNumber ?? "")", role: .destructive) {
                guard let maintenance = deletingMaintenance else { return }
                maintenance.isDeletedLocally = true
                maintenance.isDirty = true
                maintenance.lastUpdated = Date()
                saveAndPush()
                deletingMaintenance = nil
            }
            Button("ยกเลิก", role: .cancel) { }
        }
    }

    private var deleteDialogBinding: Binding<Bool> {
        Binding(
            get: { deletingMaintenance != nil },
            set: { if !$0 { deletingMaintenance = nil } }
        )
    }

    private func updateStatus(_ maintenance: Maintenance, to status: String) {
        maintenance.status = status
        if status == "เสร็จสิ้น" {
            maintenance.resolvedAt = currentDateString()
        }
        maintenance.lastUpdated = Date()
        maintenance.isDirty = true
        saveAndPush()
    }

    private func saveAndPush() {
        do {
            try modelContext.save()
            Task {
                await SyncManager.shared.pushCurrentLocalState(modelContext: modelContext)
            }
        } catch {
            print("Maintenance save error: \(error)")
        }
    }

    private func currentDateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
}

private struct MaintenanceRow: View {
    let maintenance: Maintenance
    let onStatus: (String) -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    private var status: String {
        maintenance.status.isEmpty ? "รอดำเนินการ" : maintenance.status
    }

    private var statusColor: Color {
        switch status {
        case "เสร็จสิ้น": return .green
        case "กำลังซ่อม": return .orange
        case "กำลังติดต่อช่าง": return .purple
        case "รอตรวจสอบชำระเงิน": return .blue
        default: return .secondary
        }
    }

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "wrench.and.screwdriver.fill")
                        .foregroundStyle(.orange)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("ห้อง \(maintenance.roomNumber)")
                            .font(.custom("SukhumvitSet-Bold", size: 15))
                        Text(maintenance.issue)
                            .font(.custom("SukhumvitSet-Text", size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    Spacer()
                    Text(status)
                        .font(.custom("SukhumvitSet-Medium", size: 10))
                        .foregroundStyle(statusColor)
                }

                HStack(spacing: 8) {
                    statusButton("รับงาน", next: "กำลังติดต่อช่าง", enabled: status == "รอดำเนินการ")
                    statusButton("ซ่อม", next: "กำลังซ่อม", enabled: status == "กำลังติดต่อช่าง")
                    statusButton("ปิดงาน", next: "เสร็จสิ้น", enabled: status == "กำลังซ่อม" || status == "รอตรวจสอบชำระเงิน")
                    Spacer()
                    if maintenance.cost > 0 {
                        Text(maintenance.cost.formatted(.number.precision(.fractionLength(0))) + " ฿")
                            .font(.custom("SukhumvitSet-Bold", size: 12))
                    }
                }
            }
        }
        .contextMenu {
            Button(action: onEdit) {
                Label("แก้ไข", systemImage: "pencil")
            }
            Button(role: .destructive, action: onDelete) {
                Label("ลบ", systemImage: "trash")
            }
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive, action: onDelete) {
                Label("ลบ", systemImage: "trash")
            }
            Button(action: onEdit) {
                Label("แก้ไข", systemImage: "pencil")
            }
            .tint(.indigo)
        }
    }

    private func statusButton(_ title: String, next: String, enabled: Bool) -> some View {
        Button {
            onStatus(next)
        } label: {
            Text(title)
                .font(.custom("SukhumvitSet-Bold", size: 10))
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(enabled ? Color.indigo.opacity(0.18) : Color.primary.opacity(0.06), in: Capsule())
        }
        .disabled(!enabled)
    }
}

private struct MaintenanceEditor: View {
    @Environment(\.dismiss) private var dismiss
    let rooms: [Room]
    let onSave: (Maintenance) -> Void
    @State private var roomNumber: String
    @State private var issue: String
    @State private var status: String
    @State private var cost: String
    @State private var paymentMethod: String
    @State private var slipPath: String
    @State private var issueImage: String
    @State private var selectedDetent: PresentationDetent = .large

    private let statuses = ["รอดำเนินการ", "กำลังติดต่อช่าง", "กำลังซ่อม", "รอตรวจสอบชำระเงิน", "เสร็จสิ้น"]

    init(maintenance: Maintenance? = nil, rooms: [Room], onSave: @escaping (Maintenance) -> Void) {
        self.rooms = rooms
        self.onSave = onSave
        _roomNumber = State(initialValue: maintenance?.roomNumber ?? rooms.first?.roomNumber ?? "")
        _issue = State(initialValue: maintenance?.issue ?? "")
        _status = State(initialValue: maintenance?.status.isEmpty == false ? maintenance?.status ?? "รอดำเนินการ" : "รอดำเนินการ")
        _cost = State(initialValue: maintenance.map { String(format: "%.0f", $0.cost) } ?? "")
        _paymentMethod = State(initialValue: maintenance?.paymentMethod ?? "")
        _slipPath = State(initialValue: maintenance?.slipPath ?? "")
        _issueImage = State(initialValue: maintenance?.issueImage ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("รายการซ่อม") {
                    if rooms.isEmpty {
                        TextField("เลขห้อง", text: $roomNumber)
                    } else {
                        Picker("ห้อง", selection: $roomNumber) {
                            ForEach(rooms) { room in
                                Text(room.roomNumber).tag(room.roomNumber)
                            }
                        }
                    }
                    TextField("อาการ/รายละเอียด", text: $issue, axis: .vertical)
                        .lineLimit(3...6)
                    Picker("สถานะ", selection: $status) {
                        ForEach(statuses, id: \.self) { Text($0).tag($0) }
                    }
                }

                Section("ค่าใช้จ่ายและหลักฐาน") {
                    TextField("ค่าใช้จ่าย", text: $cost)
                        .keyboardType(.decimalPad)
                    TextField("ช่องทางชำระเงิน", text: $paymentMethod)
                    TextField("ลิงก์/ชื่อไฟล์สลิป", text: $slipPath)
                    TextField("ลิงก์/ชื่อไฟล์รูปอาการเสีย", text: $issueImage)
                }
            }
            .navigationTitle("งานซ่อม")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("ยกเลิก") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("บันทึก") {
                        let item = Maintenance(roomNumber: clean(roomNumber), issue: clean(issue))
                        item.status = status
                        item.cost = Double(cost) ?? 0
                        item.paymentMethod = clean(paymentMethod)
                        item.slipPath = clean(slipPath)
                        item.issueImage = clean(issueImage)
                        item.reportedAt = currentDateString()
                        if status == "เสร็จสิ้น" {
                            item.resolvedAt = currentDateString()
                        }
                        onSave(item)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(clean(roomNumber).isEmpty || clean(issue).isEmpty)
                }
            }
            .dismissKeyboardOnTap()
            .scrollDismissesKeyboard(.interactively)
        }
        .presentationDetents([.medium, .large], selection: $selectedDetent)
        .presentationDragIndicator(.visible)
    }

    private func clean(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func currentDateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
}
