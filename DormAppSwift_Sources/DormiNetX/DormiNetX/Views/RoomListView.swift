import SwiftUI
import SwiftData
import Charts

// Dashboard Models are in DashboardTab.swift

struct RoomListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var rooms: [Room]
    @State private var isSyncing = false
    @State private var isSidebarOpen = false
    @State private var isSettingsMode = false
    @State private var selectedTab: DashboardTab = .overview
    @AppStorage("isLoggedIn") var isLoggedIn: Bool = false
    @Environment(\.colorScheme) var colorScheme
    @State private var isLoggingOut = false
    @State private var showAddTenantSheet = false
    @State private var showSyncOverlay = false
    
    var body: some View {
        ZStack(alignment: .leading) {
            
            ZStack {
                ScrollView(showsIndicators: false) {
                    Group {
                        switch selectedTab {
                        case .overview:
                            OverviewTabView()
                        case .tenants:
                            TenantsTabView(showAddSheet: $showAddTenantSheet)
                        case .finance:
                            FinanceTabView()
                        case .bills:
                            BillsTabView()
                        case .rooms:
                            RoomsTabView()
                        case .pricing:
                            PricingTabView()
                        case .transfers:
                            TransfersTabView()
                        case .maintenance:
                            MaintenanceTabView()
                        case .adminManagement:
                            AdminManagementTabView()
                        case .securityToken:
                            SecurityTokenTabView()
                        case .backup:
                            BackupTabView()
                        case .systemLogs:
                            SystemLogsTabView()
                        }
                    }
                    .id(selectedTab)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.98)),
                        removal: .opacity
                    ))
                    .animation(.easeInOut(duration: 0.25), value: selectedTab)
                }
                .scrollDisabled(selectedTab == .securityToken || selectedTab == .tenants)
                
                VStack {
                    HStack {
                        Button(action: {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                isSidebarOpen = true
                            }
                        }) {
                            ZStack {
                                Circle()
                                    .fill(.ultraThinMaterial)
                                    .frame(width: 44, height: 44)
                                    .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
                                Image(systemName: selectedTab.icon)
                                    .font(.custom("SukhumvitSet-Medium", size: 18))
                                    .foregroundColor(.primary)
                                    .rotationEffect(Angle(degrees: isSidebarOpen ? 90 : 0))
                            }
                        }
                        .buttonStyle(PressableButtonStyle())
                        
                        Text(selectedTab.rawValue)
                            .font(.custom("SukhumvitSet-Bold", size: 24))
                            .foregroundColor(.primary)
                            .padding(.leading, 8)
                        
                        Spacer()
                        
                        HStack(spacing: 12) {
                            ThemeToggleButton()
                            
                            Button(action: syncData) {
                                ZStack {
                                    Circle()
                                        .fill(.ultraThinMaterial)
                                        .frame(width: 44, height: 44)
                                        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
                                    
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                        .font(.custom("SukhumvitSet-Medium", size: 18))
                                        .foregroundColor(colorScheme == .dark ? .white : .indigo)
                                        .rotationEffect(Angle(degrees: isSyncing ? 360 : 0))
                                }
                            }
                            .buttonStyle(PressableButtonStyle())
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    .padding(.bottom, 15)
                    Spacer()
                }
            }
            .overlay(alignment: .bottomTrailing) {
                if selectedTab == .tenants {
                    Button {
                        showAddTenantSheet = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 58, height: 58)
                            .background(
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.blue, Color.indigo],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .shadow(color: .blue.opacity(0.4), radius: 12, x: 0, y: 6)
                            )
                    }
                    .padding(.trailing, 16)
                    .padding(.bottom, 0)
                    .ignoresSafeArea(.all, edges: .bottom)
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.75), value: selectedTab)
            .scaleEffect(isSidebarOpen ? 0.92 : 1)
            .disabled(isSidebarOpen)
            
            if isSidebarOpen {
                Rectangle()
                    .fill(colorScheme == .dark ? Color.black.opacity(0.2) : Color.white.opacity(0.05))
                    .background(.ultraThinMaterial)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                            isSidebarOpen = false
                        }
                    }
                    .transition(.opacity)
            }
            
            SidebarMenu(isOpen: $isSidebarOpen, isLoggedIn: $isLoggedIn, isSettingsMode: $isSettingsMode, selectedTab: $selectedTab, isLoggingOut: $isLoggingOut)
                .frame(maxWidth: .infinity, alignment: .leading)
                .offset(x: isSidebarOpen ? 0 : -(UIApplication.shared.connectedScenes.compactMap { ($0 as? UIWindowScene)?.screen.bounds.width }.first ?? 400))
                .ignoresSafeArea()
        }
        .overlay {
            if showSyncOverlay {
                SyncAnimationOverlay()
                    .transition(.opacity)
                    .zIndex(999)
            }
        }
        .overlay {
            if isLoggingOut {
                ZStack {
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .ignoresSafeArea()
                    
                    VStack(spacing: 30) {
                        LogoutAnimationView(isLoggingOut: isLoggingOut)
                            .frame(width: 86, height: 100)
                            .scaleEffect(1.2)
                        
                        Text("ออกจากระบบ...")
                            .font(.custom("SukhumvitSet-Bold", size: 16))
                            .foregroundColor(.indigo)
                    }
                }
                .transition(.opacity)
                .zIndex(1000)
            }
        }
        .animation(.easeInOut(duration: 0.4), value: isLoggingOut)
        .gesture(
            DragGesture(minimumDistance: 15)
                .onEnded { value in
                    let translation = value.translation.width
                    let predicted = value.predictedEndTranslation.width
                    
                    if translation > 40 || predicted > 80 {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                            isSidebarOpen = true
                        }
                    } else if translation < -40 || predicted < -80 {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                            isSidebarOpen = false
                        }
                    }
                }
        )
    }
    
    private func syncData() {
        guard !showSyncOverlay else { return }
        
        withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
            isSyncing = true
        }
        
        withAnimation(.easeInOut(duration: 0.4)) {
            showSyncOverlay = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
            withAnimation(.easeInOut(duration: 0.5)) {
                showSyncOverlay = false
            }
            withAnimation {
                isSyncing = false
            }
        }
    }
}

struct CloudOutlineShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        
        path.move(to: CGPoint(x: w * 0.15, y: h * 0.85))
        path.addLine(to: CGPoint(x: w * 0.85, y: h * 0.85))
        path.addQuadCurve(to: CGPoint(x: w * 0.92, y: h * 0.62), control: CGPoint(x: w * 1.0, y: h * 0.85))
        path.addQuadCurve(to: CGPoint(x: w * 0.72, y: h * 0.38), control: CGPoint(x: w * 0.92, y: h * 0.38))
        path.addQuadCurve(to: CGPoint(x: w * 0.45, y: h * 0.22), control: CGPoint(x: w * 0.65, y: h * 0.12))
        path.addQuadCurve(to: CGPoint(x: w * 0.22, y: h * 0.42), control: CGPoint(x: w * 0.25, y: h * 0.15))
        path.addQuadCurve(to: CGPoint(x: w * 0.15, y: h * 0.85), control: CGPoint(x: w * -0.02, y: h * 0.7))
        
        return path
    }
}

struct SyncAnimationOverlay: View {
    @State private var cloudProgress: CGFloat = 0.0
    @State private var arrowOffset: CGFloat = -40
    @State private var arrowOpacity: Double = 0.0
    @State private var dotOffsets: [CGSize] = [
        CGSize(width: -120, height: -180),
        CGSize(width: 150, height: -160),
        CGSize(width: -100, height: 130),
        CGSize(width: 130, height: 150),
        CGSize(width: -160, height: 20),
        CGSize(width: 170, height: -30)
    ]
    @State private var dotOpacities: [Double] = Array(repeating: 0.0, count: 6)
    @State private var statusText = "กำลังเชื่อมต่อ..."
    @State private var statusOpacity: Double = 0.0
    @State private var pulseArrow = false
    @State private var bgOpacity: Double = 0.0
    
    private let scatteredOffsets: [CGSize] = [
        CGSize(width: -120, height: -180),
        CGSize(width: 150, height: -160),
        CGSize(width: -100, height: 130),
        CGSize(width: 130, height: 150),
        CGSize(width: -160, height: 20),
        CGSize(width: 170, height: -30)
    ]
    
    var body: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
                .opacity(bgOpacity)
            
            VStack(spacing: 24) {
                ZStack {
                    ForEach(0..<6, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.indigo.opacity(0.8))
                            .frame(width: 12, height: 12)
                            .offset(dotOffsets[i])
                            .opacity(dotOpacities[i])
                    }
                    
                    CloudOutlineShape()
                        .trim(from: 0, to: cloudProgress)
                        .stroke(
                            Color.indigo,
                            style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round)
                        )
                        .frame(width: 140, height: 110)
                    
                    VStack(spacing: 2) {
                        Image(systemName: "arrow.down")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.indigo)
                    }
                    .offset(y: arrowOffset)
                    .opacity(arrowOpacity)
                    .scaleEffect(pulseArrow ? 1.15 : 1.0)
                }
                .frame(width: 140, height: 110)
                
                Text(statusText)
                    .font(.custom("SukhumvitSet-Bold", size: 16))
                    .foregroundColor(.indigo)
                    .opacity(statusOpacity)
            }
        }
        .onAppear {
            startSyncAnimation()
        }
    }
    
    private func startSyncAnimation() {
        withAnimation(.easeIn(duration: 0.3)) {
            bgOpacity = 1.0
        }
        
        for i in 0..<6 {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(Double(i) * 0.08)) {
                dotOffsets[i] = .zero
                dotOpacities[i] = 1.0
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation(.easeInOut(duration: 1.2)) {
                cloudProgress = 1.0
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) {
                arrowOffset = 12
                arrowOpacity = 1.0
            }
            withAnimation(.easeIn(duration: 0.4)) {
                statusOpacity = 1.0
            }
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true).delay(0.3)) {
                pulseArrow = true
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
            withAnimation(.easeInOut(duration: 0.3)) {
                statusText = "ซิงค์ข้อมูลสำเร็จ"
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            pulseArrow = false
            
            withAnimation(.easeOut(duration: 0.3)) {
                arrowOpacity = 0.0
                arrowOffset = 20
                statusOpacity = 0.0
            }
            
            withAnimation(.easeInOut(duration: 0.8)) {
                cloudProgress = 0.0
            }
            
            for i in 0..<6 {
                withAnimation(.spring(response: 0.8, dampingFraction: 0.8).delay(Double(5 - i) * 0.05)) {
                    dotOffsets[i] = scatteredOffsets[i]
                    dotOpacities[i] = 0.0
                }
            }
            
            withAnimation(.easeOut(duration: 0.4).delay(0.6)) {
                bgOpacity = 0.0
            }
        }
    }
}

struct GlassSummaryCard: View {
    var title: String
    var value: String
    var icon: String
    var color: Color
    
    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: icon)
                        .foregroundColor(color)
                        .font(.custom("SukhumvitSet-Bold", size: 22))
                    Spacer()
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(value)
                        .font(.custom("SukhumvitSet-Bold", size: 22))
                        .foregroundColor(.primary)
                    Text(title)
                        .font(.custom("SukhumvitSet-Text", size: 12))
                        .foregroundColor(.secondary)
                }
            }
            .padding(10)
        }
    }
}

struct SidebarMenu: View {
    @Binding var isOpen: Bool
    @Binding var isLoggedIn: Bool
    @Binding var isSettingsMode: Bool
    @Binding var selectedTab: DashboardTab
    @Binding var isLoggingOut: Bool
    @Environment(\.colorScheme) var colorScheme
    @AppStorage("userName") var userName: String = ""
    @AppStorage("userEmail") var userEmail: String = ""
    @AppStorage("userRole") var userRole: String = "admin"
    @AppStorage("adminID") var adminID: Int = 0
    @AppStorage("profileImageUpdateToken") var profileImageUpdateToken: Double = 0
    @State private var showingEditProfile = false
    @State private var currentEditingAdmin: Admin? = nil
    @State private var gearRotation: Double = 0
    
    var body: some View {
        ZStack(alignment: .leading) {
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                        isOpen = false
                    }
                }
            
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 35, height: 35)
                        Text("S")
                            .font(.custom("SukhumvitSet-Bold", size: 16))
                            .foregroundColor(.white)
                    }
                    
                    Text(isSettingsMode ? "MAINTENANCE" : "DORMINET ADMIN")
                        .font(.custom("SukhumvitSet-Bold", size: 14))
                        .tracking(1.5)
                        .foregroundColor(.primary)
                }
                .padding(.top, 60)
                .padding(.horizontal, 25)
                .padding(.bottom, 30)
                
                Text("MENU")
                    .font(.custom("SukhumvitSet-Bold", size: 11))
                    .foregroundColor(.secondary)
                    .tracking(2)
                    .padding(.horizontal, 25)
                    .padding(.bottom, 10)
                
                VStack(spacing: 5) {
                    let tabsToShow = DashboardTab.allCases.filter { $0.isSettingsMenu == isSettingsMode }
                    ForEach(tabsToShow) { tab in
                        SidebarItem(tab: tab, selectedTab: $selectedTab) {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                                isOpen = false
                            }
                        }
                    }
                }
                .padding(.horizontal, 15)
                .padding(.vertical, 15)
                .frame(width: 280, alignment: .leading)
                
                Spacer()
                
                VStack(spacing: 15) {
                    Divider()
                        .background(Color.secondary.opacity(0.3))
                    
                    HStack(spacing: 12) {
                        let displayChar = userName.isEmpty ? "A" : String(userName.prefix(1).uppercased())
                        let displayName = userName.isEmpty ? "Admin" : userName
                        
                        ZStack {
                            let _ = profileImageUpdateToken
                            if let localURL = APIService.shared.getLocalProfileImageURL(adminID: adminID),
                               let uiImage = UIImage(contentsOfFile: localURL.path) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 40, height: 40)
                                    .clipShape(Circle())
                            } else {
                                Circle()
                                    .fill(LinearGradient(colors: [.indigo, .pink], startPoint: .topLeading, endPoint: .bottomTrailing))
                                    .frame(width: 40, height: 40)
                                    .overlay(Text(displayChar).font(.custom("SukhumvitSet-Bold", size: 17)).foregroundColor(.white))
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(displayName)
                                .font(.custom("SukhumvitSet-Bold", size: 14))
                                .foregroundColor(.primary)
                                .lineLimit(1)
                            Text("Administrator")
                                .font(.custom("SukhumvitSet-Medium", size: 10))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            let generator = UIImpactFeedbackGenerator(style: .medium)
                            generator.impactOccurred()
                            
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                                gearRotation += 90
                            }
                            
                            if userRole == "superadmin" {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                                    isSettingsMode.toggle()
                                    selectedTab = isSettingsMode ? .adminManagement : .overview
                                }
                            } else {
                                showingEditProfile = true
                            }
                        }) {
                            Image(systemName: "gearshape.fill")
                                .font(.custom("SukhumvitSet-Bold", size: 18))
                                .foregroundColor(.indigo)
                                .rotationEffect(.degrees(gearRotation))
                                .padding(10)
                                .background(
                                    Circle()
                                        .fill(Color.indigo.opacity(isSettingsMode ? 0.25 : 0.1))
                                        .scaleEffect(isSettingsMode ? 1.15 : 1.0)
                                )
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .stroke(Color.indigo.opacity(isSettingsMode ? 0.4 : 0), lineWidth: 2)
                                        .scaleEffect(isSettingsMode ? 1.15 : 1.0)
                                )
                        }
                        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isSettingsMode)
                        
                        Button(action: {
                            UserDefaults.standard.removeObject(forKey: "savedAccountsHistory")
                            let generator = UINotificationFeedbackGenerator()
                            generator.notificationOccurred(.success)
                        }) {
                            Image(systemName: "clock.badge.xmark")
                                .font(.custom("SukhumvitSet-Bold", size: 18))
                                .foregroundColor(.orange)
                                .padding(10)
                                .background(Color.orange.opacity(0.1))
                                .clipShape(Circle())
                        }
                        
                        Button(action: {
                            let generator = UIImpactFeedbackGenerator(style: .heavy)
                            generator.impactOccurred()
                            
                            isOpen = false
                            
                            withAnimation(.easeInOut(duration: 0.4)) {
                                isLoggingOut = true
                            }
                            
                            APIService.shared.authToken = nil
                            APIService.shared.currentEmail = nil
                            APIService.shared.userRole = nil
                            
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                                // ปรับเวลาให้เท่ากับของ ContentView (0.8 วิ) จะได้ละลายสลับหน้าแบบพอดีกัน
                                withAnimation(.easeInOut(duration: 0.8)) {
                                    isLoggedIn = false
                                }
                                
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                                    isLoggingOut = false
                                }
                            }
                        }) {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .font(.custom("SukhumvitSet-Bold", size: 18))
                                .foregroundColor(.red.opacity(0.8))
                                .padding(10)
                                .background(Color.red.opacity(0.1))
                                .clipShape(Circle())
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .sheet(item: $currentEditingAdmin) { admin in
            EditAdminSheet(admin: admin, onSuccess: {
            })
        }
        .onChange(of: showingEditProfile) { _, newValue in
            if newValue {
                Task {
                    do {
                        let admins = try await APIService.shared.fetchAdmins()
                        if let me = admins.first(where: { $0.id == adminID }) {
                            currentEditingAdmin = me
                        }
                    } catch {
                        print("Failed to fetch admin data: \(error)")
                    }
                    showingEditProfile = false
                }
            }
        }
    }
}

struct SidebarItem: View {
    var tab: DashboardTab
    @Binding var selectedTab: DashboardTab
    var action: () -> Void
    @Environment(\.colorScheme) var colorScheme
    
    var isActive: Bool {
        selectedTab == tab
    }
    
    var body: some View {
        Button(action: {
            selectedTab = tab
            action()
        }) {
            HStack(spacing: 15) {
                Image(systemName: tab.icon)
                    .font(.custom("SukhumvitSet-Text", size: 16))
                    .frame(width: 24)
                Text(tab.rawValue)
                    .font(.custom("SukhumvitSet-Medium", size: 14))
                Spacer()
            }
            .foregroundColor(isActive ? (colorScheme == .dark ? .white : .blue) : .primary.opacity(0.7))
            .padding(.vertical, 12)
            .padding(.horizontal, 15)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isActive ? (colorScheme == .dark ? Color.indigo.opacity(0.5) : Color.blue.opacity(0.2)) : Color.clear)
            )
        }
    }
}

struct LogoutAnimationView: View {
    var isLoggingOut: Bool
    
    let scatteredOffsets: [CGSize] = [
        CGSize(width: -200, height: -250),
        CGSize(width: -100, height: -300),
        CGSize(width: -250, height: -80),
        CGSize(width: -150, height: -120),
        CGSize(width: -300, height: 80),
        CGSize(width: -200, height: 100),
        CGSize(width: -250, height: 250),
        CGSize(width: -100, height: 200)
    ]
    @State private var dotOffsets: [CGSize]
    @State private var dotOpacities: [Double] = Array(repeating: 0.0, count: 8)
    
    let scatteredOffsets2: [CGSize] = [
        CGSize(width: 250, height: -200),
        CGSize(width: 200, height: 50),
        CGSize(width: 300, height: 250)
    ]
    @State private var dotOffsets2: [CGSize]
    @State private var dotOpacities2: [Double] = Array(repeating: 0.0, count: 3)
    
    @State private var outlineProgress: CGFloat = 0.0
    
    init(isLoggingOut: Bool) {
        self.isLoggingOut = isLoggingOut
        _dotOffsets = State(initialValue: scatteredOffsets)
        _dotOffsets2 = State(initialValue: scatteredOffsets2)
    }
    
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            LazyVGrid(columns: [GridItem(.fixed(16)), GridItem(.fixed(16))], spacing: 10) {
                ForEach(0..<8, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.indigo)
                        .frame(width: 14, height: 14)
                        .offset(dotOffsets[index])
                        .opacity(dotOpacities[index])
                }
            }
            .frame(width: 38, height: 86)
            .offset(x: 7, y: -7)
            
            LazyVGrid(columns: [GridItem(.fixed(16))], spacing: 10) {
                ForEach(0..<3, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.indigo)
                        .frame(width: 14, height: 14)
                        .offset(dotOffsets2[index])
                        .opacity(dotOpacities2[index])
                }
            }
            .frame(width: 14, height: 62)
            .offset(x: 65, y: -7)
            
            TwinBuildingsOutline()
                .trim(from: 0, to: outlineProgress)
                .stroke(Color.indigo, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                .frame(width: 86, height: 100)
        }
        .onAppear {
            if isLoggingOut {
                withAnimation(.easeInOut(duration: 0.8)) {
                    outlineProgress = 1.0
                }
                
                for i in 0..<8 {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(Double(i) * 0.05 + 0.3)) {
                        dotOffsets[i] = .zero
                        dotOpacities[i] = 1.0
                    }
                }
                
                for i in 0..<3 {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(Double(i) * 0.07 + 0.4)) {
                        dotOffsets2[i] = .zero
                        dotOpacities2[i] = 1.0
                    }
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                    withAnimation(.easeInOut(duration: 0.8)) {
                        outlineProgress = 0.0
                    }
                    
                    for i in 0..<8 {
                        withAnimation(.spring(response: 0.8, dampingFraction: 0.8).delay(Double(7 - i) * 0.05)) {
                            dotOffsets[i] = scatteredOffsets[i]
                            dotOpacities[i] = 0.0
                        }
                    }
                    
                    for i in 0..<3 {
                        withAnimation(.spring(response: 0.8, dampingFraction: 0.8).delay(Double(2 - i) * 0.07)) {
                            dotOffsets2[i] = scatteredOffsets2[i]
                            dotOpacities2[i] = 0.0
                        }
                    }
                }
            }
        }
    }
}