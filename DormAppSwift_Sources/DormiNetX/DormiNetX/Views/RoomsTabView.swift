import SwiftUI
import SwiftData

struct RoomsTabView: View {
    @Query(sort: \Room.roomNumber) private var rooms: [Room]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("ห้องพัก")
                .font(.custom("SukhumvitSet-Bold", size: 24))
            Text("ข้อมูลห้องพักที่บันทึกไว้ในเครื่อง")
                .font(.custom("SukhumvitSet-Text", size: 12))
                .foregroundStyle(.secondary)

            if rooms.isEmpty {
                emptyState
            } else {
                ForEach(rooms) { room in
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
                }
            }
        }
        .padding(.top, 106)
        .padding(.horizontal, 20)
    }

    private var emptyState: some View {
        GlassCard {
            Text("ยังไม่มีข้อมูลห้องพัก")
                .font(.custom("SukhumvitSet-Medium", size: 14))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 28)
        }
    }
}
