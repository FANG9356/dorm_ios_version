import SwiftUI
import SwiftData
import UIKit

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
                maintenance.resolvedAt = draft.resolvedAt
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

    private var nextAction: (title: String, status: String)? {
        switch status {
        case "รอดำเนินการ": return ("รับงาน", "กำลังติดต่อช่าง")
        case "กำลังติดต่อช่าง": return ("เริ่มซ่อม", "กำลังซ่อม")
        case "กำลังซ่อม", "รอตรวจสอบชำระเงิน": return ("ปิดงาน", "เสร็จสิ้น")
        default: return nil
        }
    }

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                Button(action: onEdit) {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "wrench.and.screwdriver.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.orange)
                            .frame(width: 34, height: 34)
                            .background(Color.orange.opacity(0.12), in: Circle())
                        VStack(alignment: .leading, spacing: 4) {
                            Text("ห้อง \(maintenance.roomNumber)")
                                .font(.custom("SukhumvitSet-Bold", size: 17))
                            Text(maintenance.issue)
                                .font(.custom("SukhumvitSet-Text", size: 14))
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                        Spacer()
                        Text(status)
                            .font(.custom("SukhumvitSet-Medium", size: 12))
                            .foregroundStyle(statusColor)
                            .padding(.horizontal, 10)
                            .frame(minHeight: 32)
                            .background(statusColor.opacity(0.12), in: Capsule())
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                HStack(spacing: 10) {
                    Button(action: onEdit) {
                        Label("ดู / แก้ไข", systemImage: "pencil")
                            .font(.custom("SukhumvitSet-Bold", size: 14))
                            .frame(maxWidth: .infinity, minHeight: 46)
                    }
                    .buttonStyle(.bordered)
                    .tint(.secondary)

                    if let nextAction {
                        Button {
                            onStatus(nextAction.status)
                        } label: {
                            Label(nextAction.title, systemImage: "arrow.right.circle.fill")
                                .font(.custom("SukhumvitSet-Bold", size: 14))
                                .frame(maxWidth: .infinity, minHeight: 46)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.indigo)
                    }
                }

                if maintenance.cost > 0 {
                    HStack {
                        Text("ค่าใช้จ่าย")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(maintenance.cost.formatted(.number.precision(.fractionLength(0...2))) + " บาท")
                            .font(.custom("SukhumvitSet-Bold", size: 14))
                    }
                    .font(.custom("SukhumvitSet-Text", size: 13))
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
                Section("ห้องและรายละเอียด") {
                    if rooms.isEmpty {
                        TextField("เลขห้อง", text: $roomNumber)
                            .limitedText($roomNumber, maxLength: 10, trimNewlines: true)
                            .font(.custom("SukhumvitSet-Text", size: 17))
                            .frame(minHeight: 50)
                    } else {
                        Picker("ห้อง", selection: $roomNumber) {
                            ForEach(rooms) { room in
                                Text(room.roomNumber).tag(room.roomNumber)
                            }
                        }
                        .font(.custom("SukhumvitSet-Medium", size: 16))
                        .frame(minHeight: 50)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("อาการ / รายละเอียด")
                            .font(.custom("SukhumvitSet-Medium", size: 15))
                        TextField("เช่น ไฟดับ น้ำไม่ไหล หรืออุปกรณ์ชำรุด", text: $issue, axis: .vertical)
                            .font(.custom("SukhumvitSet-Text", size: 17))
                            .lineLimit(4...7)
                            .padding(14)
                            .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
                            .limitedText($issue, maxLength: 300)
                    }
                    .padding(.vertical, 6)
                }

                Section("อัปเดตสถานะ") {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        ForEach(statuses, id: \.self) { item in
                            Button {
                                status = item
                            } label: {
                                HStack(spacing: 7) {
                                    Image(systemName: status == item ? "checkmark.circle.fill" : "circle")
                                    Text(item)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.8)
                                }
                                .font(.custom("SukhumvitSet-Medium", size: 13))
                                .foregroundStyle(status == item ? Color.white : Color.primary)
                                .frame(maxWidth: .infinity, minHeight: 48)
                                .background(status == item ? Color.indigo : Color.primary.opacity(0.07), in: RoundedRectangle(cornerRadius: 14))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 6)
                }

                Section("ค่าใช้จ่าย") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("จำนวนเงิน")
                            .font(.custom("SukhumvitSet-Medium", size: 15))
                        HStack {
                            TextField("0.00", text: $cost)
                                .font(.system(size: 22, weight: .semibold, design: .rounded))
                                .keyboardType(.decimalPad)
                                .decimalInput($cost, maxIntegerDigits: 9, maxFractionDigits: 2)
                            Spacer()
                            Text("บาท")
                                .font(.custom("SukhumvitSet-Medium", size: 16))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 14)
                        .frame(minHeight: 58)
                        .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("ช่องทางชำระ")
                            .font(.custom("SukhumvitSet-Medium", size: 15))
                        TextField("เช่น เงินสด หรือโอนผ่านธนาคาร", text: $paymentMethod)
                            .font(.custom("SukhumvitSet-Text", size: 16))
                            .padding(.horizontal, 14)
                            .frame(minHeight: 54)
                            .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
                            .limitedText($paymentMethod, maxLength: 60, trimNewlines: true)
                    }
                    .padding(.vertical, 4)
                }

                Section("รูปและหลักฐาน") {
                    MaintenanceEvidenceView(title: "รูปอาการเสีย", paths: mediaPaths(issueImage), emptyText: "ยังไม่มีรูปอาการเสีย")
                    MaintenanceEvidenceView(title: "สลิปชำระเงิน", paths: mediaPaths(slipPath), emptyText: "ยังไม่มีสลิปชำระเงิน")
                }
            }
            .navigationTitle("งานซ่อม")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("ยกเลิก") { dismiss() }
                        .font(.custom("SukhumvitSet-Medium", size: 16))
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
                    .font(.custom("SukhumvitSet-Bold", size: 16))
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

    private func mediaPaths(_ value: String) -> [String] {
        value.split(separator: ",").map {
            String($0).trimmingCharacters(in: .whitespacesAndNewlines)
        }.filter { !$0.isEmpty }
    }

    private func currentDateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
}

private struct MaintenanceEvidenceView: View {
    let title: String
    let paths: [String]
    let emptyText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.custom("SukhumvitSet-Medium", size: 15))

            if paths.isEmpty {
                Label(emptyText, systemImage: "photo")
                    .font(.custom("SukhumvitSet-Text", size: 14))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(Array(paths.enumerated()), id: \.offset) { _, path in
                            evidence(path)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func evidence(_ path: String) -> some View {
        if let url = SlipImageManager.url(for: path),
           let image = UIImage(contentsOfFile: url.path) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 112, height: 88)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .accessibilityLabel(title)
        } else {
            VStack(spacing: 6) {
                Image(systemName: "photo.badge.exclamationmark")
                    .font(.system(size: 22))
                Text("ไม่พบไฟล์ในเครื่อง")
                    .font(.custom("SukhumvitSet-Text", size: 11))
            }
            .foregroundStyle(.secondary)
            .frame(width: 130, height: 88)
            .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
        }
    }
}
