import SwiftUI
import SwiftData
import UIKit

struct TransfersTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Payment.lastUpdated, order: .reverse) private var payments: [Payment]
    @Query(sort: \DormUser.roomNumber) private var users: [DormUser]
    @Query(sort: \Room.roomNumber) private var allRooms: [Room]
    @Query(sort: \RoomType.name) private var roomTypes: [RoomType]
    @State private var editingPayment: Payment?

    private var rooms: [Room] { allRooms.filter { !$0.isDeletedLocally } }
    private var paymentsWithEvidence: [Payment] {
        payments.filter { !$0.isDeletedLocally && (!$0.slipPath.isEmpty || !$0.slipPathArray.isEmpty) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("ตรวจสอบสลิป")
                .font(.custom("SukhumvitSet-Bold", size: 24))
            Text("อนุมัติ แก้ไข หรือส่งกลับรายการชำระเงินที่แนบหลักฐาน")
                .font(.custom("SukhumvitSet-Text", size: 12))
                .foregroundStyle(.secondary)

            if paymentsWithEvidence.isEmpty {
                GlassCard {
                    VStack(spacing: 12) {
                        Image(systemName: "photo.stack.fill")
                            .font(.system(size: 34))
                            .foregroundStyle(.secondary)
                        Text("ยังไม่มีหลักฐานการโอน")
                            .font(.custom("SukhumvitSet-Medium", size: 14))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 28)
                }
            } else {
                ForEach(paymentsWithEvidence) { payment in
                    TransferEvidenceRow(
                        payment: payment,
                        onApprove: { approve(payment) },
                        onReject: { reject(payment) },
                        onEdit: { editingPayment = payment }
                    )
                }
            }
        }
        .padding(.top, 106)
        .padding(.horizontal, 20)
        .sheet(item: $editingPayment) { payment in
            PaymentEditor(payment: payment, users: users, rooms: rooms, roomTypes: roomTypes, defaultMonth: payment.month) { draft in
                payment.userId = draft.userId
                payment.roomNumber = draft.roomNumber
                payment.rentFee = draft.rentFee
                payment.waterFee = draft.waterFee
                payment.electricFee = draft.electricFee
                payment.commonFee = draft.commonFee
                payment.lateFee = draft.lateFee
                payment.applianceFee = draft.applianceFee
                payment.amount = draft.amount
                payment.month = draft.month
                payment.paymentDate = draft.paymentDate
                payment.method = draft.method
                payment.slipPath = draft.slipPath
                payment.slipPathArray = draft.slipPathArray
                payment.dueDate = draft.dueDate
                payment.paymentStatus = draft.paymentStatus
                payment.paidAmount = draft.paidAmount
                payment.lastUpdated = Date()
                payment.isDirty = true
                saveAndPush()
            }
            .iphoneSheetStyle()
        }
    }

    private func approve(_ payment: Payment) {
        payment.paymentStatus = "paid"
        payment.paidAmount = payment.amount
        payment.paymentDate = currentDateString()
        payment.lastUpdated = Date()
        payment.isDirty = true
        saveAndPush()
    }

    private func reject(_ payment: Payment) {
        payment.paymentStatus = "pending"
        payment.paidAmount = 0
        payment.lastUpdated = Date()
        payment.isDirty = true
        saveAndPush()
    }

    private func saveAndPush() {
        do {
            try modelContext.save()
            Task {
                await SyncManager.shared.pushCurrentLocalState(modelContext: modelContext)
            }
        } catch {
            print("Transfer save error: \(error)")
        }
    }

    private func currentDateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
}

private struct TransferEvidenceRow: View {
    let payment: Payment
    let onApprove: () -> Void
    let onReject: () -> Void
    let onEdit: () -> Void
    @State private var showingSlipPreview = false

    var body: some View {
        GlassCard {
            VStack(spacing: 14) {
                HStack {
                    Image(systemName: "photo.fill")
                        .foregroundStyle(.teal)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("ห้อง \(payment.roomNumber)")
                            .font(.custom("SukhumvitSet-Bold", size: 15))
                        Text("รอบบิล \(payment.month)")
                            .font(.custom("SukhumvitSet-Text", size: 11))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(payment.paymentStatus == "paid" ? "ตรวจแล้ว" : "รอตรวจ")
                        .font(.custom("SukhumvitSet-Medium", size: 10))
                        .foregroundStyle(payment.paymentStatus == "paid" ? .green : .orange)
                }

                if let slipImage {
                    Button {
                        showingSlipPreview = true
                    } label: {
                        ZStack(alignment: .bottomTrailing) {
                            Image(uiImage: slipImage)
                                .resizable()
                                .scaledToFill()
                                .frame(maxWidth: .infinity)
                                .frame(height: 170)
                                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                                )

                            Label("ดูเต็มจอ", systemImage: "arrow.up.left.and.arrow.down.right")
                                .font(.custom("SukhumvitSet-Bold", size: 11))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(.black.opacity(0.46), in: Capsule())
                                .padding(10)
                        }
                    }
                    .buttonStyle(.plain)
                }

                HStack(spacing: 8) {
                    Text(evidenceLabel)
                        .font(.custom("SukhumvitSet-Text", size: 10))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Spacer()
                    evidenceAction("แก้ไข", icon: "pencil", color: .blue, action: onEdit)
                    evidenceAction("ปฏิเสธ", icon: "xmark", color: .orange, action: onReject)
                    evidenceAction("อนุมัติ", icon: "checkmark", color: .green, action: onApprove)
                }
            }
        }
        .fullScreenCover(isPresented: $showingSlipPreview) {
            if let slipImage {
                SlipPreviewView(image: slipImage)
            }
        }
    }

    private var evidenceLabel: String {
        if slipImage != nil { return "มีรูปสลิปแนบแล้ว" }
        if !payment.slipPath.isEmpty { return payment.slipPath }
        return "\(payment.slipPathArray.count) ไฟล์"
    }

    private func evidenceAction(_ title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.custom("SukhumvitSet-Bold", size: 11))
                .labelStyle(.titleAndIcon)
                .foregroundStyle(color)
                .padding(.horizontal, 9)
                .frame(height: 30)
                .background(color.opacity(0.12), in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private var slipImage: UIImage? {
        let path = payment.slipPath.isEmpty ? payment.slipPathArray.first ?? "" : payment.slipPath
        guard let url = SlipImageManager.url(for: path),
              FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }

        return UIImage(contentsOfFile: url.path)
    }
}

private struct SlipPreviewView: View {
    let image: UIImage
    @Environment(\.dismiss) private var dismiss
    @State private var scale: CGFloat = 1

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topTrailing) {
                Color.black.ignoresSafeArea()

                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .scaleEffect(scale)
                    .frame(
                        width: max(1, proxy.size.width - 32),
                        height: max(1, proxy.size.height - proxy.safeAreaInsets.top - proxy.safeAreaInsets.bottom - 64)
                    )
                    .position(
                        x: proxy.size.width / 2,
                        y: (proxy.size.height + proxy.safeAreaInsets.top - proxy.safeAreaInsets.bottom) / 2
                    )
                    .gesture(
                        MagnificationGesture()
                            .onChanged { value in
                                scale = min(3.5, max(1, value))
                            }
                    )
                    .onTapGesture(count: 2) {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                            scale = scale > 1 ? 1 : 2
                        }
                    }

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(.black.opacity(0.5), in: Circle())
                        .overlay(
                            Circle()
                                .stroke(.white.opacity(0.18), lineWidth: 1)
                        )
                }
                .padding(.top, max(12, proxy.safeAreaInsets.top + 8))
                .padding(.trailing, 18)
            }
        }
    }
}
