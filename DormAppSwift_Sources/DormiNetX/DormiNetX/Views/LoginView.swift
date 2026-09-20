import SwiftUI

struct LoginView: View {
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var isPasswordVisible: Bool = false
    
    // Authentication modes
    @State private var isSignUpMode: Bool = false
    @State private var isForgotPasswordMode: Bool = false
    @State private var passwordResetEmail: String?
    @State private var passwordResetRefCode: String?
    @State private var showingPasswordReset = false
    @State private var passwordResetCompleted = false
    @State private var showingPasswordResetSuccess = false
    @State private var name: String = ""
    @State private var confirmPassword: String = ""
    @State private var isConfirmPasswordVisible: Bool = false
    
    @State private var errorMessage: String? = nil
    @State private var isLoading: Bool = false
    
    @AppStorage("isLoggedIn") var isLoggedIn: Bool = false
    @AppStorage("userEmail") var userEmail: String = ""
    @AppStorage("userName") var userName: String = ""
    @AppStorage("securityTokenEnabled") var securityTokenEnabled: Bool = false
    @ObservedObject private var credentials = CredentialStore.shared
    
    @State private var showingPasscodeModal: Bool = false
    @State private var passcodeInput: String = ""
    @State private var passcodeError: String? = nil
    @State private var pendingSavedAccount: SavedAccount?
    @State private var isVerifyingPasscode = false
    @FocusState private var isPasscodeFocused: Bool
    
    @State private var savedAccounts: [SavedAccount] = []
    @Environment(\.colorScheme) var colorScheme
    
    // Controls fade-in
    @State private var isScreenReady = false
    
    var body: some View {
        ZStack {
            // Keep the inner UI grouped so the whole screen can fade together
            ZStack {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 35) {
                        Image(systemName: "building.2.crop.circle.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 90, height: 90)
                            .foregroundColor(colorScheme == .dark ? .white : .indigo)
                            .shadow(color: (colorScheme == .dark ? Color.white : Color.indigo).opacity(0.3), radius: 10, x: 0, y: 5)
                            .padding(.top, 130)
                        ZStack {
                            Text("DormiNet")
                                .font(.custom("SukhumvitSet-Bold", size: 38))
                                .foregroundColor(.primary)
                                .opacity(!isSignUpMode && !isForgotPasswordMode ? 1 : 0)
                                .rotation3DEffect(
                                    .degrees(!isSignUpMode && !isForgotPasswordMode ? 0 : -90),
                                    axis: (x: 1, y: 0, z: 0),
                                    perspective: 0.5
                                )
                                .offset(y: isSignUpMode || isForgotPasswordMode ? -20 : 0)
                                .blur(radius: isSignUpMode || isForgotPasswordMode ? 5 : 0)

                            HStack(spacing: 8) {
                                Text(isForgotPasswordMode ? "รีเซ็ตรหัสผ่าน" : "สร้างบัญชี")
                                if !isForgotPasswordMode {
                                    Image(systemName: "sparkles")
                                        .font(.custom("SukhumvitSet-Bold", size: 28))
                                }
                            }
                            .font(.custom("SukhumvitSet-Bold", size: 36))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.indigo, .purple, .pink],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .opacity(isSignUpMode || isForgotPasswordMode ? 1 : 0)
                            .rotation3DEffect(
                                .degrees(isSignUpMode || isForgotPasswordMode ? 0 : 90),
                                axis: (x: 1, y: 0, z: 0),
                                perspective: 0.5
                            )
                            .offset(y: isSignUpMode || isForgotPasswordMode ? 0 : 20)
                            .blur(radius: isSignUpMode || isForgotPasswordMode ? 0 : 5)
                        }

                        VStack(spacing: 20) {
                            if isSignUpMode {
                                HStack {
                                    Image(systemName: "person.fill")
                                        .foregroundColor(colorScheme == .dark ? .white.opacity(0.7) : .indigo)
                                        .frame(width: 20)
                                    TextField("ชื่อผู้ใช้", text: $name)
                                        .font(.custom("SukhumvitSet-Medium", size: 16))
                                        .textInputAutocapitalization(.words)
                                        .disableAutocorrection(true)
                                        .foregroundColor(.primary)
                                        .limitedText($name, maxLength: 60, trimNewlines: true)
                                }
                                .padding()
                                .background(colorScheme == .dark ? Color.white.opacity(0.1) : Color.white.opacity(0.6))
                                .cornerRadius(15)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 15)
                                        .stroke(colorScheme == .dark ? Color.white.opacity(0.2) : Color.white, lineWidth: 1.5)
                                )
                                .shadow(color: .black.opacity(0.045), radius: 6, x: 0, y: 3)
                                .transition(.asymmetric(
                                    insertion: .scale(scale: 0.9).combined(with: .opacity).combined(with: .move(edge: .top)),
                                    removal: .scale(scale: 0.9).combined(with: .opacity).combined(with: .move(edge: .top))
                                ))
                            }
                            
                            HStack {
                                Image(systemName: "envelope.fill")
                                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.7) : .indigo)
                                    .frame(width: 20)
                                TextField("อีเมล", text: $email)
                                    .font(.custom("SukhumvitSet-Medium", size: 16))
                                    .textInputAutocapitalization(.never)
                                    .disableAutocorrection(true)
                                    .keyboardType(.emailAddress)
                                    .foregroundColor(.primary)
                                    .normalizedEmail($email)
                            }
                            .padding()
                            .background(colorScheme == .dark ? Color.white.opacity(0.1) : Color.white.opacity(0.6))
                            .cornerRadius(15)
                            .overlay(
                                RoundedRectangle(cornerRadius: 15)
                                    .stroke(colorScheme == .dark ? Color.white.opacity(0.2) : Color.white, lineWidth: 1.5)
                            )
                            .shadow(color: .black.opacity(0.045), radius: 6, x: 0, y: 3)
                            
                            if !isForgotPasswordMode {
                                HStack {
                                    Image(systemName: "lock.fill")
                                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.7) : .indigo)
                                    .frame(width: 20)
                                
                                if isPasswordVisible {
                                    TextField("รหัสผ่าน", text: $password)
                                        .font(.custom("SukhumvitSet-Medium", size: 16))
                                        .textInputAutocapitalization(.never)
                                        .disableAutocorrection(true)
                                        .foregroundColor(.primary)
                                        .limitedText($password, maxLength: 64, trimNewlines: true)
                                } else {
                                    SecureField("รหัสผ่าน", text: $password)
                                        .font(.custom("SukhumvitSet-Medium", size: 16))
                                        .foregroundColor(.primary)
                                        .limitedText($password, maxLength: 64, trimNewlines: true)
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
                            .shadow(color: .black.opacity(0.045), radius: 6, x: 0, y: 3)
                            }
                            
                            if isSignUpMode {
                                HStack {
                                    Image(systemName: "lock.fill")
                                        .foregroundColor(colorScheme == .dark ? .white.opacity(0.7) : .indigo)
                                        .frame(width: 20)
                                    
                                    if isConfirmPasswordVisible {
                                        TextField("ยืนยันรหัสผ่าน", text: $confirmPassword)
                                            .font(.custom("SukhumvitSet-Medium", size: 16))
                                            .textInputAutocapitalization(.never)
                                            .disableAutocorrection(true)
                                            .foregroundColor(.primary)
                                            .limitedText($confirmPassword, maxLength: 64, trimNewlines: true)
                                    } else {
                                        SecureField("ยืนยันรหัสผ่าน", text: $confirmPassword)
                                            .font(.custom("SukhumvitSet-Medium", size: 16))
                                            .foregroundColor(.primary)
                                            .limitedText($confirmPassword, maxLength: 64, trimNewlines: true)
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
                                .shadow(color: .black.opacity(0.045), radius: 6, x: 0, y: 3)
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
                                    .fixedSize(horizontal: false, vertical: true)
                                    .transition(
                                        .asymmetric(
                                            insertion: .opacity.combined(with: .offset(y: -6)).combined(with: .scale(scale: 0.97)),
                                            removal: .opacity.combined(with: .offset(y: -4)).combined(with: .scale(scale: 0.98))
                                        )
                                    )
                            }

                            if !isSignUpMode && !isForgotPasswordMode && errorMessage != nil {
                                Button(action: {
                                    withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                                        isForgotPasswordMode = true
                                        isSignUpMode = false
                                        clearError()
                                        password = ""
                                        confirmPassword = ""
                                        name = ""
                                        isPasswordVisible = false
                                        isConfirmPasswordVisible = false
                                    }
                                }) {
                                    Text("ลืมรหัสผ่าน?")
                                        .font(.custom("SukhumvitSet-Medium", size: 13))
                                        .foregroundColor(colorScheme == .dark ? .white.opacity(0.85) : .indigo)
                                }
                                .buttonStyle(PressableButtonStyle())
                                .padding(.top, -8)
                            }

                            Button(action: {
                                Task { await handleAuth() }
                            }) {
                                HStack {
                                    if isLoading {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: colorScheme == .dark ? .white : .indigo))
                                    } else {
                                        Text(isForgotPasswordMode ? "ส่งคำขอรีเซ็ตรหัสผ่าน" : (isSignUpMode ? "สมัครบัญชี" : "เข้าสู่ระบบ"))
                                            .font(.custom("SukhumvitSet-Bold", size: 17))
                                            .id(isForgotPasswordMode ? "forgot" : (isSignUpMode ? "signup" : "login"))
                                            .transition(.asymmetric(
                                                insertion: .opacity.combined(with: .offset(x: 8)),
                                                removal: .opacity.combined(with: .offset(x: -8))
                                            ))
                                    }
                                }
                                .foregroundColor(colorScheme == .dark ? .white : .indigo)
                                .animation(.easeInOut(duration: 0.3), value: isLoading)
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
                            .disabled(isLoading || email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || (!isForgotPasswordMode && password.isEmpty) || (isSignUpMode && (name.isEmpty || confirmPassword.isEmpty)))
                        }
                        .padding(.horizontal, 30)
                        .animation(.easeInOut(duration: 0.42), value: errorMessage)
                        
                        Button(action: {
                            withAnimation(.spring(response: 0.6, dampingFraction: 0.75)) {
                                if isForgotPasswordMode {
                                    resetToSignIn()
                                } else if isSignUpMode {
                                    resetToSignIn()
                                } else {
                                    resetToSignUp()
                                }
                            }
                        }) {
                            Text(isForgotPasswordMode ? "กลับไปเข้าสู่ระบบ" : (isSignUpMode ? "มีบัญชีอยู่แล้ว? เข้าสู่ระบบ" : "ยังไม่มีบัญชี? สมัครบัญชี"))
                                .font(.custom("SukhumvitSet-Text", size: 15))
                                .foregroundColor(.indigo)
                                .id(isSignUpMode)
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
                .scrollDismissesKeyboard(.interactively)
                .contentShape(Rectangle())
                .simultaneousGesture(TapGesture().onEnded {
                    dismissKeyboard()
                })
                
                VStack {
                    if !showingPasscodeModal {
                        HStack(spacing: 15) {
                            ThemeToggleButton()
                            
                            if !savedAccounts.isEmpty {
                                Menu {
                                    ForEach(savedAccounts) { account in
                                        Button(action: {
                                            selectSavedAccount(account)
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
                        .padding(.top, 15)
                    }
                    Spacer()
                }
                .safeAreaPadding()
                
                if showingPasscodeModal {
                    ZStack {
                        Rectangle()
                            .fill(.ultraThinMaterial)
                            .ignoresSafeArea()
                            .onTapGesture {
                                isPasscodeFocused = false
                                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                            }
                        
                        VStack {
                            GlassCard {
                                VStack(spacing: 20) {
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
                                        Text("ใส่รหัสยืนยัน 6 หลัก")
                                            .font(.custom("SukhumvitSet-Bold", size: 17))
                                            .foregroundColor(.primary)
                                        Text("กรอกรหัสความปลอดภัยเพื่อเข้าใช้งานต่อ")
                                            .font(.custom("SukhumvitSet-Medium", size: 13))
                                            .foregroundColor(.secondary)
                                            .multilineTextAlignment(.center)
                                    }
                                    
                                    ZStack {
                                        TextField("", text: $passcodeInput)
                                            .font(.custom("SukhumvitSet-Bold", size: 22))
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
                                            pendingSavedAccount = nil
                                            passcodeInput = ""
                                            passcodeError = nil
                                            isVerifyingPasscode = false
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
            .opacity(isScreenReady ? 1.0 : 0.0) // 💡 ควบคุมให้ทุกอย่างเฟดเข้า/ออกพร้อมกันทั้งหมด
            .dismissKeyboardOnTap()
        }
        .animation(.spring(response: 0.38, dampingFraction: 0.8), value: showingPasscodeModal)
        .onAppear {
            loadSavedAccounts()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeOut(duration: 0.4)) {
                    isScreenReady = true
                }
            }
        }
        .animation(.easeInOut(duration: 0.8), value: colorScheme)
        .sheet(isPresented: $showingPasswordReset, onDismiss: {
            if passwordResetCompleted {
                resetToSignIn()
                passwordResetCompleted = false
                showingPasswordResetSuccess = true
            }
        }) {
            if let passwordResetEmail {
                PasswordResetView(email: passwordResetEmail, refCode: passwordResetRefCode) {
                    passwordResetCompleted = true
                    // Remove this device's saved session; server-side JWT revocation is separate.
                    do {
                        let remaining = savedAccounts.filter {
                            $0.email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() != passwordResetEmail
                        }
                        try credentials.setSavedAccountsData(JSONEncoder().encode(remaining))
                        savedAccounts = remaining
                    } catch { credentials.errorMessage = error.localizedDescription }
                }
            }
        }
        .alert("เปลี่ยนรหัสผ่านสำเร็จ", isPresented: $showingPasswordResetSuccess) {
            Button("ตกลง", role: .cancel) {}
        } message: {
            Text("กรุณาเข้าสู่ระบบด้วยรหัสผ่านใหม่")
        }
    }
    
    private func showError(_ message: String) {
        withAnimation(.easeInOut(duration: 0.45)) {
            errorMessage = message
        }
    }

    private func clearError() {
        guard errorMessage != nil else { return }
        withAnimation(.easeOut(duration: 0.25)) {
            errorMessage = nil
        }
    }

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }

    private func resetToSignIn() {
        isSignUpMode = false
        isForgotPasswordMode = false
        clearError()
        password = ""
        confirmPassword = ""
        name = ""
        isPasswordVisible = false
        isConfirmPasswordVisible = false
    }

    private func resetToSignUp() {
        isSignUpMode = true
        isForgotPasswordMode = false
        clearError()
        password = ""
        confirmPassword = ""
        name = ""
        isPasswordVisible = false
        isConfirmPasswordVisible = false
    }

    private func handleAuth() async {
        clearError()

        if isForgotPasswordMode {
            await handleForgotPassword()
            return
        }

        if isSignUpMode {
            if name.count <= 4 {
                showError("ชื่อผู้ใช้ต้องมีอย่างน้อย 5 ตัวอักษร")
                return
            }
            
            let emailRegex = "^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}$"
            if email.range(of: emailRegex, options: .regularExpression) == nil {
                showError("รูปแบบอีเมลไม่ถูกต้อง")
                return
            }
            
            if password.count < 8 {
                showError("รหัสผ่านต้องมีอย่างน้อย 8 ตัวอักษร")
                return
            }
            
            let hasUppercase = password.contains(where: { $0.isUppercase })
            let hasLowercase = password.contains(where: { $0.isLowercase })
            let hasNumber = password.contains(where: { $0.isNumber })
            let hasSpecial = password.contains(where: { !$0.isLetter && !$0.isNumber })
            
            if !hasUppercase || !hasLowercase || !hasNumber || !hasSpecial {
                showError("รหัสผ่านต้องมีตัวพิมพ์ใหญ่ ตัวพิมพ์เล็ก ตัวเลข และอักขระพิเศษ")
                return
            }
            
            guard password == confirmPassword else {
                showError("รหัสผ่านและการยืนยันรหัสผ่านไม่ตรงกัน")
                return
            }
        }
        
        isLoading = true
        clearError()
        
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
                        userName = String(email.split(separator: "@").first ?? "ผู้ใช้")
                    }
                    
                    if securityTokenEnabled && !isSignUpMode {
                        passcodeInput = ""
                        passcodeError = nil
                        withAnimation(.spring(response: 0.38, dampingFraction: 0.8)) {
                            showingPasscodeModal = true
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isPasscodeFocused = true
                            }
                        }
                    } else {
                        // Fade out LoginView before switching screens
                        withAnimation(.easeOut(duration: 0.2)) {
                            isScreenReady = false
                        }
                        
                        // Switch to Dashboard after the login UI has faded out
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            withAnimation(.easeInOut(duration: 0.6)) {
                                isLoggedIn = true
                                saveAccount()
                            }
                        }
                    }
                }
            } else {
                showError(isSignUpMode ? (backendErrorMsg ?? "สมัครบัญชีไม่สำเร็จ") : "เข้าสู่ระบบไม่สำเร็จ กรุณาตรวจสอบอีเมลและรหัสผ่าน")
            }
        } catch {
            showError("เกิดปัญหาเครือข่าย หรือเซิร์ฟเวอร์ไม่ตอบสนอง")
            print("Auth Error: \(error)")
        }
        
        isLoading = false
    }
    
    private func handleForgotPassword() async {
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let emailRegex = "^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}$"

        guard normalizedEmail.range(of: emailRegex, options: .regularExpression) != nil else {
            await MainActor.run { showError("กรุณากรอกอีเมลให้ถูกต้อง") }
            return
        }

        guard !isLoading else { return }
        isLoading = true
        clearError()
        defer { isLoading = false }
        do {
            let refCode = try await PasswordResetService().requestCode(email: normalizedEmail)
            passwordResetEmail = normalizedEmail.lowercased()
            passwordResetRefCode = refCode
            showingPasswordReset = true
        } catch { showError(error.localizedDescription) }
    }

    private func loadSavedAccounts() {
        do {
            if let data = try credentials.savedAccountsData() {
                savedAccounts = try JSONDecoder().decode([SavedAccount].self, from: data)
            }
        } catch { showError(error.localizedDescription) }
    }
    
    private func saveAccount() {
        var accounts = savedAccounts
        accounts.removeAll(where: { $0.email == email })
        let currentToken = APIService.shared.authToken ?? ""
        let currentRole = APIService.shared.userRole
        let currentAdminID = UserDefaults.standard.integer(forKey: "adminID")
        accounts.insert(
            SavedAccount(
                name: userName,
                email: email,
                token: currentToken,
                role: currentRole,
                adminID: currentAdminID > 0 ? currentAdminID : nil
            ),
            at: 0
        )
        
        if accounts.count > 5 {
            accounts = Array(accounts.prefix(5))
        }
        
        do {
            try credentials.setSavedAccountsData(JSONEncoder().encode(accounts))
            savedAccounts = accounts
        } catch { showError(error.localizedDescription) }
    }
    
    private func clearSavedAccounts() {
        do {
            try credentials.setSavedAccountsData(nil)
            savedAccounts = []
        } catch { showError(error.localizedDescription) }
    }

    private func selectSavedAccount(_ account: SavedAccount) {
        email = account.email
        password = ""
        name = account.name
        isSignUpMode = false
        isForgotPasswordMode = false
        errorMessage = nil
        confirmPassword = ""
        isConfirmPasswordVisible = false

        guard let token = account.token, !token.isEmpty else {
            showError("ไม่พบเซสชันที่บันทึกไว้ กรุณาเข้าสู่ระบบใหม่")
            return
        }
        guard APIService.shared.localSessionAccountID(token: token) != nil else {
            showError(CredentialError.expiredSession.localizedDescription)
            return
        }

        if securityTokenEnabled {
            pendingSavedAccount = account
            passcodeInput = ""
            passcodeError = nil
            isVerifyingPasscode = false
            withAnimation(.spring(response: 0.38, dampingFraction: 0.8)) {
                showingPasscodeModal = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isPasscodeFocused = true
            }
        } else {
            do {
                try restoreSavedAccount(account, token: token)
                completeLoginTransition()
            } catch { showError(error.localizedDescription) }
        }
    }

    private func restoreSavedAccount(_ account: SavedAccount, token: String) throws {
        if let adminID = account.adminID, adminID > 0 {
            UserDefaults.standard.set(adminID, forKey: "adminID")
        }
        try APIService.shared.restoreSession(token: token, email: account.email, fallbackRole: account.role)
        userEmail = account.email
        userName = account.name.isEmpty ? String(account.email.split(separator: "@").first ?? "ผู้ใช้") : account.name
    }

    private func completeLoginTransition(shouldSaveAccount: Bool = true) {
        withAnimation(.easeOut(duration: 0.3)) {
            isScreenReady = false
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.easeInOut(duration: 0.6)) {
                isLoggedIn = true
                if shouldSaveAccount {
                    saveAccount()
                }
            }
        }
    }
    
    private func verifyPasscode() {
        guard !isVerifyingPasscode else { return }

        let isValid: Bool
        do { isValid = try credentials.verifyPasscode(passcodeInput) }
        catch {
            passcodeError = error.localizedDescription
            passcodeInput = ""
            return
        }
        if isValid {
            isVerifyingPasscode = true
            isPasscodeFocused = false
            withAnimation(.easeInOut(duration: 0.2)) {
                showingPasscodeModal = false
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                if let account = pendingSavedAccount, let token = account.token, !token.isEmpty {
                    do { try restoreSavedAccount(account, token: token) }
                    catch {
                        isVerifyingPasscode = false
                        showError(error.localizedDescription)
                        return
                    }
                    pendingSavedAccount = nil
                }

                completeLoginTransition()
            }
        } else {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                passcodeError = "รหัสยืนยัน 6 หลักไม่ถูกต้อง"
                passcodeInput = ""
            }
        }
    }
}

struct SavedAccount: Identifiable, Codable {
    var id: String { email }
    let name: String
    let email: String
    var token: String?
    var role: String?
    var adminID: Int?
}
