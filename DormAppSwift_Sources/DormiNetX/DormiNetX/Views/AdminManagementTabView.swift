import SwiftUI
import PhotosUI

struct AdminManagementTabView: View {
    @State private var admins: [Admin] = []
    @State private var isLoading = true
    @State private var errorMessage: String? = nil
    
    // For Add/Edit Modal
    @State private var showingAddAdmin = false
    @State private var editingAdmin: Admin? = nil
    @State private var newAdminName = ""
    @State private var newAdminEmail = ""
    @State private var newAdminPassword = ""
    @State private var isSubmitting = false
    
    var body: some View {
        VStack(spacing: 20) {
            
            // Header actions & Summary
            HStack {
                // Left side: Summary
                VStack(alignment: .leading, spacing: 4) {
                    Text("บัญชีที่เข้าถึงระบบได้")
                        .font(.custom("SukhumvitSet-Bold", size: 18))
                        .foregroundColor(.primary)
                    Text("ดูแลสิทธิ์และข้อมูลเข้าสู่ระบบของผู้ใช้งาน \(admins.count) บัญชี")
                        .font(.custom("SukhumvitSet-Medium", size: 14))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: {
                    showingAddAdmin = true
                }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("เพิ่มผู้ดูแลระบบ")
                            .font(.custom("SukhumvitSet-Bold", size: 14))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(LinearGradient(colors: [.indigo, .purple], startPoint: .leading, endPoint: .trailing))
                    .clipShape(Capsule())
                    .shadow(color: .indigo.opacity(0.3), radius: 5, x: 0, y: 3)
                }
                .buttonStyle(PressableButtonStyle())
            }
            .padding(.top, 20)
            
            if let error = errorMessage {
                Text(error)
                    .font(.custom("SukhumvitSet-Medium", size: 14))
                    .foregroundColor(.red)
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(10)
            }
            
            if isLoading && admins.isEmpty {
                Spacer()
                ProgressView()
                    .scaleEffect(1.5)
                Spacer()
            } else {
                LazyVStack(spacing: 15) {
                    ForEach(admins) { admin in
                        AdminRow(admin: admin, onDelete: {
                            deleteAdmin(adminID: admin.id)
                        }, onEdit: {
                            editingAdmin = admin
                        }, onImageUpdate: {
                            Task { await loadAdmins(showLoadingSpinner: false) }
                        })
                        .transition(.scale(scale: 0.95).combined(with: .opacity))
                    }
                }
                .padding(.bottom, 20)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 70) // To clear floating header
        .onAppear {
            Task {
                await loadAdmins(showLoadingSpinner: admins.isEmpty)
            }
        }
        .sheet(isPresented: $showingAddAdmin) {
            AddAdminSheet(isPresented: $showingAddAdmin, onSuccess: {
                Task {
                    await loadAdmins(showLoadingSpinner: false)
                }
            })
            .iphoneSheetStyle()
        }
        .sheet(item: $editingAdmin) { admin in
            EditAdminSheet(admin: admin, onSuccess: {
                Task { await loadAdmins(showLoadingSpinner: false) }
            })
            .iphoneFullSheetStyle()
        }
    }
    
    private func loadAdmins(showLoadingSpinner: Bool = false) async {
        if showLoadingSpinner {
            isLoading = true
        }
        errorMessage = nil
        do {
            let fetchedAdmins = try await APIService.shared.fetchAdmins()
            withAnimation(.easeInOut(duration: 0.25)) {
                admins = fetchedAdmins
            }
        } catch {
            errorMessage = "ไม่สามารถดึงข้อมูลได้: \(error.localizedDescription)"
        }
        isLoading = false
    }
    
    private func deleteAdmin(adminID: Int) {
        Task {
            do {
                let success = try await APIService.shared.deleteAdmin(id: adminID)
                if success {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        admins.removeAll { $0.id == adminID }
                    }
                } else {
                    errorMessage = "ลบข้อมูลไม่สำเร็จ"
                }
            } catch {
                errorMessage = "เกิดข้อผิดพลาดในการลบ: \(error.localizedDescription)"
            }
        }
    }
}

struct AdminRow: View {
    let admin: Admin
    let onDelete: () -> Void
    let onEdit: () -> Void
    let onImageUpdate: () -> Void
    
    @State private var showDeleteConfirm = false
    
    var body: some View {
        GlassCard {
            HStack(spacing: 15) {
                ProfileImageView(admin: admin, size: 50, onImageUpdate: onImageUpdate)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(admin.username)
                        .font(.custom("SukhumvitSet-Bold", size: 18))
                        .foregroundColor(.primary)
                    
                    HStack {
                        Image(systemName: "envelope.fill")
                            .font(.system(size: 10))
                        Text(admin.email)
                            .font(.custom("SukhumvitSet-Text", size: 13))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .foregroundColor(.secondary)
                }
                .contentShape(Rectangle()) // Make the whole area tappable
                .onTapGesture {
                    onEdit()
                }
                
                Spacer()
                
                // Actions (No longer showing Super Admin badge)
                Button(action: {
                    showDeleteConfirm = true
                }) {
                    Image(systemName: "trash.fill")
                        .foregroundColor(.red.opacity(0.8))
                        .padding(10)
                        .background(Color.red.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(PressableButtonStyle())
                .alert("ยืนยันการลบ", isPresented: $showDeleteConfirm) {
                    Button("ยกเลิก", role: .cancel) { }
                    Button("ลบข้อมูล", role: .destructive) {
                        onDelete()
                    }
                } message: {
                    Text("คุณแน่ใจหรือไม่ว่าต้องการลบบัญชี \(admin.username)?")
                }
            }
        }
    }
}

struct AddAdminSheet: View {
    @Binding var isPresented: Bool
    var onSuccess: () -> Void
    
    @State private var name = ""
    @State private var primaryEmail = ""
    @State private var backupEmail = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    
    @AppStorage("userEmail") var userEmail: String = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("ข้อมูลผู้ดูแลระบบ").font(.custom("SukhumvitSet-Medium", size: 13))) {
                    TextField("ชื่อผู้ดูแลระบบ", text: $name)
                        .font(.custom("SukhumvitSet-Text", size: 16))
                        .autocapitalization(.none)
                        .limitedText($name, maxLength: 60, trimNewlines: true)
                    
                    TextField("อีเมลหลัก", text: $primaryEmail)
                        .font(.custom("SukhumvitSet-Text", size: 16))
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .normalizedEmail($primaryEmail)
                        .disabled(true)
                        .foregroundColor(.secondary)
                    
                    TextField("อีเมลสำหรับผู้ดูแล", text: $backupEmail)
                        .font(.custom("SukhumvitSet-Text", size: 16))
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .normalizedEmail($backupEmail)
                    
                    SecureField("รหัสผ่านชั่วคราว", text: $password)
                        .font(.custom("SukhumvitSet-Text", size: 16))
                        .limitedText($password, maxLength: 64, trimNewlines: true)
                        
                    LabeledContent("สิทธิ์การใช้งาน", value: "ผู้ดูแลทั่วไป")
                        .font(.custom("SukhumvitSet-Text", size: 16))
                }
                
                if let error = errorMessage {
                    Section {
                        Text(error)
                            .font(.custom("SukhumvitSet-Medium", size: 14))
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("เพิ่มผู้ดูแลระบบใหม่")
            .navigationBarTitleDisplayMode(.inline)
            .dismissKeyboardOnTap()
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("ยกเลิก") {
                        isPresented = false
                    }
                    .font(.custom("SukhumvitSet-Bold", size: 16))
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("บันทึก") {
                        Task {
                            await submit()
                        }
                    }
                    .font(.custom("SukhumvitSet-Bold", size: 16))
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                              backupEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                              password.isEmpty || isLoading)
                }
            }
            .overlay(
                Group {
                    if isLoading {
                        Color.black.opacity(0.2).ignoresSafeArea()
                        ProgressView()
                            .scaleEffect(1.5)
                    }
                }
            )
            .onAppear {
                primaryEmail = userEmail
            }
        }
    }
    
    private func submit() async {
        isLoading = true
        errorMessage = nil
        
        do {
            try await APIService.shared.createStaff(
                username: name,
                recoveryEmail: backupEmail,
                temporaryPassword: password
            )
            onSuccess()
            isPresented = false
        } catch {
            errorMessage = "เกิดข้อผิดพลาด: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
}

struct EditAdminSheet: View {
    @Environment(\.dismiss) var dismiss
    let admin: Admin
    var onSuccess: () -> Void
    
    @State private var username = ""
    @State private var email = ""
    @State private var backupEmail = ""
    @State private var oldPassword = ""
    @State private var newPassword = ""
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    HStack {
                        Spacer()
                        ProfileImageView(admin: admin, size: 100)
                            .padding(.vertical, 10)
                        Spacer()
                    }
                }
                .listRowBackground(Color.clear)
                
                Section(header: Text("ข้อมูลบัญชี")) {
                    TextField("ชื่อผู้ดูแลระบบ", text: $username)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .limitedText($username, maxLength: 60, trimNewlines: true)
                    
                    TextField("อีเมลหลัก", text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .normalizedEmail($email)
                        .disabled(true)
                        .foregroundColor(.secondary)
                    
                    TextField("อีเมลสำรอง (ไม่บังคับ)", text: $backupEmail)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .foregroundColor(.secondary)
                        .normalizedEmail($backupEmail)
                }
                
                Section(header: Text("เปลี่ยนรหัสผ่าน"), footer: Text("หากไม่ต้องการเปลี่ยนรหัสผ่าน ให้เว้นว่างไว้")) {
                    SecureField("รหัสผ่านเดิม", text: $oldPassword)
                        .limitedText($oldPassword, maxLength: 64, trimNewlines: true)
                    SecureField("รหัสผ่านใหม่", text: $newPassword)
                        .limitedText($newPassword, maxLength: 64, trimNewlines: true)
                }
                
                if let errorMessage = errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.custom("SukhumvitSet-Medium", size: 14))
                    }
                }
            }
            .navigationTitle("แก้ไขข้อมูล")
            .navigationBarTitleDisplayMode(.inline)
            .dismissKeyboardOnTap()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("ยกเลิก") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: {
                        Task { await submit() }
                    }) {
                        if isLoading {
                            ProgressView()
                        } else {
                            Text("บันทึก")
                                .bold()
                        }
                    }
                    .disabled(isLoading || username.isEmpty || email.isEmpty)
                }
            }
            .onAppear {
                username = admin.username
                email = admin.email
                backupEmail = admin.backup_email ?? ""
            }
            .onTapGesture {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
        }
    }
    
    private func submit() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let success = try await APIService.shared.updateAdmin(id: admin.id, username: username, email: email, backupEmail: backupEmail, oldPassword: oldPassword.isEmpty ? nil : oldPassword, newPassword: newPassword.isEmpty ? nil : newPassword)
            if success {
                onSuccess()
                dismiss()
            } else {
                errorMessage = "การแก้ไขข้อมูลล้มเหลว"
            }
        } catch {
            errorMessage = "เกิดข้อผิดพลาด: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
}

struct ProfileImageView: View {
    let admin: Admin
    let size: CGFloat
    var onImageUpdate: (() -> Void)? = nil
    
    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var profileImage: Image? = nil
    @State private var isUploading = false
    
    var fallbackAvatar: some View {
        Circle()
            .fill(LinearGradient(colors: [.blue, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing))
            .frame(width: size, height: size)
            .overlay(
                Text(String(admin.username.prefix(1)).uppercased())
                    .font(.custom("SukhumvitSet-Bold", size: size * 0.4))
                    .foregroundColor(.white)
            )
    }
    
    var body: some View {
        PhotosPicker(selection: $selectedItem, matching: .images, photoLibrary: .shared()) {
            ZStack {
                if let profileImage = profileImage {
                    profileImage
                        .resizable()
                        .scaledToFill()
                        .frame(width: size, height: size)
                        .clipShape(Circle())
                } else if let localURL = APIService.shared.getLocalProfileImageURL(adminID: admin.id) {
                    if let uiImage = UIImage(contentsOfFile: localURL.path) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: size, height: size)
                            .clipShape(Circle())
                    } else {
                        fallbackAvatar
                    }
                } else {
                    fallbackAvatar
                }
                
                if isUploading {
                    Circle()
                        .fill(Color.black.opacity(0.5))
                        .frame(width: size, height: size)
                    ProgressView()
                        .tint(.white)
                } else {
                    // Small edit badge
                    Circle()
                        .fill(Color.white)
                        .frame(width: size * 0.32, height: size * 0.32)
                        .shadow(radius: 2)
                        .overlay(
                            Image(systemName: "pencil")
                                .font(.system(size: size * 0.18, weight: .bold))
                                .foregroundColor(.blue)
                        )
                        .offset(x: size * 0.34, y: size * 0.34)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isUploading)
        .onChange(of: selectedItem) { _, newItem in
            Task {
                guard let data = try? await newItem?.loadTransferable(type: Data.self) else { return }
                guard let uiImage = UIImage(data: data) else { return }
                profileImage = Image(uiImage: uiImage)
                isUploading = true
                do {
                    let success = try await APIService.shared.saveProfileImageLocally(adminID: admin.id, imageData: data)
                    if success {
                        onImageUpdate?()
                    }
                } catch {
                    print("Upload failed: \(error)")
                }
                isUploading = false
            }
        }
    }
}
