import SwiftUI
import SwiftData

struct PricingTabView: View {
    @Binding var showAddRoomType: Bool
    @Environment(\.modelContext) private var modelContext
    @AppStorage("defaultDepositPercent") private var defaultDepositPercent = 5.0
    @Query(sort: \RoomType.name) private var roomTypes: [RoomType]
    @Query(sort: \Room.roomNumber) private var allRooms: [Room]
    @Query(sort: \DormUser.roomNumber) private var users: [DormUser]
    @State private var editingRoomType: RoomType?
    @State private var roomTypeToDelete: RoomType?
    @State private var showCreateRoomType = false
    @State private var showCreateRoom = false
    @State private var editingRoom: Room?
    @State private var roomToDelete: Room?
    @State private var searchText = ""

    private var rooms: [Room] {
        allRooms.filter { !$0.isDeletedLocally }
    }

    private var visibleRoomTypes: [RoomType] {
        let query = normalizedSearchText
        guard !query.isEmpty else { return roomTypes }
        return roomTypes.filter { roomType in
            let searchable = [
                roomType.name,
                roomType.price.formatted(.number.precision(.fractionLength(0...2))),
                roomType.waterFee.formatted(.number.precision(.fractionLength(0...2))),
                roomType.electricFee.formatted(.number.precision(.fractionLength(0...2))),
                roomType.commonFee.formatted(.number.precision(.fractionLength(0...2)))
            ].joined(separator: " ").lowercased()
            return searchable.contains(query)
        }
    }

    private var visibleRooms: [Room] {
        let query = normalizedSearchText
        guard !query.isEmpty else { return rooms }
        return rooms.filter { room in
            let tenant = tenant(for: room)
            let searchable = [
                room.roomNumber,
                room.roomType,
                tenant.map { "\($0.prefix)\($0.firstName) \($0.lastName)" } ?? "",
                tenant == nil ? "ว่าง" : "มีผู้พัก"
            ].joined(separator: " ").lowercased()
            return searchable.contains(query)
        }
    }

    private var normalizedSearchText: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    var body: some View {
        content
        .sheet(isPresented: $showAddRoomType) {
            PricingAddActionSheet(
                canCreateRoom: !roomTypes.isEmpty,
                onCreateType: {
                    showAddRoomType = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                        showCreateRoomType = true
                    }
                },
                onCreateRoom: {
                    showAddRoomType = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                        showCreateRoom = true
                    }
                }
            )
            .presentationDetents([.height(roomTypes.isEmpty ? 264 : 248)])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(32)
            .presentationBackground(.ultraThinMaterial)
        }
        .sheet(isPresented: $showCreateRoomType) {
            RoomTypeEditor { roomType in
                modelContext.insert(roomType)
                modelContext.insert(LocalSystemLog(action: "เพิ่มประเภทห้อง", details: "\(roomType.name) ค่าเช่า \(roomType.price.formatted(.number.precision(.fractionLength(0)))) บาท"))
                saveAndPush()
            }
            .iphoneSheetStyle()
        }
        .sheet(isPresented: $showCreateRoom) {
            PricingRoomEditor(roomTypes: roomTypes) { roomNumber, roomType in
                let room = Room(roomNumber: roomNumber, roomType: roomType)
                room.ownerAccountID = UserDefaults.standard.integer(forKey: "adminID")
                room.isDirty = true
                room.lastUpdated = Date()
                modelContext.insert(room)
                modelContext.insert(LocalSystemLog(action: "เพิ่มเลขห้อง", details: "ห้อง \(room.roomNumber) ประเภท \(room.roomType)"))
                saveAndPush()
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
                modelContext.insert(LocalSystemLog(action: "แก้ไขประเภทห้อง", details: "\(roomType.name) ค่าเช่า \(roomType.price.formatted(.number.precision(.fractionLength(0)))) บาท"))
                saveAndPush()
            }
            .iphoneSheetStyle()
        }
        .sheet(item: $editingRoom) { room in
            PricingRoomEditor(room: room, roomTypes: roomTypes) { roomNumber, roomType in
                room.roomNumber = roomNumber
                room.roomType = roomType
                room.isDirty = true
                room.lastUpdated = Date()
                modelContext.insert(LocalSystemLog(action: "แก้ไขเลขห้อง", details: "ห้อง \(room.roomNumber) ประเภท \(room.roomType)"))
                saveAndPush()
            }
            .iphoneSheetStyle()
        }
        .confirmationDialog("ลบประเภทห้องนี้หรือไม่", isPresented: roomTypeDeleteDialogBinding) {
            Button("ลบ \(roomTypeToDelete?.name ?? "")", role: .destructive) {
                guard let roomType = roomTypeToDelete else { return }
                modelContext.insert(LocalSystemLog(action: "ลบประเภทห้อง", details: roomType.name))
                modelContext.delete(roomType)
                saveAndPush()
                roomTypeToDelete = nil
            }
            Button("ยกเลิก", role: .cancel) { }
        }
        .confirmationDialog("ลบห้องพักนี้หรือไม่", isPresented: roomDeleteDialogBinding) {
            Button("ลบห้อง \(roomToDelete?.roomNumber ?? "")", role: .destructive) {
                guard let room = roomToDelete else { return }
                room.isDeletedLocally = true
                room.isDirty = true
                room.lastUpdated = Date()
                modelContext.insert(LocalSystemLog(action: "ลบเลขห้อง", details: "ห้อง \(room.roomNumber)"))
                saveAndPush()
                roomToDelete = nil
            }
            Button("ยกเลิก", role: .cancel) { }
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("ตั้งค่าห้องและราคา").font(.custom("SukhumvitSet-Bold", size: 24))
                    Text("สร้างประเภทห้อง ตั้งราคา และเพิ่มเลขห้องจากข้อมูลชุดเดียว")
                        .font(.custom("SukhumvitSet-Text", size: 12)).foregroundStyle(.secondary)
                }
            }

            ManagementSearchField(
                text: $searchText,
                placeholder: "ค้นหาประเภทห้อง, เลขห้อง, ชื่อลูกบ้าน..."
            )

            depositPercentSettings

            sectionHeader("ประเภทห้อง")
            if roomTypes.isEmpty || visibleRoomTypes.isEmpty {
                GlassCard {
                    Text(roomTypes.isEmpty ? "ยังไม่มีประเภทห้อง" : "ไม่พบประเภทห้องที่ค้นหา")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 28)
                }
            } else {
                ForEach(visibleRoomTypes) { roomType in
                    GlassCard {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(LocalizedStringKey(roomType.name)).font(.custom("SukhumvitSet-Bold", size: 16))
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

            sectionHeader("เลขห้อง")
                .padding(.top, 8)
            if rooms.isEmpty || visibleRooms.isEmpty {
                GlassCard {
                    VStack(spacing: 8) {
                        Image(systemName: "door.left.hand.open")
                            .font(.custom("SukhumvitSet-Medium", size: 30))
                            .foregroundStyle(.secondary)
                        Text(rooms.isEmpty ? "ยังไม่มีห้องพัก" : "ไม่พบห้องพักที่ค้นหา")
                            .font(.custom("SukhumvitSet-Medium", size: 14))
                            .foregroundStyle(.secondary)
                        Text(rooms.isEmpty
                             ? (roomTypes.isEmpty ? "สร้างประเภทห้องก่อน แล้วค่อยเพิ่มเลขห้อง" : "กดปุ่ม + เพื่อเพิ่มเลขห้องและเลือกประเภท")
                             : "ลองเปลี่ยนคำค้นหาใหม่")
                            .font(.custom("SukhumvitSet-Text", size: 12))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                }
            } else {
                ForEach(visibleRooms) { room in
                    PricingRoomRow(room: room, tenant: tenant(for: room)) {
                        editingRoom = room
                    } onDelete: {
                        roomToDelete = room
                    }
                }
            }
        }
        .padding(.top, 106).padding(.horizontal, 20)
    }

    private var roomTypeDeleteDialogBinding: Binding<Bool> {
        Binding(
            get: { roomTypeToDelete != nil },
            set: { if !$0 { roomTypeToDelete = nil } }
        )
    }

    private var roomDeleteDialogBinding: Binding<Bool> {
        Binding(
            get: { roomToDelete != nil },
            set: { if !$0 { roomToDelete = nil } }
        )
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.custom("SukhumvitSet-Bold", size: 17))
            .foregroundStyle(.primary)
    }

    private var depositPercentSettings: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("เงินมัดจำเริ่มต้น")
                            .font(.custom("SukhumvitSet-Bold", size: 16))
                        Text("ใช้คำนวณอัตโนมัติในหน้าเพิ่มลูกบ้าน")
                            .font(.custom("SukhumvitSet-Text", size: 11))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("\(clampedDepositPercent.formatted(.number.precision(.fractionLength(0))))%")
                        .font(.custom("SukhumvitSet-Bold", size: 20))
                        .foregroundStyle(.indigo)
                }

                Stepper(value: depositPercentBinding, in: 5...100, step: 1) {
                    Text("ขั้นต่ำ 5%")
                        .font(.custom("SukhumvitSet-Medium", size: 13))
                        .foregroundStyle(.secondary)
                }

                if defaultDepositPercent != clampedDepositPercent {
                    Text("ระบบปรับค่าให้ไม่ต่ำกว่า 5% แล้ว")
                        .font(.custom("SukhumvitSet-Text", size: 11))
                        .foregroundStyle(.secondary)
                        .onAppear {
                            defaultDepositPercent = clampedDepositPercent
                        }
                }
            }
        }
    }

    private var depositPercentBinding: Binding<Double> {
        Binding(
            get: { clampedDepositPercent },
            set: { defaultDepositPercent = max(5, min(100, $0)) }
        )
    }

    private var clampedDepositPercent: Double {
        max(5, min(100, defaultDepositPercent))
    }

    private func tenant(for room: Room) -> DormUser? {
        users.first {
            !$0.isDeletedLocally &&
            $0.status != "ย้ายออกแล้ว" &&
            clean($0.roomNumber) == clean(room.roomNumber)
        }
    }

    private func saveAndPush() {
        do {
            try modelContext.save()
            Task {
                await SyncManager.shared.pushCurrentLocalState(modelContext: modelContext)
            }
        } catch {
            print("Pricing save error: \(error)")
        }
    }

    private func clean(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private struct PricingRoomRow: View {
    let room: Room
    let tenant: DormUser?
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        GlassCard {
            HStack(spacing: 12) {
                Image(systemName: "door.left.hand.open")
                    .foregroundStyle(.indigo)
                VStack(alignment: .leading, spacing: 4) {
                    Text("ห้อง \(room.roomNumber)")
                        .font(.custom("SukhumvitSet-Bold", size: 15))
                    Text(room.roomType)
                        .font(.custom("SukhumvitSet-Text", size: 12))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(tenant == nil ? "ว่าง" : "มีผู้พัก")
                    .font(.custom("SukhumvitSet-Bold", size: 12))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(.ultraThinMaterial))
            }
        }
        .contextMenu {
            if tenant == nil {
                Button(action: onEdit) {
                    Label("แก้ไข", systemImage: "pencil")
                }
                Button(role: .destructive, action: onDelete) {
                    Label("ลบ", systemImage: "trash")
                }
            }
        }
        .swipeActions(edge: .trailing) {
            if tenant == nil {
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
}

private struct PricingAddActionSheet: View {
    @Environment(\.colorScheme) private var colorScheme
    let canCreateRoom: Bool
    let onCreateType: () -> Void
    let onCreateRoom: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "plus.circle.fill")
                    .font(.custom("SukhumvitSet-SemiBold", size: 28))
                    .foregroundStyle(Color.indigo)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(.primary.opacity(colorScheme == .dark ? 0.08 : 0.04)))

                VStack(alignment: .leading, spacing: 4) {
                    Text("เพิ่มข้อมูล")
                        .font(.custom("SukhumvitSet-Bold", size: 20))
                    Text("ตั้งราคาเป็นจุดเริ่มต้นของข้อมูลห้องทั้งหมด")
                        .font(.custom("SukhumvitSet-Text", size: 12))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .foregroundStyle(.primary)

                Spacer(minLength: 0)
            }

            VStack(spacing: 10) {
                addActionButton(
                    title: "เพิ่มประเภทห้อง",
                    subtitle: "ตั้งชื่อ ค่าเช่า และค่าบริการ",
                    icon: "tag.fill",
                    isEnabled: true,
                    action: onCreateType
                )

                addActionButton(
                    title: "เพิ่มเลขห้อง",
                    subtitle: canCreateRoom ? "เลือกประเภทห้องที่ตั้งราคาไว้" : "ต้องเพิ่มประเภทห้องก่อน",
                    icon: "door.left.hand.open",
                    isEnabled: canCreateRoom,
                    action: onCreateRoom
                )
            }
        }
        .padding(.horizontal, 22)
        .padding(.top, 18)
        .padding(.bottom, 20)
    }

    private func addActionButton(
        title: String,
        subtitle: String,
        icon: String,
        isEnabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.custom("SukhumvitSet-SemiBold", size: 16))
                    .foregroundStyle(isEnabled ? Color.indigo : .secondary)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(.primary.opacity(colorScheme == .dark ? 0.08 : 0.045)))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.custom("SukhumvitSet-Bold", size: 15))
                    .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.custom("SukhumvitSet-Text", size: 11))
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.custom("SukhumvitSet-Bold", size: 11))
                    .foregroundStyle(.secondary.opacity(0.8))
            }
            .foregroundStyle(isEnabled ? .primary : .secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.primary.opacity(colorScheme == .dark ? 0.075 : 0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(.white.opacity(colorScheme == .dark ? 0.08 : 0.36), lineWidth: 1)
            )
            .opacity(isEnabled ? 1 : 0.55)
        }
        .buttonStyle(PressableButtonStyle())
        .disabled(!isEnabled)
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
                    labeledTextField("ชื่อประเภทห้อง", placeholder: "เช่น ห้องพัดลม", text: $name)
                        .limitedText($name, maxLength: 40, trimNewlines: true)
                    moneyInputRow("ค่าเช่ารายเดือน", text: $price, note: "ยอดหลักที่ใช้สร้างบิลรายเดือน")
                }

                Section("ค่าใช้จ่ายเพิ่มเติม") {
                    moneyInputRow("ค่าน้ำ", text: $water, note: "ใส่ 0 ถ้ายังไม่คิดรวมในประเภทห้อง")
                    moneyInputRow("ค่าไฟ", text: $electric, note: "ใส่ 0 ถ้าคิดตามมิเตอร์ภายหลัง")
                    moneyInputRow("ค่าส่วนกลาง", text: $common, note: "ค่าบริการประจำเดือนถ้ามี")
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

    private func labeledTextField(_ title: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.custom("SukhumvitSet-Bold", size: 13))
                .foregroundStyle(.secondary)

            TextField(placeholder, text: text)
                .font(.custom("SukhumvitSet-Medium", size: 16))
                .frame(minHeight: 44)
        }
        .padding(.vertical, 4)
    }

    private func moneyInputRow(_ title: String, text: Binding<String>, note: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.custom("SukhumvitSet-Bold", size: 13))
                        .foregroundStyle(.primary)
                    Text(note)
                        .font(.custom("SukhumvitSet-Text", size: 10))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 12)

                HStack(spacing: 6) {
                    TextField("0", text: text)
                        .font(.custom("SukhumvitSet-Bold", size: 17))
                        .multilineTextAlignment(.trailing)
                        .keyboardType(.decimalPad)
                        .decimalInput(text, maxIntegerDigits: 8, maxFractionDigits: 2)
                        .frame(minWidth: 58, maxWidth: 96)

                    Text("บาท")
                        .font(.custom("SukhumvitSet-Medium", size: 11))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 8)
    }
}

private struct PricingRoomEditor: View {
    @Environment(\.dismiss) private var dismiss
    let roomTypes: [RoomType]
    let onSave: (String, String) -> Void
    @State private var roomNumber: String
    @State private var roomType: String
    @State private var selectedDetent: PresentationDetent = .medium

    init(room: Room? = nil, roomTypes: [RoomType], onSave: @escaping (String, String) -> Void) {
        self.roomTypes = roomTypes
        self.onSave = onSave
        _roomNumber = State(initialValue: room?.roomNumber ?? "")
        _roomType = State(initialValue: room?.roomType ?? roomTypes.first?.name ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("ข้อมูลห้อง") {
                    TextField("เลขห้อง", text: $roomNumber)
                        .keyboardType(.numbersAndPunctuation)
                        .limitedText($roomNumber, maxLength: 10, trimNewlines: true)

                    Picker("ประเภทห้อง", selection: $roomType) {
                        ForEach(roomTypes) { type in
                            Text(LocalizedStringKey(type.name)).tag(type.name)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(.primary)
                }

                if let type = roomTypes.first(where: { clean($0.name) == clean(roomType) }) {
                    Section("ราคาจากประเภทห้อง") {
                        priceLine("ค่าเช่า", value: type.price)
                        priceLine("ค่าน้ำ", value: type.waterFee)
                        priceLine("ค่าไฟ", value: type.electricFee)
                        priceLine("ค่าส่วนกลาง", value: type.commonFee)
                    }
                }
            }
            .navigationTitle("เลขห้อง")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("ยกเลิก") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("บันทึก") {
                        onSave(clean(roomNumber), clean(roomType))
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(clean(roomNumber).isEmpty || clean(roomType).isEmpty || roomTypes.isEmpty)
                }
            }
            .dismissKeyboardOnTap()
            .scrollDismissesKeyboard(.interactively)
        }
        .presentationDetents([.medium, .large], selection: $selectedDetent)
        .presentationDragIndicator(.visible)
    }

    private func priceLine(_ title: String, value: Double) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value.formatted(.number.precision(.fractionLength(0))) + " ฿")
                .fontWeight(.semibold)
        }
    }

    private func clean(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
