import SwiftUI
import SwiftData
import PhotosUI
import UIKit

struct FinanceTabView: View {
    @Binding var showingPaymentEditor: Bool
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Payment.lastUpdated, order: .reverse) private var allPayments: [Payment]
    @Query(sort: \DormUser.roomNumber) private var users: [DormUser]
    @Query(sort: \Room.roomNumber) private var allRooms: [Room]
    @Query(sort: \RoomType.name) private var roomTypes: [RoomType]
    @State private var selectedMonth = Date()
    @State private var selectedStatus = "ทั้งหมด"
    @State private var searchText = ""
    @State private var showingMonthPicker = false
    @State private var selectedBillingUser: DormUser?
    @State private var paymentEditTarget: PaymentEditTarget?
    @State private var pendingPaymentEditTarget: PaymentEditTarget?
    @State private var deletingPayment: Payment?
	@State private var lineResultMessage: String?
    @State private var paymentErrorMessage: String?

    private let statuses = ["ทั้งหมด", "ชำระแล้ว", "รอชำระ", "ชำระบางส่วน"]
    private var payments: [Payment] { allPayments.filter { !$0.isDeletedLocally } }
    private var rooms: [Room] { allRooms.filter { !$0.isDeletedLocally } }

    var body: some View {
        VStack(spacing: 16) {
            header
            summaryGrid
            filters
            billingUserList
        }
        .padding(.top, 106)
        .padding(.horizontal, 20)
        .padding(.bottom, 32)
        .sheet(isPresented: $showingMonthPicker) {
            FinanceMonthPicker(selection: $selectedMonth)
                .presentationDetents([.height(360)])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(32)
                .presentationBackground(.ultraThinMaterial)
        }
        .sheet(item: $selectedBillingUser, onDismiss: {
            guard let target = pendingPaymentEditTarget else { return }
            pendingPaymentEditTarget = nil
            paymentEditTarget = target
        }) { user in
            BillingHistorySheet(
                user: user,
                payments: paymentsFor(user),
                onIssueBill: { month in
                    pendingPaymentEditTarget = .draft(generatedPayment(for: user, month: month))
                    selectedBillingUser = nil
                },
                onEdit: { payment in
                    pendingPaymentEditTarget = .existing(payment)
                    selectedBillingUser = nil
                },
                onDelete: { payment in
                    selectedBillingUser = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        deletingPayment = payment
                    }
                },
                onMarkPaid: { payment in
                    markPaid(payment)
                },
                onSendLine: { payment in
					Task {
						await SyncManager.shared.pushCurrentLocalState(modelContext: modelContext, reason: "เตรียมส่งบิลผ่าน LINE")
						if case .failed(let message) = SyncManager.shared.state {
							lineResultMessage = "ซิงก์ข้อมูลก่อนส่ง LINE ไม่สำเร็จ: \(message)"
							return
						}
						do {
							let message = try await APIService.shared.sendLineInvoice(paymentID: payment.id)
							modelContext.insert(LocalSystemLog(action: "ส่งบิลผ่าน LINE", details: "ส่งบิลห้อง \(payment.roomNumber) รอบ \(payment.month) แล้ว"))
							try? modelContext.save()
							lineResultMessage = message
						} catch {
							lineResultMessage = error.localizedDescription
						}
					}
                }
            )
            .iphoneSheetStyle()
        }
        .sheet(item: $paymentEditTarget) { target in
            PaymentEditor(payment: target.payment, users: users, rooms: rooms, roomTypes: roomTypes, defaultMonth: target.payment.month.isEmpty ? monthKey : target.payment.month) { draft in
                do {
                    let ledgerSource: String
                    let ledgerPayment: Payment
                    switch target {
                    case .existing(let payment):
                        apply(draft, to: payment)
                        ledgerSource = "payment-editor"
                        ledgerPayment = payment
                        modelContext.insert(LocalSystemLog(action: "แก้ไขรายการชำระเงิน", details: "แก้ไขรายการห้อง \(payment.roomNumber) รอบ \(payment.month)"))
                    case .draft:
                        draft.lastUpdated = Date()
                        draft.isDirty = true
                        modelContext.insert(draft)
                        ledgerSource = "manual-invoice"
                        ledgerPayment = draft
                        modelContext.insert(LocalSystemLog(action: "ออกบิล", details: "ออกบิลห้อง \(draft.roomNumber) รอบ \(draft.month)"))
                    }
                    _ = try PaymentLedger.recordUnrecordedBalance(
                        for: ledgerPayment,
                        in: modelContext,
                        source: ledgerSource
                    )
                    try modelContext.save()
                } catch {
                    modelContext.rollback()
                    throw error
                }
                Task { await SyncManager.shared.pushCurrentLocalState(modelContext: modelContext) }
            }
            .iphoneSheetStyle()
        }
        .confirmationDialog("ลบรายการชำระเงินนี้หรือไม่", isPresented: deleteDialogBinding) {
            Button("ลบรายการห้อง \(deletingPayment?.roomNumber ?? "")", role: .destructive) {
                guard let payment = deletingPayment else { return }
                delete(payment)
                deletingPayment = nil
            }
            Button("ยกเลิก", role: .cancel) { }
        }
		.alert("การส่งบิลผ่าน LINE", isPresented: Binding(
			get: { lineResultMessage != nil },
			set: { if !$0 { lineResultMessage = nil } }
		)) {
			Button("ตกลง", role: .cancel) { lineResultMessage = nil }
		} message: {
			Text(lineResultMessage ?? "")
		}
        .alert("ดำเนินการกับบิลไม่ได้", isPresented: Binding(
            get: { paymentErrorMessage != nil },
            set: { if !$0 { paymentErrorMessage = nil } }
        )) {
            Button("ตกลง", role: .cancel) { paymentErrorMessage = nil }
        } message: {
            Text(paymentErrorMessage ?? "")
        }
        .onAppear {
            ensurePaymentsForSelectedMonth()
        }
        .onChange(of: selectedMonth) { _, _ in
            ensurePaymentsForSelectedMonth()
        }
        .onChange(of: showingPaymentEditor) { _, isShowing in
            if isShowing {
                showingPaymentEditor = false
            }
        }
    }

    private var deleteDialogBinding: Binding<Bool> {
        Binding(
            get: { deletingPayment != nil },
            set: { if !$0 { deletingPayment = nil } }
        )
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("สรุปยอดเดือนนี้")
                    .font(.custom("SukhumvitSet-Bold", size: 28))
                    .foregroundStyle(.primary)
                Text("ติดตามยอดรับแล้ว ค้างชำระ และรายการที่ต้องดูแล")
                    .font(.custom("SukhumvitSet-Text", size: 13))
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }

    private var summaryGrid: some View {
        let monthPayments = payments.filter { BillingCycle.normalizedMonthKey($0.month) == monthKey }
        let received = monthPayments.filter { $0.paymentStatus == "paid" }.reduce(0) { $0 + ($1.paidAmount ?? 0.0) }
        let pending = monthPayments.filter { $0.paymentStatus == "pending" }.reduce(0) { $0 + $1.amount }
        let partial = monthPayments.filter { $0.paymentStatus == "partial" }.reduce(0) { $0 + ($1.paidAmount ?? 0.0) }

        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            FinanceSummaryCard(title: "รับแล้ว", amount: received, color: .green, icon: "checkmark.circle.fill")
            FinanceSummaryCard(title: "ค้างชำระ", amount: pending, color: .orange, icon: "clock.fill")
            FinanceSummaryCard(title: "ชำระบางส่วน", amount: partial, color: .blue, icon: "circle.lefthalf.filled")
            FinanceSummaryCard(title: "รายการทั้งหมด", amount: Double(monthPayments.count), color: .indigo, icon: "list.bullet.rectangle.fill", isCount: true)
        }
    }

    private var filters: some View {
        FinanceFilterPanel(
            searchText: $searchText,
            selectedStatus: $selectedStatus,
            statuses: statuses,
            monthLabel: AppDate.thaiMonth(monthKey),
            onSelectMonth: { showingMonthPicker = true }
        )
    }

    private var paymentList: some View {
        let visiblePayments = payments.filter { payment in
            let matchesMonth = BillingCycle.normalizedMonthKey(payment.month) == monthKey
            let matchesStatus = selectedStatus == "ทั้งหมด" || statusLabel(for: payment) == selectedStatus
            let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let user = userFor(payment)
            let name = "\(user?.firstName ?? "") \(user?.lastName ?? "")".lowercased()
            let matchesSearch = query.isEmpty || payment.roomNumber.lowercased().contains(query) || name.contains(query)
            return matchesMonth && matchesStatus && matchesSearch
        }

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("รายการประจำเดือน")
                    .font(.custom("SukhumvitSet-Bold", size: 16))
                Spacer()
                Text("\(visiblePayments.count) รายการ")
                    .font(.custom("SukhumvitSet-Medium", size: 11))
                    .foregroundStyle(.secondary)
            }

            if visiblePayments.isEmpty {
                GlassCard {
                    VStack(spacing: 10) {
                        Image(systemName: "tray")
                            .font(.custom("SukhumvitSet-Medium", size: 30))
                            .foregroundStyle(.secondary)
                        Text("ยังไม่มีรายการตามตัวกรอง")
                            .font(.custom("SukhumvitSet-Medium", size: 14))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 22)
                }
            } else {
                ForEach(visiblePayments) { payment in
                    PaymentRow(
                        payment: payment,
                        user: userFor(payment),
                        status: statusLabel(for: payment),
                        onMarkPaid: { markPaid(payment) },
                        onEdit: { paymentEditTarget = .existing(payment) },
                        onDelete: { deletingPayment = payment }
                    )
                }
            }
        }
    }

    private var billingUserList: some View {
        let visibleUsers = usersForBilling.filter { user in
            let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let name = "\(user.prefix)\(user.firstName) \(user.lastName)".lowercased()
            let matchesSearch = query.isEmpty || user.roomNumber.lowercased().contains(query) || name.contains(query) || user.phone.lowercased().contains(query)
            let currentPayment = paymentFor(user, month: monthKey)
            let currentStatus = currentPayment.map(statusLabel) ?? "รอชำระ"
            let matchesStatus = selectedStatus == "ทั้งหมด" || currentStatus == selectedStatus
            return matchesSearch && matchesStatus
        }

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("ห้องที่ต้องติดตาม")
                    .font(.custom("SukhumvitSet-Bold", size: 16))
                Spacer()
                Text("\(visibleUsers.count) ห้อง")
                    .font(.custom("SukhumvitSet-Medium", size: 11))
                    .foregroundStyle(.secondary)
            }

            if visibleUsers.isEmpty {
                GlassCard {
                    VStack(spacing: 10) {
                        Image(systemName: "person.text.rectangle")
                            .font(.custom("SukhumvitSet-Medium", size: 30))
                            .foregroundStyle(.secondary)
                        Text(searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                             ? "ยังไม่มีลูกบ้านที่ต้องออกบิล"
                             : "ไม่พบรายการการเงินที่ค้นหา")
                            .font(.custom("SukhumvitSet-Medium", size: 14))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 22)
                }
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(visibleUsers) { user in
                        BillingUserCard(
                            user: user,
                            currentPayment: paymentFor(user, month: monthKey),
                            dueDay: dueDayText(for: user)
                        ) {
                            selectedBillingUser = user
                        }
                    }
                }
            }
        }
    }

    private var monthKey: String {
        AppDate.monthKey(from: selectedMonth)
    }

    private func userFor(_ payment: Payment) -> DormUser? {
        users.first { stableLocalUserID(for: $0) == payment.userId && payment.userId > 0 } ?? users.first { $0.roomNumber == payment.roomNumber }
    }

    private var usersForBilling: [DormUser] {
        users
            .filter {
                !$0.isDeletedLocally &&
                $0.status != "ย้ายออกแล้ว" &&
                !$0.roomNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
            .sorted { clean($0.roomNumber).localizedStandardCompare(clean($1.roomNumber)) == .orderedAscending }
    }

    private func paymentsFor(_ user: DormUser) -> [Payment] {
        payments.filter { isPayment($0, for: user) }
    }

    private func paymentFor(_ user: DormUser, month: String) -> Payment? {
        payments.first {
            isPayment($0, for: user) &&
            BillingCycle.normalizedMonthKey($0.month) == BillingCycle.normalizedMonthKey(month) &&
            $0.paymentPlan != "installment"
        }
    }

    private func isPayment(_ payment: Payment, for user: DormUser) -> Bool {
        if payment.userId > 0 {
            return stableLocalUserID(for: user) == payment.userId
        }
        return clean(payment.roomNumber) == clean(user.roomNumber)
    }

    private func dueDayText(for user: DormUser) -> String {
        let day = Int(String(user.moveInDate.suffix(2))) ?? 1
        return "ครบกำหนดวันที่ \(max(1, min(day, 31)))"
    }

    private func statusLabel(for payment: Payment) -> String {
        switch payment.paymentStatus {
        case "paid": return "ชำระแล้ว"
        case "partial": return "ชำระบางส่วน"
        default: return "รอชำระ"
        }
    }

    private func markPaid(_ payment: Payment) {
        payment.paymentStatus = "paid"
        payment.paidAmount = payment.amount
        payment.paymentDate = currentDateString()
        payment.lastUpdated = Date()
        payment.isDirty = true
        modelContext.insert(LocalSystemLog(action: "รับชำระเงิน", details: "รับชำระเต็มจำนวน ห้อง \(payment.roomNumber) รอบ \(payment.month)"))
        do {
            _ = try PaymentLedger.recordUnrecordedBalance(for: payment, in: modelContext, source: "quick-settlement")
            try modelContext.save()
            Task { await SyncManager.shared.pushCurrentLocalState(modelContext: modelContext) }
        } catch {
            modelContext.rollback()
            lineResultMessage = error.localizedDescription
        }
    }

    private func apply(_ draft: Payment, to payment: Payment) {
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
        payment.waterMeterPrev = draft.waterMeterPrev
        payment.waterMeterCurr = draft.waterMeterCurr
        payment.electricMeterPrev = draft.electricMeterPrev
        payment.electricMeterCurr = draft.electricMeterCurr
        payment.paymentPlan = draft.paymentPlan
        payment.installmentPhase = draft.installmentPhase
        payment.dueDate = draft.dueDate
        payment.paymentStatus = draft.paymentStatus
        payment.slipPathArray = draft.slipPathArray
        payment.paidAmount = draft.paidAmount
        payment.lastUpdated = Date()
        payment.isDirty = true
    }

    private func saveAndPush() {
        do {
            try modelContext.save()
            Task {
                await SyncManager.shared.pushCurrentLocalState(modelContext: modelContext)
            }
        } catch {
            print("Payment save error: \(error)")
        }
    }

    private func delete(_ payment: Payment) {
        do {
            try PaymentLedger.ensureInvoiceCanBeDeleted(payment, in: modelContext)
            payment.isDeletedLocally = true
            payment.isDirty = true
            payment.lastUpdated = Date()
            modelContext.insert(LocalSystemLog(action: "ลบรายการชำระเงิน", details: "ลบรายการห้อง \(payment.roomNumber) รอบ \(payment.month)"))
            try modelContext.save()
            Task { await SyncManager.shared.pushCurrentLocalState(modelContext: modelContext) }
        } catch {
            modelContext.rollback()
            paymentErrorMessage = error.localizedDescription
        }
    }

    private func ensurePaymentsForSelectedMonth() {
        let activeUsers = users.filter {
            !$0.isDeletedLocally &&
            !$0.roomNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            $0.status != "ย้ายออกแล้ว"
        }
        guard !activeUsers.isEmpty else { return }

        var didCreate = false
        for user in activeUsers {
            let hasMoveInInstallment = monthKey == moveInMonth(for: user) && payments.contains { payment in
                BillingCycle.normalizedMonthKey(payment.month) == monthKey &&
                payment.paymentPlan == "installment" &&
                isPayment(payment, for: user)
            }
            let hasRegularPayment = payments.contains { payment in
                BillingCycle.normalizedMonthKey(payment.month) == monthKey &&
                payment.paymentPlan != "installment" &&
                isPayment(payment, for: user)
            }

            guard shouldCreatePayment(for: user, month: monthKey),
                  !hasMoveInInstallment,
                  !hasRegularPayment else {
                continue
            }

            let payment = generatedPayment(for: user, month: monthKey)
            modelContext.insert(payment)
            do {
                _ = try PaymentLedger.recordUnrecordedBalance(for: payment, in: modelContext, source: "automatic-billing")
            } catch {
                modelContext.rollback()
                print("Payment ledger error: \(error)")
                return
            }
            modelContext.insert(LocalSystemLog(action: "สร้างรายการชำระอัตโนมัติ", details: "สร้างรายการห้อง \(payment.roomNumber) รอบ \(payment.month)"))
            didCreate = true
        }

        guard didCreate else { return }
        saveAndPush()
    }

    private func shouldCreatePayment(for user: DormUser, month: String) -> Bool {
        guard BillingCycle.date("\(month)-01") != nil,
              BillingCycle.date(user.moveInDate) != nil else { return false }
        if user.indefiniteContract != 1, !user.contractEndDate.isEmpty,
           let contractMonth = BillingCycle.normalizedMonthKey(String(user.contractEndDate.prefix(7))),
           month > contractMonth { return false }
        if user.status == "จอง" {
            return month == moveInMonth(for: user)
        }

        let moveInMonth = moveInMonth(for: user)
        guard !moveInMonth.isEmpty else { return true }
        return month >= moveInMonth
    }

    private func generatedPayment(for user: DormUser, month: String) -> Payment {
        let payment = Payment(month: month)
        let roomType = roomType(for: user)
        let rent = roomType?.price ?? 0
        let isBooking = user.status == "จอง"
        let isMoveInMonth = month == moveInMonth(for: user)
        let amount = PaymentAmounts.sum(isBooking ? [user.deposit] : [rent, isMoveInMonth ? user.deposit : 0])

        payment.userId = stableLocalUserID(for: user)
        payment.roomNumber = user.roomNumber
        payment.rentFee = isBooking ? 0 : rent
        payment.depositFee = isBooking || isMoveInMonth ? user.deposit : 0
        payment.waterFee = 0
        payment.electricFee = 0
        payment.commonFee = 0
        payment.lateFee = 0
        payment.applianceFee = 0
        payment.amount = amount
        payment.method = paymentMethodLabel(for: user)
        payment.slipPath = user.bookingSlips.first ?? ""
        payment.slipPathArray = user.bookingSlips
        payment.paymentPlan = isBooking ? "booking" : "monthly"
        payment.installmentPhase = user.installmentMonths
        payment.dueDate = BillingCycle.dueDateKey(month: month, moveInDate: user.moveInDate)
        payment.paymentStatus = inferredPaymentStatus(for: user, isMoveInMonth: isMoveInMonth)
        payment.paidAmount = payment.paymentStatus == "paid" ? amount : (payment.paymentStatus == "partial" ? user.installmentAmount : 0)
        payment.lastUpdated = Date()
        payment.isDirty = true
        return payment
    }

    private func inferredPaymentStatus(for user: DormUser, isMoveInMonth: Bool) -> String {
        guard isMoveInMonth else { return "pending" }
        if user.paymentMethod == "installment" { return "partial" }
        if user.paymentMethod == "full_payment" { return "paid" }
        return "pending"
    }

    private func paymentMethodLabel(for user: DormUser) -> String {
        let method = user.paymentMethod == "installment" ? "ผ่อนชำระ" : (user.paymentMethod == "full_payment" ? "ชำระเต็มจำนวน" : "รอระบุ")
        let channel = user.paymentChannel == "cash" ? "เงินสด" : (user.paymentChannel == "bank_transfer" ? "โอนผ่านธนาคาร" : "ยังไม่ได้ระบุช่องทาง")
        return "\(method) • \(channel)"
    }

    private func roomType(for user: DormUser) -> RoomType? {
        guard let room = rooms.first(where: { clean($0.roomNumber) == clean(user.roomNumber) }) else { return nil }
        return roomTypes.first { clean($0.name) == clean(room.roomType) }
    }

    private func moveInMonth(for user: DormUser) -> String {
        BillingCycle.normalizedMonthKey(String(user.moveInDate.prefix(7))) ?? ""
    }

    private func clean(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func currentDateString() -> String {
        AppDate.dateKey(from: Date())
    }
}

private struct FinanceFilterPanel: View {
    @Environment(\.colorScheme) private var colorScheme
    @Binding var searchText: String
    @Binding var selectedStatus: String
    let statuses: [String]
    let monthLabel: String
    let onSelectMonth: () -> Void
    @State private var dragX: CGFloat = 0
    @State private var isDraggingStatus = false
    @State private var hoveredStatus: String?
    @State private var statusFrames: [String: CGRect] = [:]

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.custom("SukhumvitSet-Medium", size: 15))
                    .foregroundStyle(.secondary)

                TextField("ค้นหาห้อง, ชื่อลูกบ้าน, เบอร์โทร...", text: $searchText)
                    .font(.custom("SukhumvitSet-Text", size: 14))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.custom("SukhumvitSet-Medium", size: 14))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("ล้างคำค้นหา")
                }
            }
            .padding(.horizontal, 14)
            .frame(height: 48)

            panelDivider

            Button(action: onSelectMonth) {
                HStack(spacing: 12) {
                    Image(systemName: "calendar")
                        .font(.custom("SukhumvitSet-SemiBold", size: 16))
                        .foregroundStyle(.secondary)
                    Text("รอบบิล")
                        .font(.custom("SukhumvitSet-Medium", size: 14))
                    Spacer()
                    Text(LocalizedStringKey(monthLabel))
                        .font(.custom("SukhumvitSet-Medium", size: 14))
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.custom("SukhumvitSet-SemiBold", size: 11))
                        .foregroundStyle(.secondary)
                }
                .foregroundStyle(.primary)
                .padding(.horizontal, 14)
                .frame(height: 48)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("เลือกรอบบิล \(monthLabel)")

            panelDivider

            HStack(spacing: 0) {
                ForEach(statuses, id: \.self) { status in
                    let isHovered = isDraggingStatus && hoveredStatus == status
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation(.easeInOut(duration: 0.22)) {
                            selectedStatus = status
                        }
                    } label: {
                        Text(LocalizedStringKey(status))
                            .font(.custom("SukhumvitSet-Bold", size: 13))
                            .foregroundStyle(selectedStatus == status ? Color.primary : Color.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.68)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity)
                            .background(
                                Capsule().fill(selectedStatus == status ? activeTabFill : Color.clear)
                            )
                            .overlay(
                                Capsule().stroke(selectedStatus == status ? activeTabBorder : Color.clear, lineWidth: 1)
                            )
                            .opacity(isHovered ? 0 : 1)
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selectedStatus == status ? .isSelected : [])
                    .background(
                        GeometryReader { geometry in
                            Color.clear
                                .onAppear {
                                    statusFrames[status] = geometry.frame(in: .named("FinanceStatusTabs"))
                                }
                                .onChange(of: geometry.frame(in: .named("FinanceStatusTabs"))) { _, frame in
                                    statusFrames[status] = frame
                                }
                        }
                    )
                }
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 6)
            .frame(height: 52)
            .coordinateSpace(name: "FinanceStatusTabs")
            .overlay {
                GeometryReader { geometry in
                    if isDraggingStatus, let hoveredStatus {
                        Text(LocalizedStringKey(hoveredStatus))
                            .font(.custom("SukhumvitSet-Bold", size: 12))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(.ultraThickMaterial)
                                    .shadow(color: .black.opacity(0.14), radius: 8, x: 0, y: 4)
                            )
                            .overlay(Capsule().stroke(activeTabBorder, lineWidth: 1))
                            .position(
                                x: min(max(dragX, 34), max(34, geometry.size.width - 34)),
                                y: geometry.size.height / 2
                            )
                            .animation(.interactiveSpring(response: 0.25, dampingFraction: 0.8), value: dragX)
                    }
                }
                .allowsHitTesting(false)
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 10, coordinateSpace: .named("FinanceStatusTabs"))
                    .onChanged { value in
                        isDraggingStatus = true
                        dragX = value.location.x
                        guard value.location.x >= 0,
                              let nearest = statusFrames.min(by: {
                                  abs($0.value.midX - value.location.x) < abs($1.value.midX - value.location.x)
                              }) else { return }
                        if hoveredStatus != nearest.key {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            hoveredStatus = nearest.key
                        }
                    }
                    .onEnded { _ in
                        if isDraggingStatus, let hoveredStatus {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                selectedStatus = hoveredStatus
                            }
                        }
                        isDraggingStatus = false
                        hoveredStatus = nil
                    }
            )
        }
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: colorScheme == .dark ? .black.opacity(0.08) : .clear, radius: 18, x: 0, y: 8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(colorScheme == .dark ? Color.primary.opacity(0.12) : Color.white.opacity(0.18), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var panelDivider: some View {
        Divider()
            .opacity(colorScheme == .dark ? 0.35 : 0.14)
            .padding(.horizontal, 12)
    }

    private var activeTabFill: Color {
        colorScheme == .dark ? Color.primary.opacity(0.10) : Color.white.opacity(0.46)
    }

    private var activeTabBorder: Color {
        colorScheme == .dark ? Color.primary.opacity(0.14) : Color.white.opacity(0.20)
    }
}

private struct FinanceMonthPicker: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selection: Date
    @State private var month: Int
    @State private var year: Int

    private static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Bangkok") ?? .current
        return calendar
    }

    private let monthNames = [
        "มกราคม", "กุมภาพันธ์", "มีนาคม", "เมษายน", "พฤษภาคม", "มิถุนายน",
        "กรกฎาคม", "สิงหาคม", "กันยายน", "ตุลาคม", "พฤศจิกายน", "ธันวาคม"
    ]

    init(selection: Binding<Date>) {
        _selection = selection
        let components = Self.calendar.dateComponents([.year, .month], from: selection.wrappedValue)
        _month = State(initialValue: components.month ?? 1)
        _year = State(initialValue: components.year ?? 2026)
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Button("ยกเลิก") { dismiss() }
                    .font(.custom("SukhumvitSet-Medium", size: 15))

                Spacer()

                VStack(spacing: 2) {
                    Text("เลือกรอบบิล")
                        .font(.custom("SukhumvitSet-Bold", size: 17))
                    Text("\(monthNames[max(0, min(11, month - 1))]) \(year + 543)")
                        .font(.custom("SukhumvitSet-Text", size: 11))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button("เลือก") {
                    var components = DateComponents()
                    components.calendar = Self.calendar
                    components.timeZone = Self.calendar.timeZone
                    components.year = year
                    components.month = month
                    components.day = 1
                    components.hour = 12
                    if let date = Self.calendar.date(from: components) {
                        selection = date
                    }
                    dismiss()
                }
                .font(.custom("SukhumvitSet-Bold", size: 15))
            }
            .padding(.horizontal, 22)
            .padding(.top, 12)

            HStack(spacing: 0) {
                Picker("เดือน", selection: $month) {
                    ForEach(Array(monthNames.enumerated()), id: \.offset) { index, name in
                        Text(LocalizedStringKey(name)).tag(index + 1)
                    }
                }
                .pickerStyle(.wheel)
                .frame(maxWidth: .infinity)

                Picker("ปี", selection: $year) {
                    ForEach((currentYear - 20)...(currentYear + 30), id: \.self) { value in
                        Text(String(value + 543)).tag(value)
                    }
                }
                .pickerStyle(.wheel)
                .frame(maxWidth: .infinity)
            }
            .labelsHidden()
            .padding(.horizontal, 12)
        }
    }

    private var currentYear: Int {
        Self.calendar.component(.year, from: Date())
    }
}

private enum PaymentEditTarget: Identifiable {
    case existing(Payment)
    case draft(Payment)

    var id: UUID { payment.id }
    var payment: Payment {
        switch self {
        case .existing(let payment), .draft(let payment):
            return payment
        }
    }
}

private struct BillingUserCard: View {
    let user: DormUser
    let currentPayment: Payment?
    let dueDay: String
    let action: () -> Void

    private var fullName: String {
        "\(user.prefix)\(user.firstName) \(user.lastName)"
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        Button(action: action) {
            GlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top) {
                        Text(user.roomNumber)
                            .font(.custom("SukhumvitSet-Bold", size: 24))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)

                        Spacer()

                        Text(LocalizedStringKey(statusText))
                            .font(.custom("SukhumvitSet-Bold", size: 10))
                            .foregroundStyle(statusColor)
                            .padding(.horizontal, 9)
                            .frame(height: 26)
                            .background(statusColor.opacity(0.13), in: Capsule())
                    }

                    Text(fullName.isEmpty ? "ลูกบ้าน" : fullName)
                        .font(.custom("SukhumvitSet-Bold", size: 13))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Rectangle()
                        .fill(Color.primary.opacity(0.08))
                        .frame(height: 1)

                    Label(dueDay, systemImage: "calendar")
                        .font(.custom("SukhumvitSet-Text", size: 10))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var statusText: String {
        guard let currentPayment else { return "รอออกบิล" }
        switch currentPayment.paymentStatus {
        case "paid": return "ชำระแล้ว"
        case "partial": return "บางส่วน"
        case "checking": return "รอตรวจ"
        default: return "รอชำระ"
        }
    }

    private var statusColor: Color {
        guard let currentPayment else { return .secondary }
        switch currentPayment.paymentStatus {
        case "paid": return .green
        case "partial": return .blue
        case "checking": return .yellow
        default: return .orange
        }
    }
}

private struct BillingHistorySheet: View {
    @Environment(\.dismiss) private var dismiss
    let user: DormUser
    let payments: [Payment]
    let onIssueBill: (String) -> Void
    let onEdit: (Payment) -> Void
    let onDelete: (Payment) -> Void
    let onMarkPaid: (Payment) -> Void
    let onSendLine: (Payment) -> Void
    private let cycles: [BillingCycle]
    private let paymentsByMonth: [String: [Payment]]

    init(
        user: DormUser,
        payments: [Payment],
        onIssueBill: @escaping (String) -> Void,
        onEdit: @escaping (Payment) -> Void,
        onDelete: @escaping (Payment) -> Void,
        onMarkPaid: @escaping (Payment) -> Void,
        onSendLine: @escaping (Payment) -> Void
    ) {
        self.user = user
        self.payments = payments
        self.onIssueBill = onIssueBill
        self.onEdit = onEdit
        self.onDelete = onDelete
        self.onMarkPaid = onMarkPaid
        self.onSendLine = onSendLine
        var cycles = BillingCycle.generate(
            moveInDate: user.moveInDate,
            contractEndDate: user.contractEndDate,
            indefiniteContract: user.indefiniteContract == 1
        )
        let scheduledMonths = Set(cycles.map(\.monthId))
        let activePayments = payments.filter { !$0.isDeletedLocally }
        let paymentMonths = Set(activePayments.compactMap { BillingCycle.normalizedMonthKey($0.month) })
        // Historical invoices remain accessible even after contract dates are edited.
        for month in paymentMonths.subtracting(scheduledMonths) {
            guard let date = BillingCycle.date("\(month)-01") else { continue }
            let due = BillingCycle.dueDateKey(month: month, moveInDate: user.moveInDate)
            cycles.append(BillingCycle(monthId: month, label: BillingCycle.monthLabel(for: date),
                                       dueDay: Int(due.suffix(2)) ?? 1, isFuture: false))
        }
        self.cycles = cycles.sorted { $0.monthId < $1.monthId }
        self.paymentsByMonth = Dictionary(grouping: activePayments) {
            BillingCycle.normalizedMonthKey($0.month) ?? $0.month
        }.mapValues { payments in
            payments.sorted {
                if $0.installmentPhase != $1.installmentPhase { return $0.installmentPhase < $1.installmentPhase }
                return $0.id.uuidString < $1.id.uuidString
            }
        }
    }

    private var fullName: String {
        "\(user.prefix)\(user.firstName) \(user.lastName)"
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    historyHeader

                    ForEach(Array(cycles.enumerated()), id: \.element.monthId) { index, cycle in
                        if let monthlyPayments = paymentsByMonth[cycle.monthId], !monthlyPayments.isEmpty {
                            ForEach(monthlyPayments) { payment in
                                cycleRow(cycle, number: index + 1, payment: payment)
                            }
                        } else {
                            cycleRow(cycle, number: index + 1, payment: nil)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 28)
            }
            .navigationTitle("ประวัติการชำระเงิน")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("ปิด") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private func cycleRow(_ cycle: BillingCycle, number: Int, payment: Payment?) -> some View {
        BillingCycleRow(number: number, cycle: cycle, payment: payment,
                        onIssueBill: { onIssueBill(cycle.monthId) }, onEdit: onEdit,
                        onDelete: onDelete, onMarkPaid: onMarkPaid, onSendLine: onSendLine)
    }

    private var historyHeader: some View {
        GlassCard {
            HStack(spacing: 14) {
                VStack(spacing: 2) {
                    Text(user.roomNumber)
                        .font(.custom("SukhumvitSet-Bold", size: 28))
                        .foregroundStyle(.primary)
                    Text("ห้อง")
                        .font(.custom("SukhumvitSet-Text", size: 11))
                        .foregroundStyle(.secondary)
                }
                .frame(width: 78, height: 70)
                .background(Color.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 20, style: .continuous))

                VStack(alignment: .leading, spacing: 5) {
                    Text(fullName.isEmpty ? "ลูกบ้าน" : fullName)
                        .font(.custom("SukhumvitSet-Bold", size: 18))
                        .foregroundStyle(.primary)
                    Text("ระบบคำนวณรอบบิลรายเดือนจากวันเข้าอยู่และสัญญา")
                        .font(.custom("SukhumvitSet-Text", size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer()
            }
        }
    }
}

private struct BillingCycleRow: View {
    let number: Int
    let cycle: BillingCycle
    let payment: Payment?
    let onIssueBill: () -> Void
    let onEdit: (Payment) -> Void
    let onDelete: (Payment) -> Void
    let onMarkPaid: (Payment) -> Void
    let onSendLine: (Payment) -> Void
    @State private var showingSlipPreview = false
    @State private var showingReceipt = false

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 13) {
                HStack(alignment: .center, spacing: 12) {
                    Text("\(number)")
                        .font(.custom("SukhumvitSet-Bold", size: 13))
                        .foregroundStyle(payment == nil ? Color.secondary : Color.green)
                        .frame(width: 34, height: 34)
                        .background((payment == nil ? Color.primary.opacity(0.06) : Color.green.opacity(0.14)), in: Circle())

                    VStack(alignment: .leading, spacing: 3) {
                        Text(LocalizedStringKey(cycle.label))
                            .font(.custom("SukhumvitSet-Bold", size: 16))
                            .foregroundStyle(cycle.isFuture && payment == nil ? .secondary : .primary)
                        if let payment, payment.paymentPlan == "installment" {
                            Text("ผ่อนชำระ งวดที่ \(payment.installmentPhase)")
                                .font(.custom("SukhumvitSet-Text", size: 11))
                                .foregroundStyle(.secondary)
                        }
                        Text("กำหนดชำระวันที่ \(cycle.dueDay)")
                            .font(.custom("SukhumvitSet-Text", size: 11))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text(LocalizedStringKey(statusText))
                            .font(.custom("SukhumvitSet-Bold", size: 10))
                            .foregroundStyle(statusColor)
                        if let payment {
                            Text(payment.amount.formatted(.number.precision(.fractionLength(0))) + " ฿")
                                .font(.custom("SukhumvitSet-Bold", size: 16))
                                .foregroundStyle(.primary)
                        }
                    }
                }

                actionContent
            }
            .opacity(cycle.isFuture && payment == nil ? 0.62 : 1)
        }
        .fullScreenCover(isPresented: $showingSlipPreview) {
            if !slipImages.isEmpty {
                SlipPreviewView(images: slipImages)
            }
        }
        .fullScreenCover(isPresented: $showingReceipt) {
            if let payment {
                PaymentReceiptView(payment: payment, cycle: cycle)
            }
        }
    }

    @ViewBuilder
    private var actionContent: some View {
        if let payment {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                if payment.paymentStatus != "paid" {
                    compactAction("รับชำระ", icon: "checkmark.circle.fill", color: .green) {
                        onMarkPaid(payment)
                    }
                }
                if hasSlipImages {
                    compactAction("หลักฐาน", icon: "photo.on.rectangle", color: .primary) {
                        showingSlipPreview = true
                    }
                }
                if payment.paymentStatus == "paid" {
                    compactAction("ใบเสร็จ", icon: "doc.richtext", color: .blue) {
                        showingReceipt = true
                    }
                }
                compactAction("แก้ไข", icon: "pencil", color: .blue) {
                    onEdit(payment)
                }
                compactAction("ลบ", icon: "trash", color: .red) {
                    onDelete(payment)
                }
                compactAction("LINE", icon: "paperplane.fill", color: .green) {
                    onSendLine(payment)
                }
            }
        } else {
            Button(action: onIssueBill) {
                HStack(spacing: 8) {
                    Image(systemName: cycle.isFuture ? "doc.badge.plus" : "doc.text.fill")
                    Text(cycle.isFuture ? LocalizedStringKey("เตรียมบิลล่วงหน้า") : LocalizedStringKey("ออกบิล / รับชำระ"))
                    Spacer()
                    Image(systemName: "chevron.right")
                }
                .font(.custom("SukhumvitSet-Bold", size: 13))
                .foregroundStyle(cycle.isFuture ? Color.secondary : Color.blue)
                .padding(.horizontal, 13)
                .frame(height: 44)
                .background(Color.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }

    private var slipImages: [UIImage] {
        guard payment != nil else { return [] }
        return slipPaths.compactMap { path in
            guard let url = SlipImageManager.url(for: path),
                  FileManager.default.fileExists(atPath: url.path) else {
                return nil
            }
            return UIImage(contentsOfFile: url.path)
        }
    }

    private var hasSlipImages: Bool {
        slipPaths.contains { path in
            guard let url = SlipImageManager.url(for: path) else { return false }
            return FileManager.default.fileExists(atPath: url.path)
        }
    }

    private var slipPaths: [String] {
        guard let payment else { return [] }
        var paths = (payment.slipPathArray ?? [])
        if !payment.slipPath.isEmpty && !paths.contains(payment.slipPath) {
            paths.insert(payment.slipPath, at: 0)
        }
        return paths
    }

    private func compactAction(_ title: LocalizedStringKey, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.custom("SukhumvitSet-Bold", size: 11))
                .foregroundStyle(color)
                .frame(maxWidth: .infinity)
                .frame(height: 38)
                .background(color.opacity(0.12), in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private var statusText: String {
        guard let payment else {
            return cycle.isFuture ? "ยังไม่ถึงรอบบิล" : "รอออกบิล"
        }
        switch payment.paymentStatus {
        case "paid": return "ชำระแล้ว"
        case "partial": return "ชำระบางส่วน"
        case "checking": return "รอตรวจสอบสลิป"
        default: return "รอชำระเงิน"
        }
    }

    private var statusColor: Color {
        guard let payment else { return cycle.isFuture ? .secondary : .orange }
        switch payment.paymentStatus {
        case "paid": return .green
        case "partial": return .blue
        case "checking": return .yellow
        default: return .orange
        }
    }
}

private struct PaymentReceiptView: View {
    @Environment(\.dismiss) private var dismiss
    let payment: Payment
    let cycle: BillingCycle
    @State private var sharePayload: ReceiptSharePayload?
    @State private var saveMessage: String?
    @State private var showingSaveAlert = false
    @State private var isSavingReceipt = false
    
    @State private var showingLedgerAlert = false
    @State private var ledgerActionType: String = ""
    @State private var ledgerReason: String = ""
    @State private var ledgerAmount: String = ""
    @State private var isProcessingLedger = false
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.opacity(0.94)
                    .ignoresSafeArea()

                VStack {
                    ReceiptExportCard(payment: payment, cycle: cycle)
                        .padding(.horizontal, 18)
                        .padding(.top, 12)

                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .allowsHitTesting(false)
            }
            .navigationTitle("ใบเสร็จ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.custom("SukhumvitSet-Bold", size: 14))
                            .foregroundStyle(.white)
                            .frame(width: 38, height: 38)
                            .background(.white.opacity(0.12), in: Circle())
                    }
                }
                ToolbarItemGroup(placement: .confirmationAction) {
                    if payment.serverId != nil && payment.paymentStatus != "voided" && payment.paymentStatus != "refunded" {
                        Menu {
                            if payment.paymentStatus != "paid" {
                                Button(role: .destructive) {
                                    ledgerActionType = "void"
                                    ledgerReason = ""
                                    showingLedgerAlert = true
                                } label: {
                                    Label("ยกเลิกบิล", systemImage: "xmark.bin")
                                }
                                
                                Button {
                                    ledgerActionType = "adjust"
                                    ledgerReason = ""
                                    ledgerAmount = "\(payment.amount)"
                                    showingLedgerAlert = true
                                } label: {
                                    Label("ปรับปรุงยอด", systemImage: "pencil.and.list.clipboard")
                                }
                            } else {
                                Button(role: .destructive) {
                                    ledgerActionType = "refund"
                                    ledgerReason = ""
                                    showingLedgerAlert = true
                                } label: {
                                    Label("คืนเงิน", systemImage: "arrow.uturn.backward")
                                }
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .foregroundStyle(isProcessingLedger ? .gray : .white)
                        }
                        .disabled(isProcessingLedger)
                    }

                    Button {
                        shareReceipt()
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .foregroundStyle(.white)

                    Button {
                        saveReceipt()
                    } label: {
                        Image(systemName: "square.and.arrow.down")
                    }
                    .foregroundStyle(.white)
                    .disabled(isSavingReceipt)
                    .accessibilityLabel(isSavingReceipt ? "กำลังบันทึกใบเสร็จ" : "บันทึกใบเสร็จ")

                    Button {
                        printReceipt()
                    } label: {
                        Image(systemName: "printer")
                    }
                    .foregroundStyle(.white)
                }
            }
        }
        .sheet(item: $sharePayload) { payload in
            ActivityShareSheet(items: [payload.image])
                .presentationDetents([.medium, .large])
        }
        .alert(LocalizedStringKey(saveMessage ?? ""), isPresented: $showingSaveAlert) {
            Button("ตกลง", role: .cancel) { }
        }
        .alert(LocalizedStringKey(ledgerActionTitle), isPresented: $showingLedgerAlert) {
            TextField("ระบุเหตุผล (บังคับ)", text: $ledgerReason)
            if ledgerActionType == "adjust" {
                TextField("ยอดเงินใหม่", text: $ledgerAmount)
                    .keyboardType(.decimalPad)
            }
            Button("ยกเลิก", role: .cancel) { }
            Button("ยืนยัน", role: .destructive) {
                processLedgerAction()
            }
            .disabled(ledgerReason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        } message: {
            if ledgerActionType == "void" { Text("คุณต้องการยกเลิกบิลนี้ใช่หรือไม่?\n(เมื่อยกเลิกแล้วจะไม่สามารถรับชำระได้อีก)") }
            else if ledgerActionType == "refund" { Text("คุณต้องการคืนเงินบิลนี้ใช่หรือไม่?\n(สถานะจะเปลี่ยนเป็นคืนเงินเรียบร้อย)") }
            else { Text("คุณต้องการปรับปรุงยอดเงินบิลนี้ใช่หรือไม่?") }
        }
    }
    
    private var ledgerActionTitle: String {
        switch ledgerActionType {
        case "void": return "ยกเลิกบิล"
        case "refund": return "คืนเงิน (Refund)"
        case "adjust": return "ปรับปรุงยอด"
        default: return "จัดการบัญชี"
        }
    }
    
    private func processLedgerAction() {
        guard !ledgerReason.isEmpty, let serverId = payment.serverId else { return }
        isProcessingLedger = true
        Task { @MainActor in
            defer { isProcessingLedger = false }
            do {
                let msg: String
                switch ledgerActionType {
                case "void":
                    msg = try await APIService.shared.voidPayment(serverId: serverId, reason: ledgerReason)
                    payment.paymentStatus = "voided"
                case "refund":
                    msg = try await APIService.shared.refundPayment(serverId: serverId, reason: ledgerReason)
                    payment.paymentStatus = "refunded"
                case "adjust":
                    let newAmt = Double(ledgerAmount) ?? payment.amount
                    msg = try await APIService.shared.adjustPayment(serverId: serverId, newAmount: newAmt, reason: ledgerReason)
                    payment.amount = newAmt
                default:
                    return
                }
                payment.isDirty = true
                payment.lastUpdated = Date()
                modelContext.insert(LocalSystemLog(action: "ระบบบัญชี: \(ledgerActionType)", details: "อัปเดตบิลห้อง \(payment.roomNumber) รอบ \(payment.month) แล้ว (\(msg))"))
                try? modelContext.save()
                
                Task {
                    await SyncManager.shared.pushCurrentLocalState(modelContext: modelContext, reason: "Ledger Action")
                }
                
                saveMessage = "ดำเนินการสำเร็จ: \(msg)"
                showingSaveAlert = true
            } catch {
                saveMessage = "ข้อผิดพลาด: \(error.localizedDescription)"
                showingSaveAlert = true
            }
        }
    }

    private func shareReceipt() {
        guard let image = renderedReceiptImage() else {
            saveMessage = "สร้างรูปใบเสร็จไม่สำเร็จ"
            showingSaveAlert = true
            return
        }
        sharePayload = ReceiptSharePayload(image: image)
    }

    private func saveReceipt() {
        guard !isSavingReceipt else { return }
        guard let image = renderedReceiptImage() else {
            saveMessage = "สร้างรูปใบเสร็จไม่สำเร็จ"
            showingSaveAlert = true
            return
        }
        isSavingReceipt = true
        Task { @MainActor in
            defer { isSavingReceipt = false }
            let authorization = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
            guard authorization == .authorized || authorization == .limited else {
                saveMessage = "กรุณาอนุญาตให้บันทึกรูปภาพในการตั้งค่าของเครื่อง"
                showingSaveAlert = true
                return
            }
            do {
                try await PHPhotoLibrary.shared().performChanges {
                    PHAssetChangeRequest.creationRequestForAsset(from: image)
                }
                saveMessage = "บันทึกใบเสร็จลงรูปภาพแล้ว"
            } catch {
                saveMessage = "บันทึกใบเสร็จไม่สำเร็จ: \(error.localizedDescription)"
            }
            showingSaveAlert = true
        }
    }

    private func printReceipt() {
        guard let image = renderedReceiptImage() else {
            saveMessage = "สร้างเอกสารสำหรับพิมพ์ไม่สำเร็จ"
            showingSaveAlert = true
            return
        }
        let controller = UIPrintInteractionController.shared
        controller.printInfo = UIPrintInfo(dictionary: nil)
        controller.printInfo?.outputType = .general
        controller.printInfo?.jobName = "DormiNet Receipt \(payment.roomNumber) \(cycle.monthId)"
        controller.printingItem = image
        controller.present(animated: true)
    }

    @MainActor
    private func renderedReceiptImage() -> UIImage? {
        let renderer = ImageRenderer(content:
            ReceiptExportCard(payment: payment, cycle: cycle)
                .frame(width: 820)
                .padding(42)
                .background(Color.white)
        )
        renderer.scale = 2
        return renderer.uiImage
    }
}

private struct ReceiptSharePayload: Identifiable {
    let id = UUID()
    let image: UIImage
}

private struct ActivityShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

private struct ReceiptExportCard: View {
    let payment: Payment
    let cycle: BillingCycle

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("DormiNet")
                        .font(.custom("SukhumvitSet-Medium", size: 24))
                        .foregroundStyle(.black)
                    Text("ใบเสร็จรับเงิน")
                        .font(.custom("SukhumvitSet-Bold", size: 28))
                        .foregroundStyle(.black)
                }

                Spacer()

                Text(LocalizedStringKey(receiptStatusLabel))
                    .font(.custom("SukhumvitSet-Bold", size: 13))
                    .foregroundStyle(.black.opacity(0.72))
                    .padding(.horizontal, 13)
                    .frame(height: 34)
                    .overlay(
                        Capsule()
                            .stroke(Color.black.opacity(0.14), lineWidth: 1)
                    )
            }

            HStack(spacing: 12) {
                infoBox("ห้อง", payment.roomNumber)
                infoBox("รอบบิล", cycle.label)
                infoBox("วันที่ชำระ", thaiDate(payment.paymentDate))
            }

            VStack(spacing: 0) {
                receiptLine("ช่องทางชำระเงิน", thaiPaymentMethod)
                divider
                receiptLine("ค่าเช่า", currency(payment.rentFee))
                if payment.depositFee != 0 {
                    receiptLine("เงินมัดจำ", currency(payment.depositFee))
                }
                if PaymentAmounts.unallocated(in: payment) != 0 {
                    receiptLine("ยอดเดิมที่ยังไม่แยกรายการ", currency(PaymentAmounts.unallocated(in: payment)))
                }
                receiptLine("ค่าน้ำ", currency(payment.waterFee))
                receiptLine("ค่าไฟ", currency(payment.electricFee))
                receiptLine("ค่าส่วนกลาง", currency(payment.commonFee))
                receiptLine("ค่าอุปกรณ์เสริม", currency(payment.applianceFee))
                receiptLine("ค่าปรับล่าช้า", currency(payment.lateFee))
                divider
                receiptLine("ยอดรวม", currency(payment.amount), isTotal: true)
                receiptLine("รับชำระแล้ว", currency((payment.paidAmount ?? 0.0)), isTotal: true)
                receiptLine("ยอดคงเหลือ", currency(max(payment.amount - (payment.paidAmount ?? 0.0), 0)), isTotal: true)
            }
            .padding(.vertical, 6)

            HStack {
                Text("เอกสารนี้สร้างจากข้อมูลภายในเครื่องของระบบ DormiNet")
                    .font(.custom("SukhumvitSet-Text", size: 11))
                    .foregroundStyle(.gray)
                Spacer()
                Text(generatedDateText)
                    .font(.custom("SukhumvitSet-Medium", size: 11))
                    .foregroundStyle(.gray)
            }
        }
        .padding(26)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.black.opacity(0.08), lineWidth: 1)
        )
    }
    
    private var receiptStatusLabel: String {
        switch payment.paymentStatus {
        case "paid": return "ชำระแล้ว"
        case "voided": return "ยกเลิก (Void)"
        case "refunded": return "คืนเงิน (Refund)"
        default: return "ยังไม่ปิดบิล"
        }
    }

    private func infoBox(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(LocalizedStringKey(title))
                .font(.custom("SukhumvitSet-Medium", size: 11))
                .foregroundStyle(.gray)
            Text(value)
                .font(.custom("SukhumvitSet-Bold", size: 15))
                .foregroundStyle(.black)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 10)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.black.opacity(0.08))
                .frame(height: 1)
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.black.opacity(0.09))
            .frame(height: 1)
            .padding(.vertical, 8)
    }

    private func receiptLine(_ title: String, _ value: String, isTotal: Bool = false) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(LocalizedStringKey(title))
                .font(.custom(isTotal ? "SukhumvitSet-Bold" : "SukhumvitSet-Text", size: isTotal ? 15 : 13))
                .foregroundStyle(isTotal ? Color.black : Color.gray)
            Spacer(minLength: 18)
            Text(value)
                .font(.custom("SukhumvitSet-Bold", size: isTotal ? 18 : 14))
                .foregroundStyle(.black)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.vertical, 5)
    }

    private func currency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "th_TH")
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = value.rounded() == value ? 0 : 2

        let amount = formatter.string(from: NSNumber(value: value)) ?? "0"
        return "\(amount) บาท"
    }

    private var thaiPaymentMethod: String {
        let trimmed = payment.method.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "-" }

        return trimmed
            .replacingOccurrences(of: "เงินโอน (Transfer)", with: "โอนผ่านธนาคาร")
            .replacingOccurrences(of: "เงินสด (Cash)", with: "เงินสด")
            .replacingOccurrences(of: "Transfer", with: "โอนผ่านธนาคาร")
            .replacingOccurrences(of: "Cash", with: "เงินสด")
            .replacingOccurrences(of: "Full payment", with: "ชำระเต็มจำนวน")
            .replacingOccurrences(of: "Installment", with: "ผ่อนชำระ")
    }

    private var generatedDateText: String {
        AppDate.thaiDateTime(Date())
    }

    private func thaiDate(_ rawValue: String) -> String {
        AppDate.thaiDate(rawValue)
    }
}

private struct FinanceSummaryCard: View {
    let title: String
    let amount: Double
    let color: Color
    let icon: String
    var isCount = false

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: icon)
                        .foregroundStyle(color)
                    Spacer()
                    Text(LocalizedStringKey(title))
                        .font(.custom("SukhumvitSet-Medium", size: 11))
                        .foregroundStyle(.secondary)
                }

                Text(isCount ? String(Int(amount)) : amount.formatted(.number.precision(.fractionLength(0))))
                    .font(.custom("SukhumvitSet-Bold", size: 21))
                    .foregroundStyle(.primary)
                Text(isCount ? LocalizedStringKey("รายการ") : LocalizedStringKey("บาท"))
                    .font(.custom("SukhumvitSet-Text", size: 10))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct PaymentRow: View {
    let payment: Payment
    let user: DormUser?
    let status: String
    let onMarkPaid: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    private var statusColor: Color {
        switch status {
        case "ชำระแล้ว": return .green
        case "ชำระบางส่วน": return .blue
        default: return .orange
        }
    }

    var body: some View {
        GlassCard {
            VStack(spacing: 10) {
                HStack(spacing: 12) {
                    VStack(spacing: 4) {
                        Text(payment.roomNumber)
                            .font(.custom("SukhumvitSet-Bold", size: 18))
                        Image(systemName: "door.left.hand.open")
                            .font(.custom("SukhumvitSet-Medium", size: 12))
                            .foregroundStyle(.secondary)
                    }
                    .frame(width: 48)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(user?.firstName ?? "ลูกบ้าน") \(user?.lastName ?? "")")
                            .font(.custom("SukhumvitSet-Bold", size: 14))
                        Text(payment.method.isEmpty ? "ยังไม่ได้ระบุช่องทาง" : payment.method)
                            .font(.custom("SukhumvitSet-Text", size: 11))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 5) {
                        Text(payment.amount.formatted(.number.precision(.fractionLength(0))) + " ฿")
                            .font(.custom("SukhumvitSet-Bold", size: 15))
                        Text(LocalizedStringKey(status))
                            .font(.custom("SukhumvitSet-Medium", size: 10))
                            .foregroundStyle(statusColor)
                        if payment.paymentPlan == "installment", payment.installmentPhase > 0 {
                            Text("งวด \(payment.installmentPhase)")
                                .font(.custom("SukhumvitSet-Medium", size: 10))
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                HStack {
                    if payment.paymentStatus != "paid" {
                        Button(action: onMarkPaid) {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.custom("SukhumvitSet-Bold", size: 13))
                                Text("รับชำระเต็มจำนวน")
                                    .font(.custom("SukhumvitSet-Bold", size: 12))
                                Image(systemName: "chevron.right")
                                    .font(.custom("SukhumvitSet-Bold", size: 10))
                                    .opacity(0.75)
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 13)
                            .frame(height: 34)
                            .background(
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.green, Color.green.opacity(0.78)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            )
                            .shadow(color: Color.green.opacity(0.22), radius: 8, x: 0, y: 4)
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer()
                    if payment.isDirty {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .foregroundStyle(.orange)
                    }
                }
            }
        }
        .contextMenu {
            Button(action: onEdit) {
                Label("แก้ไข", systemImage: "pencil")
            }
            Button(role: .destructive, action: onDelete) {
                Label("ลบ", systemImage: "trash")
            }
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive, action: onDelete) {
                Label("ลบ", systemImage: "trash")
            }
            Button(action: onEdit) {
                Label("แก้ไข", systemImage: "pencil")
            }
            .tint(.indigo)
        }
    }
}

struct PaymentEditor: View {
    @Environment(\.dismiss) private var dismiss
    let users: [DormUser]
    let rooms: [Room]
    let roomTypes: [RoomType]
    let defaultMonth: String
    let onSave: (Payment) throws -> Void
    private let sourcePaymentPlan: String
    private let sourceInstallmentPhase: Int
    private let sourcePayment: Payment?
    private let legacyAdjustment: Double

    @State private var roomNumber: String
    @State private var month: String
    @State private var rentFee: String
    @State private var depositFee: String
    @State private var validationError: String?
    @State private var waterFee: String
    @State private var electricFee: String
    @State private var commonFee: String
    @State private var lateFee: String
    @State private var applianceFee: String
    @State private var paidAmount: String
    @State private var method: String
    @State private var slipPath: String
    @State private var dueDate: String
    @State private var paymentDate: String
    @State private var paymentStatus: String
    @State private var slipPaths: [String]
    @State private var selectedSlipItems: [PhotosPickerItem] = []
    @State private var isImportingSlip = false
    @State private var slipImportMessage: String?
    @State private var selectedDetent: PresentationDetent = .large
    @State private var billDate: Date
    @State private var dueDateValue: Date
    @State private var paymentDateValue: Date

    private let statusOptions = [
        ("pending", "รอชำระ"),
        ("partial", "จ่ายบางส่วน"),
        ("paid", "ชำระแล้ว")
    ]

    init(payment: Payment? = nil, users: [DormUser], rooms: [Room], roomTypes: [RoomType], defaultMonth: String, onSave: @escaping (Payment) throws -> Void) {
        self.users = users
        self.rooms = rooms
        self.roomTypes = roomTypes
        self.defaultMonth = defaultMonth
        self.onSave = onSave
        self.sourcePaymentPlan = payment?.paymentPlan ?? "monthly"
        self.sourceInstallmentPhase = payment?.installmentPhase ?? 0
        self.sourcePayment = payment
        self.legacyAdjustment = payment.map { PaymentAmounts.unallocated(in: $0) } ?? 0
        _roomNumber = State(initialValue: payment?.roomNumber ?? rooms.first?.roomNumber ?? users.first?.roomNumber ?? "")
        _month = State(initialValue: payment?.month ?? defaultMonth)
        _rentFee = State(initialValue: payment.map { PaymentAmounts.input($0.rentFee) } ?? "")
        _depositFee = State(initialValue: payment.map { PaymentAmounts.input($0.depositFee) } ?? "")
        _waterFee = State(initialValue: payment.map { PaymentAmounts.input($0.waterFee) } ?? "")
        _electricFee = State(initialValue: payment.map { PaymentAmounts.input($0.electricFee) } ?? "")
        _commonFee = State(initialValue: payment.map { PaymentAmounts.input($0.commonFee) } ?? "")
        _lateFee = State(initialValue: payment.map { PaymentAmounts.input($0.lateFee) } ?? "")
        _applianceFee = State(initialValue: payment.map { PaymentAmounts.input($0.applianceFee) } ?? "")
        _paidAmount = State(initialValue: payment.map { PaymentAmounts.input(($0.paidAmount ?? 0.0)) } ?? "")
        _method = State(initialValue: payment?.method ?? "")
        let initialSlipPaths = Self.normalizedSlipPaths(from: payment)
        _slipPath = State(initialValue: initialSlipPaths.first ?? "")
        _slipPaths = State(initialValue: initialSlipPaths)
        _dueDate = State(initialValue: payment?.dueDate ?? "")
        _paymentDate = State(initialValue: payment?.paymentDate ?? "")
        _paymentStatus = State(initialValue: payment?.paymentStatus.isEmpty == false ? payment?.paymentStatus ?? "pending" : "pending")
        let initialBillDate = Self.dateFromMonthKey(payment?.month ?? defaultMonth) ?? Date()
        let initialDueDate = Self.dateFromDateKey(payment?.dueDate ?? "") ?? initialBillDate
        _billDate = State(initialValue: initialBillDate)
        _dueDateValue = State(initialValue: initialDueDate)
        _paymentDateValue = State(initialValue: Self.dateFromDateKey(payment?.paymentDate ?? "") ?? Date())
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    PaymentEditorContextCard(
                        roomNumber: clean(roomNumber).isEmpty ? "-" : clean(roomNumber),
                        tenantName: selectedTenantName,
                        roomType: selectedRoomTypeName,
                        month: clean(month).isEmpty ? defaultMonth : clean(month),
                        planText: planText,
                        amount: totalAmount,
                        paidAmount: effectivePaidAmount,
                        status: statusTitle(for: paymentStatus),
                        statusColor: statusColor(for: paymentStatus),
                        slipCount: slipPaths.count
                    )

                    formSectionHeader("ข้อมูลบิล", subtitle: "เลือกห้องและรอบที่ต้องการแก้ไข")
                    editorCard {
                        if rooms.isEmpty {
                            labeledTextField("เลขห้อง", placeholder: "เช่น 101", text: $roomNumber)
                        } else {
                            roomPickerButton
                        }

                        Button {
                            applyRoomTypeDefaults()
                        } label: {
                            Label("เติมราคาจากประเภทห้อง", systemImage: "wand.and.stars")
                                .font(.custom("SukhumvitSet-Bold", size: 13))
                                .frame(maxWidth: .infinity)
                                .frame(height: 42)
                                .background(Color.primary.opacity(0.06), in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.blue)

                        dividerLine

                        DatePicker("รอบบิล", selection: $billDate, displayedComponents: [.date])
                            .datePickerStyle(.compact)
                            .font(.custom("SukhumvitSet-Medium", size: 14))
                            .onChange(of: billDate) { _, newValue in
                                month = Self.monthKey(from: newValue)
                                if clean(dueDate).isEmpty {
                                    dueDateValue = newValue
                                    dueDate = Self.dateKey(from: newValue)
                                }
                            }

                        DatePicker("วันครบกำหนด", selection: $dueDateValue, displayedComponents: [.date])
                            .datePickerStyle(.compact)
                            .font(.custom("SukhumvitSet-Medium", size: 14))
                            .onChange(of: dueDateValue) { _, newValue in
                                dueDate = Self.dateKey(from: newValue)
                            }
                    }

                    formSectionHeader("ยอดที่คิดเงิน", subtitle: "แยกรายการค่าใช้จ่ายเพื่อให้ตรวจสอบง่าย")
                    editorCard {
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 12) {
                            moneyField("ค่าเช่า", text: $rentFee)
                            moneyField("เงินมัดจำ", text: $depositFee)
                            moneyField("ค่าน้ำ", text: $waterFee)
                            moneyField("ค่าไฟ", text: $electricFee)
                            moneyField("ส่วนกลาง", text: $commonFee)
                            moneyField("ค่าปรับ", text: $lateFee)
                            moneyField("อุปกรณ์เสริม", text: $applianceFee)
                        }

                        if legacyAdjustment != 0 {
                            LabeledContent("ยอดเดิมที่ยังไม่แยกรายการ") {
                                Text(PaymentAmounts.input(legacyAdjustment) + " บาท")
                            }
                            .font(.custom("SukhumvitSet-Medium", size: 13))
                        }

                        dividerLine

                        HStack(alignment: .lastTextBaseline) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("ยอดรวมบิล")
                                    .font(.custom("SukhumvitSet-Bold", size: 15))
                                    .foregroundStyle(.primary)
                                Text("รวมค่าใช้จ่ายทั้งหมดของรอบนี้")
                                    .font(.custom("SukhumvitSet-Text", size: 11))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(totalAmount.formatted(.number.precision(.fractionLength(0...2))) + " ฿")
                                .font(.custom("SukhumvitSet-Bold", size: 22))
                                .foregroundStyle(.primary)
                        }
                    }

                    formSectionHeader("ผลการรับเงิน", subtitle: "อัปเดตสถานะ ช่องทางชำระ และหลักฐานสลิป")
                    editorCard {
                        statusSelector
                        statusHelper

                        dividerLine

                        if paymentStatus == "partial" {
                            labeledTextField("ยอดรับชำระสะสม", placeholder: "0", text: $paidAmount)
                                .keyboardType(.decimalPad)
                                .decimalInput($paidAmount, maxIntegerDigits: 9, maxFractionDigits: 2)
                        } else {
                            LabeledContent("ยอดรับชำระสะสม", value: PaymentAmounts.input(effectivePaidAmount) + " บาท")
                        }
                        paymentMethodQuickChoices
                        labeledTextField("ช่องทางชำระเงิน", placeholder: "เช่น เงินสด หรือ โอนผ่านธนาคาร", text: $method)
                            .limitedText($method, maxLength: 60, trimNewlines: true)
                        paymentDateSummary

                        dividerLine

                        slipPickerContent
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 28)
            }
            .navigationTitle("แก้ไขรายการชำระเงิน")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("ยกเลิก") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("บันทึก") {
                        savePayment()
                    }
                    .fontWeight(.semibold)
                    .disabled(clean(roomNumber).isEmpty || clean(month).isEmpty)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .alert("บันทึกไม่ได้", isPresented: Binding(
                get: { validationError != nil },
                set: { if !$0 { validationError = nil } }
            )) {
                Button("ตกลง", role: .cancel) { validationError = nil }
            } message: { Text(validationError ?? "") }
            .onAppear {
                month = Self.monthKey(from: billDate)
                dueDate = Self.dateKey(from: dueDateValue)
                if paymentStatus != "pending", clean(paymentDate).isEmpty {
                    paymentDate = Self.dateKey(from: paymentDateValue)
                }
                applyRoomTypeDefaults(onlyWhenEmpty: true)
            }
        }
        .presentationDetents([.medium, .large], selection: $selectedDetent)
        .presentationDragIndicator(.visible)
    }

    private var roomPickerButton: some View {
        Menu {
            ForEach(rooms) { room in
                Button {
                    roomNumber = room.roomNumber
                    applyRoomTypeDefaults(onlyWhenEmpty: true)
                } label: {
                    Text(room.roomNumber)
                }
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "door.left.hand.open")
                    .font(.custom("SukhumvitSet-Bold", size: 18))
                    .foregroundStyle(.blue)
                    .frame(width: 36, height: 36)
                    .background(Color.blue.opacity(0.12), in: Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text("ห้อง")
                        .font(.custom("SukhumvitSet-Medium", size: 11))
                        .foregroundStyle(.secondary)
                    Text(clean(roomNumber).isEmpty ? "เลือกห้อง" : "ห้อง \(clean(roomNumber))")
                        .font(.custom("SukhumvitSet-Bold", size: 17))
                        .foregroundStyle(.primary)
                }

                Spacer()

                Text("แตะเพื่อเลือก")
                    .font(.custom("SukhumvitSet-Medium", size: 11))
                    .foregroundStyle(.secondary)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.custom("SukhumvitSet-Bold", size: 12))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 62)
            .background(Color.primary.opacity(0.065), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var statusSelector: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("สถานะการชำระ")
                .font(.custom("SukhumvitSet-Bold", size: 14))
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                ForEach(statusOptions, id: \.0) { value, title in
                    Button {
                        paymentStatus = value
                        if value == "paid" {
                            paidAmount = PaymentAmounts.input(totalAmount)
                        } else if value == "pending" {
                            paidAmount = "0"
                            paymentDate = ""
                        }

                        if value != "pending", clean(paymentDate).isEmpty {
                            paymentDateValue = Date()
                            paymentDate = Self.dateKey(from: paymentDateValue)
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(statusColor(for: value))
                                .frame(width: 7, height: 7)
                            Text(LocalizedStringKey(title))
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                        }
                            .font(.custom("SukhumvitSet-Bold", size: 11))
                            .foregroundStyle(paymentStatus == value ? Color.white : Color.primary.opacity(0.72))
                            .frame(maxWidth: .infinity)
                            .frame(height: 40)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(paymentStatus == value ? Color.indigo : Color.primary.opacity(0.07))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var statusHelper: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle")
                .font(.custom("SukhumvitSet-SemiBold", size: 13))
                .foregroundStyle(.secondary)
            Text(LocalizedStringKey(statusDescription))
                .font(.custom("SukhumvitSet-Text", size: 12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var paymentDateSummary: some View {
        HStack(spacing: 12) {
            Image(systemName: paymentStatus == "pending" ? "calendar.badge.clock" : "calendar.badge.checkmark")
                .font(.custom("SukhumvitSet-SemiBold", size: 18))
                .foregroundStyle(paymentStatus == "pending" ? Color.secondary : Color.green)
                .frame(width: 34, height: 34)
                .background(Color.primary.opacity(0.06), in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text("วันที่ชำระ")
                    .font(.custom("SukhumvitSet-Medium", size: 11))
                    .foregroundStyle(.secondary)
                Text(paymentStatus == "pending" ? "ยังไม่บันทึกวันที่ เพราะยังรอชำระ" : thaiDateLabel(paymentDateValue))
                    .font(.custom("SukhumvitSet-Bold", size: 14))
                    .foregroundStyle(.primary)
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 56)
        .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var statusDescription: String {
        switch paymentStatus {
        case "paid":
            return "ใช้เมื่อรับครบทั้งยอดแล้ว ระบบจะเติมยอดชำระและวันที่ชำระของวันนี้ให้อัตโนมัติ"
        case "partial":
            return "ใช้เมื่อรับเงินมาแล้วบางส่วน ยังไม่ถือว่าปิดบิล เหลือยอดคงค้างให้ตามต่อ"
        default:
            return "ใช้เมื่อยังไม่ได้รับเงิน บิลนี้จะถูกนับเป็นยอดค้างชำระ"
        }
    }

    private var selectedTenant: DormUser? {
        if let sourcePayment, sourcePayment.userId > 0 {
            return users.first { stableLocalUserID(for: $0) == sourcePayment.userId }
        }
        return users.first { clean($0.roomNumber) == clean(roomNumber) && $0.status != "ย้ายออกแล้ว" }
    }

    private var planText: String {
        if sourcePaymentPlan == "installment", sourceInstallmentPhase > 0 {
            return "ผ่อนชำระ งวด \(sourceInstallmentPhase)"
        }
        if sourcePaymentPlan == "booking" {
            return "รายการจอง/แรกเข้า"
        }
        return "บิลรายเดือน"
    }

    private var selectedTenantName: String {
        guard let selectedTenant else { return "ยังไม่พบลูกบ้านของห้องนี้" }
        let fullName = "\(selectedTenant.firstName) \(selectedTenant.lastName)".trimmingCharacters(in: .whitespacesAndNewlines)
        return fullName.isEmpty ? "ลูกบ้าน" : fullName
    }

    private var selectedRoomTypeName: String {
        guard let room = rooms.first(where: { clean($0.roomNumber) == clean(roomNumber) }) else {
            return "ยังไม่พบข้อมูลห้อง"
        }
        return room.roomType.isEmpty ? "ไม่ระบุประเภทห้อง" : room.roomType
    }

    private func statusTitle(for value: String) -> String {
        statusOptions.first { $0.0 == value }?.1 ?? "รอชำระ"
    }

    private func statusColor(for value: String) -> Color {
        switch value {
        case "paid": return .green
        case "partial": return .blue
        default: return .orange
        }
    }

    private func formSectionHeader(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(LocalizedStringKey(title))
                .font(.custom("SukhumvitSet-Bold", size: 14))
                .foregroundStyle(.primary)
            Text(LocalizedStringKey(subtitle))
                .font(.custom("SukhumvitSet-Text", size: 11))
                .foregroundStyle(.secondary)
        }
        .textCase(nil)
        .padding(.top, 8)
    }

    private var dividerLine: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.08))
            .frame(height: 1)
            .padding(.vertical, 4)
    }

    private func editorCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.primary.opacity(0.055))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.primary.opacity(0.07), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var slipPickerContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !slipImages.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(Array(slipImages.enumerated()), id: \.offset) { index, image in
                            ZStack(alignment: .topTrailing) {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 112, height: 140)
                                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                                    )

                                Button {
                                    removeSlip(at: index)
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.custom("SukhumvitSet-Bold", size: 10))
                                        .foregroundStyle(.white)
                                        .frame(width: 24, height: 24)
                                        .background(.black.opacity(0.55), in: Circle())
                                }
                                .buttonStyle(.plain)
                                .padding(6)
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
            }

            PhotosPicker(selection: $selectedSlipItems, maxSelectionCount: 10, matching: .images, photoLibrary: .shared()) {
                HStack(spacing: 10) {
                    if isImportingSlip {
                        ProgressView()
                            .scaleEffect(0.82)
                    } else {
                        Image(systemName: slipPaths.isEmpty ? "photo.badge.plus" : "photo.on.rectangle")
                            .font(.custom("SukhumvitSet-Bold", size: 17))
                    }

                    Text(slipPaths.isEmpty ? LocalizedStringKey("เพิ่มรูปสลิป") : LocalizedStringKey("เพิ่มรูปสลิปอีก"))
                        .font(.custom("SukhumvitSet-Bold", size: 15))

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.custom("SukhumvitSet-Bold", size: 13))
                        .foregroundStyle(.secondary)
                }
                .foregroundStyle(.blue)
                .padding(.horizontal, 14)
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(isImportingSlip)

            if !slipPaths.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text(slipImportMessage ?? "มีรูปสลิปแนบ \(slipPaths.count) รูป")
                        .font(.custom("SukhumvitSet-Text", size: 12))
                        .foregroundStyle(.secondary)
                }
            } else if let slipImportMessage {
                Text(slipImportMessage)
                    .font(.custom("SukhumvitSet-Text", size: 12))
                    .foregroundStyle(.secondary)
            }
        }
        .onChange(of: selectedSlipItems) { _, newItems in
            importSlipImages(newItems)
        }
    }

    private var slipImages: [UIImage] {
        slipPaths.compactMap { path in
            guard let url = SlipImageManager.url(for: path),
                  FileManager.default.fileExists(atPath: url.path) else {
                return nil
            }
            return UIImage(contentsOfFile: url.path)
        }
    }

    private var totalAmount: Double {
        PaymentAmounts.sum([money(rentFee), money(depositFee), money(waterFee), money(electricFee),
                            money(commonFee), money(lateFee), money(applianceFee), legacyAdjustment])
    }

    private var effectivePaidAmount: Double {
        paymentStatus == "paid" ? totalAmount : (paymentStatus == "pending" ? 0 : money(paidAmount))
    }

    private func moneyField(_ title: String, text: Binding<String>) -> some View {
        compactMoneyField(title, text: text)
            .keyboardType(.decimalPad)
            .decimalInput(text, maxIntegerDigits: 9, maxFractionDigits: 2)
    }

    private func labeledTextField(_ title: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(LocalizedStringKey(title))
                .font(.custom("SukhumvitSet-Medium", size: 12))
                .foregroundStyle(.secondary)

            TextField(LocalizedStringKey(placeholder), text: text)
                .font(.custom("SukhumvitSet-Text", size: 16))
                .foregroundStyle(.primary)
                .padding(.horizontal, 14)
                .frame(minHeight: 48)
                .background(Color.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.primary.opacity(0.07), lineWidth: 1)
                )
        }
    }

    private func compactMoneyField(_ title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(LocalizedStringKey(title))
                .font(.custom("SukhumvitSet-Medium", size: 11))
                .foregroundStyle(.secondary)

            HStack(spacing: 6) {
                TextField("0", text: text)
                    .font(.custom("SukhumvitSet-Bold", size: 17))
                    .foregroundStyle(.primary)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)

                Text("บาท")
                    .font(.custom("SukhumvitSet-Medium", size: 11))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .frame(height: 46)
            .background(Color.primary.opacity(0.052), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .stroke(Color.primary.opacity(0.065), lineWidth: 1)
            )
        }
    }

    private var paymentMethodQuickChoices: some View {
        HStack(spacing: 8) {
            paymentMethodButton("เงินสด", value: "\(paymentMethodPrefix) • เงินสด")
            paymentMethodButton("โอนธนาคาร", value: "\(paymentMethodPrefix) • โอนผ่านธนาคาร")
        }
    }

    private var paymentMethodPrefix: String {
        switch paymentStatus {
        case "partial": return "จ่ายบางส่วน"
        case "paid": return "ชำระเต็มจำนวน"
        default: return "รอชำระ"
        }
    }

    private func paymentMethodButton(_ title: String, value: String) -> some View {
        Button {
            method = value
        } label: {
            Text(LocalizedStringKey(title))
                .font(.custom("SukhumvitSet-Bold", size: 12))
                .foregroundStyle(method == value ? Color.white : Color.primary.opacity(0.7))
                .frame(maxWidth: .infinity)
                .frame(height: 38)
                .background(method == value ? Color.indigo : Color.primary.opacity(0.06), in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private func savePayment() {
        month = Self.monthKey(from: billDate)
        dueDate = Self.dateKey(from: dueDateValue)

        let finalStatus = paymentStatus
        let finalPaidAmount = effectivePaidAmount
        var finalPaymentDate = clean(paymentDate)
        do {
            let fields = [rentFee, depositFee, waterFee, electricFee, commonFee, lateFee, applianceFee]
            guard fields.allSatisfy({ clean($0).isEmpty || (Double(clean($0)).map { $0.isFinite && $0 >= 0 } ?? false) }) else {
                throw PaymentAmounts.InvalidPayment("กรุณาตรวจสอบยอดค่าใช้จ่าย ต้องเป็นตัวเลขที่ไม่ติดลบ")
            }
            try PaymentAmounts.validate(total: totalAmount, paid: finalPaidAmount, status: finalStatus,
                                        previousPaid: sourcePayment?.paidAmount ?? 0)
        } catch {
            validationError = error.localizedDescription
            return
        }
        if finalStatus == "pending" { finalPaymentDate = "" }

        if finalStatus != "pending", finalPaymentDate.isEmpty {
            paymentDate = Self.dateKey(from: paymentDateValue)
            finalPaymentDate = paymentDate
        }

        let item = Payment(month: clean(month), amount: totalAmount)
        item.roomNumber = clean(roomNumber)
        if let sourcePayment, sourcePayment.userId > 0 {
            item.userId = sourcePayment.userId
        } else if let tenant = users.first(where: { $0.roomNumber == item.roomNumber && $0.status != "ย้ายออกแล้ว" }) {
            item.userId = stableLocalUserID(for: tenant)
        } else {
            item.userId = 0
        }
        item.rentFee = money(rentFee)
        item.depositFee = money(depositFee)
        item.waterMeterPrev = sourcePayment?.waterMeterPrev ?? 0
        item.waterMeterCurr = sourcePayment?.waterMeterCurr ?? 0
        item.electricMeterPrev = sourcePayment?.electricMeterPrev ?? 0
        item.electricMeterCurr = sourcePayment?.electricMeterCurr ?? 0
        item.waterFee = money(waterFee)
        item.electricFee = money(electricFee)
        item.commonFee = money(commonFee)
        item.lateFee = money(lateFee)
        item.applianceFee = money(applianceFee)
        item.paidAmount = finalPaidAmount
        item.method = clean(method).isEmpty && finalStatus != "pending" ? paymentMethodPrefix : clean(method)
        item.slipPath = slipPaths.first ?? clean(slipPath)
        item.slipPathArray = slipPaths
        item.dueDate = clean(dueDate)
        item.paymentDate = finalPaymentDate
        item.paymentStatus = finalStatus
        item.paymentPlan = sourcePaymentPlan
        item.installmentPhase = sourceInstallmentPhase
        do {
            try onSave(item)
            dismiss()
        } catch {
            validationError = "บันทึกลงเครื่องไม่สำเร็จ กรุณาตรวจสอบพื้นที่ว่างแล้วลองใหม่"
        }
    }

    private func thaiDateLabel(_ date: Date) -> String {
        AppDate.thaiDate(AppDate.dateKey(from: date))
    }

    private static func monthKey(from date: Date) -> String {
        AppDate.monthKey(from: date)
    }

    private static func dateKey(from date: Date) -> String {
        AppDate.dateKey(from: date)
    }

    private static func dateFromMonthKey(_ value: String) -> Date? {
        AppDate.date(fromStorageMonth: value)
    }

    private static func dateFromDateKey(_ value: String) -> Date? {
        AppDate.date(fromStorageDate: value)
    }

    private func removeSlip(at index: Int) {
        guard slipPaths.indices.contains(index) else { return }
        slipPaths.remove(at: index)
        slipPath = slipPaths.first ?? ""
        slipImportMessage = slipPaths.isEmpty ? nil : "มีรูปสลิปแนบ \(slipPaths.count) รูป"
    }

    private func importSlipImages(_ items: [PhotosPickerItem]) {
        guard !items.isEmpty else { return }

        isImportingSlip = true
        slipImportMessage = nil

        Task {
            do {
                var imported: [String] = []
                for item in items {
                    guard let data = try await item.loadTransferable(type: Data.self) else {
                        continue
                    }
                    imported.append(try SlipImageManager.saveImageData(data))
                }

                guard !imported.isEmpty else { throw CocoaError(.fileReadUnknown) }
                await MainActor.run {
                    slipPaths.append(contentsOf: imported)
                    slipPath = slipPaths.first ?? ""
                    selectedSlipItems = []
                    isImportingSlip = false
                    slipImportMessage = "เพิ่มรูปสลิปแล้ว \(imported.count) รูป"
                }
            } catch {
                await MainActor.run {
                    selectedSlipItems = []
                    isImportingSlip = false
                    slipImportMessage = "เพิ่มรูปสลิปไม่สำเร็จ"
                }
            }
        }
    }

    private func applyRoomTypeDefaults(onlyWhenEmpty: Bool = false) {
        if onlyWhenEmpty {
            let hasAnyManualFee = !rentFee.isEmpty || !waterFee.isEmpty || !electricFee.isEmpty || !commonFee.isEmpty
            guard !hasAnyManualFee else { return }
        }

        guard let room = rooms.first(where: { $0.roomNumber == roomNumber }),
              let type = roomTypes.first(where: { $0.name == room.roomType }) else { return }
        rentFee = PaymentAmounts.input(type.price)
        waterFee = PaymentAmounts.input(type.waterFee)
        electricFee = PaymentAmounts.input(type.electricFee)
        commonFee = PaymentAmounts.input(type.commonFee)
    }

    private func money(_ value: String) -> Double {
        Double(value.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
    }

    private func clean(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func normalizedSlipPaths(from payment: Payment?) -> [String] {
        guard let payment else { return [] }
        var paths = (payment.slipPathArray ?? [])
        if !payment.slipPath.isEmpty && !paths.contains(payment.slipPath) {
            paths.insert(payment.slipPath, at: 0)
        }
        return paths
    }
}

private struct PaymentEditorContextCard: View {
    let roomNumber: String
    let tenantName: String
    let roomType: String
    let month: String
    let planText: String
    let amount: Double
    let paidAmount: Double
    let status: String
    let statusColor: Color
    let slipCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(spacing: 3) {
                    Text(roomNumber)
                        .font(.custom("SukhumvitSet-Bold", size: 24))
                        .foregroundStyle(.primary)
                        .minimumScaleFactor(0.75)
                        .lineLimit(1)
                    Text("ห้อง")
                        .font(.custom("SukhumvitSet-Text", size: 11))
                        .foregroundStyle(.secondary)
                }
                .frame(width: 70, height: 62)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.primary.opacity(0.06))
                )

                VStack(alignment: .leading, spacing: 5) {
                    Text(tenantName)
                        .font(.custom("SukhumvitSet-Bold", size: 18))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Label(LocalizedStringKey(roomType), systemImage: "door.left.hand.open")
                        .font(.custom("SukhumvitSet-Text", size: 12))
                        .foregroundStyle(.secondary)
                    Label("รอบบิล \(AppDate.thaiMonth(month))", systemImage: "calendar")
                        .font(.custom("SukhumvitSet-Text", size: 12))
                        .foregroundStyle(.secondary)
                    Label(LocalizedStringKey(planText), systemImage: "doc.text")
                        .font(.custom("SukhumvitSet-Text", size: 12))
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)
            }

            HStack(spacing: 10) {
                contextPill(title: "ยอดรวม", value: currency(amount), color: .indigo)
                contextPill(title: "ชำระแล้ว", value: currency(paidAmount), color: .green)
            }

            HStack(spacing: 8) {
                Label(LocalizedStringKey(status), systemImage: "circle.fill")
                    .font(.custom("SukhumvitSet-Bold", size: 12))
                    .foregroundStyle(statusColor)
                    .padding(.horizontal, 10)
                    .frame(height: 30)
                    .background(statusColor.opacity(0.12), in: Capsule())

                Label("\(slipCount) รูปสลิป", systemImage: "photo.on.rectangle")
                    .font(.custom("SukhumvitSet-Medium", size: 12))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .frame(height: 30)
                    .background(Color.primary.opacity(0.06), in: Capsule())
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }

    private func contextPill(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(LocalizedStringKey(title))
                .font(.custom("SukhumvitSet-Text", size: 11))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.custom("SukhumvitSet-Bold", size: 15))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .frame(height: 58)
        .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func currency(_ amount: Double) -> String {
        let formatted = amount.formatted(.number.precision(.fractionLength(0)))
        return "\(formatted) บาท"
    }
}
