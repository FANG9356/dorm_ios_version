import SwiftUI
import SwiftData
import UIKit

enum MaintenanceWorkflow {
    static func statuses(hasCost: Bool) -> [String] {
        if hasCost {
            return ["รอดำเนินการ", "กำลังติดต่อช่าง", "รออนุมัติค่าใช้จ่าย", "รอตรวจสอบชำระเงิน", "กำลังซ่อม", "เสร็จสิ้น"]
        } else {
            return ["รอดำเนินการ", "กำลังติดต่อช่าง", "กำลังซ่อม", "เสร็จสิ้น"]
        }
    }

    static func shortTitle(for status: String) -> String {
        switch status {
        case "กำลังติดต่อช่าง": return "ติดต่อช่าง"
        case "รออนุมัติค่าใช้จ่าย": return "อนุมัติราคา"
        case "ปฏิเสธค่าใช้จ่าย": return "ปฏิเสธ"
        case "กำลังซ่อม": return "ซ่อม"
        case "รอตรวจสอบชำระเงิน": return "ตรวจชำระ"
        case "เสร็จสิ้น": return "เสร็จ"
        default: return "รอ"
        }
    }

    static func canTransition(from originalStatus: String, to newStatus: String, hasCost: Bool) -> Bool {
        if originalStatus == newStatus { return true }
        let flow = statuses(hasCost: hasCost)
        
        let original = originalStatus == "ปฏิเสธค่าใช้จ่าย" ? "รออนุมัติค่าใช้จ่าย" : (originalStatus.isEmpty ? flow[0] : originalStatus)
        guard let currentIndex = flow.firstIndex(of: original),
              let newIndex = flow.firstIndex(of: newStatus) else {
            // ถ้า originalStatus ไม่อยู่ใน flow (เช่น เปลี่ยนใจลบค่าใช้จ่าย)
            return true 
        }
        
        // อนุญาตให้เดินหน้าทีละ 1 ขั้น หรือถอยหลังได้ 1 ขั้น เพื่อแก้ไขข้อมูล
        return abs(newIndex - currentIndex) <= 1
    }
}

struct MaintenanceTabView: View {
    @Binding var showingEditor: Bool
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Maintenance.lastUpdated, order: .reverse) private var allMaintenances: [Maintenance]
    @Query(sort: \Room.roomNumber) private var allRooms: [Room]
    @State private var editingMaintenance: Maintenance?
    @State private var searchText = ""

    private var maintenances: [Maintenance] {
        allMaintenances.filter { !$0.isDeletedLocally }
    }

    private var rooms: [Room] {
        allRooms.filter { !$0.isDeletedLocally }
    }

    private var visibleMaintenances: [Maintenance] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return maintenances }
        return maintenances.filter { maintenance in
            let status = maintenance.status.isEmpty ? "รอดำเนินการ" : maintenance.status
            let searchable = [
                maintenance.roomNumber,
                maintenance.issue,
                status,
                maintenance.paymentMethod,
                maintenance.reportedAt,
                maintenance.resolvedAt,
                maintenance.cost.formatted(.number.precision(.fractionLength(0...2)))
            ].joined(separator: " ").lowercased()
            return searchable.contains(query)
        }
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

            ManagementSearchField(
                text: $searchText,
                placeholder: "ค้นหาห้อง, อาการ, สถานะงานซ่อม..."
            )

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
            } else if visibleMaintenances.isEmpty {
                GlassCard {
                    VStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 34))
                            .foregroundStyle(.secondary)
                        Text("ไม่พบงานซ่อมที่ค้นหา")
                            .font(.custom("SukhumvitSet-Medium", size: 14))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 28)
                }
            } else {
                ForEach(visibleMaintenances) { maintenance in
                    MaintenanceRow(
                        maintenance: maintenance,
                        onOpen: { editingMaintenance = maintenance }
                    )
                }
            }
        }
        .padding(.top, 106)
        .padding(.horizontal, 20)
        .task {
            // Maintenance can be created from LINE while this device is idle.
            // Refresh on entry so the list does not depend on the global
            // refresh button being pressed first.
            await SyncManager.shared.syncWithGoBackend(modelContext: modelContext)
        }
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
            MaintenanceEditor(maintenance: maintenance, rooms: rooms, onDelete: {
                maintenance.isDeletedLocally = true
                maintenance.isDirty = true
                maintenance.lastUpdated = Date()
                saveAndPush()
            }) { draft in
                maintenance.roomNumber = draft.roomNumber
                maintenance.issue = draft.issue
                maintenance.status = draft.status
                maintenance.cost = draft.cost
                maintenance.paymentMethod = draft.paymentMethod
                maintenance.slipPath = draft.slipPath
                maintenance.issueImage = draft.issueImage
                maintenance.quoteApprovedAt = draft.quoteApprovedAt
                maintenance.resolvedAt = draft.resolvedAt
                maintenance.lastUpdated = Date()
                maintenance.isDirty = true
                saveAndPush()
            }
            .iphoneSheetStyle()
        }
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

}

private struct MaintenanceRow: View {
    let maintenance: Maintenance
    let onOpen: () -> Void

    private var status: String {
        maintenance.status.isEmpty ? "รอดำเนินการ" : maintenance.status
    }

    private var hasCost: Bool {
        maintenance.cost > 0 || ["รออนุมัติค่าใช้จ่าย", "ปฏิเสธค่าใช้จ่าย", "รอตรวจสอบชำระเงิน"].contains(maintenance.status)
    }

    private var currentStatusIndex: Int {
        MaintenanceWorkflow.statuses(hasCost: hasCost).firstIndex(of: status) ?? 0
    }

    var body: some View {
        Button(action: onOpen) {
            GlassCard {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "wrench.and.screwdriver.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.orange)
                            .frame(width: 38, height: 38)
                            .background(Color.orange.opacity(0.12), in: Circle())
                        VStack(alignment: .leading, spacing: 4) {
                            Text("ห้อง \(maintenance.roomNumber)")
                                .font(.custom("SukhumvitSet-Bold", size: 17))
                            Text(maintenance.issue)
                                .font(.custom("SukhumvitSet-Text", size: 14))
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                            if !maintenance.reportedAt.isEmpty {
                                Text(maintenance.reportedAt)
                                    .font(.custom("SukhumvitSet-Text", size: 11))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        Spacer()
                        HStack(spacing: 7) {
                            Text(status)
                                .font(.custom("SukhumvitSet-Medium", size: 12))
                                .lineLimit(1)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 11)
                        .frame(minHeight: 34)
                        .background(.ultraThinMaterial, in: Capsule())
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        if status == "ปฏิเสธค่าใช้จ่าย" || status == "ยกเลิก" {
                            HStack(spacing: 8) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.red)
                                Text(status == "ปฏิเสธค่าใช้จ่าย" ? "ลูกบ้านปฏิเสธใบเสนอราคา" : "ยกเลิกรายการ")
                                    .font(.custom("SukhumvitSet-Medium", size: 14))
                                    .foregroundStyle(.red)
                            }
                        } else {
                            Text("ความคืบหน้า")
                                .font(.custom("SukhumvitSet-Medium", size: 12))
                                .foregroundStyle(.secondary)
                            MaintenanceProgressView(currentIndex: currentStatusIndex, hasCost: hasCost)
                        }
                    }

                    Divider()
                        .overlay(Color.primary.opacity(0.08))

                    HStack(spacing: 10) {
                        if maintenance.cost > 0 {
                            Label(
                                maintenance.cost.formatted(.number.precision(.fractionLength(0...2))) + " บาท",
                                systemImage: "banknote"
                            )
                            .font(.custom("SukhumvitSet-Medium", size: 12))
                            .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Text("แตะเพื่อดูรายละเอียด")
                            .font(.custom("SukhumvitSet-Medium", size: 12))
                            .foregroundStyle(.secondary)
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .contentShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("ห้อง \(maintenance.roomNumber), \(maintenance.issue), สถานะ \(status)")
        .accessibilityHint("แตะเพื่อดูรายละเอียดและแก้ไข")
    }
}

private struct MaintenanceProgressView: View {
    let currentIndex: Int
    let hasCost: Bool

    private var currentFlow: [String] {
        MaintenanceWorkflow.statuses(hasCost: hasCost)
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 0) {
                ForEach(Array(currentFlow.indices), id: \.self) { index in
                    HStack(spacing: 0) {
                        Rectangle()
                            .fill(index == 0 ? Color.clear : connectorColor(at: index - 1))
                            .frame(height: 2)

                        Circle()
                            .fill(dotFill(at: index))
                            .frame(width: index == currentIndex ? 13 : 9, height: index == currentIndex ? 13 : 9)
                            .overlay {
                                if index == currentIndex {
                                    Circle()
                                        .stroke(Color.indigo.opacity(0.28), lineWidth: 5)
                                }
                            }

                        Rectangle()
                            .fill(index == currentFlow.count - 1 ? Color.clear : connectorColor(at: index))
                            .frame(height: 2)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 18)

            HStack(spacing: 0) {
                ForEach(Array(currentFlow.enumerated()), id: \.offset) { index, item in
                    Text(MaintenanceWorkflow.shortTitle(for: item))
                        .font(.custom("SukhumvitSet-Medium", size: 12))
                        .foregroundStyle(index == currentIndex ? Color.primary : Color.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.68)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private func dotFill(at index: Int) -> Color {
        if index == currentIndex { return .indigo }
        if index < currentIndex { return .primary.opacity(0.56) }
        return .secondary.opacity(0.28)
    }

    private func connectorColor(at index: Int) -> Color {
        index < currentIndex ? .primary.opacity(0.32) : .secondary.opacity(0.16)
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
    @State private var quoteApprovedAt: String
    @State private var reportedAt: String
    @State private var hasCost: Bool
    @State private var selectedDetent: PresentationDetent = .large
    @State private var showingDeleteConfirmation = false
    private let isEditing: Bool
    private let onDelete: (() -> Void)?
    private let originalStatus: String

    private let paymentMethods = [(value: "", title: "ยังไม่ระบุ"), (value: "เงินสด", title: "เงินสด"), (value: "โอนเงิน", title: "โอนผ่านธนาคาร")]

    init(
        maintenance: Maintenance? = nil,
        rooms: [Room],
        onDelete: (() -> Void)? = nil,
        onSave: @escaping (Maintenance) -> Void
    ) {
        self.rooms = rooms
        self.onDelete = onDelete
        self.onSave = onSave
        self.isEditing = maintenance != nil
        self.originalStatus = maintenance?.status.isEmpty == false ? maintenance?.status ?? "รอดำเนินการ" : "รอดำเนินการ"
        _roomNumber = State(initialValue: maintenance?.roomNumber ?? rooms.first?.roomNumber ?? "")
        _issue = State(initialValue: maintenance?.issue ?? "")
        _status = State(initialValue: maintenance?.status.isEmpty == false ? maintenance?.status ?? "รอดำเนินการ" : "รอดำเนินการ")
        _cost = State(initialValue: maintenance.map { String(format: "%.0f", $0.cost) } ?? "")
        _paymentMethod = State(initialValue: maintenance?.paymentMethod ?? "")
        _slipPath = State(initialValue: maintenance?.slipPath ?? "")
        _issueImage = State(initialValue: maintenance?.issueImage ?? "")
        _quoteApprovedAt = State(initialValue: maintenance?.quoteApprovedAt ?? "")
        _reportedAt = State(initialValue: maintenance?.reportedAt ?? "")
        let initialCost = maintenance?.cost ?? 0
        let initialStatus = maintenance?.status ?? ""
        _hasCost = State(initialValue: initialCost > 0 || ["รออนุมัติค่าใช้จ่าย", "ปฏิเสธค่าใช้จ่าย", "รอตรวจสอบชำระเงิน"].contains(initialStatus))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    MaintenanceEditorCard(title: "ห้องและรายละเอียด", systemImage: "door.left.hand.open") {
                        roomSelector
                        
                        if !reportedAt.isEmpty {
                            Divider().overlay(Color.primary.opacity(0.08))
                            HStack {
                                Text("วันที่แจ้งซ่อม")
                                    .font(.custom("SukhumvitSet-Medium", size: 13))
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(reportedAt)
                                    .font(.custom("SukhumvitSet-Medium", size: 13))
                            }
                        }

                        Divider().overlay(Color.primary.opacity(0.08))

                        VStack(alignment: .leading, spacing: 10) {
                            Text("อาการ / รายละเอียด")
                                .font(.custom("SukhumvitSet-Medium", size: 13))
                                .foregroundStyle(.secondary)
                            TextField("เช่น ไฟดับ น้ำไม่ไหล หรืออุปกรณ์ชำรุด", text: $issue, axis: .vertical)
                                .font(.custom("SukhumvitSet-Text", size: 17))
                                .lineLimit(4...7)
                                .padding(16)
                                .frame(minHeight: 124, alignment: .topLeading)
                                .background(Color.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .stroke(Color.primary.opacity(0.07), lineWidth: 0.75)
                                }
                                .limitedText($issue, maxLength: 300)
                        }
                    }

                    MaintenanceEditorCard(title: "อัปเดตสถานะ", systemImage: "point.topleft.down.to.point.bottomright.curvepath") {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack(spacing: 9) {
                                Image(systemName: "lock.shield.fill")
                                    .foregroundStyle(.indigo)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("ทำงานตามลำดับ")
                                        .font(.custom("SukhumvitSet-Medium", size: 13))
                                    Text("ถ้ามีค่าใช้จ่าย ต้องส่งราคาให้ลูกบ้านอนุมัติใน LINE ก่อนเริ่มซ่อม")
                                        .font(.custom("SukhumvitSet-Text", size: 11))
                                        .foregroundStyle(.secondary)
                                }
                            }

                            VStack(spacing: 0) {
                                ForEach(Array(MaintenanceWorkflow.statuses(hasCost: hasCost).enumerated()), id: \.offset) { index, item in
                                    statusRow(item: item, index: index)
                                }
                            }

                            if status == "ปฏิเสธค่าใช้จ่าย" {
                                Label("ลูกบ้านปฏิเสธใบเสนอราคา: ระบบจะยกเลิกเคสทิ้งอัตโนมัติใน 24 ชม.", systemImage: "exclamationmark.triangle.fill")
                                    .font(.custom("SukhumvitSet-Medium", size: 12))
                                    .foregroundStyle(.red)
                                    .padding(.top, -6)
                                    .padding(.horizontal, 4)
                            }
                        }
                    }

                    MaintenanceEditorCard(title: "ค่าใช้จ่าย", systemImage: "banknote") {
                        Toggle(isOn: $hasCost.animation()) {
                            Text("มีค่าใช้จ่ายเพิ่มเติม")
                                .font(.custom("SukhumvitSet-Medium", size: 15))
                        }
                        .tint(.indigo)
                        .onChange(of: hasCost) { _, newValue in
                            if !newValue {
                                cost = ""
                                paymentMethod = ""
                            }
                        }

                        if hasCost {
                            Divider().overlay(Color.primary.opacity(0.08))

                            VStack(alignment: .leading, spacing: 9) {
                                Text("จำนวนเงิน")
                                    .font(.custom("SukhumvitSet-Medium", size: 13))
                                    .foregroundStyle(.secondary)
                                HStack(alignment: .firstTextBaseline) {
                                    TextField("0.00", text: $cost)
                                        .font(.system(size: 28, weight: .semibold, design: .rounded))
                                        .keyboardType(.decimalPad)
                                        .decimalInput($cost, maxIntegerDigits: 9, maxFractionDigits: 2)
                                        .disabled(!canEditCost)
                                    Spacer()
                                    Text("บาท")
                                        .font(.custom("SukhumvitSet-Medium", size: 15))
                                        .foregroundStyle(.secondary)
                                }
                    }
                            .padding(.horizontal, 16)
                            .frame(minHeight: 70)
                            .background(Color.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        }

                        if (Double(cost) ?? 0) > 0 {
                            Label("เลือก “รออนุมัติค่าใช้จ่าย” เพื่อส่งใบเสนอราคาไปยัง LINE", systemImage: "checkmark.message")
                                .font(.custom("SukhumvitSet-Text", size: 11))
                                .foregroundStyle(.secondary)
                        }

                        if !canEditCost {
                            Label("ยอดนี้ถูกส่งให้ลูกบ้านแล้ว หากต้องแก้ให้ย้อนกลับไปออกใบเสนอราคาใหม่", systemImage: "lock.fill")
                                .font(.custom("SukhumvitSet-Text", size: 11))
                                .foregroundStyle(.secondary)
                        }

                        Divider().overlay(Color.primary.opacity(0.08))

                        VStack(alignment: .leading, spacing: 9) {
                            Text("ช่องทางชำระ")
                                .font(.custom("SukhumvitSet-Medium", size: 13))
                                .foregroundStyle(.secondary)
                            paymentMethodMenu
                        }
                    }

                    MaintenanceEditorCard(title: "รูปและหลักฐาน", systemImage: "photo.on.rectangle.angled") {
                        MaintenanceEvidenceView(title: "รูปอาการเสีย", paths: mediaPaths(issueImage), emptyText: "ยังไม่มีรูปอาการเสีย")
                        Divider().overlay(Color.primary.opacity(0.08))
                        MaintenanceEvidenceView(title: "สลิปชำระเงิน", paths: mediaPaths(slipPath), emptyText: "ยังไม่มีสลิปชำระเงิน")
                    }

                    if isEditing, onDelete != nil {
                        Button(role: .destructive) {
                            showingDeleteConfirmation = true
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "trash")
                                Text("ลบรายการแจ้งซ่อม")
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            .font(.custom("SukhumvitSet-Medium", size: 15))
                            .padding(.horizontal, 18)
                            .frame(maxWidth: .infinity, minHeight: 58)
                            .background(Color.red.opacity(0.07), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(Color.red.opacity(0.16), lineWidth: 0.75)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 36)
            }
            .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("งานซ่อม")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("ยกเลิก") { dismiss() }
                        .font(.custom("SukhumvitSet-Medium", size: 16))
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("บันทึก") {
                        let parsedCost = Double(cost) ?? 0
                        guard MaintenanceWorkflow.canTransition(from: originalStatus, to: status, hasCost: hasCost) else { return }
                        let item = Maintenance(roomNumber: clean(roomNumber), issue: clean(issue))
                        item.status = status
                        item.cost = parsedCost
                        item.paymentMethod = clean(paymentMethod)
                        item.slipPath = clean(slipPath)
                        item.issueImage = clean(issueImage)
                        item.quoteApprovedAt = status == "รออนุมัติค่าใช้จ่าย" && originalStatus != status ? "" : quoteApprovedAt
                        item.reportedAt = currentDateString()
                        if status == "เสร็จสิ้น" {
                            item.resolvedAt = currentDateString()
                        }
                        onSave(item)
                        dismiss()
                    }
                    .font(.custom("SukhumvitSet-Bold", size: 16))
                    .disabled(
                        clean(roomNumber).isEmpty ||
                        clean(issue).isEmpty ||
                        !MaintenanceWorkflow.canTransition(from: originalStatus, to: status, hasCost: hasCost)
                    )
                }
            }
            .dismissKeyboardOnTap()
            .scrollDismissesKeyboard(.interactively)
            .alert("ยืนยันการลบ", isPresented: $showingDeleteConfirmation) {
                Button("ยกเลิก", role: .cancel) { }
                Button("ลบรายการ", role: .destructive) {
                    onDelete?()
                    dismiss()
                }
            } message: {
                Text("ต้องการลบรายการแจ้งซ่อมนี้หรือไม่? รายการจะถูกซิงก์ออกจากอุปกรณ์อื่นด้วย")
            }
        }
        .presentationDetents([.medium, .large], selection: $selectedDetent)
        .presentationDragIndicator(.visible)
    }

    @ViewBuilder
    private var roomSelector: some View {
        if isEditing {
            HStack(spacing: 12) {
                Image(systemName: "door.left.hand.open")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.indigo)
                    .frame(width: 38, height: 38)
                    .background(Color.indigo.opacity(0.10), in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text("ห้อง")
                        .font(.custom("SukhumvitSet-Text", size: 12))
                        .foregroundStyle(.secondary)
                    Text(roomNumber)
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                }
                Spacer()
                Text("แก้ไขไม่ได้")
                    .font(.custom("SukhumvitSet-Text", size: 11))
                    .foregroundStyle(.tertiary)
            }
            .accessibilityElement(children: .combine)
        } else if rooms.isEmpty {
            TextField("เลขห้อง", text: $roomNumber)
                .limitedText($roomNumber, maxLength: 10, trimNewlines: true)
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .padding(.horizontal, 16)
                .frame(minHeight: 58)
                .background(Color.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        } else {
            Menu {
                ForEach(rooms) { room in
                    Button {
                        roomNumber = room.roomNumber
                    } label: {
                        if roomNumber == room.roomNumber {
                            Label("ห้อง \(room.roomNumber)", systemImage: "checkmark")
                        } else {
                            Text("ห้อง \(room.roomNumber)")
                        }
                    }
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "door.left.hand.open")
                        .foregroundStyle(.indigo)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("เลือกห้อง")
                            .font(.custom("SukhumvitSet-Text", size: 12))
                            .foregroundStyle(.secondary)
                        Text(roomNumber.isEmpty ? "ยังไม่ได้เลือก" : "ห้อง \(roomNumber)")
                            .font(.custom("SukhumvitSet-Medium", size: 16))
                            .foregroundStyle(roomNumber.isEmpty ? Color.secondary : Color.primary)
                    }
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16)
                .frame(minHeight: 62)
                .background(Color.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
        }
    }

    private func statusRow(item: String, index: Int) -> some View {
        let selected = status == item
        let persisted = originalStatus == item
        let available = MaintenanceWorkflow.canTransition(from: originalStatus, to: item, hasCost: hasCost)

        let flow = MaintenanceWorkflow.statuses(hasCost: hasCost)

        return Button {
            status = item
        } label: {
            HStack(spacing: 13) {
                VStack(spacing: 0) {
                    Rectangle()
                        .fill(index == 0 ? Color.clear : statusConnectorColor(before: index, flow: flow))
                        .frame(width: 2, height: 17)
                    Circle()
                        .fill(selected ? Color.indigo : persisted ? Color.primary.opacity(0.7) : Color.secondary.opacity(available ? 0.35 : 0.16))
                        .frame(width: selected ? 13 : 9, height: selected ? 13 : 9)
                        .overlay {
                            if selected {
                                Circle().stroke(Color.indigo.opacity(0.20), lineWidth: 5)
                            }
                        }
                    Rectangle()
                        .fill(index == flow.count - 1 ? Color.clear : statusConnectorColor(before: index + 1, flow: flow))
                        .frame(width: 2, height: 17)
                }
                .frame(width: 18, height: 47)

                Text(item)
                    .font(.custom("SukhumvitSet-Medium", size: 14))
                    .foregroundStyle(available ? Color.primary : Color.secondary.opacity(0.48))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                Spacer()

                if selected && !persisted {
                    Text("สถานะใหม่")
                        .foregroundStyle(.indigo)
                } else if persisted {
                    Text("ปัจจุบัน")
                        .foregroundStyle(.secondary)
                } else if !available {
                    Image(systemName: "lock.fill")
                        .foregroundStyle(.tertiary)
                } else {
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.tertiary)
                }
            }
            .font(.custom("SukhumvitSet-Text", size: 11))
            .padding(.horizontal, 14)
            .frame(minHeight: 58)
            .background(selected ? Color.indigo.opacity(0.09) : Color.clear, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                if selected {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.indigo.opacity(0.18), lineWidth: 0.75)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!available || selected)
        .accessibilityHint(available ? "เลือกสถานะนี้ได้" : "ต้องบันทึกสถานะตามลำดับก่อน")
    }

    private func statusConnectorColor(before index: Int, flow: [String]) -> Color {
        let original = originalStatus == "ปฏิเสธค่าใช้จ่าย" ? "รออนุมัติค่าใช้จ่าย" : originalStatus
        guard let originalIndex = flow.firstIndex(of: original) else {
            return .secondary.opacity(0.12)
        }
        return index <= originalIndex ? .primary.opacity(0.24) : .secondary.opacity(0.12)
    }

    private var paymentMethodMenu: some View {
        Menu {
            ForEach(paymentMethods, id: \.value) { method in
                Button {
                    paymentMethod = method.value
                } label: {
                    if paymentMethod == method.value {
                        Label(method.title, systemImage: "checkmark")
                    } else {
                        Text(method.title)
                    }
                }
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: paymentMethod == "เงินสด" ? "banknote" : "building.columns")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.indigo)
                    .frame(width: 36, height: 36)
                    .background(Color.indigo.opacity(0.09), in: Circle())
                Text(paymentMethodTitle)
                    .font(.custom("SukhumvitSet-Medium", size: 15))
                    .foregroundStyle(paymentMethod.isEmpty ? Color.secondary : Color.primary)
                Spacer()
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, minHeight: 62)
            .background(Color.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.primary.opacity(0.07), lineWidth: 0.75)
            }
        }
    }

    private func clean(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var paymentMethodTitle: String {
        paymentMethods.first(where: { $0.value == paymentMethod })?.title ?? paymentMethod
    }

    private var canEditCost: Bool {
        let flow = MaintenanceWorkflow.statuses(hasCost: hasCost)
        guard let originalIndex = flow.firstIndex(of: originalStatus),
              let selectedIndex = flow.firstIndex(of: status) else { return true }
        
        let quoteIndex = flow.firstIndex(of: "รออนุมัติค่าใช้จ่าย") ?? 2
        if !quoteApprovedAt.isEmpty && originalStatus == "กำลังติดต่อช่าง" && status != "รออนุมัติค่าใช้จ่าย" {
            return false
        }
        return originalIndex < quoteIndex || selectedIndex < quoteIndex || (selectedIndex == quoteIndex && originalIndex != quoteIndex)
    }

    private func mediaPaths(_ value: String) -> [String] {
        value.split(separator: ",").map {
            String($0).trimmingCharacters(in: .whitespacesAndNewlines)
        }.filter { !$0.isEmpty }
    }

    private func currentDateString() -> String {
        AppDate.dateKey(from: Date())
    }
}

private struct MaintenanceEditorCard<Content: View>: View {
    let title: String
    let systemImage: String
    let content: Content

    init(title: String, systemImage: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.systemImage = systemImage
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(title, systemImage: systemImage)
                .font(.custom("SukhumvitSet-Bold", size: 16))
                .foregroundStyle(.primary)
                .symbolRenderingMode(.hierarchical)

            content
        }
        .padding(20)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 0.75)
        }
        .shadow(color: .black.opacity(0.06), radius: 16, y: 7)
    }
}

private struct MaintenanceEvidenceView: View {
    let title: String
    let paths: [String]
    let emptyText: String
    @State private var preview: MaintenanceEvidencePreview?

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
        .fullScreenCover(item: $preview) { item in
            MaintenanceImageViewer(item: item)
        }
    }

    @ViewBuilder
    private func evidence(_ path: String) -> some View {
        if let url = SlipImageManager.url(for: path),
           let image = UIImage(contentsOfFile: url.path) {
            Button {
                preview = MaintenanceEvidencePreview(title: title, image: image)
            } label: {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 128, height: 96)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(alignment: .bottomTrailing) {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(8)
                            .background(.black.opacity(0.62), in: Circle())
                            .padding(7)
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("ดู\(title)แบบเต็มจอ")
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

private struct MaintenanceEvidencePreview: Identifiable {
    let id = UUID()
    let title: String
    let image: UIImage
}

private struct MaintenanceImageViewer: View {
    @Environment(\.dismiss) private var dismiss
    let item: MaintenanceEvidencePreview
    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                Image(uiImage: item.image)
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(scale)
                    .gesture(
                        MagnificationGesture()
                            .onChanged { value in
                                scale = min(max(lastScale * value, 1), 5)
                            }
                            .onEnded { _ in lastScale = scale }
                    )
                    .onTapGesture(count: 2) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            scale = scale > 1 ? 1 : 2
                            lastScale = scale
                        }
                    }
            }
            .navigationTitle(item.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(.black, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("ปิด") { dismiss() }
                        .foregroundStyle(.white)
                }
            }
        }
    }
}
