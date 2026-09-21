import SwiftUI
import SwiftData

struct SystemLogsTabView: View {
    @Query(sort: \LocalSystemLog.timestamp, order: .reverse) private var logs: [LocalSystemLog]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                Text("ประวัติการทำงาน")
                    .font(.custom("SukhumvitSet-Bold", size: 30))
                    .foregroundStyle(.primary)

                Text("ตรวจดูเหตุการณ์ล่าสุดที่แอปบันทึกไว้ในเครื่อง")
                    .font(.custom("SukhumvitSet-Text", size: 13))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack {
                Text("เหตุการณ์ล่าสุด")
                    .font(.custom("SukhumvitSet-Bold", size: 17))
                    .foregroundStyle(.primary)

                Spacer()

                Text("\(logs.count) รายการ")
                    .font(.custom("SukhumvitSet-Medium", size: 12))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .frame(height: 30)
                    .background(.ultraThinMaterial, in: Capsule())
            }
            .padding(.top, 12)

            if logs.isEmpty {
                GlassCard {
                    VStack(spacing: 12) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.custom("SukhumvitSet-SemiBold", size: 34))
                            .foregroundStyle(.secondary)
                        Text("ยังไม่มีประวัติการทำงาน")
                            .font(.custom("SukhumvitSet-Medium", size: 14))
                            .foregroundStyle(.secondary)
                    }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 28)
                }
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(logs) { log in
                        SystemLogRow(log: log)
                    }
                }
            }
        }
        .padding(.top, 106)
        .padding(.horizontal, 20)
        .padding(.bottom, 32)
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

private struct SystemLogRow: View {
    let log: LocalSystemLog

    var body: some View {
        GlassCard {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color.indigo.opacity(0.12))
                        .frame(width: 44, height: 44)

                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.custom("SukhumvitSet-SemiBold", size: 18))
                        .foregroundStyle(.indigo)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(log.action)
                        .font(.custom("SukhumvitSet-Bold", size: 16))
                        .foregroundStyle(.primary)
                        .lineLimit(2)

                    if !log.details.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(log.details)
                            .font(.custom("SukhumvitSet-Text", size: 13))
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                    }

                    Text(log.timestamp.formatted(date: .abbreviated, time: .shortened))
                        .font(.custom("SukhumvitSet-Text", size: 12))
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
