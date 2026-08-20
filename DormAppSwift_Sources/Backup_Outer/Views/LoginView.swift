import SwiftUI

struct LoginView: View {
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var isPasswordVisible: Bool = false
    
    // สำหรับโหมดสมัครสมาชิก
    @State private var isSignUpMode: Bool = false
    @State private var name: String = ""
    @State private var confirmPassword: String = ""
    @State private var isConfirmPasswordVisible: Bool = false
    
    @State private var errorMessage: String? = nil
    @State private var isLoading: Bool = false
    
    @AppStorage("isLoggedIn") var isLoggedIn: Bool = false
    @AppStorage("userEmail") var userEmail: String = ""
    @AppStorage("userName") var userName: String = ""
    @AppStorage("securityTokenEnabled") var securityTokenEnabled: Bool = false
    @AppStorage("securityPasscode") var securityPasscode: String = "123456"
    
    @State private var showingPasscodeModal: Bool = false
    @State private var passcodeInput: String = ""
    @State private var passcodeError: String? = nil
    @FocusState private var isPasscodeFocused: Bool
    
    @State private var savedAccounts: [SavedAccount] = []
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        ZStack {
            GlassBackgroundView()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 35) {
                    // Logo
                    Image(systemName: "building.2.crop.circle.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 90, height: 90)
                        .foregroundColor(colorScheme == .dark ? .white : .indigo)
                        .shadow(color: (colorScheme == .dark ? Color.white : Color.indigo).opacity(0.3), radius: 10, x: 0, y: 5)
                        .padding(.top, 80) // เพิ่ม padding ให้ตกลงมาอีกนิด
                    
                    // Title Text with Creative 3D Flip & Gradient Animation
                    ZStack {
                        // โหมด Login (DormiNet)
                        Text("DormiNet")
                            .font(.custom("SukhumvitSet-Bold", size: 38))
                            .foregroundColor(.primary)
                            .opacity(isSignUpMode ? 0 : 1)
                            .rotation3DEffect(
                                .degrees(isSignUpMode ? -90 : 0),
                                axis: (x: 1, y: 0, z: 0),
                                perspective: 0.5
                            )
                            .offset(y: isSignUpMode ? -20 : 0)
                            .blur(radius: isSignUpMode ? 5 : 0)
                        
                        // โหมดสมัครสมาชิก (Create Account)
                        HStack(spacing: 8) {
                            Text("Create Account")
                            Image(systemName: "sparkles")
                                .font(.custom("SukhumvitSet-Bold", size: 28))
                        }
                        .font(.custom("SukhumvitSet-Bold", size: 36))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.indigo, .purple, .pink],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .opacity(isSignUpMode ? 1 : 0)
                        .rotation3DEffect(
                            .degrees(isSignUpMode ? 0 : 90),
                            axis: (x: 1, y: 0, z: 0),
                            perspective: 0.5
                        )
                        .offset(y: isSignUpMode ? 0 : 20)
                        .blur(radius: isSignUpMode ? 0 : 5)
                    }
                    
                    VStack(spacing: 20) {
                        
                        if isSignUpMode {
                            // Name Field (Animated)
                            HStack {
                                Image(systemName: "person.fill")
                                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.7) : .indigo)
                                    .frame(width: 20)
                                TextField("Name", text: $name)
                                    .foregroundColor(.primary)
                            }
                            .padding()
                            .background(colorScheme == .dark ? Color.white.opacity(0.1) : Color.white.opacity(0.6))
                            .cornerRadius(15)
                            .overlay(
                                RoundedRectangle(cornerRadius: 15)
                                    .stroke(colorScheme == .dark ? Color.white.opacity(0.2) : Color.white, lineWidth: 1.5)
                            )
                            .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
                            .transition(.asymmetric(
                                insertion: .scale(scale: 0.9).combined(with: .opacity).combined(with: .move(edge: .top)),
                                removal: .scale(scale: 0.9).combined(with: .opacity).combined(with: .move(edge: .top))
                            ))
                        }
                        
                        // Email Field
                        HStack {
                            Image(systemName: "envelope.fill")
                                .foregroundColor(colorScheme == .dark ? .white.opacity(0.7) : .indigo)
                                .frame(width: 20)
                            TextField("Email", text: $email)
                                .autocapitalization(.none)
                                .keyboardType(.emailAddress)
                                .foregroundColor(.primary)
                        }
                        .padding()
                        .background(colorScheme == .dark ? Color.white.opacity(0.1) : Color.white.opacity(0.6))
                        .cornerRadius(15)
                        .overlay(
                            RoundedRectangle(cornerRadius: 15)
                                .stroke(colorScheme == .dark ? Color.white.opacity(0.2) : Color.white, lineWidth: 1.5)
                        )
                        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
                        
                        // Password Field
                        HStack {
                            Image(systemName: "lock.fill")
                                .foregroundColor(colorScheme == .dark ? .white.opacity(0.7) : .indigo)
                                .frame(width: 20)
                            
                            if isPasswordVisible {
                                TextField("Password", text: $password)
                                    .foregroundColor(.primary)
                            } else {
                                SecureField("Password", text: $password)
                                    .foregroundColor(.primary)
                            }
                            
                            Button(action: {
                                isPasswordVisible.toggle()
                            }) {
                                Image(systemName: isPasswordVisible ? "eye.slash.fill" : "eye.fill")
                                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.6) : .gray)
                            }
                        }
                        .padding()
                        .background(colorScheme == .dark ? Color.white.opacity(0.1) : Color.white.opacity(0.6))
                        .cornerRadius(15)
                        .overlay(
                            RoundedRectangle(cornerRadius: 15)
                                .stroke(colorScheme == .dark ? Color.white.opacity(0.2) : Color.white, lineWidth: 1.5)
                        )
                        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
                        
                        if isSignUpMode {
                            // Confirm Password Field (Animated)
                            HStack {
                                Image(systemName: "lock.fill")
                                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.7) : .indigo)
                                    .frame(width: 20)
                                
                                if isConfirmPasswordVisible {
                                    TextField("Confirm Password", text: $confirmPassword)
                                        .foregroundColor(.primary)
                                } else {
                                    SecureField("Confirm Password", text: $confirmPassword)
                                        .foregroundColor(.primary)
                                }
                                
                                Button(action: {
                                    isConfirmPasswordVisible.toggle()
                                }) {
                                    Image(systemName: isConfirmPasswordVisible ? "eye.slash.fill" : "eye.fill")
                                        .foregroundColor(colorScheme == .dark ? .white.opacity(0.6) : .gray)
                                }
                            }
                            .padding()
                            .background(colorScheme == .dark ? Color.white.opacity(0.1) : Color.white.opacity(0.6))
                            .cornerRadius(15)
                            .overlay(
                                RoundedRectangle(cornerRadius: 15)
                                    .stroke(colorScheme == .dark ? Color.white.opacity(0.2) : Color.white, lineWidth: 1.5)
                            )
                            .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
                            .transition(.asymmetric(
                                insertion: .scale(scale: 0.9).combined(with: .opacity).combined(with: .move(edge: .top)),
                                removal: .scale(scale: 0.9).combined(with: .opacity).combined(with: .move(edge: .top))
                            ))
                        }
                        
                        if let errorMessage = errorMessage {
                            Text(errorMessage)
                                .foregroundColor(.red)
                                .font(.custom("SukhumvitSet-Text", size: 12))
                                .multilineTextAlignment(.center)
                                .transition(.opacity.combined(with: .scale))
                        }
                        
                        // Action Button (Glassy)
                        Button(action: {
                            Task { await handleAuth() }
                        }) {
                            HStack {
                                if isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: colorScheme == .dark ? .white : .indigo))
                                } else {
                                    Text(isSignUpMode ? "Sign Up" : "Sign In")
                                        .font(.custom("SukhumvitSet-Bold", size: 17))
                                        .id(isSignUpMode) // Animation สำหรับ Text ในปุ่ม
                                        .transition(.asymmetric(
                                            insertion: .opacity.combined(with: .move(edge: .trailing)),
                                            removal: .opacity.combined(with: .move(edge: .leading))
                                        ))
                                }
                            }
                            .foregroundColor(colorScheme == .dark ? .white : .indigo)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(colorScheme == .dark ? Color.white.opacity(0.15) : Color.white.opacity(0.7))
                            .cornerRadius(15)
                            .overlay(
                                RoundedRectangle(cornerRadius: 15)
                                    .stroke(colorScheme == .dark ? Color.white.opacity(0.3) : Color.indigo.opacity(0.3), lineWidth: 1)
                            )
                            .shadow(color: .indigo.opacity(0.15), radius: 10, x: 0, y: 5)
                        }
                        .buttonStyle(PressableButtonStyle())
                        .disabled(isLoading || email.isEmpty || password.isEmpty || (isSignUpMode && (name.isEmpty || confirmPassword.isEmpty)))
                    }
                    .padding(.horizontal, 30)
                    
                    // Toggle Mode Button with Creative Animation
                    Button(action: {
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.75)) {
                            isSignUpMode.toggle()
                            errorMessage = nil
                        }
                    }) {
                        Text(isSignUpMode ? "Already have an account? Sign In" : "Don't have an account? Sign Up")
                            .font(.custom("SukhumvitSet-Text", size: 15))
                            .foregroundColor(.indigo)
                            .id(isSignUpMode) // Animation ข้อความด้านล่าง
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .move(edge: .bottom)).combined(with: .scale(scale: 0.9)),
                                removal: .opacity.combined(with: .move(edge: .top)).combined(with: .scale(scale: 0.9))
                            ))
                    }
                    .buttonStyle(PressableButtonStyle())
                    .padding(.top, 10)
                    .padding(.bottom, 40)
                }
            }
            .scrollDismissesKeyboard(.immediately)
            
            // วางปุ่มสลับ Theme ไว้หลัง ScrollView จะได้ไม่โดนทับและกดได้เสมอ
            VStack {
                HStack(spacing: 15) {
                    ThemeToggleButton()
                    
                    if !savedAccounts.isEmpty {
                        Menu {
                            ForEach(savedAccounts) { account in
                                Button(action: {
                                    email = account.email
                                    password = account.password
                                    name = account.name
                                    isSignUpMode = false
                                    Task {
                                        await handleAuth()
                                    }
                                }) {
                                    Text(account.name.isEmpty ? account.email : "\(account.name) (\(account.email))")
                                }
                            }
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(colorScheme == .dark ? Color.white.opacity(0.15) : Color.black.opacity(0.05))
                                    .frame(width: 44, height: 44)
                                    .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
                                Image(systemName: "chevron.down.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(colorScheme == .dark ? .white : .indigo)
                            }
                        }
                    }
                    
                    Spacer()
                }
                .padding(.leading, 20)
                .padding(.top, 20)
                
                Spacer()
            }
            .safeAreaPadding()
            
            // 6-Digit Security Token Verification Modal Overlay
            if showingPasscodeModal {
                ZStack {
                    // Translucent glass backdrop (Tapping dismisses keyboard)
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .ignoresSafeArea()
                        .onTapGesture {
                            isPasscodeFocused = false
                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        }
                    
                    // Modal Card (Positioned higher so keyboard never overlaps)
                    VStack {
                        GlassCard {
                            VStack(spacing: 20) {
                                // Icon Badge
                                ZStack {
                                    Circle()
                                        .fill(LinearGradient(colors: [.indigo, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                                        .frame(width: 56, height: 56)
                                        .shadow(color: .indigo.opacity(0.3), radius: 8, x: 0, y: 4)
                                    
                                    Image(systemName: "lock.shield.fill")
                                        .font(.system(size: 26))
                                        .foregroundColor(.white)
                                }
                                
                                VStack(spacing: 4) {
                                    Text("ยืนยันรหัสความปลอดภัย 6 หลัก")
                                        .font(.custom("SukhumvitSet-Bold", size: 17))
                                        .foregroundColor(.primary)
                                    Text("กรุณากรอกรหัสผ่าน 6 หลักเพื่อเข้าใช้งานระบบ")
                                        .font(.custom("SukhumvitSet-Medium", size: 13))
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.center)
                                }
                                
                                // 6 Digit Display Boxes with Invisible TextField
                                ZStack {
                                    TextField("", text: $passcodeInput)
                                        .keyboardType(.numberPad)
                                        .focused($isPasscodeFocused)
                                        .opacity(0.01)
                                        .onChange(of: passcodeInput) { oldValue, newValue in
                                            let filtered = newValue.filter { $0.isNumber }
                                            passcodeInput = String(filtered.prefix(6))
                                            if passcodeInput.count == 6 {
                                                verifyPasscode()
                                            }
                                        }
                                    
                                    HStack(spacing: 8) {
                                        ForEach(0..<6, id: \.self) { index in
                                            let char = index < passcodeInput.count ? String(Array(passcodeInput)[index]) : ""
                                            Text(char)
                                                .font(.custom("SukhumvitSet-Bold", size: 22))
                                                .foregroundColor(colorScheme == .dark ? .white : .indigo)
                                                .frame(width: 38, height: 48)
                                                .background(colorScheme == .dark ? Color.white.opacity(0.12) : Color.indigo.opacity(0.1))
                                                .cornerRadius(10)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 10)
                                                        .stroke(index == passcodeInput.count ? Color.indigo : Color.indigo.opacity(0.3), lineWidth: index == passcodeInput.count ? 2 : 1)
                                                )
                                        }
                                    }
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        isPasscodeFocused = true
                                    }
                                }
                                
                                if let error = passcodeError {
                                    Text(error)
                                        .font(.custom("SukhumvitSet-Medium", size: 13))
                                        .foregroundColor(.red)
                                }
                                
                                HStack(spacing: 12) {
                                    Button(action: {
                                        isPasscodeFocused = false
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            showingPasscodeModal = false
                                        }
                                    }) {
                                        Text("ยกเลิก")
                                            .font(.custom("SukhumvitSet-Medium", size: 14))
                                            .foregroundColor(.secondary)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 10)
                                    }
                                    
                                    Button(action: {
                                        verifyPasscode()
                                    }) {
                                        Text("ยืนยัน")
                                            .font(.custom("SukhumvitSet-Bold", size: 14))
                                            .foregroundColor(.white)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 10)
                                            .background(Color.indigo)
                                            .cornerRadius(10)
                                    }
                                    .disabled(passcodeInput.count < 6)
                                    .opacity(passcodeInput.count < 6 ? 0.6 : 1.0)
                                }
                            }
                            .padding(20)
                        }
                        .frame(maxWidth: 340)
                        .padding(.horizontal, 20)
                        .offset(y: isPasscodeFocused ? -110 : 0)
                        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isPasscodeFocused)
                    }
                }
                .ignoresSafeArea(.keyboard, edges: .bottom)
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .animation(.spring(response: 0.38, dampingFraction: 0.8), value: showingPasscodeModal)
        .onAppear {
            loadSavedAccounts()
        }
        .onTapGesture {
            // ซ่อนคีย์บอร์ดเมื่อแตะพื้นที่ว่าง
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
        .animation(.easeInOut(duration: 0.8), value: colorScheme) // แอนิเมชั่นค่อยๆ เฟดเมื่อสลับธีม
    }
    
    private func handleAuth() async {
        if isSignUpMode {
            if name.count <= 4 {
                errorMessage = "ชื่อต้องมีความยาวมากกว่า 4 ตัวอักษร"
                return
            }
            
            let emailRegex = "^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}$"
            if email.range(of: emailRegex, options: .regularExpression) == nil {
                errorMessage = "รูปแบบอีเมลไม่ถูกต้อง"
                return
            }
            
            if password.count < 8 {
                errorMessage = "รหัสผ่านต้องมีความยาวอย่างน้อย 8 ตัวอักษร"
                return
            }
            
            let hasUppercase = password.contains(where: { $0.isUppercase })
            let hasLowercase = password.contains(where: { $0.isLowercase })
            let hasNumber = password.contains(where: { $0.isNumber })
            let hasSpecial = password.contains(where: { !$0.isLetter && !$0.isNumber })
            
            if !hasUppercase || !hasLowercase || !hasNumber || !hasSpecial {
                errorMessage = "รหัสผ่านต้องประกอบด้วยตัวพิมพ์ใหญ่ ตัวพิมพ์เล็ก ตัวเลข และอักขระพิเศษ"
                return
            }
            
            guard password == confirmPassword else {
                errorMessage = "รหัสผ่านไม่ตรงกัน"
                return
            }
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let success: Bool
            let returnedName: String?
            
            var backendErrorMsg: String? = nil
            
            if isSignUpMode {
                let result = try await APIService.shared.register(name: name, email: email, password: password)
                success = result.0
                returnedName = result.1
                backendErrorMsg = result.2
            } else {
                let result = try await APIService.shared.login(email: email, password: password)
                success = result.0
                returnedName = result.1
            }
            
            if success {
                await MainActor.run {
                    userEmail = email
                    if let fetchedName = returnedName, !fetchedName.isEmpty {
                        userName = fetchedName
                    } else if isSignUpMode {
                        userName = name
                    } else if userName.isEmpty {
                        userName = String(email.split(separator: "@").first ?? "User")
                    }
                    if securityTokenEnabled && !securityPasscode.isEmpty && !isSignUpMode {
                        passcodeInput = ""
                        passcodeError = nil
                        withAnimation(.spring(response: 0.38, dampingFraction: 0.8)) {
                            showingPasscodeModal = true
                        }
                        // Delay keyboard focus so modal animation finishes smoothly first without stutter
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isPasscodeFocused = true
                            }
                        }
                    } else {
                        isLoggedIn = true
                        saveAccount()
                    }
                }
            } else {
                errorMessage = isSignUpMode ? (backendErrorMsg ?? "การสมัครสมาชิกล้มเหลว") : "การเข้าสู่ระบบล้มเหลว กรุณาตรวจสอบอีเมลและรหัสผ่าน"
            }
        } catch {
            errorMessage = "เกิดข้อผิดพลาดในการเชื่อมต่อเครือข่าย หรือเซิร์ฟเวอร์อาจไม่ตอบสนอง"
            print("Auth Error: \(error)")
        }
        
        isLoading = false
    }
    
    private func loadSavedAccounts() {
        if let data = UserDefaults.standard.data(forKey: "savedAccountsHistory"),
           let decoded = try? JSONDecoder().decode([SavedAccount].self, from: data) {
            savedAccounts = decoded
        }
    }
    
    private func saveAccount() {
        var accounts = savedAccounts
        accounts.removeAll(where: { $0.email == email })
        let currentToken = APIService.shared.authToken ?? ""
        accounts.insert(SavedAccount(name: userName, email: email, password: password, token: currentToken), at: 0)
        
        // Keep only last 5 accounts
        if accounts.count > 5 {
            accounts = Array(accounts.prefix(5))
        }
        
        if let data = try? JSONEncoder().encode(accounts) {
            UserDefaults.standard.set(data, forKey: "savedAccountsHistory")
        }
        savedAccounts = accounts
    }
    
    private func clearSavedAccounts() {
        UserDefaults.standard.removeObject(forKey: "savedAccountsHistory")
        savedAccounts = []
    }
    
    private func verifyPasscode() {
        if passcodeInput == securityPasscode {
            isPasscodeFocused = false
            withAnimation(.easeInOut(duration: 0.2)) {
                showingPasscodeModal = false
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    isLoggedIn = true
                    saveAccount()
                }
            }
        } else {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                passcodeError = "รหัสผ่าน 6 หลักไม่ถูกต้อง"
                passcodeInput = ""
            }
        }
    }
}

struct SavedAccount: Identifiable, Codable {
    var id: String { email }
    let name: String
    let email: String
    let password: String
    var token: String?
}
