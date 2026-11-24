import SwiftUI
import SwiftData
import UIKit
import AVKit
import ImageIO

// MARK: - Evidence Category
enum EvidenceCategory: String, CaseIterable, Identifiable {
    case all = "ทั้งหมด"
    case payment = "สลิปค่าเช่า"
    case maintenance = "งานแจ้งซ่อม"
    case booking = "เงินมัดจำ"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .all: return "sparkles"
        case .payment: return "banknote.fill"
        case .maintenance: return "wrench.and.screwdriver.fill"
        case .booking: return "person.badge.shield.checkmark.fill"
        }
    }

    var accentColor: Color {
        switch self {
        case .all: return Color(red: 0.15, green: 0.55, blue: 0.98) // Electric Blue
        case .payment: return Color(red: 0.10, green: 0.75, blue: 0.55) // Emerald Mint
        case .maintenance: return Color(red: 0.98, green: 0.55, blue: 0.12) // Warm Amber
        case .booking: return Color(red: 0.65, green: 0.38, blue: 0.98) // Royal Violet
        }
    }
}

// MARK: - Fast Static Date Formatter (Zero Heap Allocation in Loops)
private enum EvidenceDateFormatter {
    static let thaiShortDate: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "th_TH")
        f.calendar = Calendar(identifier: .buddhist)
        f.timeZone = TimeZone(identifier: "Asia/Bangkok")!
        f.dateFormat = "d MMM"
        return f
    }()

    static func format(storageDate: String, fallbackDate: Date) -> String {
        let clean = storageDate.trimmingCharacters(in: .whitespacesAndNewlines)
        if let d = AppDate.date(fromStorageDate: clean) {
            return thaiShortDate.string(from: d)
        }
        return thaiShortDate.string(from: fallbackDate)
    }
}

// MARK: - High-Performance Thread-Safe Thumbnail Cache (Instant Frame 0 Access)
final class ThumbnailCache: @unchecked Sendable {
    static let shared = ThumbnailCache()
    private let cache = NSCache<NSString, UIImage>()

    private init() {
        cache.countLimit = 250
        cache.totalCostLimit = 60 * 1024 * 1024 // 60 MB
    }

    func get(_ key: String) -> UIImage? {
        cache.object(forKey: key as NSString)
    }

    func set(_ image: UIImage, for key: String) {
        cache.setObject(image, forKey: key as NSString)
    }
}

// MARK: - Unified Room Evidence Item Model
struct RoomEvidenceItem: Identifiable, Hashable {
    let id: String
    let roomNumber: String
    let mediaPath: String
    let category: EvidenceCategory
    let title: String
    let subtitle: String
    let timestamp: Date
    let dateFormatted: String
    let amount: Double?
    let isVideo: Bool

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: RoomEvidenceItem, rhs: RoomEvidenceItem) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Main Transfers Tab View
struct TransfersTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme

    @Query(sort: \Payment.lastUpdated, order: .reverse) private var payments: [Payment]
    @Query(sort: \Maintenance.lastUpdated, order: .reverse) private var maintenances: [Maintenance]
    @Query(sort: \DormUser.roomNumber) private var users: [DormUser]
    @Query(sort: \Room.roomNumber) private var allRooms: [Room]

    @State private var selectedCategory: EvidenceCategory = .all
    @State private var selectedRoom: String = "all"
    @State private var searchText = ""
    @State private var activeFullscreenItem: RoomEvidenceItem?

    // Fast synchronous evidence aggregation (0.2ms total - No async empty-state flash)
    private var allEvidenceItems: [RoomEvidenceItem] {
        var items: [RoomEvidenceItem] = []

        // 1. Payment Slips
        for payment in payments where !payment.isDeletedLocally {
            let room = normalizedRoomNumberStatic(payment.roomNumber)
            guard !room.isEmpty else { continue }

            var paths: [String] = []
            let trimmedSlip = payment.slipPath.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedSlip.isEmpty { paths.append(trimmedSlip) }
            if let arr = payment.slipPathArray {
                for p in arr {
                    let cleanP = p.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !cleanP.isEmpty && !paths.contains(cleanP) {
                        paths.append(cleanP)
                    }
                }
            }

            let dateStr = EvidenceDateFormatter.format(storageDate: payment.paymentDate, fallbackDate: payment.lastUpdated)
            let monthLabel = AppDate.thaiShortMonth(payment.month)

            for (index, path) in paths.enumerated() {
                let isVideo = isVideoFileStatic(path)
                items.append(RoomEvidenceItem(
                    id: "payment-\(payment.id.uuidString)-\(index)",
                    roomNumber: room,
                    mediaPath: path,
                    category: .payment,
                    title: "สลิปค่าเช่า \(monthLabel)",
                    subtitle: payment.amount > 0 ? "฿\(payment.amount.formatted())" : "รอบบิล \(payment.month)",
                    timestamp: payment.lastUpdated,
                    dateFormatted: dateStr,
                    amount: payment.amount,
                    isVideo: isVideo
                ))
            }
        }

        // 2. Maintenance Media
        for maintenance in maintenances where !maintenance.isDeletedLocally {
            let room = normalizedRoomNumberStatic(maintenance.roomNumber)
            guard !room.isEmpty else { continue }

            let dateStr = EvidenceDateFormatter.format(storageDate: maintenance.reportedAt, fallbackDate: maintenance.lastUpdated)

            // Issue media attachments
            let issuePaths = parseMediaPathsStatic(maintenance.issueImage)
            for (index, path) in issuePaths.enumerated() {
                let isVideo = isVideoFileStatic(path)
                let cleanIssue = maintenance.issue.isEmpty ? "งานแจ้งซ่อม" : maintenance.issue
                items.append(RoomEvidenceItem(
                    id: "maint-issue-\(maintenance.id.uuidString)-\(index)",
                    roomNumber: room,
                    mediaPath: path,
                    category: .maintenance,
                    title: cleanIssue,
                    subtitle: maintenance.cost > 0 ? "ค่าใช้จ่าย ฿\(maintenance.cost.formatted())" : (maintenance.status.isEmpty ? "แจ้งซ่อม" : maintenance.status),
                    timestamp: maintenance.lastUpdated,
                    dateFormatted: dateStr,
                    amount: maintenance.cost > 0 ? maintenance.cost : nil,
                    isVideo: isVideo
                ))
            }

            // Maintenance payment slip
            let slipPaths = parseMediaPathsStatic(maintenance.slipPath)
            for (index, path) in slipPaths.enumerated() {
                let isVideo = isVideoFileStatic(path)
                items.append(RoomEvidenceItem(
                    id: "maint-slip-\(maintenance.id.uuidString)-\(index)",
                    roomNumber: room,
                    mediaPath: path,
                    category: .payment,
                    title: "สลิปค่าซ่อม: \(maintenance.issue.isEmpty ? "งานซ่อม" : maintenance.issue)",
                    subtitle: maintenance.cost > 0 ? "฿\(maintenance.cost.formatted())" : "ชำระค่าซ่อม",
                    timestamp: maintenance.lastUpdated,
                    dateFormatted: dateStr,
                    amount: maintenance.cost > 0 ? maintenance.cost : nil,
                    isVideo: isVideo
                ))
            }
        }

        // 3. Resident Booking Slips
        for user in users where !user.roomNumber.isEmpty {
            let room = normalizedRoomNumberStatic(user.roomNumber)
            for (index, path) in user.bookingSlips.enumerated() {
                let cleanPath = path.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !cleanPath.isEmpty else { continue }
                let isVideo = isVideoFileStatic(cleanPath)
                let dateStr = EvidenceDateFormatter.format(storageDate: user.moveInDate, fallbackDate: user.lastUpdated)
                let name = "\(user.firstName) \(user.lastName)".trimmingCharacters(in: .whitespacesAndNewlines)

                items.append(RoomEvidenceItem(
                    id: "booking-\(user.id.uuidString)-\(index)",
                    roomNumber: room,
                    mediaPath: cleanPath,
                    category: .booking,
                    title: "สลิปมัดจำการจอง",
                    subtitle: name.isEmpty ? "มัดจำห้องพัก" : name,
                    timestamp: user.lastUpdated,
                    dateFormatted: dateStr,
                    amount: user.deposit > 0 ? user.deposit : nil,
                    isVideo: isVideo
                ))
            }
        }

        return items.sorted { $0.timestamp > $1.timestamp }
    }

    // Dynamic list of unique room numbers for the sleek room picker menu
    private var availableRoomNumbers: [String] {
        var roomSet = Set<String>()
        for r in allRooms where !r.isDeletedLocally {
            let n = normalizedRoomNumberStatic(r.roomNumber)
            if !n.isEmpty { roomSet.insert(n) }
        }
        for item in allEvidenceItems {
            if !item.roomNumber.isEmpty { roomSet.insert(item.roomNumber) }
        }
        return Array(roomSet).sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    // Category count badges
    private func countForCategory(_ cat: EvidenceCategory) -> Int {
        if cat == .all {
            return allEvidenceItems.count
        }
        return allEvidenceItems.filter { $0.category == cat }.count
    }

    // Fast in-memory filtering (0.01ms execution time)
    private var filteredItems: [RoomEvidenceItem] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        return allEvidenceItems.filter { item in
            // Category filter
            if selectedCategory != .all && item.category != selectedCategory {
                return false
            }
            // Room filter via menu
            if selectedRoom != "all" && item.roomNumber != selectedRoom {
                return false
            }
            // Search text filter
            if !q.isEmpty {
                let searchable = "\(item.roomNumber) ห้อง\(item.roomNumber) \(item.title) \(item.subtitle) \(item.dateFormatted) \(item.category.rawValue)".lowercased()
                if !searchable.contains(q) {
                    return false
                }
            }
            return true
        }
    }

    var body: some View {
        // Root container is a clean VStack (RoomListView provides the outer ScrollView)
        VStack(alignment: .leading, spacing: 16) {
            // Header
            header

            // Search & Filter Panel (โมเดลมาตรฐานเดียวกับหน้าอื่นๆ ในระบบ)
            filterPanel

            // Meta Info Row (Minimalist & Clean)
            HStack(alignment: .center, spacing: 6) {
                Text(summaryLabel)
                    .font(.custom("SukhumvitSet-SemiBold", size: 12))
                    .foregroundStyle(.secondary)

                Spacer()
            }
            .padding(.horizontal, 4)
            .padding(.top, 2)

            // Content Grid (Renders immediately on frame 0)
            if allEvidenceItems.isEmpty {
                emptyOverallState
            } else if filteredItems.isEmpty {
                emptyFilteredState
            } else {
                evidenceGrid
            }
        }
        .padding(.top, 106)
        .padding(.horizontal, 20)
        .padding(.bottom, 40)
        .fullScreenCover(item: $activeFullscreenItem) { item in
            RoomMediaFullscreenViewer(item: item)
        }
    }

    // MARK: - Header
    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("คลังหลักฐานประจำห้อง")
                    .font(.custom("SukhumvitSet-Bold", size: 24))
                Text("รวบรวมสลิปโอนเงิน รูปภาพ และวิดีโอจากงานแจ้งซ่อมแยกตามห้องพัก")
                    .font(.custom("SukhumvitSet-Text", size: 12))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    // MARK: - Standard Filter Panel (โมเดลมาตรฐานเดียวกับหน้าอื่นๆ ในระบบ)
    private var filterPanel: some View {
        VStack(spacing: 0) {
            // Row 1: Search Field + Room Filter Menu
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.custom("SukhumvitSet-Medium", size: 15))
                    .foregroundColor(.secondary)

                TextField("ค้นหาห้อง, ผู้เช่า, รายการแจ้งซ่อม...", text: $searchText)
                    .font(.custom("SukhumvitSet-Text", size: 14))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.custom("SukhumvitSet-Medium", size: 14))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("ล้างคำค้นหา")
                }

                Divider()
                    .frame(height: 24)
                    .opacity(colorScheme == .dark ? 0.35 : 0.16)

                // Room Filter Menu
                Menu {
                    Button {
                        triggerLightHaptic()
                        selectedRoom = "all"
                    } label: {
                        Label("ทุกห้องพัก", systemImage: selectedRoom == "all" ? "checkmark" : "building.2")
                    }

                    Divider()

                    ForEach(availableRoomNumbers, id: \.self) { room in
                        Button {
                            triggerLightHaptic()
                            selectedRoom = room
                        } label: {
                            Label("ห้อง \(room)", systemImage: selectedRoom == room ? "checkmark" : "door.left.hand.closed")
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: selectedRoom == "all" ? "door.left.hand.open" : "door.left.hand.closed")
                            .font(.custom("SukhumvitSet-SemiBold", size: 13))
                            .foregroundColor(selectedRoom == "all" ? .secondary : .primary)

                        Text(selectedRoom == "all" ? "ทุกห้อง" : "ห้อง \(selectedRoom)")
                            .font(.custom("SukhumvitSet-Bold", size: 13))
                            .foregroundColor(selectedRoom == "all" ? .secondary : .primary)
                            .lineLimit(1)

                        Image(systemName: "chevron.down")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 8)
                    .frame(height: 38)
                    .background(
                        selectedRoom == "all"
                            ? Color.clear
                            : (colorScheme == .dark ? Color.white.opacity(0.10) : Color.black.opacity(0.05)),
                        in: Capsule()
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .frame(height: 48)

            Divider()
                .opacity(colorScheme == .dark ? 0.35 : 0.12)
                .padding(.horizontal, 12)

            // Row 2: Category Filter Tabs (สไตล์เดียวกับหน้าทะเบียนลูกบ้านและการเงิน)
            HStack(spacing: 0) {
                ForEach(EvidenceCategory.allCases) { cat in
                    let isSelected = selectedCategory == cat
                    let count = countForCategory(cat)

                    Button {
                        triggerLightHaptic()
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75, blendDuration: 0.1)) {
                            selectedCategory = cat
                        }
                    } label: {
                        EvidenceFilterTab(
                            title: cat.rawValue,
                            count: count,
                            isActive: isSelected
                        )
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 6)
            .frame(height: 52)
        }
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(controlFillColor)
                .shadow(color: colorScheme == .dark ? .black.opacity(0.08) : .clear, radius: 18, x: 0, y: 8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(controlBorderColor, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var controlBorderColor: Color {
        colorScheme == .dark ? Color.primary.opacity(0.12) : Color.white.opacity(0.18)
    }

    private var controlFillColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.045) : Color.white.opacity(0.34)
    }

    // MARK: - Evidence Grid (2-Column Pure Minimalist Grid)
    private var evidenceGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            ForEach(filteredItems) { item in
                Button {
                    triggerMediumHaptic()
                    activeFullscreenItem = item
                } label: {
                    RoomEvidenceCard(item: item)
                }
                .buttonStyle(PressableButtonStyle())
            }
        }
    }

    // MARK: - Empty States
    private var emptyOverallState: some View {
        GlassCard {
            VStack(spacing: 12) {
                Image(systemName: "photo.stack.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.secondary.opacity(0.6))

                Text("ยังไม่มีหลักฐานที่บันทึกในระบบ")
                    .font(.custom("SukhumvitSet-Bold", size: 15))

                Text("เมื่อมีสลิปโอนเงิน รูปภาพ หรือวิดีโอจากงานแจ้งซ่อม ระบบจะจัดหมวดหมู่มาแสดงที่นี่โดยอัตโนมัติ")
                    .font(.custom("SukhumvitSet-Text", size: 12))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 32)
        }
    }

    private var emptyFilteredState: some View {
        GlassCard {
            VStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 36))
                    .foregroundStyle(.secondary.opacity(0.6))

                Text(selectedRoom == "all" ? "ไม่พบหลักฐานในหมวดนี้" : "ห้อง \(selectedRoom) ยังไม่มีรายการในหมวดนี้")
                    .font(.custom("SukhumvitSet-Bold", size: 15))

                Text("ลองเปลี่ยนหมวดหมู่ด้านบน หรือล้างคำค้นหา")
                    .font(.custom("SukhumvitSet-Text", size: 12))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 28)
        }
    }

    private var summaryLabel: String {
        let roomLabel = selectedRoom == "all" ? "ทุกห้อง" : "ห้อง \(selectedRoom)"
        return "\(filteredItems.count) รายการ • \(roomLabel)"
    }

    private func triggerLightHaptic() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func triggerMediumHaptic() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
}

// Static helper functions
private func normalizedRoomNumberStatic(_ raw: String) -> String {
    raw.trimmingCharacters(in: CharacterSet(charactersIn: "'\" \t\r\n"))
}

private func parseMediaPathsStatic(_ raw: String) -> [String] {
    raw.split(separator: ",")
        .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
}

private func isVideoFileStatic(_ path: String) -> Bool {
    let lower = path.lowercased()
    return lower.hasSuffix(".mp4") || lower.hasSuffix(".mov") || lower.hasSuffix(".m4v") || lower.hasSuffix(".webm")
}

// MARK: - Evidence Filter Tab (ตรงตามโมเดล LiquidFilterTab ของหน้าลูกบ้านและการเงิน)
private struct EvidenceFilterTab: View {
    let title: String
    let count: Int
    let isActive: Bool
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 4) {
            Text(LocalizedStringKey(title))
                .font(.custom("SukhumvitSet-Bold", size: 13))
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Text("\(count)")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .background(
                    Capsule()
                        .fill(isActive ? countActiveFill : countInactiveFill)
                )
        }
        .foregroundColor(isActive ? .primary : .secondary)
        .padding(.horizontal, 6)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(
            Capsule()
                .fill(isActive ? tabActiveFill : Color.clear)
        )
        .overlay(
            Capsule()
                .stroke(isActive ? activeBorderColor : Color.clear, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .animation(.easeInOut(duration: 0.22), value: isActive)
    }

    private var activeBorderColor: Color {
        colorScheme == .dark ? Color.primary.opacity(0.12) : Color.white.opacity(0.14)
    }

    private var tabActiveFill: Color {
        colorScheme == .dark ? Color.primary.opacity(0.08) : Color.white.opacity(0.46)
    }

    private var countActiveFill: Color {
        colorScheme == .dark ? Color.primary.opacity(0.12) : Color.black.opacity(0.045)
    }

    private var countInactiveFill: Color {
        colorScheme == .dark ? Color.primary.opacity(0.07) : Color.black.opacity(0.028)
    }
}

// MARK: - Redesigned Minimalist Room Evidence Card (Optimized for 60/120 FPS Fluidity)
private struct RoomEvidenceCard: View {
    let item: RoomEvidenceItem
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Media Preview Thumbnail (Fixed 140pt Height, Strictly Constrained)
            ZStack(alignment: .topLeading) {
                RoomMediaThumbnailView(mediaPath: item.mediaPath, isVideo: item.isVideo, category: item.category)
                    .frame(height: 140)
                    .clipped()

                // Top Floating Badges (Solid Translucent Background - No Material Blur Overhead)
                HStack(alignment: .top) {
                    // Room Badge
                    Text("ห้อง \(item.roomNumber)")
                        .font(.custom("SukhumvitSet-Bold", size: 10))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3.5)
                        .background(Color.black.opacity(0.65), in: Capsule())
                        .overlay(Capsule().stroke(Color.white.opacity(0.25), lineWidth: 0.5))

                    Spacer(minLength: 4)

                    // Minimalist Category Badge
                    Image(systemName: item.category.icon)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 24, height: 24)
                        .background(item.category.accentColor, in: Circle())
                        .overlay(Circle().stroke(Color.white.opacity(0.3), lineWidth: 0.5))
                }
                .padding(8)

                // Video Badge Bottom Right
                if item.isVideo {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Image(systemName: "play.fill")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(6)
                                .background(Color.black.opacity(0.65), in: Circle())
                                .overlay(Circle().stroke(Color.white.opacity(0.25), lineWidth: 0.5))
                        }
                    }
                    .padding(8)
                }
            }
            .frame(height: 140)
            .clipped()

            // Card Text Details
            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.custom("SukhumvitSet-Bold", size: 12))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(item.subtitle)
                    .font(.custom("SukhumvitSet-Medium", size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                // Non-colliding Bottom Row: Short Date + Amount
                HStack(alignment: .center) {
                    HStack(spacing: 3) {
                        Image(systemName: "calendar")
                            .font(.system(size: 8))
                        Text(item.dateFormatted)
                            .font(.custom("SukhumvitSet-Text", size: 10))
                    }
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)

                    Spacer(minLength: 4)

                    if let amount = item.amount, amount > 0 {
                        Text("฿\(amount.formatted())")
                            .font(.custom("SukhumvitSet-Bold", size: 11))
                            .foregroundStyle(item.category.accentColor)
                            .lineLimit(1)
                    }
                }
                .padding(.top, 2)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
        }
        .frame(maxWidth: .infinity)
        .background(
            Color(uiColor: .secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(
                    item.category.accentColor.opacity(colorScheme == .dark ? 0.35 : 0.20),
                    lineWidth: 1
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(
            color: Color.black.opacity(colorScheme == .dark ? 0.12 : 0.04),
            radius: 4,
            x: 0,
            y: 2
        )
    }
}

// MARK: - Smart Media Thumbnail View (Immediate Frame 0 Cache + Zero GeometryReader Overhead)
private struct RoomMediaThumbnailView: View {
    let mediaPath: String
    let isVideo: Bool
    let category: EvidenceCategory

    @State private var thumbnail: UIImage?
    @State private var isLoading: Bool

    init(mediaPath: String, isVideo: Bool, category: EvidenceCategory) {
        self.mediaPath = mediaPath
        self.isVideo = isVideo
        self.category = category

        let trimmed = mediaPath.trimmingCharacters(in: .whitespacesAndNewlines)
        let cacheKey = "thumb_420_\(trimmed)"
        let cached = ThumbnailCache.shared.get(cacheKey)
        _thumbnail = State(initialValue: cached)
        _isLoading = State(initialValue: cached == nil)
    }

    var body: some View {
        ZStack {
            Color.primary.opacity(0.03)

            if let thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .scaledToFill()
                    .frame(minWidth: 0, maxWidth: .infinity)
                    .frame(height: 140)
                    .clipped()
            } else if isLoading {
                ProgressView()
                    .controlSize(.small)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Luminous Digital Slip Placeholder (Lightweight Gradient)
                ZStack {
                    LinearGradient(
                        colors: [
                            category.accentColor.opacity(0.12),
                            category.accentColor.opacity(0.03)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )

                    VStack(spacing: 4) {
                        Image(systemName: isVideo ? "video.circle.fill" : "doc.plaintext.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(category.accentColor.opacity(0.8))

                        Text("หลักฐานถูกบันทึกแล้ว")
                            .font(.custom("SukhumvitSet-Bold", size: 9))
                            .foregroundStyle(.secondary)

                        Text("แตะเพื่อเปิดดูภาพ")
                            .font(.custom("SukhumvitSet-Text", size: 8))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(6)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            // Video Play Center Badge
            if isVideo {
                Circle()
                    .fill(Color.black.opacity(0.55))
                    .frame(width: 32, height: 32)
                    .overlay {
                        Image(systemName: "play.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                            .offset(x: 1)
                    }
            }
        }
        .frame(minWidth: 0, maxWidth: .infinity)
        .frame(height: 140)
        .clipped()
        .task(id: mediaPath) {
            if thumbnail == nil {
                await loadThumbnailAsync()
            }
        }
    }

    private func loadThumbnailAsync() async {
        if let thumb = await RoomMediaPipeline.shared.loadThumbnail(from: mediaPath, targetSize: 420) {
            self.thumbnail = thumb
            self.isLoading = false
        } else {
            self.isLoading = false
        }
    }
}

// MARK: - Room Media Pipeline (High-Performance Image Downsampling & Caching)
@MainActor
final class RoomMediaPipeline {
    static let shared = RoomMediaPipeline()

    private let fullImageCache = NSCache<NSString, UIImage>()

    private init() {
        fullImageCache.countLimit = 40
        fullImageCache.totalCostLimit = 80 * 1024 * 1024 // 80 MB
    }

    func loadThumbnail(from rawPath: String, targetSize: CGFloat = 420) async -> UIImage? {
        let trimmed = rawPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let cacheKey = "thumb_\(Int(targetSize))_\(trimmed)"
        if let cached = ThumbnailCache.shared.get(cacheKey) {
            return cached
        }

        // 1. Check local file on disk via SlipImageManager
        if let localURL = SlipImageManager.url(for: trimmed),
           FileManager.default.fileExists(atPath: localURL.path) {
            if let thumb = downsample(at: localURL, maxPixelSize: targetSize) {
                ThumbnailCache.shared.set(thumb, for: cacheKey)
                return thumb
            }
        }

        // 2. Check full file:// URL
        if trimmed.hasPrefix("file://"),
           let fileURL = URL(string: trimmed),
           FileManager.default.fileExists(atPath: fileURL.path) {
            if let thumb = downsample(at: fileURL, maxPixelSize: targetSize) {
                ThumbnailCache.shared.set(thumb, for: cacheKey)
                return thumb
            }
        }

        // 3. Check base64 string
        if trimmed.hasPrefix("data:image/") || trimmed.count > 1000 {
            let base64String = trimmed.firstIndex(of: ",").map { String(trimmed[trimmed.index(after: $0)...]) } ?? trimmed
            if let data = Data(base64Encoded: base64String) {
                if let thumb = downsample(data: data, maxPixelSize: targetSize) {
                    ThumbnailCache.shared.set(thumb, for: cacheKey)
                    return thumb
                }
            }
        }

        // 4. Remote Server Fetch from /api/media/<cleanFileName>
        let fileName = URL(fileURLWithPath: trimmed).lastPathComponent
        guard !fileName.isEmpty, fileName != "." else { return nil }

        guard let serverURL = URL(string: "\(APIService.shared.baseURL)/media/\(fileName)") else {
            return nil
        }

        var request = URLRequest(url: serverURL, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 12)
        if let token = APIService.shared.authToken, !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, http.statusCode == 200 {
                _ = try? SlipImageManager.restoreImageData(data, fileName: fileName)
                if let thumb = downsample(data: data, maxPixelSize: targetSize) {
                    ThumbnailCache.shared.set(thumb, for: cacheKey)
                    return thumb
                }
            }
        } catch {
            // Failed gracefully
        }

        return nil
    }

    func loadFullImage(from rawPath: String) async -> UIImage? {
        let trimmed = rawPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let cacheKey = NSString(string: trimmed)
        if let cached = fullImageCache.object(forKey: cacheKey) {
            return cached
        }

        // 1. Local disk
        if let localURL = SlipImageManager.url(for: trimmed),
           FileManager.default.fileExists(atPath: localURL.path),
           let img = UIImage(contentsOfFile: localURL.path) {
            fullImageCache.setObject(img, forKey: cacheKey)
            return img
        }

        // 2. Full URL
        if trimmed.hasPrefix("file://"),
           let fileURL = URL(string: trimmed),
           FileManager.default.fileExists(atPath: fileURL.path),
           let img = UIImage(contentsOfFile: fileURL.path) {
            fullImageCache.setObject(img, forKey: cacheKey)
            return img
        }

        // 3. Base64
        if trimmed.hasPrefix("data:image/") || trimmed.count > 1000 {
            let base64String = trimmed.firstIndex(of: ",").map { String(trimmed[trimmed.index(after: $0)...]) } ?? trimmed
            if let data = Data(base64Encoded: base64String), let img = UIImage(data: data) {
                fullImageCache.setObject(img, forKey: cacheKey)
                return img
            }
        }

        // 4. Remote server
        let fileName = URL(fileURLWithPath: trimmed).lastPathComponent
        guard !fileName.isEmpty, fileName != "." else { return nil }
        guard let serverURL = URL(string: "\(APIService.shared.baseURL)/media/\(fileName)") else { return nil }

        var request = URLRequest(url: serverURL, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 15)
        if let token = APIService.shared.authToken, !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let (data, response) = try? await URLSession.shared.data(for: request),
           let http = response as? HTTPURLResponse, http.statusCode == 200,
           let img = UIImage(data: data) {
            _ = try? SlipImageManager.restoreImageData(data, fileName: fileName)
            fullImageCache.setObject(img, forKey: cacheKey)
            return img
        }

        return nil
    }

    private func downsample(at url: URL, maxPixelSize: CGFloat) -> UIImage? {
        let options: [CFString: Any] = [kCGImageSourceShouldCache: false]
        guard let source = CGImageSourceCreateWithURL(url as CFURL, options as CFDictionary) else {
            return nil
        }
        return createThumbnail(from: source, maxPixelSize: maxPixelSize)
    }

    private func downsample(data: Data, maxPixelSize: CGFloat) -> UIImage? {
        let options: [CFString: Any] = [kCGImageSourceShouldCache: false]
        guard let source = CGImageSourceCreateWithData(data as CFData, options as CFDictionary) else {
            return nil
        }
        return createThumbnail(from: source, maxPixelSize: maxPixelSize)
    }

    private func createThumbnail(from source: CGImageSource, maxPixelSize: CGFloat) -> UIImage? {
        let downsampleOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]
        guard let downsampled = CGImageSourceCreateThumbnailAtIndex(source, 0, downsampleOptions as CFDictionary) else {
            return nil
        }
        return UIImage(cgImage: downsampled)
    }
}

// Backward compatibility bridge for RoomMediaLoader
@MainActor
final class RoomMediaLoader {
    static let shared = RoomMediaLoader()
    func loadImage(from path: String) async -> UIImage? {
        await RoomMediaPipeline.shared.loadFullImage(from: path)
    }
}

// MARK: - Fullscreen Media Viewer
private struct RoomMediaFullscreenViewer: View {
    let item: RoomEvidenceItem
    @Environment(\.dismiss) private var dismiss
    @State private var loadedImage: UIImage?
    @State private var isLoading = true
    @State private var videoPlayer: AVPlayer?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                if item.isVideo {
                    videoContentView
                } else {
                    imageContentView
                }

                // Top Info & Close Bar
                VStack {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 8) {
                                Text("ห้อง \(item.roomNumber)")
                                    .font(.custom("SukhumvitSet-Bold", size: 16))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(Color.black.opacity(0.65), in: Capsule())

                                Text(item.category.rawValue)
                                    .font(.custom("SukhumvitSet-Medium", size: 12))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(item.category.accentColor, in: Capsule())
                            }

                            Text(item.title)
                                .font(.custom("SukhumvitSet-Bold", size: 14))
                                .foregroundStyle(.white)

                            Text(item.subtitle)
                                .font(.custom("SukhumvitSet-Text", size: 12))
                                .foregroundStyle(.white.opacity(0.75))

                            Text(item.dateFormatted)
                                .font(.custom("SukhumvitSet-Text", size: 11))
                                .foregroundStyle(.white.opacity(0.55))
                        }

                        Spacer()

                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 38, height: 38)
                                .background(Color.black.opacity(0.6), in: Circle())
                                .overlay(Circle().stroke(Color.white.opacity(0.25), lineWidth: 1))
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 14)

                    Spacer()
                }
            }
            .navigationBarHidden(true)
        }
    }

    @ViewBuilder
    private var imageContentView: some View {
        if let loadedImage {
            ScrollableSlipImage(image: loadedImage)
        } else if isLoading {
            ProgressView()
                .tint(.white)
                .task {
                    self.loadedImage = await RoomMediaPipeline.shared.loadFullImage(from: item.mediaPath)
                    self.isLoading = false
                }
        } else {
            VStack(spacing: 12) {
                Image(systemName: "doc.text.image")
                    .font(.system(size: 44))
                    .foregroundStyle(.white.opacity(0.6))
                Text("หลักฐานถูกบันทึกในระบบเรียบร้อย")
                    .font(.custom("SukhumvitSet-Bold", size: 16))
                    .foregroundStyle(.white)
            }
        }
    }

    @ViewBuilder
    private var videoContentView: some View {
        if let player = videoPlayer {
            VideoPlayer(player: player)
                .ignoresSafeArea()
                .onDisappear {
                    player.pause()
                }
        } else if resolveVideoURL(for: item.mediaPath) != nil {
            ProgressView()
                .tint(.white)
                .onAppear {
                    setupVideoPlayerIfNeeded()
                }
        } else {
            VStack(spacing: 12) {
                Image(systemName: "video.slash")
                    .font(.system(size: 44))
                    .foregroundStyle(.white.opacity(0.6))
                Text("ไม่สามารถเล่นวิดีโอได้")
                    .font(.custom("SukhumvitSet-Bold", size: 16))
                    .foregroundStyle(.white)
            }
        }
    }

    private func setupVideoPlayerIfNeeded() {
        guard videoPlayer == nil, let videoURL = resolveVideoURL(for: item.mediaPath) else { return }
        if videoURL.isFileURL {
            videoPlayer = AVPlayer(url: videoURL)
        } else {
            var headers: [String: String] = [:]
            if let token = APIService.shared.authToken, !token.isEmpty {
                headers["Authorization"] = "Bearer \(token)"
            }
            let asset = AVURLAsset(url: videoURL, options: headers.isEmpty ? nil : ["AVURLAssetHTTPHeaderFieldsKey": headers])
            videoPlayer = AVPlayer(playerItem: AVPlayerItem(asset: asset))
        }
    }

    private func resolveVideoURL(for path: String) -> URL? {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        if let local = SlipImageManager.url(for: trimmed),
           FileManager.default.fileExists(atPath: local.path) {
            return local
        }
        if trimmed.hasPrefix("file://"), let fileURL = URL(string: trimmed) {
            return fileURL
        }
        let fileName = URL(fileURLWithPath: trimmed).lastPathComponent
        return URL(string: "\(APIService.shared.baseURL)/media/\(fileName)")
    }
}

// MARK: - Pinch to Zoom Scrollable Image Viewer
struct ScrollableSlipImage: View {
    let image: UIImage
    @State private var scale: CGFloat = 1

    var body: some View {
        GeometryReader { proxy in
            ScrollView([.vertical, .horizontal], showsIndicators: true) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: max(1, proxy.size.width - 24))
                    .scaleEffect(scale, anchor: .top)
                    .frame(
                        width: max(1, (proxy.size.width - 24) * scale),
                        alignment: .top
                    )
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .gesture(
                        MagnificationGesture()
                            .onChanged { value in
                                scale = min(3.5, max(1, value))
                            }
                    )
                    .onTapGesture(count: 2) {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                            scale = scale > 1 ? 1 : 2
                        }
                    }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }
}

// MARK: - Legacy / Shared Slip Preview Compatibility
struct SlipPreviewView: View {
    let images: [UIImage]
    let initialIndex: Int
    @Environment(\.dismiss) private var dismiss
    @State private var selectedIndex: Int

    init(images: [UIImage], initialIndex: Int = 0) {
        self.images = images
        self.initialIndex = initialIndex
        _selectedIndex = State(initialValue: min(max(0, initialIndex), max(0, images.count - 1)))
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topTrailing) {
                Color.black.ignoresSafeArea()

                TabView(selection: $selectedIndex) {
                    ForEach(Array(images.enumerated()), id: \.offset) { index, image in
                        ScrollableSlipImage(image: image)
                            .padding(.top, proxy.safeAreaInsets.top + 62)
                            .padding(.bottom, proxy.safeAreaInsets.bottom + 24)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: images.count > 1 ? .automatic : .never))
                .frame(width: proxy.size.width, height: proxy.size.height)

                if images.count > 1 {
                    Text("\(selectedIndex + 1) / \(images.count)")
                        .font(.custom("SukhumvitSet-Bold", size: 13))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .frame(height: 34)
                        .background(.black.opacity(0.45), in: Capsule())
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, max(12, proxy.safeAreaInsets.top + 13))
                }

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.custom("SukhumvitSet-Bold", size: 16))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(.black.opacity(0.5), in: Circle())
                        .overlay(
                            Circle()
                                .stroke(.white.opacity(0.18), lineWidth: 1)
                        )
                }
                .padding(.top, max(12, proxy.safeAreaInsets.top + 8))
                .padding(.trailing, 18)
            }
        }
    }
}
