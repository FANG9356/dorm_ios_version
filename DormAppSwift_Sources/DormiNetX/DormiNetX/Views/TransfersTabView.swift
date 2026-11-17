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

// MARK: - View Mode
enum EvidenceViewMode: String, CaseIterable {
    case grid = "การ์ด"
    case compact = "ตาราง"

    var icon: String {
        switch self {
        case .grid: return "square.grid.2x2.fill"
        case .compact: return "square.grid.3x3.fill"
        }
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
    @State private var viewMode: EvidenceViewMode = .grid
    @State private var searchText = ""
    @State private var activeFullscreenItem: RoomEvidenceItem?

    // Pre-computed and cached evidence items for 120 FPS fluid scrolling
    @State private var cachedEvidenceItems: [RoomEvidenceItem] = []
    @State private var isProcessingData = false

    private var activeRooms: [Room] {
        allRooms
            .filter { !$0.isDeletedLocally }
            .sorted { $0.roomNumber.localizedStandardCompare($1.roomNumber) == .orderedAscending }
    }

    private var dataFingerprint: String {
        "\(payments.count)-\(maintenances.count)-\(users.count)-\(payments.first?.lastUpdated.timeIntervalSince1970 ?? 0)"
    }

    // Dynamic list of unique room numbers for the sleek room picker menu
    private var availableRoomNumbers: [String] {
        var roomSet = Set<String>()
        for r in activeRooms {
            let n = normalizedRoomNumberStatic(r.roomNumber)
            if !n.isEmpty { roomSet.insert(n) }
        }
        for item in cachedEvidenceItems {
            if !item.roomNumber.isEmpty { roomSet.insert(item.roomNumber) }
        }
        return Array(roomSet).sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    // Category count badges
    private func countForCategory(_ cat: EvidenceCategory) -> Int {
        if cat == .all {
            return cachedEvidenceItems.count
        }
        return cachedEvidenceItems.filter { $0.category == cat }.count
    }

    // Fast in-memory filtering (0.01ms execution time)
    private var filteredItems: [RoomEvidenceItem] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        return cachedEvidenceItems.filter { item in
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
        VStack(alignment: .leading, spacing: 14) {
            // Ambient Glass Control Panel (Search + Category Glow Pills)
            ambientControlPanel

            // Meta Info & View Switcher Row
            HStack(alignment: .center, spacing: 8) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(selectedCategory.accentColor)
                        .frame(width: 7, height: 7)

                    Text(summaryLabel)
                        .font(.custom("SukhumvitSet-SemiBold", size: 12))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Layout Switcher (2-Column Cards vs 3-Column Compact Grid)
                HStack(spacing: 2) {
                    ForEach(EvidenceViewMode.allCases, id: \.self) { mode in
                        Button {
                            triggerLightHaptic()
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                viewMode = mode
                            }
                        } label: {
                            Image(systemName: mode.icon)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(viewMode == mode ? Color.primary : Color.secondary.opacity(0.5))
                                .frame(width: 32, height: 28)
                                .background(
                                    viewMode == mode ? Color.primary.opacity(0.12) : Color.clear,
                                    in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(3)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(.ultraThinMaterial)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                )
            }
            .padding(.horizontal, 2)
            .padding(.top, 2)

            // Content Grid
            if isProcessingData && cachedEvidenceItems.isEmpty {
                loadingShimmerGrid
            } else if cachedEvidenceItems.isEmpty {
                emptyOverallState
            } else if filteredItems.isEmpty {
                emptyFilteredState
            } else {
                evidenceContent
            }
        }
        .padding(.top, 106)
        .padding(.horizontal, 18)
        .padding(.bottom, 40)
        .fullScreenCover(item: $activeFullscreenItem) { item in
            RoomMediaFullscreenViewer(item: item)
        }
        .task(id: dataFingerprint) {
            await refreshEvidenceItems()
        }
    }

    // MARK: - Ambient Light Glass Control Panel
    private var ambientControlPanel: some View {
        ZStack {
            // Ambient Backlight Glow (Subtly illuminates according to active category)
            selectedCategory.accentColor
                .opacity(colorScheme == .dark ? 0.20 : 0.10)
                .blur(radius: 28)
                .frame(height: 70)
                .offset(y: 8)

            VStack(spacing: 10) {
                // Row 1: Search Field + Sleek Room Selector Menu
                HStack(spacing: 8) {
                    // Search Bar
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.secondary)

                        TextField("ค้นหาห้อง, ผู้เช่า, รายการแจ้งซ่อม...", text: $searchText)
                            .font(.custom("SukhumvitSet-Text", size: 14))
                            .autocorrectionDisabled()

                        if !searchText.isEmpty {
                            Button {
                                searchText = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(colorScheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.03))
                    )

                    // Sleek Room Filter Menu (Handles 100+ rooms effortlessly without clutter)
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
                            Text(selectedRoom == "all" ? "ทุกห้อง" : "ห้อง \(selectedRoom)")
                                .font(.custom("SukhumvitSet-Bold", size: 12))
                                .lineLimit(1)

                            Image(systemName: "chevron.down")
                                .font(.system(size: 9, weight: .bold))
                        }
                        .foregroundStyle(selectedRoom == "all" ? Color.primary : selectedCategory.accentColor)
                        .padding(.horizontal, 10)
                        .frame(height: 36)
                        .background(
                            selectedRoom == "all"
                                ? (colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.04))
                                : selectedCategory.accentColor.opacity(0.14),
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                        )
                    }
                    .buttonStyle(.plain)
                }

                // Row 2: Category Filter Glow Pills (Pure Category-Centric Architecture)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(EvidenceCategory.allCases) { cat in
                            let isSelected = selectedCategory == cat
                            let count = countForCategory(cat)

                            Button {
                                triggerLightHaptic()
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.78)) {
                                    selectedCategory = cat
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: cat.icon)
                                        .font(.system(size: 11, weight: .bold))

                                    Text(cat.rawValue)
                                        .font(.custom("SukhumvitSet-Bold", size: 12))

                                    Text("\(count)")
                                        .font(.custom("SukhumvitSet-Bold", size: 10))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 1.5)
                                        .background(
                                            isSelected
                                                ? Color.white.opacity(0.28)
                                                : Color.primary.opacity(0.08),
                                            in: Capsule()
                                        )
                                }
                                .foregroundStyle(isSelected ? Color.white : Color.primary.opacity(0.75))
                                .padding(.horizontal, 12)
                                .frame(height: 32)
                                .background(
                                    isSelected
                                        ? cat.accentColor
                                        : (colorScheme == .dark ? Color.white.opacity(0.05) : Color.white.opacity(0.55)),
                                    in: Capsule()
                                )
                                .overlay(
                                    Capsule()
                                        .stroke(
                                            isSelected ? Color.white.opacity(0.35) : Color.primary.opacity(0.08),
                                            lineWidth: 1
                                        )
                                )
                                .shadow(
                                    color: isSelected ? cat.accentColor.opacity(0.4) : Color.clear,
                                    radius: 8,
                                    x: 0,
                                    y: 3
                                )
                            }
                            .buttonStyle(PressableButtonStyle())
                        }
                    }
                    .padding(.horizontal, 2)
                    .padding(.bottom, 2)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(colorScheme == .dark ? Color.white.opacity(0.045) : Color.white.opacity(0.45))
                    .background(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(.ultraThinMaterial)
                    )
                    .shadow(
                        color: colorScheme == .dark ? Color.black.opacity(0.18) : Color.black.opacity(0.04),
                        radius: 16,
                        x: 0,
                        y: 6
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(colorScheme == .dark ? 0.22 : 0.45),
                                Color.white.opacity(colorScheme == .dark ? 0.05 : 0.15)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
        }
    }

    // MARK: - Evidence Grid / Compact View
    @ViewBuilder
    private var evidenceContent: some View {
        if viewMode == .grid {
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
        } else {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                ForEach(filteredItems) { item in
                    Button {
                        triggerMediumHaptic()
                        activeFullscreenItem = item
                    } label: {
                        CompactEvidencePhotoCell(item: item)
                    }
                    .buttonStyle(PressableButtonStyle())
                }
            }
        }
    }

    // MARK: - Shimmer Loading Grid
    private var loadingShimmerGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            ForEach(0..<6, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.primary.opacity(0.05))
                    .frame(height: 200)
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

    // MARK: - Data Pipeline Aggregation (Off-Main-Thread / High-Performance)
    private func refreshEvidenceItems() async {
        isProcessingData = true
        let localPayments = payments
        let localMaintenances = maintenances
        let localUsers = users

        let aggregated = await Task.detached(priority: .userInitiated) { () -> [RoomEvidenceItem] in
            var items: [RoomEvidenceItem] = []

            // 1. Payment Slips (rent & utilities)
            for payment in localPayments where !payment.isDeletedLocally {
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

                let dateStr = !payment.paymentDate.isEmpty ? AppDate.thaiDayMonth(payment.paymentDate) : AppDate.thaiDayMonth(AppDate.dateKey(from: payment.lastUpdated))
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

            // 2. Maintenance Media (issue photos, videos & repair payment slips)
            for maintenance in localMaintenances where !maintenance.isDeletedLocally {
                let room = normalizedRoomNumberStatic(maintenance.roomNumber)
                guard !room.isEmpty else { continue }

                // Use thaiDayMonth so date string is always short and never overflows
                let dateStr = !maintenance.reportedAt.isEmpty ? AppDate.thaiDayMonth(maintenance.reportedAt) : AppDate.thaiDayMonth(AppDate.dateKey(from: maintenance.lastUpdated))

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
            for user in localUsers where !user.roomNumber.isEmpty {
                let room = normalizedRoomNumberStatic(user.roomNumber)
                for (index, path) in user.bookingSlips.enumerated() {
                    let cleanPath = path.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !cleanPath.isEmpty else { continue }
                    let isVideo = isVideoFileStatic(cleanPath)
                    let dateStr = !user.moveInDate.isEmpty ? AppDate.thaiDayMonth(user.moveInDate) : AppDate.thaiDayMonth(AppDate.dateKey(from: user.lastUpdated))
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
        }.value

        await MainActor.run {
            self.cachedEvidenceItems = aggregated
            self.isProcessingData = false
        }
    }

    private func triggerLightHaptic() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func triggerMediumHaptic() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
}

// Static helper functions to avoid capturing view state inside detached background tasks
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

// MARK: - Redesigned Minimalist Room Evidence Card (With Color & Ambient Light)
private struct RoomEvidenceCard: View {
    let item: RoomEvidenceItem
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Media Preview Thumbnail (Fixed 4:3 Aspect Ratio)
            ZStack(alignment: .topLeading) {
                RoomMediaThumbnailView(mediaPath: item.mediaPath, isVideo: item.isVideo, category: item.category)
                    .frame(height: 140)
                    .frame(maxWidth: .infinity)
                    .clipped()

                // Top Floating Glass Badges
                HStack(alignment: .top) {
                    // Room Badge (Luminous Frosted Glass Capsule)
                    Text("ห้อง \(item.roomNumber)")
                        .font(.custom("SukhumvitSet-Bold", size: 10))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3.5)
                        .background(.ultraThinMaterial, in: Capsule())
                        .overlay(Capsule().stroke(Color.white.opacity(0.3), lineWidth: 0.5))
                        .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 1)

                    Spacer()

                    // Minimalist Category Light Badge
                    Image(systemName: item.category.icon)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 24, height: 24)
                        .background(item.category.accentColor, in: Circle())
                        .overlay(Circle().stroke(Color.white.opacity(0.3), lineWidth: 0.5))
                        .shadow(color: item.category.accentColor.opacity(0.6), radius: 6, x: 0, y: 2)
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
                                .background(.ultraThinMaterial, in: Circle())
                                .overlay(Circle().stroke(Color.white.opacity(0.3), lineWidth: 0.5))
                        }
                    }
                    .padding(8)
                }
            }

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
        .background(
            Color(uiColor: .secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
        .overlay(
            // Specular Gradient Border Highlight (Color & Light effect)
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            item.category.accentColor.opacity(colorScheme == .dark ? 0.45 : 0.28),
                            Color.white.opacity(colorScheme == .dark ? 0.12 : 0.35),
                            Color.clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(
            color: item.category.accentColor.opacity(colorScheme == .dark ? 0.16 : 0.06),
            radius: 10,
            x: 0,
            y: 4
        )
    }
}

// MARK: - Compact Evidence Photo Cell View
private struct CompactEvidencePhotoCell: View {
    let item: RoomEvidenceItem

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RoomMediaThumbnailView(mediaPath: item.mediaPath, isVideo: item.isVideo, category: item.category)
                .aspectRatio(1, contentMode: .fill)
                .frame(maxWidth: .infinity)
                .clipped()

            // Subtle dark gradient scrim at bottom
            LinearGradient(
                colors: [.clear, .black.opacity(0.72)],
                startPoint: .center,
                endPoint: .bottom
            )

            // Room number badge
            Text("ห้อง \(item.roomNumber)")
                .font(.custom("SukhumvitSet-Bold", size: 10))
                .foregroundStyle(.white)
                .padding(6)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }
}

// MARK: - Smart Media Thumbnail View (Hardware-Accelerated Downsampling)
private struct RoomMediaThumbnailView: View {
    let mediaPath: String
    let isVideo: Bool
    let category: EvidenceCategory
    @State private var thumbnail: UIImage?
    @State private var isLoading = true

    var body: some View {
        ZStack {
            Color.primary.opacity(0.03)

            if let thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .scaledToFill()
            } else if isLoading {
                ProgressView()
                    .controlSize(.small)
            } else {
                // Luminous Digital Slip Placeholder (Minimalist & Illuminated)
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
                            .shadow(color: category.accentColor.opacity(0.3), radius: 6)

                        Text("หลักฐานถูกบันทึกแล้ว")
                            .font(.custom("SukhumvitSet-Bold", size: 9))
                            .foregroundStyle(.secondary)

                        Text("แตะเพื่อเปิดดูภาพ")
                            .font(.custom("SukhumvitSet-Text", size: 8))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(6)
                }
            }

            // Video Play Center Badge
            if isVideo {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 34, height: 34)
                    .overlay {
                        Image(systemName: "play.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white)
                            .offset(x: 1)
                    }
                    .shadow(color: .black.opacity(0.3), radius: 6)
            }
        }
        .task(id: mediaPath) {
            await loadThumbnail()
        }
    }

    private func loadThumbnail() async {
        isLoading = true
        if let thumb = await RoomMediaPipeline.shared.loadThumbnail(from: mediaPath, targetSize: 420) {
            self.thumbnail = thumb
            self.isLoading = false
        } else {
            self.isLoading = false
        }
    }
}

// MARK: - Room Media Pipeline (Actor-Based Off-Main-Thread Loading & Downsampling)
actor RoomMediaPipeline {
    static let shared = RoomMediaPipeline()

    private let thumbnailCache = NSCache<NSString, UIImage>()
    private let fullImageCache = NSCache<NSString, UIImage>()

    private init() {
        thumbnailCache.countLimit = 200
        thumbnailCache.totalCostLimit = 60 * 1024 * 1024 // 60 MB
        fullImageCache.countLimit = 40
        fullImageCache.totalCostLimit = 80 * 1024 * 1024  // 80 MB
    }

    func loadThumbnail(from rawPath: String, targetSize: CGFloat = 420) async -> UIImage? {
        let trimmed = rawPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let cacheKey = NSString(string: "thumb_\(Int(targetSize))_\(trimmed)")
        if let cached = thumbnailCache.object(forKey: cacheKey) {
            return cached
        }

        // 1. Check local file on disk via SlipImageManager
        if let localURL = SlipImageManager.url(for: trimmed),
           FileManager.default.fileExists(atPath: localURL.path) {
            if let thumb = downsample(at: localURL, maxPixelSize: targetSize) {
                thumbnailCache.setObject(thumb, forKey: cacheKey)
                return thumb
            }
        }

        // 2. Check full file:// URL
        if trimmed.hasPrefix("file://"),
           let fileURL = URL(string: trimmed),
           FileManager.default.fileExists(atPath: fileURL.path) {
            if let thumb = downsample(at: fileURL, maxPixelSize: targetSize) {
                thumbnailCache.setObject(thumb, forKey: cacheKey)
                return thumb
            }
        }

        // 3. Check base64 string
        if trimmed.hasPrefix("data:image/") || trimmed.count > 1000 {
            let base64String = trimmed.contains(",") ? String(trimmed.split(separator: ",")[1]) : trimmed
            if let data = Data(base64Encoded: base64String) {
                if let thumb = downsample(data: data, maxPixelSize: targetSize) {
                    thumbnailCache.setObject(thumb, forKey: cacheKey)
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
                    thumbnailCache.setObject(thumb, forKey: cacheKey)
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
            let base64String = trimmed.contains(",") ? String(trimmed.split(separator: ",")[1]) : trimmed
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
                                    .background(.ultraThinMaterial, in: Capsule())

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
                                .background(.ultraThinMaterial, in: Circle())
                                .overlay(Circle().stroke(.white.opacity(0.25), lineWidth: 1))
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
        if let videoURL = resolveVideoURL(for: item.mediaPath) {
            VideoPlayer(player: AVPlayer(url: videoURL))
                .ignoresSafeArea()
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
