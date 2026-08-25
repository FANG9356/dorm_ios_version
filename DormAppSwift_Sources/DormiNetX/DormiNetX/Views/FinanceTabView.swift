import SwiftUI
import SwiftData

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
                        Button("รับชำระเต็มจำนวน", action: onMarkPaid)
                            .font(.custom("SukhumvitSet-Bold", size: 10))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(Color.green.opacity(0.16), in: Capsule())
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
        _slipPath = State(initialValue: payment?.slipPath ?? "")
        _dueDate = State(initialValue: payment?.dueDate ?? "")
        _paymentDate = State(initialValue: payment?.paymentDate ?? "")
        _paymentStatus = State(initialValue: payment?.paymentStatus.isEmpty == false ? payment?.paymentStatus ?? "pending" : "pending")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("รอบบิล") {
                    if rooms.isEmpty {
                        TextField("เลขห้อง", text: $roomNumber)
                            .limitedText($roomNumber, maxLength: 10, trimNewlines: true)
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
                    TextField("เดือน เช่น 2026-08", text: $month)
                        .keyboardType(.numbersAndPunctuation)
                        .dateKeyInput($month, maxLength: 7)
                    TextField("วันครบกำหนด เช่น 2026-08-31", text: $dueDate)
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
                    Picker("สถานะ", selection: $paymentStatus) {
                        ForEach(statusOptions, id: \.0) { value, title in
                            Text(title).tag(value)
                        }
                    }
                    TextField("ยอดที่ชำระแล้ว", text: $paidAmount)
                        .keyboardType(.decimalPad)
                        .decimalInput($paidAmount, maxIntegerDigits: 9, maxFractionDigits: 2)
                    TextField("ช่องทางชำระเงิน", text: $method)
                        .limitedText($method, maxLength: 60, trimNewlines: true)
                    TextField("วันที่ชำระ เช่น 2026-08-23", text: $paymentDate)
                        .keyboardType(.numbersAndPunctuation)
                        .dateKeyInput($paymentDate)
                    TextField("ลิงก์/ชื่อไฟล์สลิป", text: $slipPath)
                        .limitedText($slipPath, maxLength: 200, trimNewlines: true)
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
                        item.slipPath = clean(slipPath)
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
            .dismissKeyboardOnTap()
            .scrollDismissesKeyboard(.interactively)
            .onAppear {
                applyRoomTypeDefaults(onlyWhenEmpty: true)
            }
        }
        .presentationDetents([.medium, .large], selection: $selectedDetent)
        .presentationDragIndicator(.visible)
    }

    private var totalAmount: Double {
        money(rentFee) + money(waterFee) + money(electricFee) + money(commonFee) + money(lateFee) + money(applianceFee)
    }

    private func moneyField(_ title: String, text: Binding<String>) -> some View {
        TextField(title, text: text)
            .keyboardType(.decimalPad)
            .decimalInput(text, maxIntegerDigits: 9, maxFractionDigits: 2)
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
}
