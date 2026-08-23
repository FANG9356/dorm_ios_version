import SwiftUI
import SwiftData

struct SystemLogsTabView: View {
    @Query(sort: \LocalSystemLog.timestamp, order: .reverse) private var logs: [LocalSystemLog]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("ประวัติการทำงาน")
                .font(.custom("SukhumvitSet-Bold", size: 24))
            Text("ตรวจดูเหตุการณ์ล่าสุดที่แอปบันทึกไว้ในเครื่อง")
                .font(.custom("SukhumvitSet-Text", size: 12))
                .foregroundStyle(.secondary)

            if logs.isEmpty {
                GlassCard {
                    Text("ยังไม่มีประวัติการทำงาน")
                        .font(.custom("SukhumvitSet-Medium", size: 14))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 28)
                }
            } else {
                ForEach(logs) { log in
                    GlassCard {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "doc.text.magnifyingglass")
                                .foregroundStyle(.indigo)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(log.action)
                                    .font(.custom("SukhumvitSet-Bold", size: 14))
                                Text(log.details)
                                    .font(.custom("SukhumvitSet-Text", size: 11))
                                    .foregroundStyle(.secondary)
                                Text(log.timestamp.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                }
            }
        }
        .padding(.top, 106)
        .padding(.horizontal, 20)
    }
}
