import SwiftUI
import SwiftData

struct RoomsTabView: View {
    @Binding var showingEditor: Bool
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Room.roomNumber) private var allRooms: [Room]
    @Query(sort: \RoomType.name) private var roomTypes: [RoomType]
    @State private var editingRoom: Room?
    @State private var roomToDelete: Room?

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
                    RoomManagementRow(room: room, onEdit: {
                        editingRoom = room
                    }, onDelete: {
                        roomToDelete = room
                    })
                }
            }
        }
        .padding(.top, 106)
        .padding(.horizontal, 20)
        .sheet(isPresented: $showingEditor) {
            RoomEditor(roomTypes: roomTypes) { roomNumber, roomType in
                let room = Room(roomNumber: roomNumber, roomType: roomType)
                room.ownerAccountID = UserDefaults.standard.integer(forKey: "adminID")
                room.isDirty = true
                room.lastUpdated = Date()
                modelContext.insert(room)
                saveAndPush()
            }
            .iphoneSheetStyle()
        }
        .sheet(item: $editingRoom) { room in
            RoomEditor(room: room, roomTypes: roomTypes) { roomNumber, roomType in
                room.roomNumber = roomNumber
                room.roomType = roomType
                room.isDirty = true
                room.lastUpdated = Date()
                saveAndPush()
            }
            .iphoneSheetStyle()
        }
        .confirmationDialog("ลบห้องพักนี้หรือไม่", isPresented: deleteDialogBinding) {
            Button("ลบห้อง \(roomToDelete?.roomNumber ?? "")", role: .destructive) {
                guard let room = roomToDelete else { return }
                room.isDeletedLocally = true
                room.isDirty = true
                room.lastUpdated = Date()
                saveAndPush()
                roomToDelete = nil
            }
            Button("ยกเลิก", role: .cancel) { }
        }
    }

    private var deleteDialogBinding: Binding<Bool> {
        Binding(
            get: { roomToDelete != nil },
            set: { if !$0 { roomToDelete = nil } }
        )
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
}

private struct RoomManagementRow: View {
    let room: Room
    let onEdit: () -> Void
    let onDelete: () -> Void

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
                }
                Spacer()
                Image(systemName: room.isDirty ? "arrow.triangle.2.circlepath" : "checkmark.circle.fill")
                    .foregroundStyle(room.isDirty ? .orange : .green)
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

private struct RoomEditor: View {
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
                    if roomTypes.isEmpty {
                        TextField("ประเภทห้อง", text: $roomType)
                            .limitedText($roomType, maxLength: 40, trimNewlines: true)
                    } else {
                        Picker("ประเภทห้อง", selection: $roomType) {
                            Text("ไม่ระบุ").tag("")
                            ForEach(roomTypes) { type in
                                Text(type.name).tag(type.name)
                            }
                        }
                    }
                }
            }
            .navigationTitle("ข้อมูลห้องพัก")
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
                    .disabled(clean(roomNumber).isEmpty)
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
}
