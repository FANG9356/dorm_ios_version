import SwiftUI

struct SyncStatusBadge: View {
    var isDirty: Bool
    var isDeletedLocally: Bool
    
    @ObservedObject private var syncManager = SyncManager.shared
    
    var body: some View {
        if isDirty || isDeletedLocally {
            HStack(spacing: 4) {
                Image(systemName: iconName)
                    .font(.system(size: 10, weight: .bold))
                Text(statusText)
                    .font(.custom("SukhumvitSet-SemiBold", size: 10))
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(backgroundColor)
            .foregroundColor(foregroundColor)
            .cornerRadius(6)
        }
    }
    
    private var isSyncing: Bool {
        switch syncManager.state {
        case .preparing, .uploading, .applying: return true
        default: return false
        }
    }
    
    private var isFailed: Bool {
        if case .failed = syncManager.state { return true }
        return false
    }
    
    private var statusText: String {
        if isDeletedLocally {
            return isSyncing ? "กำลังลบ..." : "รอการลบ"
        }
        if isSyncing { return "กำลังซิงก์" }
        if isFailed { return "ส่งไม่สำเร็จ" }
        return "อยู่ในเครื่อง"
    }
    
    private var iconName: String {
        if isDeletedLocally { return "trash.fill" }
        if isSyncing { return "arrow.triangle.2.circlepath" }
        if isFailed { return "exclamationmark.circle.fill" }
        return "clock.fill"
    }
    
    private var backgroundColor: Color {
        if isFailed { return Color.red.opacity(0.15) }
        if isSyncing { return Color.blue.opacity(0.15) }
        return Color.orange.opacity(0.15)
    }
    
    private var foregroundColor: Color {
        if isFailed { return .red }
        if isSyncing { return .blue }
        return .orange
    }
}
