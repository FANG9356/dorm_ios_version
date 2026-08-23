import SwiftUI
import SwiftData

struct MaintenanceTabView: View {
    @Query(sort: \Maintenance.lastUpdated, order: .reverse) private var maintenances: [Maintenance]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("แจ้งซ่อม")
                .font(.custom("SukhumvitSet-Bold", size: 24))
            Text("รายการแจ้งซ่อมจากข้อมูลในเครื่อง")
                .font(.custom("SukhumvitSet-Text", size: 12))
                .foregroundStyle(.secondary)

            if maintenances.isEmpty {
                GlassCard {
                    Text("ยังไม่มีรายการแจ้งซ่อม")
                        .font(.custom("SukhumvitSet-Medium", size: 14))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 28)
                }
            } else {
                ForEach(maintenances) { maintenance in
                    GlassCard {
                        HStack {
                            Image(systemName: "wrench.and.screwdriver.fill")
                                .foregroundStyle(.orange)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("ห้อง \(maintenance.roomNumber)")
                                    .font(.custom("SukhumvitSet-Bold", size: 15))
                                Text(maintenance.issue)
                                    .font(.custom("SukhumvitSet-Text", size: 11))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(maintenance.status.isEmpty ? "รอดำเนินการ" : maintenance.status)
                                .font(.custom("SukhumvitSet-Medium", size: 10))
                                .foregroundStyle(.orange)
                        }
                }
                }
            }
        }
        .padding(.top, 106)
        .padding(.horizontal, 20)
    }
}
