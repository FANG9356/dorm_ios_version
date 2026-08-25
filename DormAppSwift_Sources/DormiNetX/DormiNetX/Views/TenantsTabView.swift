import SwiftUI
import SwiftData

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
            Divider()
            Button(role: .destructive) { onDelete() } label: {
                Label("ลบลูกบ้าน", systemImage: "trash")
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
                    
                    VStack(spacing: 14) {
                        DetailSection(title: "ข้อมูลส่วนตัว") {
                            DetailRow(icon: "person.fill", label: "ชื่อ-นามสกุล", value: "\(displayUser.prefix ?? "")\(displayUser.first_name ?? "") \(displayUser.last_name ?? "")")
                            DetailRow(icon: "phone.fill", label: "เบอร์โทรศัพท์", value: viewModel.formatPhone(displayUser.phone))
                            DetailRow(icon: "creditcard.fill", label: "เลขบัตรประชาชน", value: maskNationalID(displayUser.national_id))
                            DetailRow(icon: "map.fill", label: "ที่อยู่", value: displayUser.address ?? "-")
                        }
                        
                        DetailSection(title: "ข้อมูลสัญญา") {
                            DetailRow(icon: "calendar", label: "วันเข้าอยู่", value: formatDate(displayUser.move_in_date))
                            DetailRow(icon: "calendar.badge.clock", label: "วันหมดสัญญา", value: displayUser.indefinite_contract == 1 ? "ไม่กำหนดระยะเวลา" : formatDate(displayUser.contract_end_date))
                            DetailRow(icon: "banknote.fill", label: "เงินมัดจำ", value: String(format: "฿%.0f", displayUser.deposit ?? 0))
                            DetailRow(icon: "creditcard.circle.fill", label: "วิธีชำระเงิน", value: paymentMethodText(displayUser.payment_method))
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
    @State private var contractEndDate = Date()
    @State private var deposit = ""
    @State private var indefiniteContract = false
    @State private var isSubmitting = false
    @State private var errorText: String?
    
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
                    DatePicker("วันเข้าอยู่", selection: $moveInDate, displayedComponents: .date)
                        .environment(\.locale, Locale(identifier: "th_TH"))
                        .environment(\.calendar, Calendar(identifier: .buddhist))
                    
                    Toggle("ไม่กำหนดระยะเวลาสัญญา", isOn: $indefiniteContract.animation(.easeInOut(duration: 0.2)))
                    
                    if !indefiniteContract {
                        DatePicker("วันหมดสัญญา", selection: $contractEndDate, displayedComponents: .date)
                            .environment(\.locale, Locale(identifier: "th_TH"))
                            .environment(\.calendar, Calendar(identifier: .buddhist))
                    }
                    TextField("เงินมัดจำ (บาท)", text: $deposit)
                        .keyboardType(.decimalPad)
                        .decimalInput($deposit, maxIntegerDigits: 8, maxFractionDigits: 2)
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
                    indefiniteContract = (u.indefinite_contract ?? 0) == 1
                    
                    let df = DateFormatter()
                    df.dateFormat = "yyyy-MM-dd"
                    df.locale = Locale(identifier: "en_US_POSIX")
                    df.calendar = Calendar(identifier: .gregorian)
                    if let d = u.move_in_date, let date = df.date(from: d) { moveInDate = date }
                    if let d = u.contract_end_date, let date = df.date(from: d) { contractEndDate = date }
                } else {
                    applyExistingRoomTypeIfNeeded()
                }
            }
            .transaction { transaction in
                transaction.disablesAnimations = true
            }
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
            user.contractEndDate = indefiniteContract ? "" : dateFormatter.string(from: contractEndDate)
            user.deposit = Double(deposit) ?? 0
            user.indefiniteContract = indefiniteContract ? 1 : 0
            user.paymentMethod = "full_payment"
            user.lastUpdated = Date()
            user.isDirty = true
            try modelContext.save()
            await SyncManager.shared.autoPushLocalChanges(modelContext: modelContext)
            await viewModel.fetchUsers(modelContext: modelContext)
            dismiss()
        } catch {
            errorText = "ไม่สามารถบันทึกข้อมูลลงเครื่องได้"
        }
        return
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
