import SwiftUI
import SwiftData
import PhotosUI
import UIKit

struct TenantsTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var viewModel = TenantsViewModel()
    @State private var selectedUser: APIUser? = nil
    @State private var showDeleteAlert = false
    @State private var userToDelete: APIUser? = nil
    @Binding var showAddSheet: Bool
    @State private var editingUser: APIUser? = nil
    
    var body: some View {
        // บังคับ ZStack ให้กางเต็มจอ 100% เสมอ และจัดตำแหน่งของในนี้ให้อยู่มุมล่างขวา
        ZStack(alignment: .bottomTrailing) {
            
            // 1. ล็อกพื้นหลังให้เต็มจอ เพื่อดันให้ ZStack ไม่หดตัว
            Color.clear
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    hideKeyboard()
                }
            
            // 2. เนื้อหาหลัก
            ScrollView {
                VStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("ทะเบียนลูกบ้าน")
                            .font(.custom("SukhumvitSet-Bold", size: 28))
                            .foregroundColor(.primary)
                        Text("ค้นหา ตรวจสถานะ และจัดการข้อมูลผู้พักอาศัย")
                            .font(.custom("SukhumvitSet-Text", size: 13))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.top, 112)
                    .padding(.bottom, 16)
                    
                    // MARK: - Liquid Glass Control Bar
                    VStack(spacing: 0) {
                        // Search + Sort in one row
                        HStack(spacing: 12) {
                            HStack(spacing: 8) {
                                Image(systemName: "magnifyingglass")
                                    .foregroundColor(.secondary)
                                    .font(.system(size: 15, weight: .medium))
                                TextField("ค้นหาห้อง, ชื่อ, เบอร์โทร...", text: $viewModel.searchText)
                                    .font(.custom("SukhumvitSet-Text", size: 14))
                                if !viewModel.searchText.isEmpty {
                                    Button {
                                        viewModel.searchText = ""
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.secondary)
                                            .font(.system(size: 14))
                                    }
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            
                            Divider()
                                .frame(height: 24)
                                .opacity(colorScheme == .dark ? 0.35 : 0.16)
                            
                            // Sort Menu
                            Menu {
                                Button { viewModel.sortBy = "room_asc" } label: {
                                    Label("ห้อง 1 → 9", systemImage: viewModel.sortBy == "room_asc" ? "checkmark" : "arrow.up")
                                }
                                Button { viewModel.sortBy = "room_desc" } label: {
                                    Label("ห้อง 9 → 1", systemImage: viewModel.sortBy == "room_desc" ? "checkmark" : "arrow.down")
                                }
                                Divider()
                                Button { viewModel.sortBy = "status_active" } label: {
                                    Label("พักอาศัยก่อน", systemImage: viewModel.sortBy == "status_active" ? "checkmark" : "person.fill.checkmark")
                                }
                                Button { viewModel.sortBy = "status_inactive" } label: {
                                    Label("ย้ายออกก่อน", systemImage: viewModel.sortBy == "status_inactive" ? "checkmark" : "arrow.right.circle")
                                }
                            } label: {
                                ZStack {
                                    Image(systemName: "arrow.up.arrow.down")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.primary.opacity(0.85))
                                }
                                .frame(width: 42, height: 40, alignment: .center)
                                .offset(x: -5)
                                .contentShape(Rectangle())
                            }
                        }
                        .frame(height: 48)
                        
                        Divider()
                            .opacity(colorScheme == .dark ? 0.35 : 0.12)
                            .padding(.horizontal, 12)
                        
                        // Filter Tabs
                        LoupeFilterTabs(viewModel: viewModel)
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
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                    
                    // MARK: - Error
                    if let error = viewModel.errorMessage {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.custom("SukhumvitSet-Text", size: 13))
                            .padding(.horizontal, 20)
                            .padding(.bottom, 8)
                    }
                    
                    // MARK: - Content
                    if viewModel.isLoading {
                        VStack(spacing: 10) {
                            ForEach(0..<5, id: \.self) { _ in
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(.ultraThinMaterial)
                                    .frame(height: 80)
                                    .shimmer()
                            }
                        }
                        .padding(.horizontal, 16)
                    } else if viewModel.filteredUsers.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "person.3.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.blue.opacity(0.3))
                            Text("ไม่พบข้อมูลลูกบ้าน")
                                .font(.custom("SukhumvitSet-Bold", size: 16))
                                .foregroundColor(.secondary)
                            if !viewModel.searchText.isEmpty {
                                Text("ลองเปลี่ยนคำค้นหาใหม่")
                                    .font(.custom("SukhumvitSet-Text", size: 13))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, minHeight: 300)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            hideKeyboard()
                        }
                    } else {
                        // Results count
                        HStack {
                            Text("รายการลูกบ้าน")
                                .font(.custom("SukhumvitSet-Bold", size: 16))
                                .foregroundColor(.primary)
                            Spacer()
                            Text("\(viewModel.filteredUsers.count) รายการ")
                                .font(.custom("SukhumvitSet-Medium", size: 12))
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Capsule().fill(countPillFillColor))
                            if viewModel.isLoading {
                                ProgressView().scaleEffect(0.7)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 4)
                        .padding(.bottom, 8)
                        
                        LazyVStack(spacing: 12) {
                            ForEach(viewModel.filteredUsers) { user in
                                PremiumTenantCard(user: user, viewModel: viewModel) {
                                    selectedUser = user
                                } onEdit: {
                                    editingUser = user
                                } onDelete: {
                                    userToDelete = user
                                    showDeleteAlert = true
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                    
                    Spacer().frame(height: 120) // ดันให้เนื้อหาพ้นปุ่มลอยด้านล่าง
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .simultaneousGesture(TapGesture().onEnded {
                hideKeyboard()
            })
            // บังคับ ScrollView ให้เต็มจอ ป้องกันการหดตัว
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .onAppear { Task { await viewModel.fetchUsers(modelContext: modelContext) } }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing) // ล็อกกรอบใหญ่สุดอีกชั้น พร้อมยึดมุมขวาล่าง
        .sheet(item: $selectedUser) { user in
            TenantDetailSheet(user: user, viewModel: viewModel) {
                editingUser = user
            } onDelete: {
                selectedUser = nil
            }
            .iphoneFullSheetStyle()
        }
        .sheet(isPresented: $showAddSheet) {
            TenantFormSheet(viewModel: viewModel, editUser: nil)
                .iphoneFullSheetStyle()
        }
        .sheet(item: $editingUser) { user in
            TenantFormSheet(viewModel: viewModel, editUser: user)
                .iphoneFullSheetStyle()
        }
        .alert("ยืนยันการลบ", isPresented: $showDeleteAlert) {
            Button("ยกเลิก", role: .cancel) { }
            Button("ลบ", role: .destructive) {
                if let u = userToDelete {
                    Task { let _ = await viewModel.deleteUser(id: u.id, modelContext: modelContext) }
                }
            }
        } message: {
            if let u = userToDelete {
                Text("ต้องการลบลูกบ้านห้อง \(u.room_number ?? "-") (\(u.first_name ?? "") \(u.last_name ?? "")) จริงหรือไม่?")
            }
        }
    }

    private var controlBorderColor: Color {
        colorScheme == .dark ? Color.primary.opacity(0.12) : Color.white.opacity(0.18)
    }

    private var controlFillColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.045) : Color.white.opacity(0.34)
    }

    private var countPillFillColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : Color.white.opacity(0.28)
    }
}

// MARK: - Loupe Filter Tabs (เพิ่มความสมูทละมุนตา)
struct LoupeFilterTabs: View {
    @ObservedObject var viewModel: TenantsViewModel
    
    @State private var dragX: CGFloat = 0
    @State private var isDragging = false
    @State private var hoveredTab: String? = nil
    @State private var tabFrames: [String: CGRect] = [:]
    
    let tabs = [
        ("all", "ทั้งหมด", Color.primary),
        ("active", "พักอาศัย", Color.primary),
        ("booking", "จอง", Color.primary),
        ("inactive", "ย้ายออก", Color.primary)
    ]
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(tabs, id: \.0) { tab in
                let count = getCount(for: tab.0)
                let isBeingHovered = isDragging && hoveredTab == tab.0
                
                Button {
                    // เพิ่มการสั่นเบาๆ ให้รู้สึกพรีเมียม
                    let impact = UIImpactFeedbackGenerator(style: .light)
                    impact.impactOccurred()
                    
                    // ปรับ Animation ให้นุ่มนวลขึ้น (Smooth Spring)
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75, blendDuration: 0.1)) {
                        viewModel.activeTab = tab.0
                    }
                } label: {
                    LiquidFilterTab(
                        title: tab.1,
                        count: count,
                        isActive: viewModel.activeTab == tab.0,
                        color: tab.2
                    )
                    .frame(maxWidth: .infinity)
                    .opacity(isBeingHovered ? 0 : 1)
                }
                .buttonStyle(.plain)
                .background(
                    GeometryReader { geo in
                        Color.clear
                            .onAppear { tabFrames[tab.0] = geo.frame(in: .named("TabBarSpace")) }
                            .onChange(of: geo.frame(in: .named("TabBarSpace"))) { _, newFrame in
                                tabFrames[tab.0] = newFrame
                            }
                    }
                )
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 6)
        .frame(height: 52)
        .coordinateSpace(name: "TabBarSpace")
        .overlay(
            GeometryReader { geo in
                ZStack {
                    if isDragging, let current = hoveredTab, let tabData = tabs.first(where: { $0.0 == current }) {
                        let count = getCount(for: tabData.0)
                        
                        HStack(spacing: 4) {
                            Text(tabData.1)
                                .font(.custom("SukhumvitSet-Bold", size: 14))
                                .lineLimit(1)
                            Text("\(count)")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(tabData.2.opacity(0.2)))
                        }
                        .foregroundColor(tabData.2)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(.ultraThickMaterial)
                                .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 4)
                        )
                        .overlay(
                            Capsule()
                                .stroke(Color.primary.opacity(0.18), lineWidth: 1)
                        )
                        .position(x: dragX, y: geo.size.height / 2)
                        // ให้ตัวแว่นขยายสไลด์ตามนิ้วแบบติดสปริงนุ่มๆ
                        .animation(.interactiveSpring(response: 0.25, dampingFraction: 0.8), value: dragX)
                    }
                }
                .allowsHitTesting(false)
            }
        )
        .simultaneousGesture(
            DragGesture(minimumDistance: 10, coordinateSpace: .named("TabBarSpace"))
                .onChanged { value in
                    isDragging = true
                    dragX = value.location.x
                    
                    if let closest = tabFrames.min(by: { abs($0.value.midX - value.location.x) < abs($1.value.midX - value.location.x) }) {
                        if value.location.x > 0 {
                            if hoveredTab != closest.key {
                                let impact = UIImpactFeedbackGenerator(style: .light)
                                impact.impactOccurred()
                                hoveredTab = closest.key
                            }
                        }
                    }
                }
                .onEnded { value in
                    isDragging = false
                    if let selected = hoveredTab {
                        // ตอนปล่อยนิ้วก็ให้นุ่มนวลเหมือนตอนแตะ
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75, blendDuration: 0.1)) {
                            viewModel.activeTab = selected
                        }
                    }
                    hoveredTab = nil
                }
        )
    }
    
    private func getCount(for tab: String) -> Int {
        switch tab {
        case "all": return viewModel.allCount
        case "active": return viewModel.activeCount
        case "booking": return viewModel.bookingCount
        case "inactive": return viewModel.inactiveCount
        default: return 0
        }
    }
}

// MARK: - Liquid Filter Tab
struct LiquidFilterTab: View {
    let title: String
    let count: Int
    let isActive: Bool
    let color: Color
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        HStack(spacing: 4) {
            Text(title)
                .font(.custom("SukhumvitSet-Bold", size: 13))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            
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
        .padding(.horizontal, 8)
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
        // ทำให้เวลาเฟดเปลี่ยนสีมันนุ่มและดูเป็นธรรมชาติมากขึ้น
        .animation(.easeInOut(duration: 0.25), value: isActive)
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

// MARK: - Premium Tenant Card
struct PremiumTenantCard: View {
    let user: APIUser
    let viewModel: TenantsViewModel
    let onTap: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    @State private var isPressed = false
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                VStack(spacing: 2) {
                    Text(user.room_number ?? "-")
                        .font(.system(size: 21, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    Text("ห้อง")
                        .font(.custom("SukhumvitSet-Medium", size: 10))
                        .foregroundColor(.secondary)
                }
                .frame(width: 58, height: 58)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(roomBadgeFillColor)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(roomBadgeBorderColor, lineWidth: 1)
                )
                
                VStack(alignment: .leading, spacing: 5) {
                    Text("\(user.prefix ?? "")\(user.first_name ?? "") \(user.last_name ?? "")")
                        .font(.custom("SukhumvitSet-Bold", size: 16))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    HStack(spacing: 6) {
                        Image(systemName: "phone.fill")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                        Text(viewModel.formatPhone(user.phone))
                            .font(.custom("SukhumvitSet-Text", size: 12))
                            .foregroundColor(.secondary)
                    }

                    if user.status == "จอง" {
                        Text(bookingSummary)
                            .font(.custom("SukhumvitSet-Text", size: 11))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 8) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(viewModel.statusColor(user.status))
                            .frame(width: 7, height: 7)
                        Text(user.status ?? "-")
                            .font(.custom("SukhumvitSet-Bold", size: 11))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(statusChipFill))
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary.opacity(0.5))
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(cardFillColor)
                    .shadow(color: cardShadowColor, radius: 12, x: 0, y: 5)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(cardBorderColor, lineWidth: 1)
            )
            .scaleEffect(isPressed ? 0.97 : 1)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button { onEdit() } label: {
                Label("แก้ไขข้อมูล", systemImage: "pencil")
            }
            if user.status == "ย้ายออกแล้ว" {
                Divider()
                Button(role: .destructive) { onDelete() } label: {
                    Label("ลบลูกบ้าน", systemImage: "trash")
                }
            }
        }
    }

    private var cardBorderColor: Color {
        colorScheme == .dark ? Color.primary.opacity(0.1) : Color.white.opacity(0.2)
    }

    private var roomBadgeBorderColor: Color {
        colorScheme == .dark ? Color.primary.opacity(0.12) : Color.white.opacity(0.18)
    }

    private var cardShadowColor: Color {
        colorScheme == .dark ? Color.black.opacity(0.05) : Color.clear
    }

    private var statusChipFill: Color {
        colorScheme == .dark ? Color.primary.opacity(0.07) : Color.black.opacity(0.035)
    }

    private var cardFillColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.045) : Color.white.opacity(0.24)
    }

    private var roomBadgeFillColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.045) : Color.white.opacity(0.18)
    }

    private var bookingSummary: String {
        let moveIn = shortDate(user.move_in_date)
        let end = shortDate(user.booking_end_date)
        if end != "-" {
            return "เข้าอยู่ \(moveIn) • หมดเขต \(end)"
        }
        return "เข้าอยู่ \(moveIn)"
    }

    private func shortDate(_ dateStr: String?) -> String {
        guard let dateStr, !dateStr.isEmpty else { return "-" }
        let parts = dateStr.split(separator: "-")
        if parts.count == 3, let month = Int(parts[1]), let day = Int(parts[2]) {
            let monthNames = ["ม.ค.", "ก.พ.", "มี.ค.", "เม.ย.", "พ.ค.", "มิ.ย.", "ก.ค.", "ส.ค.", "ก.ย.", "ต.ค.", "พ.ย.", "ธ.ค."]
            if month >= 1 && month <= 12 {
                return "\(day) \(monthNames[month - 1])"
            }
        }
        return dateStr
    }
}

// MARK: - Tenant Detail Sheet
struct TenantDetailSheet: View {
    let user: APIUser
    let viewModel: TenantsViewModel
    let onEdit: () -> Void
    let onDelete: () -> Void
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @State private var showEditSheet = false
    @State private var showDeleteAlert = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 18) {
                    VStack(spacing: 12) {
                        Text(displayUser.room_number ?? "-")
                            .font(.system(size: 56, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        
                        HStack(spacing: 6) {
                            Circle()
                                .fill(viewModel.statusColor(displayUser.status))
                                .frame(width: 7, height: 7)
                            Text(displayUser.status ?? "-")
                                .font(.custom("SukhumvitSet-Bold", size: 13))
                        }
                        .foregroundColor(.primary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(Capsule().fill(statusFillColor))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 28)
                    
                    Button {
                        showEditSheet = true
                    } label: {
                        Label("แก้ไขข้อมูล", systemImage: "pencil")
                            .font(.custom("SukhumvitSet-Bold", size: 13))
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background(
                                Capsule()
                                    .fill(actionFillColor)
                            )
                            .overlay(
                                Capsule()
                                    .stroke(actionBorderColor, lineWidth: 1)
                            )
                    }
                    .padding(.horizontal, 20)

                    if displayUser.status == "ย้ายออกแล้ว" {
                        Button {
                            showDeleteAlert = true
                        } label: {
                            Label("ลบลูกบ้าน", systemImage: "trash")
                                .font(.custom("SukhumvitSet-Bold", size: 13))
                                .foregroundColor(.red)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 11)
                                .background(
                                    Capsule()
                                        .fill(deleteFillColor)
                                )
                                .overlay(
                                    Capsule()
                                        .stroke(deleteBorderColor, lineWidth: 1)
                                )
                        }
                        .padding(.horizontal, 20)
                    }
                    
                    VStack(spacing: 14) {
                        DetailSection(title: "ข้อมูลส่วนตัว") {
                            DetailRow(icon: "person.fill", label: "ชื่อ-นามสกุล", value: "\(displayUser.prefix ?? "")\(displayUser.first_name ?? "") \(displayUser.last_name ?? "")")
                            DetailRow(icon: "phone.fill", label: "เบอร์โทรศัพท์", value: viewModel.formatPhone(displayUser.phone))
                            DetailRow(icon: "creditcard.fill", label: "เลขบัตรประชาชน", value: maskNationalID(displayUser.national_id))
                            DetailRow(icon: "map.fill", label: "ที่อยู่", value: displayUser.address ?? "-")
                        }
                        
                        DetailSection(title: "ข้อมูลสัญญา") {
                            DetailRow(icon: "calendar", label: "วันเข้าอยู่", value: formatDate(displayUser.move_in_date))
                            if displayUser.status == "จอง" {
                                DetailRow(icon: "calendar.badge.exclamationmark", label: "หมดเขตจอง", value: formatDate(displayUser.booking_end_date))
                            } else {
                                DetailRow(icon: "calendar.badge.clock", label: "วันหมดสัญญา", value: displayUser.indefinite_contract == 1 ? "ไม่กำหนดระยะเวลา" : formatDate(displayUser.contract_end_date))
                            }
                            DetailRow(icon: "banknote.fill", label: "เงินมัดจำ", value: String(format: "฿%.0f", displayUser.deposit ?? 0))
                            DetailRow(icon: "creditcard.circle.fill", label: "วิธีชำระเงิน", value: paymentMethodText(displayUser.payment_method))
                            DetailRow(icon: "building.columns.fill", label: "ช่องทางชำระ", value: paymentChannelText(displayUser.payment_channel))
                            if displayUser.payment_method == "installment" {
                                DetailRow(icon: "calendar.badge.clock", label: "จำนวนงวด", value: installmentText(displayUser.installment_months))
                                DetailRow(icon: "banknote", label: "ยอดต่องวด", value: String(format: "฿%.0f", displayUser.installment_amount ?? 0))
                            }
                            DetailRow(icon: "photo.on.rectangle", label: "สลิปแนบ", value: (displayUser.booking_slips?.isEmpty == false) ? "\(displayUser.booking_slips?.count ?? 0) ไฟล์" : "-")
                        }
                        
                        if let appliances = displayUser.additional_appliances, !appliances.isEmpty {
                            DetailSection(title: "เครื่องใช้ไฟฟ้าเพิ่มเติม") {
                                DetailRow(icon: "bolt.fill", label: "รายการ", value: appliances)
                                DetailRow(icon: "banknote.fill", label: "ค่าใช้จ่ายเพิ่ม", value: String(format: "฿%.0f/เดือน", displayUser.additional_appliance_fee ?? 0))
                            }
                        }
                        
                        if let details = displayUser.additional_details, !details.isEmpty {
                            DetailSection(title: "หมายเหตุ") {
                                Text(details)
                                    .font(.custom("SukhumvitSet-Text", size: 14))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    Spacer().frame(height: 30)
                }
            }
            .background(Color("AppBackground").ignoresSafeArea())
            .navigationTitle("รายละเอียดลูกบ้าน")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("ปิด") { dismiss() }
                }
            }
        }
        .sheet(isPresented: $showEditSheet) {
            TenantFormSheet(viewModel: viewModel, editUser: displayUser)
                .iphoneFullSheetStyle()
        }
        .alert("ยืนยันการลบ", isPresented: $showDeleteAlert) {
            Button("ยกเลิก", role: .cancel) { }
            Button("ลบ", role: .destructive) {
                Task {
                    let deleted = await viewModel.deleteUser(id: displayUser.id, modelContext: modelContext)
                    if deleted {
                        onDelete()
                        dismiss()
                    }
                }
            }
        } message: {
            Text("ต้องการลบลูกบ้านห้อง \(displayUser.room_number ?? "-") จริงหรือไม่?")
        }
    }

    private var displayUser: APIUser {
        viewModel.users.first(where: { $0.id == user.id }) ?? user
    }

    private var statusFillColor: Color {
        colorScheme == .dark ? viewModel.statusColor(displayUser.status).opacity(0.16) : Color.black.opacity(0.045)
    }

    private var actionFillColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.05) : Color.white.opacity(0.28)
    }

    private var actionBorderColor: Color {
        colorScheme == .dark ? Color.primary.opacity(0.12) : Color.white.opacity(0.22)
    }

    private var deleteFillColor: Color {
        colorScheme == .dark ? Color.red.opacity(0.12) : Color.red.opacity(0.08)
    }

    private var deleteBorderColor: Color {
        colorScheme == .dark ? Color.red.opacity(0.25) : Color.red.opacity(0.18)
    }
    
    private func maskNationalID(_ id: String?) -> String {
        guard let id = id, id.count >= 6 else { return id ?? "-" }
        let prefix = id.prefix(2)
        let suffix = id.suffix(4)
        let masked = String(repeating: "•", count: id.count - 6)
        return "\(prefix)\(masked)\(suffix)"
    }
    
    private func formatDate(_ dateStr: String?) -> String {
        guard let d = dateStr, !d.isEmpty else { return "-" }
        let parts = d.split(separator: "-")
        if parts.count == 3, let y = Int(parts[0]), let m = Int(parts[1]), let day = Int(parts[2]) {
            let monthNames = ["ม.ค.", "ก.พ.", "มี.ค.", "เม.ย.", "พ.ค.", "มิ.ย.", "ก.ค.", "ส.ค.", "ก.ย.", "ต.ค.", "พ.ย.", "ธ.ค."]
            if m >= 1 && m <= 12 {
                return "\(day) \(monthNames[m-1]) \(y + 543)"
            }
        }
        return d
    }
    
    private func paymentMethodText(_ method: String?) -> String {
        switch method {
        case "full_payment": return "ชำระเต็มจำนวน"
        case "installment": return "ผ่อนชำระ"
        default: return method ?? "-"
        }
    }

    private func paymentChannelText(_ channel: String?) -> String {
        switch channel {
        case "cash": return "เงินสด"
        case "bank_transfer": return "โอนผ่านธนาคาร"
        default: return channel ?? "-"
        }
    }

    private func installmentText(_ months: Int?) -> String {
        guard let months, months > 0 else { return "-" }
        return "\(months) งวด"
    }
}

// MARK: - Add / Edit Tenant Form Sheet
struct TenantFormSheet: View {
    @ObservedObject var viewModel: TenantsViewModel
    let editUser: APIUser?
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Room.roomNumber) private var rooms: [Room]
    @Query(sort: \RoomType.name) private var roomTypes: [RoomType]
    @Query(sort: \DormUser.roomNumber) private var localUsers: [DormUser]
    
    @State private var prefix = "นาย"
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var roomNumber = ""
    @State private var phone = ""
    @State private var nationalID = ""
    @State private var address = ""
    @State private var status = "กำลังพักอาศัย"
    @State private var roomType = ""
    @State private var moveInDate = Date()
    @State private var bookingEndDate = Date()
    @State private var contractEndDate = Date()
    @State private var deposit = ""
    @State private var paymentMethod = "full_payment"
    @State private var paymentChannel = "bank_transfer"
    @State private var installmentMonths = ""
    @State private var installmentAmount = ""
    @State private var bookingSlipPaths: [String] = []
    @State private var selectedSlipItems: [PhotosPickerItem] = []
    @State private var isImportingSlip = false
    @State private var slipImportMessage: String?
    @State private var indefiniteContract = false
    @State private var isSubmitting = false
    @State private var errorText: String?
    @State private var depositWasEdited = false
    @State private var installmentWasEdited = false
    @State private var isApplyingSuggestedValues = false
    @AppStorage("defaultDepositPercent") private var defaultDepositPercent = 5.0

    private let paymentMethodOptions = [
        ("full_payment", "ชำระเต็มจำนวน"),
        ("installment", "ผ่อนชำระ")
    ]

    private let paymentChannelOptions = [
        ("bank_transfer", "โอนผ่านธนาคาร"),
        ("cash", "เงินสด")
    ]
    
    var isEditing: Bool { editUser != nil }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("ข้อมูลส่วนตัว")) {
                    Picker("คำนำหน้า", selection: $prefix) {
                        Text("นาย").tag("นาย")
                        Text("นาง").tag("นาง")
                        Text("นางสาว").tag("นางสาว")
                    }
                    .pickerStyle(.menu)
                    .tint(.primary)
                    
                    TextField("ชื่อ", text: $firstName)
                        .limitedText($firstName, maxLength: 60, trimNewlines: true)
                    TextField("นามสกุล", text: $lastName)
                        .limitedText($lastName, maxLength: 60, trimNewlines: true)
                    TextField("เบอร์โทรศัพท์", text: $phone)
                        .keyboardType(.phonePad)
                        .digitsOnly($phone, maxLength: 10)
                    TextField("เลขบัตรประชาชน", text: $nationalID)
                        .keyboardType(.numberPad)
                        .digitsOnly($nationalID, maxLength: 13)
                    TextField("ที่อยู่", text: $address)
                        .limitedText($address, maxLength: 180, trimNewlines: true)
                }
                
                Section(header: Text("ข้อมูลห้องพัก")) {
                    if selectableRooms.isEmpty {
                        Text("ยังไม่มีห้องว่างให้เลือก กรุณาสร้างประเภทห้องในหน้าตั้งราคา แล้วเพิ่มห้องในหน้าจัดการห้องพักก่อน")
                            .font(.custom("SukhumvitSet-Text", size: 13))
                            .foregroundStyle(.secondary)
                    } else {
                        Picker("ห้อง", selection: $roomNumber) {
                            Text("เลือกห้อง").tag("")
                            if selectedRoom == nil && !roomNumber.isEmpty {
                                Text("ห้องเดิม \(roomNumber)").tag(roomNumber)
                            }
                            ForEach(selectableRooms) { room in
                                Text(roomLabel(room)).tag(room.roomNumber)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(.primary)
                        .onChange(of: roomNumber) { _, _ in
                            applyExistingRoomTypeIfNeeded()
                            applySuggestedDepositIfNeeded()
                            applySuggestedInstallmentIfNeeded()
                        }
                    }

                    if let room = selectedRoom {
                        HStack {
                            Text("ประเภทห้อง")
                            Spacer()
                            Text(room.roomType.isEmpty ? "-" : room.roomType)
                                .fontWeight(.semibold)
                        }
                        .font(.custom("SukhumvitSet-Text", size: 14))
                        .foregroundStyle(.secondary)

                        if let selectedType = selectedRoomType {
                            HStack {
                                Text("ค่าเช่าตั้งต้น")
                                Spacer()
                                Text(selectedType.price.formatted(.number.precision(.fractionLength(0))) + " ฿")
                                    .fontWeight(.semibold)
                            }
                            .font(.custom("SukhumvitSet-Text", size: 14))
                            .foregroundStyle(.secondary)
                        }
                    }
                    
                    Picker("สถานะ", selection: $status) {
                        Text("กำลังพักอาศัย").tag("กำลังพักอาศัย")
                        Text("จอง").tag("จอง")
                        Text("ย้ายออกแล้ว").tag("ย้ายออกแล้ว")
                    }
                    .pickerStyle(.menu)
                    .tint(.primary)
                }
                
                Section(header: Text("ข้อมูลสัญญา")) {
                    DatePicker(status == "จอง" ? "วันที่คาดว่าจะเข้าอยู่" : "วันเข้าอยู่", selection: $moveInDate, displayedComponents: .date)
                        .environment(\.locale, Locale(identifier: "th_TH"))
                        .environment(\.calendar, Calendar(identifier: .buddhist))

                    if status == "จอง" {
                        DatePicker("หมดเขตจอง", selection: $bookingEndDate, displayedComponents: .date)
                            .environment(\.locale, Locale(identifier: "th_TH"))
                            .environment(\.calendar, Calendar(identifier: .buddhist))
                    }
                    
                    if status != "จอง" {
                        Toggle("ไม่กำหนดระยะเวลาสัญญา", isOn: $indefiniteContract.animation(.easeInOut(duration: 0.2)))
                        
                        if !indefiniteContract {
                            DatePicker("วันหมดสัญญา", selection: $contractEndDate, displayedComponents: .date)
                                .environment(\.locale, Locale(identifier: "th_TH"))
                                .environment(\.calendar, Calendar(identifier: .buddhist))
                        }

                        TextField("เงินมัดจำ (บาท)", text: $deposit)
                            .keyboardType(.decimalPad)
                            .decimalInput($deposit, maxIntegerDigits: 8, maxFractionDigits: 2)
                            .onChange(of: deposit) { _, _ in
                                guard !isApplyingSuggestedValues else { return }
                                depositWasEdited = true
                                applySuggestedInstallmentIfNeeded()
                            }
                    } else {
                        TextField("เงินจอง/มัดจำ (บาท)", text: $deposit)
                            .keyboardType(.decimalPad)
                            .decimalInput($deposit, maxIntegerDigits: 8, maxFractionDigits: 2)
                            .onChange(of: deposit) { _, _ in
                                guard !isApplyingSuggestedValues else { return }
                                depositWasEdited = true
                                applySuggestedInstallmentIfNeeded()
                            }
                    }

                    moveInPaymentSummary
                }

                Section(header: Text("การชำระเงินตอนเข้าอยู่")) {
                    paymentMethodSelector
                    paymentChannelSelector
                    if paymentMethod == "installment" {
                        TextField("จำนวนงวด", text: $installmentMonths)
                            .keyboardType(.numberPad)
                            .digitsOnly($installmentMonths, maxLength: 2)
                            .onChange(of: installmentMonths) { _, _ in
                                applySuggestedInstallmentIfNeeded()
                            }
                        TextField("ยอดชำระต่องวด (บาท)", text: $installmentAmount)
                            .keyboardType(.decimalPad)
                            .decimalInput($installmentAmount, maxIntegerDigits: 8, maxFractionDigits: 2)
                            .onChange(of: installmentAmount) { _, _ in
                                guard !isApplyingSuggestedValues else { return }
                                installmentWasEdited = true
                            }
                        installmentSummary
                    }
                    if paymentChannel == "bank_transfer" {
                        tenantSlipPickerContent
                    }
                }
                
                if let err = errorText {
                    Section {
                        Text(err)
                            .foregroundColor(.red)
                            .font(.custom("SukhumvitSet-Text", size: 13))
                    }
                }
                
                Section {
                    Button {
                        Task { await submitForm() }
                    } label: {
                        HStack {
                            Spacer()
                            if isSubmitting {
                                ProgressView()
                            } else {
                                Text(isEditing ? "บันทึกการแก้ไข" : "เพิ่มลูกบ้าน")
                                    .font(.custom("SukhumvitSet-Bold", size: 16))
                            }
                            Spacer()
                        }
                    }
                    .disabled(isSubmitting)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .environment(\.locale, Locale(identifier: "th_TH"))
            .environment(\.calendar, Calendar(identifier: .buddhist))
            .navigationTitle(isEditing ? "แก้ไขลูกบ้าน" : "เพิ่มลูกบ้านใหม่")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("ยกเลิก") { dismiss() }
                }
            }
            .onAppear {
                if let u = editUser {
                    prefix = u.prefix ?? "นาย"
                    firstName = u.first_name ?? ""
                    lastName = u.last_name ?? ""
                    roomNumber = u.room_number ?? ""
                    phone = u.phone ?? ""
                    nationalID = u.national_id ?? ""
                    address = u.address ?? ""
                    status = u.status ?? "กำลังพักอาศัย"
                    roomType = existingRoom(for: u.room_number ?? "")?.roomType ?? ""
                    deposit = u.deposit != nil ? String(format: "%.0f", u.deposit!) : ""
                    depositWasEdited = true
                    paymentMethod = u.payment_method ?? "full_payment"
                    paymentChannel = u.payment_channel ?? "bank_transfer"
                    installmentMonths = (u.installment_months ?? 0) > 0 ? "\(u.installment_months ?? 0)" : ""
                    installmentAmount = u.installment_amount != nil ? String(format: "%.0f", u.installment_amount!) : ""
                    installmentWasEdited = true
                    bookingSlipPaths = u.booking_slips ?? []
                    indefiniteContract = (u.indefinite_contract ?? 0) == 1
                    
                    let df = DateFormatter()
                    df.dateFormat = "yyyy-MM-dd"
                    df.locale = Locale(identifier: "en_US_POSIX")
                    df.calendar = Calendar(identifier: .gregorian)
                    if let d = u.move_in_date, let date = df.date(from: d) { moveInDate = date }
                    if let d = u.booking_end_date, let date = df.date(from: d) { bookingEndDate = date }
                    if let d = u.contract_end_date, let date = df.date(from: d) { contractEndDate = date }
                } else {
                    applyExistingRoomTypeIfNeeded()
                    applySuggestedDepositIfNeeded()
                    applySuggestedInstallmentIfNeeded()
                }
            }
            .transaction { transaction in
                transaction.disablesAnimations = true
            }
        }
    }

    private var paymentMethodSelector: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("วิธีชำระเงิน")
                .font(.custom("SukhumvitSet-Medium", size: 13))
                .foregroundStyle(.secondary)

            VStack(spacing: 10) {
                ForEach(paymentMethodOptions, id: \.0) { value, title in
                    Button {
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                            paymentMethod = value
                            if value == "installment" {
                                if installmentMonths.isEmpty {
                                    installmentMonths = "2"
                                }
                                installmentWasEdited = false
                                applySuggestedInstallmentIfNeeded()
                            }
                        }
                    } label: {
                        PaymentMethodOptionRow(
                            title: title,
                            subtitle: paymentMethodSubtitle(for: value),
                            icon: paymentMethodIcon(for: value),
                            isSelected: paymentMethod == value
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var moveInPaymentSummary: some View {
        if selectedRoomType != nil {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("สรุปยอดแรกเข้า", systemImage: "sum")
                        .font(.custom("SukhumvitSet-Bold", size: 14))
                        .foregroundStyle(.primary)
                    Spacer()
                    Text("มัดจำ \(defaultDepositPercent.formatted(.number.precision(.fractionLength(0))))%")
                        .font(.custom("SukhumvitSet-Medium", size: 12))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(Color.primary.opacity(0.06)))
                }

                VStack(spacing: 8) {
                    summaryLine("ค่าเช่าห้องเดือนแรก", amount: moveInBaseTotal)
                    summaryLine(status == "จอง" ? "เงินจอง/มัดจำ" : "เงินมัดจำ", amount: depositValue)
                    Divider()
                    summaryLine("ยอดรวม", amount: moveInGrandTotal, emphasized: true)
                }

                Text("ค่าน้ำ ค่าไฟ และค่าส่วนกลางจะแยกไปคิดในบิลรายเดือนตามรอบใช้งาน")
                    .font(.custom("SukhumvitSet-Text", size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 8)
        }
    }

    private var installmentSummary: some View {
        VStack(alignment: .leading, spacing: 8) {
            summaryLine("ยอดรวมที่นำไปผ่อน", amount: moveInGrandTotal)
            summaryLine("ค่างวดโดยประมาณ", amount: installmentAmountValue, emphasized: true)
            if let months = Int(installmentMonths), months > 0 {
                Text("\(months) งวด × \(currency(installmentAmountValue))")
                    .font(.custom("SukhumvitSet-Text", size: 12))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.top, 4)
    }

    private func summaryLine(_ title: String, amount: Double, emphasized: Bool = false) -> some View {
        HStack {
            Text(title)
                .font(.custom(emphasized ? "SukhumvitSet-Bold" : "SukhumvitSet-Text", size: emphasized ? 14 : 13))
                .foregroundStyle(emphasized ? .primary : .secondary)
            Spacer()
            Text(currency(amount))
                .font(.custom("SukhumvitSet-Bold", size: emphasized ? 15 : 13))
                .foregroundStyle(emphasized ? Color.indigo : .primary)
        }
    }

    private var paymentChannelSelector: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ช่องทางชำระ")
                .font(.custom("SukhumvitSet-Medium", size: 13))
                .foregroundStyle(.secondary)

            VStack(spacing: 10) {
                ForEach(paymentChannelOptions, id: \.0) { value, title in
                    Button {
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                            paymentChannel = value
                            if value == "cash" {
                                bookingSlipPaths = []
                                selectedSlipItems = []
                            }
                        }
                    } label: {
                        PaymentMethodOptionRow(
                            title: title,
                            subtitle: paymentChannelSubtitle(for: value),
                            icon: paymentChannelIcon(for: value),
                            isSelected: paymentChannel == value
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func paymentMethodSubtitle(for value: String) -> String {
        switch value {
        case "installment":
            return "บันทึกเป็นรายการค้างบางส่วนและติดตามต่อในหน้าการเงิน"
        default:
            return "เหมาะกับลูกบ้านที่ชำระครบตอนเข้าอยู่"
        }
    }

    private func paymentMethodIcon(for value: String) -> String {
        value == "installment" ? "clock.badge.checkmark" : "checkmark.seal"
    }

    private func paymentChannelSubtitle(for value: String) -> String {
        value == "cash" ? "บันทึกรับเงินสด ไม่ต้องแนบสลิป" : "แนบสลิปไว้เป็นหลักฐานในเครื่อง"
    }

    private func paymentChannelIcon(for value: String) -> String {
        value == "cash" ? "banknote" : "building.columns"
    }

    private var moveInBaseTotal: Double {
        guard let type = selectedRoomType else { return 0 }
        return type.price
    }

    private var suggestedDeposit: Double {
        roundedMoney(moveInBaseTotal * defaultDepositPercent / 100)
    }

    private var depositValue: Double {
        Double(deposit) ?? 0
    }

    private var moveInGrandTotal: Double {
        moveInBaseTotal + depositValue
    }

    private var installmentAmountValue: Double {
        Double(installmentAmount) ?? suggestedInstallmentAmount
    }

    private var suggestedInstallmentAmount: Double {
        guard let months = Int(installmentMonths), months > 0 else { return 0 }
        return roundedMoney(moveInGrandTotal / Double(months))
    }

    private func applySuggestedDepositIfNeeded() {
        guard !isEditing, !depositWasEdited, moveInBaseTotal > 0 else { return }
        isApplyingSuggestedValues = true
        deposit = moneyInput(suggestedDeposit)
        DispatchQueue.main.async {
            isApplyingSuggestedValues = false
        }
    }

    private func applySuggestedInstallmentIfNeeded() {
        guard paymentMethod == "installment",
              let months = Int(installmentMonths),
              months > 0,
              !installmentWasEdited else { return }
        isApplyingSuggestedValues = true
        installmentAmount = moneyInput(roundedMoney(moveInGrandTotal / Double(months)))
        DispatchQueue.main.async {
            isApplyingSuggestedValues = false
        }
    }

    private func roundedMoney(_ amount: Double) -> Double {
        (amount * 100).rounded() / 100
    }

    private func moneyInput(_ amount: Double) -> String {
        if amount.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", amount)
        }
        return String(format: "%.2f", amount)
    }

    private func currency(_ amount: Double) -> String {
        "฿" + amount.formatted(.number.precision(.fractionLength(amount.truncatingRemainder(dividingBy: 1) == 0 ? 0 : 2)))
    }

    @ViewBuilder
    private var tenantSlipPickerContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !bookingSlipImages.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(Array(bookingSlipImages.enumerated()), id: \.offset) { index, image in
                            ZStack(alignment: .topTrailing) {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 112, height: 138)
                                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                                    )

                                Button {
                                    removeBookingSlip(at: index)
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(.white)
                                        .frame(width: 24, height: 24)
                                        .background(.black.opacity(0.55), in: Circle())
                                }
                                .buttonStyle(.plain)
                                .padding(6)
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
            }

            PhotosPicker(selection: $selectedSlipItems, maxSelectionCount: 10, matching: .images, photoLibrary: .shared()) {
                HStack(spacing: 10) {
                    if isImportingSlip {
                        ProgressView()
                            .scaleEffect(0.82)
                    } else {
                        Image(systemName: bookingSlipPaths.isEmpty ? "photo.badge.plus" : "photo.on.rectangle")
                            .font(.system(size: 17, weight: .bold))
                    }

                    Text(bookingSlipPaths.isEmpty ? "เพิ่มรูปสลิป" : "เพิ่มรูปสลิปอีก")
                        .font(.custom("SukhumvitSet-Bold", size: 15))

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.secondary)
                }
                .foregroundStyle(.blue)
                .frame(maxWidth: .infinity, minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(isImportingSlip)

            if !bookingSlipPaths.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text(slipImportMessage ?? "มีรูปสลิปแนบ \(bookingSlipPaths.count) รูป")
                        .font(.custom("SukhumvitSet-Text", size: 12))
                        .foregroundStyle(.secondary)
                }
            } else if let slipImportMessage {
                Text(slipImportMessage)
                    .font(.custom("SukhumvitSet-Text", size: 12))
                    .foregroundStyle(.secondary)
            }
        }
        .onChange(of: selectedSlipItems) { _, newItems in
            importBookingSlips(newItems)
        }
    }

    private var bookingSlipImages: [UIImage] {
        bookingSlipPaths.compactMap { path in
            guard let url = SlipImageManager.url(for: path),
                  FileManager.default.fileExists(atPath: url.path) else {
                return nil
            }
            return UIImage(contentsOfFile: url.path)
        }
    }

    private func submitForm() async {
        guard !isSubmitting else { return }
        isSubmitting = true
        errorText = nil
        defer { isSubmitting = false }

        guard !firstName.isEmpty, !lastName.isEmpty, !roomNumber.isEmpty else {
            errorText = "กรุณากรอกชื่อ นามสกุล และเลือกห้อง"
            return
        }

        guard selectedRoom != nil else {
            errorText = "กรุณาเลือกห้องจากรายการที่สร้างไว้ในหน้าจัดการห้องพัก"
            return
        }

        if paymentMethod == "installment" {
            guard (Int(installmentMonths) ?? 0) > 0 else {
                errorText = "กรุณาระบุจำนวนงวด"
                return
            }

            guard (Double(installmentAmount) ?? 0) > 0 else {
                errorText = "กรุณาระบุยอดชำระต่องวด"
                return
            }
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.calendar = Calendar(identifier: .gregorian)

        do {
            let localUsers = try modelContext.fetch(FetchDescriptor<DormUser>())
            let user: DormUser
            if let editUser,
               let existing = localUsers.first(where: { matches($0, editUser: editUser) }) {
                user = existing
            } else {
                user = DormUser(firstName: firstName, lastName: lastName)
                user.serverId = Int(truncatingIfNeeded: user.id.hashValue)
                modelContext.insert(user)
            }

            let cleanedRoomNumber = clean(roomNumber)
            user.prefix = clean(prefix)
            user.firstName = clean(firstName)
            user.lastName = clean(lastName)
            user.roomNumber = cleanedRoomNumber
            user.phone = clean(phone)
            user.nationalID = clean(nationalID)
            user.address = clean(address)
            user.status = status
            user.moveInDate = dateFormatter.string(from: moveInDate)
            user.contractEndDate = (status == "จอง" || indefiniteContract) ? "" : dateFormatter.string(from: contractEndDate)
            user.deposit = Double(deposit) ?? 0
            user.bookingStatus = status == "จอง" ? "reserved" : ""
            user.bookingEndDate = status == "จอง" ? dateFormatter.string(from: bookingEndDate) : ""
            user.indefiniteContract = status == "จอง" ? 0 : (indefiniteContract ? 1 : 0)
            user.paymentMethod = paymentMethod
            user.paymentChannel = paymentChannel
            user.installmentMonths = Int(installmentMonths) ?? 0
            user.installmentAmount = Double(installmentAmount) ?? 0
            user.bookingSlips = paymentChannel == "bank_transfer" ? bookingSlipPaths : []
            user.lastUpdated = Date()
            user.isDirty = true
            try ensureCurrentMonthPayment(for: user)
            try modelContext.save()
            await SyncManager.shared.autoPushLocalChanges(modelContext: modelContext)
            await viewModel.fetchUsers(modelContext: modelContext)
            dismiss()
        } catch {
            errorText = "ไม่สามารถบันทึกข้อมูลลงเครื่องได้"
        }
        return
    }

    private func removeBookingSlip(at index: Int) {
        guard bookingSlipPaths.indices.contains(index) else { return }
        bookingSlipPaths.remove(at: index)
        slipImportMessage = bookingSlipPaths.isEmpty ? nil : "มีรูปสลิปแนบ \(bookingSlipPaths.count) รูป"
    }

    private func importBookingSlips(_ items: [PhotosPickerItem]) {
        guard !items.isEmpty else { return }

        isImportingSlip = true
        slipImportMessage = nil

        Task {
            do {
                var imported: [String] = []
                for item in items {
                    guard let data = try await item.loadTransferable(type: Data.self) else {
                        continue
                    }
                    imported.append(try SlipImageManager.saveImageData(data))
                }

                guard !imported.isEmpty else { throw CocoaError(.fileReadUnknown) }
                await MainActor.run {
                    bookingSlipPaths.append(contentsOf: imported)
                    selectedSlipItems = []
                    isImportingSlip = false
                    slipImportMessage = "เพิ่มรูปสลิปแล้ว \(imported.count) รูป"
                }
            } catch {
                await MainActor.run {
                    selectedSlipItems = []
                    isImportingSlip = false
                    slipImportMessage = "เพิ่มรูปสลิปไม่สำเร็จ"
                }
            }
        }
    }

    private func ensureCurrentMonthPayment(for user: DormUser) throws {
        guard user.status != "ย้ายออกแล้ว", let room = selectedRoom else { return }

        let month = monthKey(for: moveInDate)
        let userID = user.serverId ?? Int(truncatingIfNeeded: user.id.hashValue)
        let localPayments = try modelContext.fetch(FetchDescriptor<Payment>())
        let existingPayment = localPayments.first {
            !$0.isDeletedLocally &&
            $0.month == month &&
            ($0.userId == userID || clean($0.roomNumber) == clean(user.roomNumber))
        }
        let payment = existingPayment ?? Payment(month: month)

        if existingPayment == nil {
            modelContext.insert(payment)
        }

        let type = roomTypes.first { clean($0.name) == clean(room.roomType) }
        let firstMonthRent = type?.price ?? 0
        let isBooking = user.status == "จอง"
        let amountDue = isBooking ? user.deposit : firstMonthRent + user.deposit
        let channelText = paymentChannelText(user.paymentChannel)
        payment.userId = userID
        payment.roomNumber = user.roomNumber
        payment.month = month
        payment.rentFee = isBooking ? user.deposit : firstMonthRent
        payment.waterFee = 0
        payment.electricFee = 0
        payment.commonFee = 0
        payment.lateFee = 0
        payment.applianceFee = 0
        payment.amount = amountDue
        payment.method = "\(paymentMethodText(user.paymentMethod)) • \(channelText)"
        payment.slipPath = user.bookingSlips.first ?? payment.slipPath
        payment.slipPathArray = user.bookingSlips
        payment.paymentPlan = user.paymentMethod
        payment.installmentPhase = user.installmentMonths
        payment.paymentStatus = user.paymentMethod == "installment" ? "partial" : "paid"
        payment.paidAmount = user.paymentMethod == "installment" ? user.installmentAmount : amountDue
        payment.dueDate = dueDateKey(for: moveInDate)
        payment.lastUpdated = Date()
        payment.isDirty = true
    }

    private func monthKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        return formatter.string(from: date)
    }

    private func dueDateKey(for date: Date) -> String {
        var components = Calendar(identifier: .gregorian).dateComponents([.year, .month], from: date)
        components.month = (components.month ?? 1) + 1
        components.day = 0
        let dueDate = Calendar(identifier: .gregorian).date(from: components) ?? date
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        return formatter.string(from: dueDate)
    }

    private func paymentMethodText(_ value: String) -> String {
        value == "installment" ? "ผ่อนชำระ" : "ชำระเต็มจำนวน"
    }

    private func paymentChannelText(_ value: String) -> String {
        value == "cash" ? "เงินสด" : "โอนผ่านธนาคาร"
    }

    private var selectedRoomType: RoomType? {
        guard let room = selectedRoom else { return nil }
        return roomTypes.first { clean($0.name) == clean(room.roomType) }
    }

    private var selectedRoom: Room? {
        existingRoom(for: roomNumber)
    }

    private var selectableRooms: [Room] {
        let currentRoom = clean(editUser?.room_number ?? "")
        let occupied = Set(localUsers.filter { user in
            guard !user.isDeletedLocally, user.status != "ย้ายออกแล้ว" else { return false }
            let userRoom = clean(user.roomNumber)
            if userRoom.isEmpty || userRoom == currentRoom { return false }
            if let editUser, matches(user, editUser: editUser) { return false }
            return true
        }.map { clean($0.roomNumber) })

        return rooms.filter { room in
            let roomNumber = clean(room.roomNumber)
            return !room.isDeletedLocally && !roomNumber.isEmpty && !occupied.contains(roomNumber)
        }
    }

    private func existingRoom(for roomNumber: String) -> Room? {
        let cleanedRoom = clean(roomNumber)
        return rooms.first { !$0.isDeletedLocally && clean($0.roomNumber) == cleanedRoom }
    }

    private func applyExistingRoomTypeIfNeeded() {
        guard let room = existingRoom(for: roomNumber), roomType != room.roomType else { return }
        roomType = room.roomType
    }

    private func roomLabel(_ room: Room) -> String {
        let type = clean(room.roomType)
        if type.isEmpty { return "ห้อง \(room.roomNumber)" }
        return "ห้อง \(room.roomNumber) • \(type)"
    }

    private func matches(_ user: DormUser, editUser: APIUser) -> Bool {
        let localID = user.serverId ?? Int(truncatingIfNeeded: user.id.hashValue)
        if localID == editUser.id { return true }
        return clean(user.roomNumber) == clean(editUser.room_number ?? "") &&
            clean(user.firstName) == clean(editUser.first_name ?? "") &&
            clean(user.lastName) == clean(editUser.last_name ?? "")
    }

    private func clean(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Detail Section
struct DetailSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.custom("SukhumvitSet-Bold", size: 15))
                .foregroundColor(.primary)
            
            VStack(spacing: 0) {
                content
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 15)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(sectionFillColor)
                .shadow(color: colorScheme == .dark ? .black.opacity(0.05) : .clear, radius: 12, x: 0, y: 5)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(sectionBorderColor, lineWidth: 1)
        )
    }

    private var sectionFillColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.045) : Color.white.opacity(0.24)
    }

    private var sectionBorderColor: Color {
        colorScheme == .dark ? Color.primary.opacity(0.1) : Color.white.opacity(0.2)
    }
}

// MARK: - Detail Row
struct DetailRow: View {
    let icon: String
    let label: String
    let value: String
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(iconColor)
                .frame(width: 26, height: 26)
                .background(Circle().fill(iconFillColor))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.custom("SukhumvitSet-Text", size: 12))
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.custom("SukhumvitSet-Bold", size: 14))
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding(.vertical, 10)
    }

    private var iconColor: Color {
        colorScheme == .dark ? .white.opacity(0.72) : .primary.opacity(0.62)
    }

    private var iconFillColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.035)
    }
}

private struct PaymentMethodOptionRow: View {
    let title: String
    let subtitle: String
    let icon: String
    let isSelected: Bool
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(iconFillColor)
                    .frame(width: 38, height: 38)

                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(iconColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.custom("SukhumvitSet-Bold", size: 14))
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.custom("SukhumvitSet-Text", size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            ZStack {
                Circle()
                    .stroke(isSelected ? Color.indigo.opacity(0.7) : Color.secondary.opacity(0.22), lineWidth: 1.4)
                    .frame(width: 24, height: 24)

                if isSelected {
                    Circle()
                        .fill(Color.indigo)
                        .frame(width: 18, height: 18)

                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(rowFillColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(rowBorderColor, lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var rowFillColor: Color {
        if isSelected {
            return colorScheme == .dark ? Color.indigo.opacity(0.18) : Color.indigo.opacity(0.08)
        }
        return colorScheme == .dark ? Color.white.opacity(0.045) : Color.black.opacity(0.025)
    }

    private var rowBorderColor: Color {
        if isSelected {
            return colorScheme == .dark ? Color.indigo.opacity(0.32) : Color.indigo.opacity(0.18)
        }
        return colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.045)
    }

    private var iconFillColor: Color {
        isSelected ? Color.indigo.opacity(colorScheme == .dark ? 0.24 : 0.12) : Color.primary.opacity(0.055)
    }

    private var iconColor: Color {
        isSelected ? .indigo : .secondary
    }
}

// MARK: - Form Field Row
struct FormFieldRow: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var keyboard: UIKeyboardType = .default
    
    var body: some View {
        HStack {
            Text(label)
                .font(.custom("SukhumvitSet-Medium", size: 15))
                .foregroundColor(.primary)
                .frame(width: 105, alignment: .leading)
            TextField(placeholder, text: $text)
                .font(.custom("SukhumvitSet-Text", size: 15))
                .keyboardType(keyboard)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Shimmer Effect
struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    colors: [.clear, .white.opacity(0.15), .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .offset(x: phase)
                .onAppear {
                    withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                        phase = 400
                    }
                }
            )
            .clipped()
    }
}

extension View {
    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }
}

// MARK: - Keyboard Dismiss Helper
extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
