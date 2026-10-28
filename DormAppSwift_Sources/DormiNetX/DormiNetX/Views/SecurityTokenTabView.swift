import SwiftUI

struct SecurityTokenTabView: View {
    @AppStorage("securityTokenEnabled") var securityTokenEnabled: Bool = false
    @ObservedObject private var credentials = CredentialStore.shared
    private var securityPasscode: String { credentials.passcode ?? "" }
    
    @State private var customCode: String = ""
    @State private var showCustomInput: Bool = false
    @State private var errorMessage: String = ""
    @State private var showErrorAlert: Bool = false
    @FocusState private var isCustomInputFocused: Bool
    
    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 18) {
                // Standard Settings Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("โทเคนเข้าสู่ระบบ")
                        .font(.custom("SukhumvitSet-Bold", size: 30))
                        .foregroundStyle(.primary)

                    Text("เพิ่มรหัสผ่าน 6 หลักอีกชั้นก่อนเข้าใช้งานระบบเพื่อความปลอดภัย")
                        .font(.custom("SukhumvitSet-Text", size: 13))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.bottom, 6)

                // Fixed non-scrollable content area
                VStack(spacing: 16) {
                    
                    // Enable/Disable Toggle — fixed height so toggling doesn't shift layout
                    GlassCard {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("ขอรหัสก่อนเข้าแอป")
                                    .font(.custom("SukhumvitSet-Bold", size: 16))
                                    .foregroundColor(.primary)
                                Text(securityTokenEnabled ? LocalizedStringKey("เปิดใช้งานอยู่") : LocalizedStringKey("ปิดการใช้งานอยู่"))
                                    .font(.custom("SukhumvitSet-Medium", size: 13))
                                    .foregroundColor(securityTokenEnabled ? .green : .secondary)
                            }
                            Spacer()
                            Toggle("", isOn: Binding(get: { securityTokenEnabled }, set: { enabled in
                                do {
                                    if enabled && securityPasscode.isEmpty {
                                        try credentials.setPasscode(String(format: "%06d", Int.random(in: 0...999999)))
                                    }
                                    securityTokenEnabled = enabled
                                } catch { 
                                        errorMessage = error.localizedDescription
                                        showErrorAlert = true
                                    }
                            }))
                                .tint(.indigo)
                                .labelsHidden()
                        }
                        .frame(height: 52)
                        .padding(.horizontal, 16)
                    }
                    
                    // Passcode Display & Management Card — only visible when enabled
                    if securityTokenEnabled {
                        GlassCard {
                            VStack(spacing: 20) {
                                Text("รหัสที่ใช้อยู่ตอนนี้")
                                    .font(.custom("SukhumvitSet-Bold", size: 15))
                                    .foregroundColor(.secondary)
                                
                                HStack(spacing: 8) {
                                    ForEach(0..<6, id: \.self) { index in
                                        let char = index < securityPasscode.count ? String(Array(securityPasscode)[index]) : "-"
                                        Text(char)
                                            .font(.custom("SukhumvitSet-Bold", size: 24))
                                            .foregroundColor(.indigo)
                                            .frame(width: 44, height: 52)
                                            .background(Color.indigo.opacity(0.1))
                                            .cornerRadius(12)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .stroke(Color.indigo.opacity(0.3), lineWidth: 1)
                                            )
                                    }
                                }
                                
                                Divider()
                                
                                HStack(spacing: 12) {
                                    Button(action: generateRandomPasscode) {
                                        HStack {
                                            Image(systemName: "shuffle")
                                            Text("สุ่มรหัสผ่านใหม่")
                                                .font(.custom("SukhumvitSet-Bold", size: 14))
                                        }
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .background(Color.indigo)
                                        .cornerRadius(10)
                                    }
                                    .buttonStyle(PressableButtonStyle())
                                    
                                    Button(action: {
                                        customCode = securityPasscode
                                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { showCustomInput = true }
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                            isCustomInputFocused = true
                                        }
                                    }) {
                                        HStack {
                                            Image(systemName: "pencil")
                                            Text("ตั้งค่ารหัสเอง")
                                                .font(.custom("SukhumvitSet-Bold", size: 14))
                                        }
                                        .foregroundColor(.indigo)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .background(Color.indigo.opacity(0.12))
                                        .cornerRadius(10)
                                    }
                                    .buttonStyle(PressableButtonStyle())
                                }
                            }
                            .padding(20)
                        }
                        .transition(.scale(scale: 0.95).combined(with: .opacity))
                    }
                    
                    // Custom Code Input Section
                    if showCustomInput && securityTokenEnabled {
                        GlassCard {
                            VStack(spacing: 16) {
                                Text("กำหนดรหัสผ่าน 6 หลัก")
                                    .font(.custom("SukhumvitSet-Bold", size: 16))
                                
                                ZStack {
                                    TextField("", text: $customCode)
                                        .keyboardType(.numberPad)
                                        .focused($isCustomInputFocused)
                                        .opacity(0.01)
                                        .onChange(of: customCode) { oldValue, newValue in
                                            let filtered = newValue.filter { $0.isNumber }
                                            customCode = String(filtered.prefix(6))
                                        }
                                    
                                    HStack(spacing: 8) {
                                        ForEach(0..<6, id: \.self) { index in
                                            let char = index < customCode.count ? String(Array(customCode)[index]) : ""
                                            Text(char)
                                                .font(.custom("SukhumvitSet-Bold", size: 24))
                                                .foregroundColor(.indigo)
                                                .frame(width: 44, height: 52)
                                                .background(Color.indigo.opacity(0.1))
                                                .cornerRadius(12)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 12)
                                                        .stroke(index == customCode.count ? Color.indigo : Color.indigo.opacity(0.3), lineWidth: index == customCode.count ? 2 : 1)
                                                )
                                        }
                                    }
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        isCustomInputFocused = true
                                    }
                                }
                                
                                HStack(spacing: 12) {
                                    Button("ยกเลิก") {
                                        isCustomInputFocused = false
                                        withAnimation(.easeInOut(duration: 0.2)) { showCustomInput = false }
                                    }
                                    .font(.custom("SukhumvitSet-Medium", size: 14))
                                    .foregroundColor(.secondary)
                                    
                                    Spacer()
                                    
                                    Button("บันทึก") {
                                        if customCode.count == 6 {
                                            do { 
                                                try credentials.setPasscode(customCode) 
                                            } catch { 
                                                errorMessage = error.localizedDescription
                                                showErrorAlert = true
                                                return 
                                            }
                                            isCustomInputFocused = false
                                            withAnimation(.easeInOut(duration: 0.2)) { showCustomInput = false }
                                        } else {
                                            errorMessage = String(localized: "กรุณากรอกตัวเลขให้ครบ 6 หลัก")
                                            showErrorAlert = true
                                        }
                                    }
                                    .font(.custom("SukhumvitSet-Bold", size: 14))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 8)
                                    .background(Color.indigo)
                                    .cornerRadius(8)
                                }
                            }
                            .padding(16)
                        }
                        .transition(.scale(scale: 0.95).combined(with: .opacity))
                    }
                    
                    Spacer()
                }
                .dismissKeyboardOnTap()
                .padding(.bottom, 20)
                .offset(y: isCustomInputFocused ? -330 : 0)
                .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isCustomInputFocused)
                .contentShape(Rectangle())
                .onTapGesture {
                    if isCustomInputFocused {
                        isCustomInputFocused = false
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.horizontal, 20)
            .padding(.top, 126)
            // Intercept scroll gestures so page cannot be dragged
            .gesture(DragGesture().onChanged { _ in })
        }
        .alert("เกิดข้อผิดพลาด", isPresented: $showErrorAlert) {
            Button("ตกลง", role: .cancel) { }
        } message: {
            Text(LocalizedStringKey(errorMessage))
        }
    }

    private func generateRandomPasscode() {
        let newCode = String((0..<6).map { _ in Int.random(in: 0...9) }.map(String.init).joined())
        do {
            try credentials.setPasscode(newCode)
        } catch { 
            errorMessage = error.localizedDescription
            showErrorAlert = true
        }
    }
}
