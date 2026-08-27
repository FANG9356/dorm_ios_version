import SwiftUI
import SwiftData
import PhotosUI

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
    @State private var editingPayment: Payment?
    @State private var deletingPayment: Payment?

    private let statuses = ["ทั้งหมด", "ชำระแล้ว", "รอชำระ", "ชำระบางส่วน"]
    private var payments: [Payment] { allPayments.filter { !$0.isDeletedLocally } }
    private var rooms: [Room] { allRooms.filter { !$0.isDeletedLocally } }

    var body: some View {
        VStack(spacing: 16) {
            header
            summaryGrid
            filters
            paymentList
        }
        .padding(.top, 106)
        .padding(.horizontal, 20)
        .padding(.bottom, 32)
        .sheet(isPresented: $showingPaymentEditor) {
            PaymentEditor(users: users, rooms: rooms, roomTypes: roomTypes, defaultMonth: monthKey) { payment in
                payment.isDirty = true
                payment.lastUpdated = Date()
                modelContext.insert(payment)
                saveAndPush()
            }
            .iphoneSheetStyle()
        }
        .sheet(item: $editingPayment) { payment in
            PaymentEditor(payment: payment, users: users, rooms: rooms, roomTypes: roomTypes, defaultMonth: monthKey) { draft in
                apply(draft, to: payment)
                saveAndPush()
            }
            .iphoneSheetStyle()
        }
        .confirmationDialog("ลบรายการชำระเงินนี้หรือไม่", isPresented: deleteDialogBinding) {
            Button("ลบรายการห้อง \(deletingPayment?.roomNumber ?? "")", role: .destructive) {
                guard let payment = deletingPayment else { return }
                payment.isDeletedLocally = true
                payment.isDirty = true
                payment.lastUpdated = Date()
                saveAndPush()
                deletingPayment = nil
            }
            Button("ยกเลิก", role: .cancel) { }
        }
        .onAppear {
            ensurePaymentsForSelectedMonth()
        }
        .onChange(of: selectedMonth) { _, _ in
            ensurePaymentsForSelectedMonth()
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
        let monthPayments = payments.filter { $0.month == monthKey }
        let received = monthPayments.filter { $0.paymentStatus == "paid" }.reduce(0) { $0 + $1.paidAmount }
        let pending = monthPayments.filter { $0.paymentStatus == "pending" }.reduce(0) { $0 + $1.amount }
        let partial = monthPayments.filter { $0.paymentStatus == "partial" }.reduce(0) { $0 + $1.paidAmount }

        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            FinanceSummaryCard(title: "รับแล้ว", amount: received, color: .green, icon: "checkmark.circle.fill")
            FinanceSummaryCard(title: "ค้างชำระ", amount: pending, color: .orange, icon: "clock.fill")
            FinanceSummaryCard(title: "ชำระบางส่วน", amount: partial, color: .blue, icon: "circle.lefthalf.filled")
            FinanceSummaryCard(title: "รายการทั้งหมด", amount: Double(monthPayments.count), color: .indigo, icon: "list.bullet.rectangle.fill", isCount: true)
        }
    }

    private var filters: some View {
        GlassCard {
            VStack(spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("ค้นหาห้องหรือชื่อลูกบ้าน", text: $searchText)
                        .font(.custom("SukhumvitSet-Text", size: 13))

                    DatePicker("", selection: $selectedMonth, displayedComponents: [.date])
                        .labelsHidden()
                        .environment(\.locale, Locale(identifier: "th_TH"))
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(statuses, id: \.self) { status in
                            Button(status) {
                                selectedStatus = status
                            }
                            .font(.custom("SukhumvitSet-Medium", size: 11))
                            .foregroundStyle(selectedStatus == status ? .white : .secondary)
                            .padding(.horizontal, 13)
                            .padding(.vertical, 8)
                            .background(selectedStatus == status ? Color.indigo : Color.primary.opacity(0.07), in: Capsule())
                        }
                    }
                }
            }
        }
    }

    private var paymentList: some View {
        let visiblePayments = payments.filter { payment in
            let matchesMonth = payment.month == monthKey
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
                            .font(.system(size: 30))
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
                        onEdit: { editingPayment = payment },
                        onDelete: { deletingPayment = payment }
                    )
                }
            }
        }
    }

    private var monthKey: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: selectedMonth)
    }

    private func userFor(_ payment: Payment) -> DormUser? {
        users.first { $0.serverId == payment.userId && payment.userId > 0 } ?? users.first { $0.roomNumber == payment.roomNumber }
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
        saveAndPush()
    }

    private func apply(_ draft: Payment, to payment: Payment) {
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

    private func ensurePaymentsForSelectedMonth() {
        let activeUsers = users.filter {
            !$0.isDeletedLocally &&
            !$0.roomNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            $0.status != "ย้ายออกแล้ว"
        }
        guard !activeUsers.isEmpty else { return }

        var didCreate = false
        for user in activeUsers {
            guard shouldCreatePayment(for: user, month: monthKey),
                  !payments.contains(where: { payment in
                      payment.month == monthKey &&
                      clean(payment.roomNumber) == clean(user.roomNumber)
                  }) else {
                continue
            }

            let payment = generatedPayment(for: user, month: monthKey)
            modelContext.insert(payment)
            didCreate = true
        }

        guard didCreate else { return }
        saveAndPush()
    }

    private func shouldCreatePayment(for user: DormUser, month: String) -> Bool {
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
        let amount = isBooking ? user.deposit : rent + (isMoveInMonth ? user.deposit : 0)

        payment.userId = user.serverId ?? Int(truncatingIfNeeded: user.id.hashValue)
        payment.roomNumber = user.roomNumber
        payment.rentFee = isBooking ? user.deposit : rent
        payment.waterFee = 0
        payment.electricFee = 0
        payment.commonFee = 0
        payment.lateFee = 0
        payment.applianceFee = 0
        payment.amount = amount
        payment.method = paymentMethodLabel(for: user)
        payment.slipPath = user.bookingSlips.first ?? ""
        payment.slipPathArray = user.bookingSlips
        payment.paymentPlan = user.paymentMethod
        payment.installmentPhase = user.installmentMonths
        payment.dueDate = dueDateKey(for: month)
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
        String(user.moveInDate.prefix(7))
    }

    private func dueDateKey(for month: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        guard let date = formatter.date(from: "\(month)-01") else { return "" }

        var components = Calendar(identifier: .gregorian).dateComponents([.year, .month], from: date)
        components.month = (components.month ?? 1) + 1
        components.day = 0
        let dueDate = Calendar(identifier: .gregorian).date(from: components) ?? date
        return formatter.string(from: dueDate)
    }

    private func clean(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func currentDateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
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
                    Text(title)
                        .font(.custom("SukhumvitSet-Medium", size: 11))
                        .foregroundStyle(.secondary)
                }

                Text(isCount ? String(Int(amount)) : amount.formatted(.number.precision(.fractionLength(0))))
                    .font(.custom("SukhumvitSet-Bold", size: 21))
                    .foregroundStyle(.primary)
                if !isCount {
                    Text("บาท")
                        .font(.custom("SukhumvitSet-Text", size: 10))
                        .foregroundStyle(.secondary)
                }
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
                            .font(.system(size: 12))
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
                        Text(status)
                            .font(.custom("SukhumvitSet-Medium", size: 10))
                            .foregroundStyle(statusColor)
                    }
                }

                HStack {
                    if payment.paymentStatus != "paid" {
                        Button(action: onMarkPaid) {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 13, weight: .bold))
                                Text("รับชำระเต็มจำนวน")
                                    .font(.custom("SukhumvitSet-Bold", size: 12))
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 10, weight: .bold))
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
    let onSave: (Payment) -> Void

    @State private var roomNumber: String
    @State private var month: String
    @State private var rentFee: String
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

    private let statusOptions = [
        ("pending", "รอชำระ"),
        ("partial", "ชำระบางส่วน"),
        ("paid", "ชำระแล้ว")
    ]

    init(payment: Payment? = nil, users: [DormUser], rooms: [Room], roomTypes: [RoomType], defaultMonth: String, onSave: @escaping (Payment) -> Void) {
        self.users = users
        self.rooms = rooms
        self.roomTypes = roomTypes
        self.defaultMonth = defaultMonth
        self.onSave = onSave
        _roomNumber = State(initialValue: payment?.roomNumber ?? rooms.first?.roomNumber ?? users.first?.roomNumber ?? "")
        _month = State(initialValue: payment?.month ?? defaultMonth)
        _rentFee = State(initialValue: payment.map { String(format: "%.0f", $0.rentFee) } ?? "")
        _waterFee = State(initialValue: payment.map { String(format: "%.0f", $0.waterFee) } ?? "")
        _electricFee = State(initialValue: payment.map { String(format: "%.0f", $0.electricFee) } ?? "")
        _commonFee = State(initialValue: payment.map { String(format: "%.0f", $0.commonFee) } ?? "")
        _lateFee = State(initialValue: payment.map { String(format: "%.0f", $0.lateFee) } ?? "")
        _applianceFee = State(initialValue: payment.map { String(format: "%.0f", $0.applianceFee) } ?? "")
        _paidAmount = State(initialValue: payment.map { String(format: "%.0f", $0.paidAmount) } ?? "")
        _method = State(initialValue: payment?.method ?? "")
        let initialSlipPaths = Self.normalizedSlipPaths(from: payment)
        _slipPath = State(initialValue: initialSlipPaths.first ?? "")
        _slipPaths = State(initialValue: initialSlipPaths)
        _dueDate = State(initialValue: payment?.dueDate ?? "")
        _paymentDate = State(initialValue: payment?.paymentDate ?? "")
        _paymentStatus = State(initialValue: payment?.paymentStatus.isEmpty == false ? payment?.paymentStatus ?? "pending" : "pending")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("รอบบิล") {
                    if rooms.isEmpty {
                        labeledTextField("เลขห้อง", placeholder: "เช่น 101", text: $roomNumber)
                    } else {
                        Picker("ห้อง", selection: $roomNumber) {
                            ForEach(rooms) { room in
                                Text(room.roomNumber).tag(room.roomNumber)
                            }
                        }
                        .onChange(of: roomNumber) { _, _ in
                            applyRoomTypeDefaults(onlyWhenEmpty: true)
                        }
                        Button("ใช้ราคาตามประเภทห้อง") {
                            applyRoomTypeDefaults()
                        }
                    }
                    labeledTextField("รอบเดือน", placeholder: "เช่น 2026-08", text: $month)
                        .keyboardType(.numbersAndPunctuation)
                        .dateKeyInput($month, maxLength: 7)
                    labeledTextField("วันครบกำหนด", placeholder: "เช่น 2026-08-31", text: $dueDate)
                        .keyboardType(.numbersAndPunctuation)
                        .dateKeyInput($dueDate)
                }

                Section("ค่าใช้จ่าย") {
                    moneyField("ค่าเช่า", text: $rentFee)
                    moneyField("ค่าน้ำ", text: $waterFee)
                    moneyField("ค่าไฟ", text: $electricFee)
                    moneyField("ค่าส่วนกลาง", text: $commonFee)
                    moneyField("ค่าปรับล่าช้า", text: $lateFee)
                    moneyField("ค่าอุปกรณ์เสริม", text: $applianceFee)
                    HStack {
                        Text("ยอดรวม")
                        Spacer()
                        Text(totalAmount.formatted(.number.precision(.fractionLength(0))) + " ฿")
                            .fontWeight(.semibold)
                    }
                }

                Section("การชำระเงิน") {
                    statusSelector
                    labeledTextField("ยอดที่ชำระแล้ว", placeholder: "0", text: $paidAmount)
                        .keyboardType(.decimalPad)
                        .decimalInput($paidAmount, maxIntegerDigits: 9, maxFractionDigits: 2)
                    labeledTextField("ช่องทางชำระเงิน", placeholder: "เช่น เงินสด หรือ โอนผ่านธนาคาร", text: $method)
                        .limitedText($method, maxLength: 60, trimNewlines: true)
                    labeledTextField("วันที่ชำระ", placeholder: "เช่น 2026-08-23", text: $paymentDate)
                        .keyboardType(.numbersAndPunctuation)
                        .dateKeyInput($paymentDate)
                    slipPickerContent
                }
            }
            .navigationTitle("รายการชำระเงิน")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("ยกเลิก") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("บันทึก") {
                        let item = Payment(month: clean(month), amount: totalAmount)
                        item.roomNumber = clean(roomNumber)
                        if let tenant = users.first(where: { $0.roomNumber == item.roomNumber }) {
                            item.userId = tenant.serverId ?? Int(truncatingIfNeeded: tenant.id.hashValue)
                        } else {
                            item.userId = 0
                        }
                        item.rentFee = money(rentFee)
                        item.waterFee = money(waterFee)
                        item.electricFee = money(electricFee)
                        item.commonFee = money(commonFee)
                        item.lateFee = money(lateFee)
                        item.applianceFee = money(applianceFee)
                        item.paidAmount = paymentStatus == "paid" && money(paidAmount) == 0 ? totalAmount : money(paidAmount)
                        item.method = clean(method)
                        item.slipPath = slipPaths.first ?? clean(slipPath)
                        item.slipPathArray = slipPaths
                        item.dueDate = clean(dueDate)
                        item.paymentDate = clean(paymentDate)
                        item.paymentStatus = paymentStatus
                        onSave(item)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(clean(roomNumber).isEmpty || clean(month).isEmpty)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .onAppear {
                applyRoomTypeDefaults(onlyWhenEmpty: true)
            }
        }
        .presentationDetents([.medium, .large], selection: $selectedDetent)
        .presentationDragIndicator(.visible)
    }

    private var statusSelector: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("สถานะ")
                .font(.custom("SukhumvitSet-Medium", size: 13))
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                ForEach(statusOptions, id: \.0) { value, title in
                    Button {
                        paymentStatus = value
                        if value == "paid", money(paidAmount) == 0 {
                            paidAmount = String(format: "%.0f", totalAmount)
                        } else if value == "pending" {
                            paidAmount = "0"
                        }
                    } label: {
                        Text(title)
                            .font(.custom("SukhumvitSet-Bold", size: 12))
                            .foregroundStyle(paymentStatus == value ? Color.white : Color.primary.opacity(0.72))
                            .frame(maxWidth: .infinity)
                            .frame(height: 38)
                            .background(
                                Capsule()
                                    .fill(paymentStatus == value ? Color.indigo : Color.primary.opacity(0.07))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.vertical, 4)
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
                                        .font(.system(size: 10, weight: .bold))
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
                            .font(.system(size: 17, weight: .bold))
                    }

                    Text(slipPaths.isEmpty ? "เพิ่มรูปสลิป" : "เพิ่มรูปสลิปอีก")
                        .font(.custom("SukhumvitSet-Bold", size: 15))

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.secondary)
                }
                .foregroundStyle(.blue)
                .frame(maxWidth: .infinity, minHeight: 44)
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
        money(rentFee) + money(waterFee) + money(electricFee) + money(commonFee) + money(lateFee) + money(applianceFee)
    }

    private func moneyField(_ title: String, text: Binding<String>) -> some View {
        labeledTextField(title, placeholder: "0", text: text)
            .keyboardType(.decimalPad)
            .decimalInput(text, maxIntegerDigits: 9, maxFractionDigits: 2)
    }

    private func labeledTextField(_ title: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.custom("SukhumvitSet-Medium", size: 12))
                    .foregroundStyle(.secondary)
                Image(systemName: "pencil")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary.opacity(0.8))
            }

            TextField(placeholder, text: text)
                .font(.custom("SukhumvitSet-Text", size: 16))
                .foregroundStyle(.primary)
                .padding(.horizontal, 12)
                .frame(minHeight: 44)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.primary.opacity(0.06))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                )
                .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .padding(.vertical, 6)
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
        rentFee = String(format: "%.0f", type.price)
        waterFee = String(format: "%.0f", type.waterFee)
        electricFee = String(format: "%.0f", type.electricFee)
        commonFee = String(format: "%.0f", type.commonFee)
    }

    private func money(_ value: String) -> Double {
        Double(value.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
    }

    private func clean(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func normalizedSlipPaths(from payment: Payment?) -> [String] {
        guard let payment else { return [] }
        var paths = payment.slipPathArray
        if !payment.slipPath.isEmpty && !paths.contains(payment.slipPath) {
            paths.insert(payment.slipPath, at: 0)
        }
        return paths
    }
}
