import SwiftUI
import SwiftData

struct PricingTabView: View {
    @Binding var showAddRoomType: Bool
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \RoomType.name) private var roomTypes: [RoomType]
    @State private var editingRoomType: RoomType?
    @State private var roomTypeToDelete: RoomType?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("ตั้งค่าราคา").font(.custom("SukhumvitSet-Bold", size: 24))
                    Text("จัดเก็บประเภทห้องและค่าใช้จ่ายไว้ในเครื่อง")
                        .font(.custom("SukhumvitSet-Text", size: 12)).foregroundStyle(.secondary)
                }
            }
            if roomTypes.isEmpty {
                GlassCard { Text("ยังไม่มีประเภทห้อง").foregroundStyle(.secondary).frame(maxWidth: .infinity).padding(.vertical, 28) }
            } else {
                ForEach(roomTypes) { roomType in
                    GlassCard {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(roomType.name).font(.custom("SukhumvitSet-Bold", size: 16))
                                Spacer()
                                Text(roomType.price.formatted(.number.precision(.fractionLength(0))) + " ฿")
                                    .font(.custom("SukhumvitSet-Bold", size: 16)).foregroundStyle(.indigo)
                            }
                            Text("น้ำ \(roomType.waterFee.formatted(.number.precision(.fractionLength(0)))) ฿  •  ไฟ \(roomType.electricFee.formatted(.number.precision(.fractionLength(0)))) ฿  •  ส่วนกลาง \(roomType.commonFee.formatted(.number.precision(.fractionLength(0)))) ฿")
                                .font(.custom("SukhumvitSet-Text", size: 11)).foregroundStyle(.secondary)
                        }
                    }
                    .contextMenu {
                        Button {
                            editingRoomType = roomType
                        } label: {
                            Label("แก้ไข", systemImage: "pencil")
                        }
                        Button(role: .destructive) {
                            roomTypeToDelete = roomType
                        } label: {
                            Label("ลบ", systemImage: "trash")
                        }
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            roomTypeToDelete = roomType
                        } label: {
                            Label("ลบ", systemImage: "trash")
                        }
                        Button {
                            editingRoomType = roomType
                        } label: {
                            Label("แก้ไข", systemImage: "pencil")
                        }
                        .tint(.indigo)
                    }
                }
            }
        }
        .padding(.top, 106).padding(.horizontal, 20)
        .sheet(isPresented: $showAddRoomType) {
            RoomTypeEditor { roomType in
                modelContext.insert(roomType)
                try? modelContext.save()
                Task {
                    await SyncManager.shared.pushCurrentLocalState(modelContext: modelContext)
                }
            }
            .iphoneSheetStyle()
        }
        .sheet(item: $editingRoomType) { roomType in
            RoomTypeEditor(roomType: roomType) { updated in
                roomType.name = updated.name
                roomType.price = updated.price
                roomType.waterFee = updated.waterFee
                roomType.electricFee = updated.electricFee
                roomType.commonFee = updated.commonFee
                roomType.lateFee = updated.lateFee
                roomType.lastUpdated = Date()
                roomType.isDirty = true
                try? modelContext.save()
                Task {
                    await SyncManager.shared.pushCurrentLocalState(modelContext: modelContext)
                }
            }
            .iphoneSheetStyle()
        }
        .confirmationDialog("ลบประเภทห้องนี้หรือไม่", isPresented: deleteDialogBinding) {
            Button("ลบ \(roomTypeToDelete?.name ?? "")", role: .destructive) {
                guard let roomType = roomTypeToDelete else { return }
                modelContext.delete(roomType)
                try? modelContext.save()
                Task {
                    await SyncManager.shared.pushCurrentLocalState(modelContext: modelContext)
                }
                roomTypeToDelete = nil
            }
            Button("ยกเลิก", role: .cancel) { }
        }
    }

    private var deleteDialogBinding: Binding<Bool> {
        Binding(
            get: { roomTypeToDelete != nil },
            set: { if !$0 { roomTypeToDelete = nil } }
        )
    }
}

private struct RoomTypeEditor: View {
    @Environment(\.dismiss) private var dismiss
    let onSave: (RoomType) -> Void
    @State private var selectedDetent: PresentationDetent = .medium
    @State private var name = ""
    @State private var price = ""
    @State private var water = ""
    @State private var electric = ""
    @State private var common = ""

    init(roomType: RoomType? = nil, onSave: @escaping (RoomType) -> Void) {
        self.onSave = onSave
        _name = State(initialValue: roomType?.name ?? "")
        _price = State(initialValue: roomType.map { String(format: "%.0f", $0.price) } ?? "")
        _water = State(initialValue: roomType.map { String(format: "%.0f", $0.waterFee) } ?? "")
        _electric = State(initialValue: roomType.map { String(format: "%.0f", $0.electricFee) } ?? "")
        _common = State(initialValue: roomType.map { String(format: "%.0f", $0.commonFee) } ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("ข้อมูลประเภทห้อง") {
                    TextField("ชื่อประเภทห้อง", text: $name)
                    TextField("ค่าเช่ารายเดือน", text: $price)
                        .keyboardType(.decimalPad)
                }

                Section("ค่าใช้จ่ายเพิ่มเติม") {
                    TextField("ค่าน้ำ", text: $water)
                        .keyboardType(.decimalPad)
                    TextField("ค่าไฟ", text: $electric)
                        .keyboardType(.decimalPad)
                    TextField("ค่าส่วนกลาง", text: $common)
                        .keyboardType(.decimalPad)
                }
            }
            .navigationTitle("ประเภทห้อง")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("ยกเลิก") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("บันทึก") {
                        let item = RoomType(name: name, price: Double(price) ?? 0)
                        item.waterFee = Double(water) ?? 0
                        item.electricFee = Double(electric) ?? 0
                        item.commonFee = Double(common) ?? 0
                        item.isDirty = true
                        onSave(item)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || Double(price) == nil)
                }
            }
            .dismissKeyboardOnTap()
        }
        .presentationDetents([.medium, .large], selection: $selectedDetent)
        .presentationDragIndicator(.visible)
    }
}
