import SwiftUI

struct PasswordResetView: View {
    let email: String
    @State var refCode: String?
    let onComplete: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var code = ""
    @State private var password = ""
    @State private var confirmation = ""
    @State private var isBusy = false
    @State private var errorMessage: String?
    @State private var requestMessage = "หากอีเมลนี้อยู่ในระบบ คุณจะได้รับรหัสยืนยันทางอีเมล"
    @State private var nextRequestAt = Date().addingTimeInterval(60)

    var body: some View {
        NavigationStack {
            Form {
                Section("บัญชี") {
                    Text(email)
                        .textSelection(.enabled)
                        .foregroundStyle(.secondary)
                }
                Section("รหัสยืนยันจากอีเมล") {
                    TextField("รหัสยืนยัน 6 หลัก", text: $code)
                        .keyboardType(.numberPad)
                        .textContentType(.oneTimeCode)
                        .onChange(of: code) { _, value in
                            code = String(value.filter { $0.isASCII && $0.isNumber }.prefix(6))
                        }
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        let remaining = max(0, Int(ceil(nextRequestAt.timeIntervalSince(context.date))))
                        Button {
                            Task { await resend() }
                        } label: {
                            Label(remaining > 0 ? "ขอรหัสใหม่ใน \(remaining) วินาที" : "ขอรหัสใหม่", systemImage: "arrow.clockwise")
                        }
                        .disabled(isBusy || remaining > 0)
                    }
                    if let code = refCode {
                        Text("หมายเลขอ้างอิง: \(code)")
                            .font(.custom("SukhumvitSet-SemiBold", size: 14))
                            .foregroundStyle(.primary)
                            .padding(.top, 4)
                    }
                    Text(requestMessage)
                        .font(.custom("SukhumvitSet-Medium", size: 14))
                        .foregroundStyle(.secondary)
                }
                Section("รหัสผ่านใหม่") {
                    SecureField("รหัสผ่านใหม่อย่างน้อย 8 ตัวอักษร", text: $password)
                        .textContentType(.newPassword)
                    SecureField("ยืนยันรหัสผ่านใหม่", text: $confirmation)
                        .textContentType(.newPassword)
                }
                if let errorMessage {
                    Section {
                        Label(errorMessage, systemImage: "exclamationmark.circle")
                            .foregroundStyle(.red)
                    }
                }
                Section {
                    Button {
                        Task { await reset() }
                    } label: {
                        HStack {
                            Spacer()
                            if isBusy { ProgressView() }
                            Text(isBusy ? "กำลังดำเนินการ" : "บันทึกรหัสผ่านใหม่")
                            Spacer()
                        }
                    }
                    .disabled(isBusy || code.count != 6 || password.count < 8 || confirmation.isEmpty)
                }
            }
            .font(.custom("SukhumvitSet-Medium", size: 16))
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("ตั้งรหัสผ่านใหม่")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("ยกเลิก") { dismiss() }
                        .disabled(isBusy)
                }
            }
            .interactiveDismissDisabled(isBusy)
        }
    }

    private func resend() async {
        guard !isBusy else { return }
        isBusy = true
        errorMessage = nil
        defer { isBusy = false }
        do {
            let ref = try await PasswordResetService().requestCode(email: email)
            if let ref = ref {
                self.refCode = ref
            }
            nextRequestAt = Date().addingTimeInterval(60)
            requestMessage = "ส่งคำขอรหัสใหม่แล้ว หากมีบัญชีนี้ในระบบ กรุณาตรวจสอบอีเมล"
        } catch { errorMessage = error.localizedDescription }
    }

    private func reset() async {
        guard !isBusy else { return }
        guard password == confirmation else {
            errorMessage = "รหัสผ่านและการยืนยันรหัสผ่านไม่ตรงกัน"
            return
        }
        isBusy = true
        errorMessage = nil
        defer { isBusy = false }
        do {
            try await PasswordResetService().reset(email: email, code: code, password: password)
            password = ""
            confirmation = ""
            code = ""
            onComplete()
            dismiss()
        } catch { errorMessage = error.localizedDescription }
    }
}
