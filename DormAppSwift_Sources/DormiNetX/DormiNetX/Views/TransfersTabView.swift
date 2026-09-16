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
    @State private var ledgerErrorMessage: String?
    @State private var searchText = ""

    private var rooms: [Room] { allRooms.filter { !$0.isDeletedLocally } }
    private var paymentsWithEvidence: [Payment] {
        payments.filter { !$0.isDeletedLocally && (!$0.slipPath.isEmpty || !$0.slipPathArray.isEmpty) }
    }

    private var visiblePayments: [Payment] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return paymentsWithEvidence }
        return paymentsWithEvidence.filter { payment in
            let user = userFor(payment)
            let status = payment.paymentStatus == "paid" ? "ตรวจแล้ว อนุมัติ" : "รอตรวจ"
            let searchable = [
                payment.roomNumber,
                user.map { "\($0.prefix)\($0.firstName) \($0.lastName)" } ?? "",
                payment.month,
                AppDate.thaiMonth(payment.month),
                payment.method,
                status
            ].joined(separator: " ").lowercased()
            return searchable.contains(query)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("ตรวจสอบสลิป")
                .font(.custom("SukhumvitSet-Bold", size: 24))
            Text("อนุมัติ แก้ไข หรือส่งกลับรายการชำระเงินที่แนบหลักฐาน")
                .font(.custom("SukhumvitSet-Text", size: 12))
                .foregroundStyle(.secondary)

            ManagementSearchField(
                text: $searchText,
                placeholder: "ค้นหาห้อง, ชื่อลูกบ้าน, รอบบิล..."
            )

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
            } else if visiblePayments.isEmpty {
                GlassCard {
                    VStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 34))
                            .foregroundStyle(.secondary)
                        Text("ไม่พบหลักฐานการโอนที่ค้นหา")
                            .font(.custom("SukhumvitSet-Medium", size: 14))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 28)
                }
            } else {
                ForEach(visiblePayments) { payment in
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
                do {
                    payment.userId = draft.userId
                    payment.roomNumber = draft.roomNumber
                    payment.rentFee = draft.rentFee
                    payment.depositFee = draft.depositFee
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
                    _ = try PaymentLedger.recordUnrecordedBalance(for: payment, in: modelContext, source: "transfer-editor")
                    try modelContext.save()
                } catch {
                    modelContext.rollback()
                    throw error
                }
                Task { await SyncManager.shared.pushCurrentLocalState(modelContext: modelContext) }
            }
            .iphoneSheetStyle()
        }
        .alert("ไม่สามารถแก้ประวัติรับเงิน", isPresented: Binding(
            get: { ledgerErrorMessage != nil },
            set: { if !$0 { ledgerErrorMessage = nil } }
        )) {
            Button("ตกลง", role: .cancel) { ledgerErrorMessage = nil }
        } message: {
            Text(ledgerErrorMessage ?? "")
        }
    }

    private func approve(_ payment: Payment) {
        payment.paymentStatus = "paid"
        payment.paidAmount = payment.amount
        payment.paymentDate = currentDateString()
        payment.lastUpdated = Date()
        payment.isDirty = true
        do {
            _ = try PaymentLedger.recordUnrecordedBalance(for: payment, in: modelContext, source: "slip-approval")
            try modelContext.save()
            Task { await SyncManager.shared.pushCurrentLocalState(modelContext: modelContext) }
        } catch {
            modelContext.rollback()
            ledgerErrorMessage = error.localizedDescription
        }
    }

    private func reject(_ payment: Payment) {
        do {
            guard try PaymentLedger.recordedTotal(for: payment.id, in: modelContext) == 0 else {
                ledgerErrorMessage = "รายการนี้รับเงินและออกใบเสร็จแล้ว ต้องใช้ขั้นตอนคืนเงินหรือปรับยอดแทนการปฏิเสธสลิป"
                return
            }
        } catch {
            ledgerErrorMessage = error.localizedDescription
            return
        }
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
        AppDate.dateKey(from: Date())
    }

    private func userFor(_ payment: Payment) -> DormUser? {
        users.first { stableLocalUserID(for: $0) == payment.userId && payment.userId > 0 }
            ?? users.first { $0.roomNumber == payment.roomNumber }
    }
}

private struct TransferEvidenceRow: View {
    let payment: Payment
    let onApprove: () -> Void
    let onReject: () -> Void
    let onEdit: () -> Void
    @State private var showingSlipPreview = false
    @State private var previewIndex = 0

    var body: some View {
        GlassCard {
            VStack(spacing: 14) {
                HStack {
                    Image(systemName: "photo.fill")
                        .foregroundStyle(.teal)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("ห้อง \(payment.roomNumber)")
                            .font(.custom("SukhumvitSet-Bold", size: 15))
                        Text("รอบบิล \(AppDate.thaiMonth(payment.month))")
                            .font(.custom("SukhumvitSet-Text", size: 11))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(payment.paymentStatus == "paid" ? "ตรวจแล้ว" : "รอตรวจ")
                        .font(.custom("SukhumvitSet-Medium", size: 10))
                        .foregroundStyle(payment.paymentStatus == "paid" ? .green : .orange)
                }

                if !slipImages.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(Array(slipImages.enumerated()), id: \.offset) { index, image in
                                Button {
                                    previewIndex = index
                                    showingSlipPreview = true
                                } label: {
                                    ZStack(alignment: .bottomTrailing) {
                                        Image(uiImage: image)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: slipImages.count == 1 ? nil : 190, height: 170)
                                            .frame(maxWidth: slipImages.count == 1 ? .infinity : nil)
                                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                                            )

                                        Label(index == 0 ? "ดูเต็มจอ" : "\(index + 1)", systemImage: index == 0 ? "arrow.up.left.and.arrow.down.right" : "photo")
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
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
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
            if !slipImages.isEmpty {
                SlipPreviewView(images: slipImages, initialIndex: previewIndex)
            }
        }
    }

    private var evidenceLabel: String {
        if !slipImages.isEmpty { return "มีรูปสลิปแนบ \(slipImages.count) รูป" }
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

    private var slipImages: [UIImage] {
        var paths = payment.slipPathArray
        if !payment.slipPath.isEmpty && !paths.contains(payment.slipPath) {
            paths.insert(payment.slipPath, at: 0)
        }

        return paths.compactMap { path in
            guard let url = SlipImageManager.url(for: path),
                  FileManager.default.fileExists(atPath: url.path) else {
                return nil
            }
            return UIImage(contentsOfFile: url.path)
        }
    }
}

struct SlipPreviewView: View {
    let images: [UIImage]
    let initialIndex: Int
    @Environment(\.dismiss) private var dismiss
    @State private var selectedIndex: Int

    init(images: [UIImage], initialIndex: Int = 0) {
        self.images = images
        self.initialIndex = initialIndex
        _selectedIndex = State(initialValue: min(max(0, initialIndex), max(0, images.count - 1)))
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topTrailing) {
                Color.black.ignoresSafeArea()

                TabView(selection: $selectedIndex) {
                    ForEach(Array(images.enumerated()), id: \.offset) { index, image in
                        ScrollableSlipImage(image: image)
                            .padding(.top, proxy.safeAreaInsets.top + 62)
                            .padding(.bottom, proxy.safeAreaInsets.bottom + 24)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: images.count > 1 ? .automatic : .never))
                .frame(width: proxy.size.width, height: proxy.size.height)

                if images.count > 1 {
                    Text("\(selectedIndex + 1) / \(images.count)")
                        .font(.custom("SukhumvitSet-Bold", size: 13))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .frame(height: 34)
                        .background(.black.opacity(0.45), in: Capsule())
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, max(12, proxy.safeAreaInsets.top + 13))
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

struct ScrollableSlipImage: View {
    let image: UIImage
    @State private var scale: CGFloat = 1

    var body: some View {
        GeometryReader { proxy in
            ScrollView([.vertical, .horizontal], showsIndicators: true) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: max(1, proxy.size.width - 24))
                    .scaleEffect(scale, anchor: .top)
                    .frame(
                        width: max(1, (proxy.size.width - 24) * scale),
                        alignment: .top
                    )
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .gesture(
                        MagnificationGesture()
                            .onChanged { value in
                                scale = min(3.2, max(1, value))
                            }
                    )
                    .onTapGesture(count: 2) {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                            scale = scale > 1 ? 1 : 2
                        }
                    }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }
}
