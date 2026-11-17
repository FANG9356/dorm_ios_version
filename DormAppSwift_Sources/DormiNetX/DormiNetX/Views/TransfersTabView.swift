import SwiftUI
import SwiftData
import UIKit
import AVKit

// MARK: - Evidence Category
enum EvidenceCategory: String, CaseIterable, Identifiable {
    case all = "ทั้งหมด"
    case payment = "สลิปชำระเงิน"
    case maintenance = "แจ้งซ่อม"
    case booking = "สลิปมัดจำ"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .all: return "photo.stack"
        case .payment: return "banknote"
        case .maintenance: return "wrench.and.screwdriver"
        case .booking: return "person.badge.shield.checkmark"
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
    let statusText: String
    let statusColor: Color
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
    @Query(sort: \Payment.lastUpdated, order: .reverse) private var payments: [Payment]
    @Query(sort: \Maintenance.lastUpdated, order: .reverse) private var maintenances: [Maintenance]
    @Query(sort: \DormUser.roomNumber) private var users: [DormUser]
    @Query(sort: \Room.roomNumber) private var allRooms: [Room]

    @State private var selectedRoom: String = "all"
    @State private var selectedCategory: EvidenceCategory = .all
    @State private var searchText = ""
    @State private var activeFullscreenItem: RoomEvidenceItem?

    private var activeRooms: [Room] {
        allRooms
            .filter { !$0.isDeletedLocally }
            .sorted { $0.roomNumber.localizedStandardCompare($1.roomNumber) == .orderedAscending }
    }

    // All evidence items across payments, maintenances, and booking slips
    private var allEvidenceItems: [RoomEvidenceItem] {
        var items: [RoomEvidenceItem] = []

        // 1. Payment Slips (rent & utilities)
        for payment in payments where !payment.isDeletedLocally {
            let room = normalizedRoomNumber(payment.roomNumber)
            guard !room.isEmpty else { continue }

            var paths: [String] = []
            let trimmedSlip = payment.slipPath.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedSlip.isEmpty {
                paths.append(trimmedSlip)
            }
            if let arr = payment.slipPathArray {
                for p in arr {
                    let cleanP = p.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !cleanP.isEmpty && !paths.contains(cleanP) {
                        paths.append(cleanP)
                    }
                }
            }

            for (index, path) in paths.enumerated() {
                let isVideo = isVideoFile(path)
                let dateStr = !payment.paymentDate.isEmpty ? AppDate.thaiDate(payment.paymentDate) : AppDate.thaiDate(AppDate.dateKey(from: payment.lastUpdated))
                let statusLabel = payment.paymentStatus == "paid" ? String(localized: "ตรวจแล้ว") : String(localized: "รอตรวจ")
                items.append(RoomEvidenceItem(
                    id: "payment-\(payment.id.uuidString)-\(index)",
                    roomNumber: room,
                    mediaPath: path,
                    category: .payment,
                    title: "สลิปค่าเช่า รอบ \(AppDate.thaiMonth(payment.month))",
                    subtitle: payment.amount > 0 ? "ยอดเงิน \(payment.amount.formatted()) บาท" : "รอบบิล \(payment.month)",
                    timestamp: payment.lastUpdated,
                    dateFormatted: dateStr,
                    amount: payment.amount,
                    statusText: statusLabel,
                    statusColor: payment.paymentStatus == "paid" ? .green : .orange,
                    isVideo: isVideo
                ))
            }
        }

        // 2. Maintenance Media (issue photos, videos & repair payment slips)
        for maintenance in maintenances where !maintenance.isDeletedLocally {
            let room = normalizedRoomNumber(maintenance.roomNumber)
            guard !room.isEmpty else { continue }

            // Issue media attachments
            let issuePaths = parseMediaPaths(maintenance.issueImage)
            for (index, path) in issuePaths.enumerated() {
                let isVideo = isVideoFile(path)
                let dateStr = !maintenance.reportedAt.isEmpty ? AppDate.thaiDateTime(from: maintenance.reportedAt) : AppDate.thaiDate(AppDate.dateKey(from: maintenance.lastUpdated))
                items.append(RoomEvidenceItem(
                    id: "maint-issue-\(maintenance.id.uuidString)-\(index)",
                    roomNumber: room,
                    mediaPath: path,
                    category: .maintenance,
                    title: "แจ้งซ่อม: \(maintenance.issue.isEmpty ? "แจ้งปัญหาทั่วไป" : maintenance.issue)",
                    subtitle: maintenance.cost > 0 ? "ค่าใช้จ่าย \(maintenance.cost.formatted()) บาท" : "อาการเสียของห้อง",
                    timestamp: maintenance.lastUpdated,
                    dateFormatted: dateStr,
                    amount: maintenance.cost > 0 ? maintenance.cost : nil,
                    statusText: maintenance.status.isEmpty ? "กำลังซ่อม" : maintenance.status,
                    statusColor: maintenance.status == "เสร็จสิ้น" ? .green : .blue,
                    isVideo: isVideo
                ))
            }

            // Maintenance payment slip
            let slipPaths = parseMediaPaths(maintenance.slipPath)
            for (index, path) in slipPaths.enumerated() {
                let isVideo = isVideoFile(path)
                let dateStr = !maintenance.resolvedAt.isEmpty ? AppDate.thaiDateTime(from: maintenance.resolvedAt) : AppDate.thaiDate(AppDate.dateKey(from: maintenance.lastUpdated))
                items.append(RoomEvidenceItem(
                    id: "maint-slip-\(maintenance.id.uuidString)-\(index)",
                    roomNumber: room,
                    mediaPath: path,
                    category: .payment,
                    title: "สลิปค่าซ่อม: \(maintenance.issue)",
                    subtitle: maintenance.cost > 0 ? "ชำระ \(maintenance.cost.formatted()) บาท" : "สลิปงานซ่อม",
                    timestamp: maintenance.lastUpdated,
                    dateFormatted: dateStr,
                    amount: maintenance.cost > 0 ? maintenance.cost : nil,
                    statusText: "ชำระค่าซ่อม",
                    statusColor: .indigo,
                    isVideo: isVideo
                ))
            }
        }

        // 3. Resident Booking Slips
        for user in users where !user.roomNumber.isEmpty {
            let room = normalizedRoomNumber(user.roomNumber)
            for (index, path) in user.bookingSlips.enumerated() {
                let cleanPath = path.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !cleanPath.isEmpty else { continue }
                let isVideo = isVideoFile(cleanPath)
                let dateStr = !user.moveInDate.isEmpty ? AppDate.thaiDate(user.moveInDate) : AppDate.thaiDate(AppDate.dateKey(from: user.lastUpdated))
                items.append(RoomEvidenceItem(
                    id: "booking-\(user.id.uuidString)-\(index)",
                    roomNumber: room,
                    mediaPath: cleanPath,
                    category: .booking,
                    title: "สลิปจอง / มัดจำห้องพัก",
                    subtitle: "ผู้เช่า: \(user.prefix)\(user.firstName) \(user.lastName)",
                    timestamp: user.lastUpdated,
                    dateFormatted: dateStr,
                    amount: user.deposit > 0 ? user.deposit : nil,
                    statusText: user.status.isEmpty ? "จอง" : user.status,
                    statusColor: .purple,
                    isVideo: isVideo
                ))
            }
        }

        // Sort newest first
        return items.sorted { $0.timestamp > $1.timestamp }
    }

    // Dynamic list of unique room numbers from rooms & evidence
    private var availableRoomNumbers: [String] {
        var roomSet = Set<String>()
        for r in activeRooms {
            let n = normalizedRoomNumber(r.roomNumber)
            if !n.isEmpty { roomSet.insert(n) }
        }
        for item in allEvidenceItems {
            if !item.roomNumber.isEmpty { roomSet.insert(item.roomNumber) }
        }
        return Array(roomSet).sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    // Count of evidence items per room for badges
    private var evidenceCountByRoom: [String: Int] {
        var counts: [String: Int] = [:]
        for item in allEvidenceItems {
            counts[item.roomNumber, default: 0] += 1
        }
        return counts
    }

    // Filtered items based on selected room, category, and search query
    private var filteredItems: [RoomEvidenceItem] {
        allEvidenceItems.filter { item in
            // Room filter
            if selectedRoom != "all" && item.roomNumber != selectedRoom {
                return false
            }
            // Category filter
            if selectedCategory != .all && item.category != selectedCategory {
                return false
            }
            // Search query filter
            let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !q.isEmpty else { return true }
            let searchable = [
                item.roomNumber,
                "ห้อง \(item.roomNumber)",
                item.title,
                item.subtitle,
                item.dateFormatted,
                item.statusText,
                item.category.rawValue
            ].joined(separator: " ").lowercased()
            return searchable.contains(q)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // Header Area
                VStack(alignment: .leading, spacing: 4) {
                    Text("หลักฐานและสื่อประจำห้อง")
                        .font(.custom("SukhumvitSet-Bold", size: 24))
                    Text("รวบรวมสลิปโอนเงิน รูปภาพ และวิดีโอจากงานแจ้งซ่อมแยกตามห้องพัก")
                        .font(.custom("SukhumvitSet-Text", size: 12))
                        .foregroundStyle(.secondary)
                }

                // Search Bar
                ManagementSearchField(
                    text: $searchText,
                    placeholder: "ค้นหาห้อง, รอบบิล, ปัญหาแจ้งซ่อม, ผู้เช่า..."
                )

                // Room Selector Filter Chips
                roomFilterSection

                // Evidence Category Filter
                categoryFilterSection

                // Summary Counter Banner
                HStack {
                    Text(summaryLabel)
                        .font(.custom("SukhumvitSet-Medium", size: 12))
                        .foregroundStyle(.secondary)
                    Spacer()
                }

                // Content Grid
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
        }
        .fullScreenCover(item: $activeFullscreenItem) { item in
            RoomMediaFullscreenViewer(item: item)
        }
    }

    // MARK: - Room Selector Pills
    private var roomFilterSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("เลือกห้องพัก")
                .font(.custom("SukhumvitSet-Bold", size: 13))
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    // All Rooms Button
                    Button {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                            selectedRoom = "all"
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Text("ทุกห้อง")
                                .font(.custom("SukhumvitSet-Bold", size: 12))
                            Text("\(allEvidenceItems.count)")
                                .font(.custom("SukhumvitSet-Bold", size: 10))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(selectedRoom == "all" ? Color.white.opacity(0.25) : Color.primary.opacity(0.08), in: Capsule())
                        }
                        .foregroundStyle(selectedRoom == "all" ? .white : .primary)
                        .padding(.horizontal, 14)
                        .frame(height: 34)
                        .background(selectedRoom == "all" ? Color.primary : Color.primary.opacity(0.06), in: Capsule())
                    }
                    .buttonStyle(.plain)

                    // Individual Room Buttons
                    ForEach(availableRoomNumbers, id: \.self) { room in
                        let count = evidenceCountByRoom[room, default: 0]
                        Button {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                selectedRoom = room
                            }
                        } label: {
                            HStack(spacing: 5) {
                                Text("ห้อง \(room)")
                                    .font(.custom("SukhumvitSet-Bold", size: 12))
                                if count > 0 {
                                    Text("\(count)")
                                        .font(.custom("SukhumvitSet-Bold", size: 10))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(selectedRoom == room ? Color.white.opacity(0.25) : Color.primary.opacity(0.08), in: Capsule())
                                }
                            }
                            .foregroundStyle(selectedRoom == room ? .white : .primary)
                            .padding(.horizontal, 14)
                            .frame(height: 34)
                            .background(selectedRoom == room ? Color.primary : Color.primary.opacity(0.06), in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - Category Filter Pills
    private var categoryFilterSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(EvidenceCategory.allCases) { cat in
                    Button {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                            selectedCategory = cat
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: cat.icon)
                                .font(.system(size: 11, weight: .semibold))
                            Text(cat.rawValue)
                                .font(.custom("SukhumvitSet-Bold", size: 12))
                        }
                        .foregroundStyle(selectedCategory == cat ? .white : .secondary)
                        .padding(.horizontal, 12)
                        .frame(height: 30)
                        .background(selectedCategory == cat ? Color.accentColor : Color.primary.opacity(0.05), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Evidence Grid
    private var evidenceGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 155, maximum: 200), spacing: 14)], spacing: 14) {
            ForEach(filteredItems) { item in
                Button {
                    activeFullscreenItem = item
                } label: {
                    RoomEvidenceCard(item: item)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Empty States
    private var emptyOverallState: some View {
        GlassCard {
            VStack(spacing: 12) {
                Image(systemName: "photo.stack.fill")
                    .font(.system(size: 38))
                    .foregroundStyle(.secondary)
                Text("ยังไม่มีหลักฐานที่บันทึกในระบบ")
                    .font(.custom("SukhumvitSet-Bold", size: 15))
                Text("เมื่อมีสลิปโอนเงิน บิลชำระ หรือรูป/วิดีโอจากงานแจ้งซ่อม ระบบจะรวบรวมมาแสดงที่นี่โดยอัตโนมัติ")
                    .font(.custom("SukhumvitSet-Text", size: 12))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 36)
        }
    }

    private var emptyFilteredState: some View {
        GlassCard {
            VStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 36))
                    .foregroundStyle(.secondary)
                Text(selectedRoom == "all" ? "ไม่พบหลักฐานตามเงื่อนไขที่ค้นหา" : "ห้อง \(selectedRoom) ยังไม่มีหลักฐานในหมวดนี้")
                    .font(.custom("SukhumvitSet-Bold", size: 15))
                Text("ลองเปลี่ยนตัวเลือกห้องหรือล้างคำค้นหา")
                    .font(.custom("SukhumvitSet-Text", size: 12))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 32)
        }
    }

    private var summaryLabel: String {
        let roomLabel = selectedRoom == "all" ? "ทุกห้อง" : "ห้อง \(selectedRoom)"
        return "แสดง \(filteredItems.count) รายการ (\(roomLabel))"
    }

    // Normalize room number by stripping quotation marks and whitespace
    private func normalizedRoomNumber(_ raw: String) -> String {
        raw.trimmingCharacters(in: CharacterSet(charactersIn: "'\" \t\r\n"))
    }

    private func parseMediaPaths(_ raw: String) -> [String] {
        raw.split(separator: ",")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func isVideoFile(_ path: String) -> Bool {
        let lower = path.lowercased()
        return lower.hasSuffix(".mp4") || lower.hasSuffix(".mov") || lower.hasSuffix(".m4v") || lower.hasSuffix(".webm")
    }
}

// MARK: - Room Evidence Card View
private struct RoomEvidenceCard: View {
    let item: RoomEvidenceItem

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Media Preview Thumbnail
            ZStack(alignment: .topLeading) {
                RoomMediaThumbnailView(mediaPath: item.mediaPath, isVideo: item.isVideo)
                    .frame(height: 140)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                // Badges Overlay Top
                HStack {
                    // Room Badge
                    Text("ห้อง \(item.roomNumber)")
                        .font(.custom("SukhumvitSet-Bold", size: 11))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.black.opacity(0.65), in: Capsule())

                    Spacer()

                    // Category Pill
                    HStack(spacing: 3) {
                        Image(systemName: item.category.icon)
                            .font(.system(size: 9))
                        Text(item.category.rawValue)
                            .font(.custom("SukhumvitSet-Bold", size: 9))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(badgeBackgroundColor.opacity(0.85), in: Capsule())
                }
                .padding(8)
            }

            // Card Text Details
            VStack(alignment: .leading, spacing: 5) {
                Text(item.title)
                    .font(.custom("SukhumvitSet-Bold", size: 12))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(item.subtitle)
                    .font(.custom("SukhumvitSet-Text", size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                HStack {
                    Text(item.dateFormatted)
                        .font(.custom("SukhumvitSet-Text", size: 10))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)

                    Spacer()

                    Text(item.statusText)
                        .font(.custom("SukhumvitSet-Bold", size: 9))
                        .foregroundStyle(item.statusColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(item.statusColor.opacity(0.12), in: Capsule())
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
        }
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
    }

    private var badgeBackgroundColor: Color {
        switch item.category {
        case .all: return .gray
        case .payment: return .teal
        case .maintenance: return .orange
        case .booking: return .purple
        }
    }
}

// MARK: - Smart Media Thumbnail View with Asynchronous Local/Remote Loading
private struct RoomMediaThumbnailView: View {
    let mediaPath: String
    let isVideo: Bool
    @State private var image: UIImage?
    @State private var isLoading = true
    @State private var loadFailed = false

    var body: some View {
        ZStack {
            Color.primary.opacity(0.04)

            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if isLoading {
                ProgressView()
                    .controlSize(.small)
            } else {
                // Graceful fallback display when media file is stored only as record
                VStack(spacing: 6) {
                    Image(systemName: isVideo ? "video.badge.checkmark" : "doc.text.image")
                        .font(.system(size: 26))
                        .foregroundStyle(.secondary)
                    Text(cleanFilename(mediaPath))
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .padding(.horizontal, 10)
                    Text("บันทึกในระบบเรียบร้อย")
                        .font(.custom("SukhumvitSet-Medium", size: 9))
                        .foregroundStyle(.secondary)
                }
            }

            // Video Play Badge Overlay
            if isVideo {
                Circle()
                    .fill(.black.opacity(0.55))
                    .frame(width: 36, height: 36)
                    .overlay {
                        Image(systemName: "play.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                            .offset(x: 1.5)
                    }
            }
        }
        .task(id: mediaPath) {
            await loadMedia()
        }
    }

    private func loadMedia() async {
        isLoading = true
        if let loaded = await RoomMediaLoader.shared.loadImage(from: mediaPath) {
            self.image = loaded
            self.isLoading = false
            self.loadFailed = false
        } else {
            self.isLoading = false
            self.loadFailed = true
        }
    }

    private func cleanFilename(_ path: String) -> String {
        URL(fileURLWithPath: path).lastPathComponent
    }
}

// MARK: - Shared Media Loader & Offline Cache
@MainActor
final class RoomMediaLoader {
    static let shared = RoomMediaLoader()

    private var memoryCache = NSCache<NSString, UIImage>()

    private init() {
        memoryCache.countLimit = 150
        memoryCache.totalCostLimit = 80 * 1024 * 1024 // 80 MB
    }

    func loadImage(from rawPath: String) async -> UIImage? {
        let trimmed = rawPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let cacheKey = NSString(string: trimmed)
        if let cached = memoryCache.object(forKey: cacheKey) {
            return cached
        }

        // 1. Check local file on disk via SlipImageManager
        if let localURL = SlipImageManager.url(for: trimmed),
           FileManager.default.fileExists(atPath: localURL.path),
           let image = UIImage(contentsOfFile: localURL.path) {
            memoryCache.setObject(image, forKey: cacheKey)
            return image
        }

        // 2. Check if it's already a full file:// URL
        if trimmed.hasPrefix("file://"),
           let fileURL = URL(string: trimmed),
           FileManager.default.fileExists(atPath: fileURL.path),
           let image = UIImage(contentsOfFile: fileURL.path) {
            memoryCache.setObject(image, forKey: cacheKey)
            return image
        }

        // 3. Check if base64 encoded string
        if trimmed.hasPrefix("data:image/") || trimmed.count > 1000 {
            let base64String = trimmed.contains(",") ? String(trimmed.split(separator: ",")[1]) : trimmed
            if let data = Data(base64Encoded: base64String), let image = UIImage(data: data) {
                memoryCache.setObject(image, forKey: cacheKey)
                return image
            }
        }

        // 4. Try fetching from Server via /api/media/<cleanFileName>
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
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
               let image = UIImage(data: data) {
                // Save to local disk cache for instant offline access next time
                _ = try? SlipImageManager.restoreImageData(data, fileName: fileName)
                memoryCache.setObject(image, forKey: cacheKey)
                return image
            }
        } catch {
            // Server fetch failed, return nil to allow graceful fallback UI
        }

        return nil
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
                                    .background(.black.opacity(0.65), in: Capsule())

                                Text(item.category.rawValue)
                                    .font(.custom("SukhumvitSet-Medium", size: 12))
                                    .foregroundStyle(.white.opacity(0.85))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(.white.opacity(0.18), in: Capsule())
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
                                .background(.black.opacity(0.6), in: Circle())
                                .overlay(Circle().stroke(.white.opacity(0.2), lineWidth: 1))
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
                    self.loadedImage = await RoomMediaLoader.shared.loadImage(from: item.mediaPath)
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
                Text(item.mediaPath)
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
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

