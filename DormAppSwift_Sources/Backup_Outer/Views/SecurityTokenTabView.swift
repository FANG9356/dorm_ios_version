import SwiftUI

struct SecurityTokenTabView: View {
    @AppStorage("securityTokenEnabled") var securityTokenEnabled: Bool = false
    @AppStorage("securityPasscode") var securityPasscode: String = "123456"
    
    @State private var customCode: String = ""
    @State private var showCustomInput: Bool = false
    @State private var alertMessage: String? = nil
    @State private var showAlert: Bool = false
    @FocusState private var isCustomInputFocused: Bool
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Fixed non-scrollable content area
                VStack(spacing: 16) {
                    
                    // Header Card
                    GlassCard {
                        HStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(LinearGradient(colors: [.indigo, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                                    .frame(width: 54, height: 54)
                                Image(systemName: "lock.shield.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(.white)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("โทเคนยืนยันการเข้าสู่ระบบ")
                                    .font(.custom("SukhumvitSet-Bold", size: 18))
                                    .foregroundColor(.primary)
                                Text("เพิ่มความปลอดภัยด้วยรหัสผ่าน 6 หลัก หลังกดปุ่ม Sign In")
                                    .font(.custom("SukhumvitSet-Medium", size: 13))
                                    .foregroundColor(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .padding(16)
                    }
                    
                    // Enable/Disable Toggle — fixed height so toggling doesn't shift layout
                    GlassCard {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("เปิดใช้งานรหัสผ่าน 6 หลัก")
                                    .font(.custom("SukhumvitSet-Bold", size: 16))
                                    .foregroundColor(.primary)
                                Text(securityTokenEnabled ? "เปิดใช้งานอยู่" : "ปิดการใช้งานอยู่")
                                    .font(.custom("SukhumvitSet-Medium", size: 13))
                                    .foregroundColor(securityTokenEnabled ? .green : .secondary)
                            }
                            Spacer()
                            Toggle("", isOn: $securityTokenEnabled.animation(.easeInOut))
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
                                Text("รหัสยืนยัน 6 หลักปัจจุบัน")
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
                                            securityPasscode = customCode
                                            isCustomInputFocused = false
                                            showAlertMessage("บันทึกรหัสผ่าน 6 หลักเรียบร้อยแล้ว")
                                            withAnimation(.easeInOut(duration: 0.2)) { showCustomInput = false }
                                        } else {
                                            showAlertMessage("กรุณากรอกตัวเลขให้ครบ 6 หลัก")
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
                .padding(.horizontal, 20)
                .padding(.top, 110)
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
            // Intercept scroll gestures so page cannot be dragged
            .gesture(DragGesture().onChanged { _ in })
            
            // Ultra-Sleek Floating Top Toast Banner
            if showAlert {
                VStack {
                    HStack(spacing: 12) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.indigo)
                        
                        Text(alertMessage ?? "")
                            .font(.custom("SukhumvitSet-Bold", size: 14))
                            .foregroundColor(.primary)
                            .lineLimit(2)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                    .background(.regularMaterial)
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(
                                LinearGradient(colors: [.indigo.opacity(0.6), .purple.opacity(0.3)], startPoint: .leading, endPoint: .trailing),
                                lineWidth: 1.5
                            )
                    )
                    .shadow(color: .indigo.opacity(0.25), radius: 15, x: 0, y: 8)
                    .padding(.top, 60)
                    
                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .onTapGesture {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        showAlert = false
                    }
                }
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: showAlert)
    }
    
    private func showAlertMessage(_ msg: String) {
        alertMessage = msg
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
            showAlert = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                if alertMessage == msg {
                    showAlert = false
                }
            }
        }
    }
    
    private func generateRandomPasscode() {
        let newCode = String((0..<6).map { _ in Int.random(in: 0...9) }.map(String.init).joined())
        securityPasscode = newCode
        showAlertMessage("สุ่มรหัสผ่านใหม่เรียบร้อยแล้ว: \(newCode)")
    }
}
