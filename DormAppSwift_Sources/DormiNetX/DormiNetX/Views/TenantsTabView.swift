import SwiftUI

struct TenantsTabView: View {
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
            Color("AppBackground")
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    hideKeyboard()
                }
            
            // 2. เนื้อหาหลัก
            ScrollView {
                VStack(spacing: 0) {
                    
                    // MARK: - Liquid Glass Control Bar
                    VStack(spacing: 0) {
                        // Search + Sort in one row
                        HStack(spacing: 10) {
                            HStack(spacing: 8) {
                                Image(systemName: "magnifyingglass")
                                    .foregroundColor(.secondary)
                                    .font(.system(size: 14))
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
                                Image(systemName: "arrow.up.arrow.down")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.blue)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                            }
                        }
                        
                        Divider().padding(.horizontal, 12)
                        
                        // Filter Tabs
                        LoupeFilterTabs(viewModel: viewModel)
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .shadow(color: .black.opacity(0.08), radius: 20, x: 0, y: 8)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [.white.opacity(0.4), .white.opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 115) // ดันให้พ้นขอบบน
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
                            Text("พบ \(viewModel.filteredUsers.count) รายการ")
                                .font(.custom("SukhumvitSet-Text", size: 12))
                                .foregroundColor(.secondary)
                            Spacer()
                            if viewModel.isLoading {
                                ProgressView().scaleEffect(0.7)
                            }
                        }
                        .padding(.horizontal, 22)
                        .padding(.bottom, 4)
                        
                        LazyVStack(spacing: 10) {
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
            .scrollDismissesKeyboard(.immediately)
            .onTapGesture {
                hideKeyboard()
            }
            // บังคับ ScrollView ให้เต็มจอ ป้องกันการหดตัว
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .refreshable { await viewModel.fetchUsers() }
            .onAppear { Task { await viewModel.fetchUsers() } }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing) // ล็อกกรอบใหญ่สุดอีกชั้น พร้อมยึดมุมขวาล่าง
        .sheet(item: $selectedUser) { user in
            TenantDetailSheet(user: user, viewModel: viewModel) {
                editingUser = user
            }
        }
        .sheet(isPresented: $showAddSheet) {
            TenantFormSheet(viewModel: viewModel, editUser: nil)
        }
        .sheet(item: $editingUser) { user in
            TenantFormSheet(viewModel: viewModel, editUser: user)
        }
        .alert("ยืนยันการลบ", isPresented: $showDeleteAlert) {
            Button("ยกเลิก", role: .cancel) { }
            Button("ลบ", role: .destructive) {
                if let u = userToDelete {
                    Task { let _ = await viewModel.deleteUser(id: u.id) }
                }
            }
        } message: {
            if let u = userToDelete {
                Text("ต้องการลบลูกบ้านห้อง \(u.room_number ?? "-") (\(u.first_name ?? "") \(u.last_name ?? "")) จริงหรือไม่?")
            }
        }
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
        ("all", "ทั้งหมด", Color.blue),
        ("active", "พักอาศัย", Color.green),
        ("booking", "จอง", Color.orange),
        ("inactive", "ย้ายออก", Color.red)
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
        .padding(.vertical, 8)
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
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(.ultraThickMaterial)
                                .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 4)
                        )
                        .overlay(
                            Capsule()
                                .stroke(
                                    LinearGradient(
                                        colors: [.red.opacity(0.6), .cyan.opacity(0.4), .yellow.opacity(0.4), .blue.opacity(0.6)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1.5
                                )
                                .blur(radius: 0.5)
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
    
    var body: some View {
        HStack(spacing: 4) {
            Text(title)
                .font(.custom("SukhumvitSet-Bold", size: 14))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            
            Text("\(count)")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(
                    Capsule()
                        .fill(isActive ? color.opacity(0.15) : Color.gray.opacity(0.15))
                )
        }
        .foregroundColor(isActive ? color : .secondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(
            Capsule()
                .fill(isActive ? Color.gray.opacity(0.12) : Color.clear)
        )
        .contentShape(Rectangle())
        // ทำให้เวลาเฟดเปลี่ยนสีมันนุ่มและดูเป็นธรรมชาติมากขึ้น
        .animation(.easeInOut(duration: 0.25), value: isActive)
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
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                Text(user.room_number ?? "-")
                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                    .foregroundColor(user.status == "ย้ายออกแล้ว" ? .orange : .primary)
                    .frame(width: 54, height: 54)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(viewModel.statusColor(user.status).opacity(0.1))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(viewModel.statusColor(user.status).opacity(0.2), lineWidth: 1)
                    )
                
                VStack(alignment: .leading, spacing: 3) {
                    Text("\(user.prefix ?? "")\(user.first_name ?? "") \(user.last_name ?? "")")
                        .font(.custom("SukhumvitSet-Bold", size: 15))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Label(viewModel.formatPhone(user.phone), systemImage: "phone.fill")
                        .font(.custom("SukhumvitSet-Text", size: 12))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    HStack(spacing: 3) {
                        Circle()
                            .fill(viewModel.statusColor(user.status))
                            .frame(width: 6, height: 6)
                        Text(user.status ?? "-")
                            .font(.custom("SukhumvitSet-Bold", size: 11))
                            .foregroundColor(viewModel.statusColor(user.status))
                    }
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary.opacity(0.5))
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [.white.opacity(0.35), .white.opacity(0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
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
}

// MARK: - Tenant Detail Sheet
struct TenantDetailSheet: View {
    let user: APIUser
    let viewModel: TenantsViewModel
    let onEdit: () -> Void
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    VStack(spacing: 10) {
                        Text(user.room_number ?? "-")
                            .font(.system(size: 48, weight: .bold, design: .monospaced))
                            .foregroundColor(.primary)
                        
                        HStack(spacing: 6) {
                            Circle()
                                .fill(viewModel.statusColor(user.status))
                                .frame(width: 8, height: 8)
                            Text(user.status ?? "-")
                                .font(.custom("SukhumvitSet-Bold", size: 14))
                        }
                        .foregroundColor(viewModel.statusColor(user.status))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(viewModel.statusColor(user.status).opacity(0.1))
                        .cornerRadius(12)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 20)
                    
                    Button {
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            onEdit()
                        }
                    } label: {
                        Label("แก้ไขข้อมูลลูกบ้าน", systemImage: "pencil")
                            .font(.custom("SukhumvitSet-Bold", size: 14))
                            .foregroundColor(.blue)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(.ultraThinMaterial)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                            )
                    }
                    .padding(.horizontal, 20)
                    
                    VStack(spacing: 14) {
                        DetailSection(title: "ข้อมูลส่วนตัว") {
                            DetailRow(icon: "person.fill", label: "ชื่อ-นามสกุล", value: "\(user.prefix ?? "")\(user.first_name ?? "") \(user.last_name ?? "")")
                            DetailRow(icon: "phone.fill", label: "เบอร์โทรศัพท์", value: viewModel.formatPhone(user.phone))
                            DetailRow(icon: "creditcard.fill", label: "เลขบัตรประชาชน", value: maskNationalID(user.national_id))
                            DetailRow(icon: "map.fill", label: "ที่อยู่", value: user.address ?? "-")
                        }
                        
                        DetailSection(title: "ข้อมูลสัญญา") {
                            DetailRow(icon: "calendar", label: "วันเข้าอยู่", value: formatDate(user.move_in_date))
                            DetailRow(icon: "calendar.badge.clock", label: "วันหมดสัญญา", value: user.indefinite_contract == 1 ? "ไม่กำหนดระยะเวลา" : formatDate(user.contract_end_date))
                            DetailRow(icon: "banknote.fill", label: "เงินมัดจำ", value: String(format: "฿%.0f", user.deposit ?? 0))
                            DetailRow(icon: "creditcard.circle.fill", label: "วิธีชำระเงิน", value: paymentMethodText(user.payment_method))
                        }
                        
                        if let appliances = user.additional_appliances, !appliances.isEmpty {
                            DetailSection(title: "เครื่องใช้ไฟฟ้าเพิ่มเติม") {
                                DetailRow(icon: "bolt.fill", label: "รายการ", value: appliances)
                                DetailRow(icon: "banknote.fill", label: "ค่าใช้จ่ายเพิ่ม", value: String(format: "฿%.0f/เดือน", user.additional_appliance_fee ?? 0))
                            }
                        }
                        
                        if let details = user.additional_details, !details.isEmpty {
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
    
    @State private var prefix = "นาย"
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var roomNumber = ""
    @State private var phone = ""
    @State private var nationalID = ""
    @State private var address = ""
    @State private var status = "กำลังพักอาศัย"
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
                    TextField("นามสกุล", text: $lastName)
                    TextField("เบอร์โทรศัพท์", text: $phone)
                        .keyboardType(.phonePad)
                    TextField("เลขบัตรประชาชน", text: $nationalID)
                        .keyboardType(.numberPad)
                    TextField("ที่อยู่", text: $address)
                }
                
                Section(header: Text("ข้อมูลห้องพัก")) {
                    TextField("เลขห้อง", text: $roomNumber)
                        .keyboardType(.numberPad)
                    
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
            .scrollDismissesKeyboard(.immediately)
            .onTapGesture {
                hideKeyboard()
            }
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
                    deposit = u.deposit != nil ? String(format: "%.0f", u.deposit!) : ""
                    indefiniteContract = (u.indefinite_contract ?? 0) == 1
                    
                    let df = DateFormatter()
                    df.dateFormat = "yyyy-MM-dd"
                    df.locale = Locale(identifier: "en_US_POSIX")
                    df.calendar = Calendar(identifier: .gregorian)
                    if let d = u.move_in_date, let date = df.date(from: d) { moveInDate = date }
                    if let d = u.contract_end_date, let date = df.date(from: d) { contractEndDate = date }
                }
            }
            .transaction { transaction in
                transaction.disablesAnimations = true
            }
        }
    }
    

    

    
    private func submitForm() async {
        guard !firstName.isEmpty, !lastName.isEmpty, !roomNumber.isEmpty else {
            errorText = "กรุณากรอกชื่อ นามสกุล และเลขห้อง"
            return
        }
        
        isSubmitting = true
        errorText = nil
        
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        df.locale = Locale(identifier: "en_US_POSIX")
        df.calendar = Calendar(identifier: .gregorian)
        
        var body: [String: Any] = [
            "prefix": prefix,
            "first_name": firstName,
            "last_name": lastName,
            "room_number": roomNumber,
            "phone": phone,
            "national_id": nationalID,
            "address": address,
            "status": status,
            "move_in_date": df.string(from: moveInDate),
            "contract_end_date": indefiniteContract ? "" : df.string(from: contractEndDate),
            "deposit": Double(deposit) ?? 0,
            "indefinite_contract": indefiniteContract ? 1 : 0,
            "payment_method": "full_payment"
        ]
        
        let urlStr: String
        let method: String
        if let u = editUser {
            urlStr = "\(APIService.shared.baseURL)/users?id=\(u.id)"
            method = "PUT"
            body["id"] = u.id
        } else {
            urlStr = "\(APIService.shared.baseURL)/users"
            method = "POST"
        }
        
        guard let url = URL(string: urlStr) else {
            errorText = "URL ไม่ถูกต้อง"
            isSubmitting = false
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = APIService.shared.authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, (200...201).contains(http.statusCode) {
                await viewModel.fetchUsers()
                dismiss()
            } else {
                errorText = "เซิร์ฟเวอร์ตอบกลับผิดพลาด"
            }
        } catch {
            errorText = "ไม่สามารถบันทึกข้อมูลได้: \(error.localizedDescription)"
        }
        
        isSubmitting = false
    }
}

// MARK: - Detail Section
struct DetailSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.custom("SukhumvitSet-Bold", size: 14))
                .foregroundColor(.blue)
            
            VStack(spacing: 10) {
                content
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.3), .white.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }
}

// MARK: - Detail Row
struct DetailRow: View {
    let icon: String
    let label: String
    let value: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(.blue.opacity(0.7))
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.custom("SukhumvitSet-Text", size: 11))
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.custom("SukhumvitSet-Bold", size: 14))
                    .foregroundColor(.primary)
            }
            Spacer()
        }
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
