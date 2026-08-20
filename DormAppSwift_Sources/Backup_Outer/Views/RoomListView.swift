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
    
    var body: some View {
        ZStack(alignment: .leading) {
            // 1. Static Glass Background (Always covers full screen)
            GlassBackgroundView()
                .ignoresSafeArea()
            
            // 2. Main Dashboard Content Area
            ZStack {
                ScrollView(showsIndicators: false) {
                    Group {
                        switch selectedTab {
                        case .overview:
                            OverviewTabView()
                        case .tenants:
                            TenantsTabView()
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
                .scrollDisabled(selectedTab == .securityToken)
                
                // Floating Transparent Header
                VStack {
                    HStack {
                        // Hamburger Menu Button
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
                            
                            // Sync Button
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
            .scaleEffect(isSidebarOpen ? 0.92 : 1)
            .disabled(isSidebarOpen)
            
            // Overlay to close sidebar
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
            
            // Sidebar View
            SidebarMenu(isOpen: $isSidebarOpen, isLoggedIn: $isLoggedIn, isSettingsMode: $isSettingsMode, selectedTab: $selectedTab)
                .frame(maxWidth: .infinity, alignment: .leading)
                .offset(x: isSidebarOpen ? 0 : -UIScreen.main.bounds.width)
                .ignoresSafeArea()
        }
        // Add Swipe Gesture for sidebar on the outermost view
        .gesture(
            DragGesture(minimumDistance: 15)
                .onEnded { value in
                    let translation = value.translation.width
                    let predicted = value.predictedEndTranslation.width
                    
                    if translation > 40 || predicted > 80 {
                        // Swipe Right to open
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                            isSidebarOpen = true
                        }
                    } else if translation < -40 || predicted < -80 {
                        // Swipe Left to close
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                            isSidebarOpen = false
                        }
                    }
                }
        )
    }
    
    private func syncData() {
        withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
            isSyncing = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation {
                isSyncing = false
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
    @Environment(\.colorScheme) var colorScheme
    @AppStorage("userName") var userName: String = ""
    @AppStorage("userEmail") var userEmail: String = ""
    @AppStorage("userRole") var userRole: String = "admin"
    @AppStorage("adminID") var adminID: Int = 0
    @AppStorage("profileImageUpdateToken") var profileImageUpdateToken: Double = 0
    @State private var showingEditProfile = false
    @State private var currentEditingAdmin: Admin? = nil
    
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
                // Sidebar Header
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
                
                // User Profile & Logout at bottom
                VStack(spacing: 15) {
                    Divider()
                        .background(Color.secondary.opacity(0.3))
                    
                    HStack(spacing: 12) {
                        let displayChar = userName.isEmpty ? "A" : String(userName.prefix(1).uppercased())
                        let displayName = userName.isEmpty ? "Admin" : userName
                        
                        ZStack {
                            let _ = profileImageUpdateToken // trigger re-render on change
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
                                .padding(10)
                                .background(Color.indigo.opacity(0.1))
                                .clipShape(Circle())
                        }
                        
                        Button(action: {
                            UserDefaults.standard.removeObject(forKey: "savedAccountsHistory")
                            let generator = UINotificationFeedbackGenerator()
                            generator.notificationOccurred(.success)
                        }) {
                            Image(systemName: "trash.fill")
                                .font(.custom("SukhumvitSet-Bold", size: 18))
                                .foregroundColor(.orange)
                                .padding(10)
                                .background(Color.orange.opacity(0.1))
                                .clipShape(Circle())
                        }
                        
                        Button(action: { isLoggedIn = false }) {
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
                // If they change their name/email, we might want to update AppStorage.
                // But for now, they can log out and log in again or it updates on next sync.
            })
        }
        .onChange(of: showingEditProfile) { newValue in
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
                    showingEditProfile = false // Reset the trigger
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
