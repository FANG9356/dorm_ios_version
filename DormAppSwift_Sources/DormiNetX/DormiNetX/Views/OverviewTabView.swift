import SwiftUI
import Charts
// MARK: - Overview Tab View
struct OverviewTabView: View {
    @StateObject private var viewModel = DashboardViewModel()
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                HStack {
                    Text("ข้อมูลเชิงลึกและสถานะการดำเนินงานของระบบ")
                        .font(.custom("SukhumvitSet-Medium", size: 14))
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    if viewModel.isLoading {
                        ProgressView()
                    }
                }
                .padding(.horizontal, 20)
                
                if let error = viewModel.errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.custom("SukhumvitSet-Text", size: 14))
                }
                
                // KPIs
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 15) {
                    // KPI 1: Occupancy Rate
                    let totalRooms = viewModel.stats.total_residents + viewModel.stats.empty_rooms
                    let occRate = totalRooms > 0 ? (Double(viewModel.stats.total_residents) / Double(totalRooms)) * 100 : 0
                    GlassSummaryCard(title: "อัตราการเข้าพัก", value: "\(String(format: "%.0f", occRate))%", icon: "person.2.fill", color: .blue)
                    
                    // KPI 2: Room Status
                    GlassSummaryCard(title: "ห้องว่าง", value: "\(viewModel.stats.empty_rooms)", icon: "bed.double.fill", color: .indigo)
                    
                    // KPI 3: Income
                    GlassSummaryCard(title: "เงินสดรับเดือนนี้", value: String(format: "฿%.1fk", viewModel.stats.income_this_month / 1000.0), icon: "banknote.fill", color: .green)
                    
                    // KPI 4: Billing Cycle
                    GlassSummaryCard(title: "ยอดเก็บรอบบิลนี้", value: String(format: "฿%.1fk", viewModel.stats.billing_cycle_income / 1000.0), icon: "doc.text.fill", color: .cyan)
                    
                    // KPI 5: Deposit
                    GlassSummaryCard(title: "มัดจำแรกเข้า", value: String(format: "฿%.1fk", viewModel.depositThisMonth / 1000.0), icon: "archivebox.fill", color: .orange)
                    
                    // KPI 6: Pending
                    GlassSummaryCard(title: "บิลค้างชำระ", value: "\(viewModel.stats.pending_bills)", icon: "exclamationmark.triangle.fill", color: viewModel.stats.pending_bills > 0 ? .red : .gray)
                }
                .padding(.horizontal, 20)
                
                // Charts Section
                VStack(spacing: 20) {
                    // Revenue Chart
                    GlassCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Label("แนวโน้มรายรับทางการเงิน", systemImage: "chart.line.uptrend.xyaxis")
                                .font(.custom("SukhumvitSet-Bold", size: 14))
                                .foregroundColor(.green)
                            
                            Chart(viewModel.financialStats) { stat in
                                AreaMark(
                                    x: .value("เดือน", stat.name),
                                    y: .value("รายรับ", stat.income)
                                )
                                .foregroundStyle(LinearGradient(colors: [Color.green.opacity(0.6), Color.green.opacity(0.0)], startPoint: .top, endPoint: .bottom))
                                
                                LineMark(
                                    x: .value("เดือน", stat.name),
                                    y: .value("รายรับ", stat.income)
                                )
                                .foregroundStyle(Color.green)
                            }
                            .frame(height: 180)
                            .chartYAxis {
                                AxisMarks(position: .leading) { value in
                                    AxisValueLabel() {
                                        if let intValue = value.as(Double.self) {
                                            Text("฿\(Int(intValue/1000))k")
                                                .font(.custom("SukhumvitSet-Text", size: 10))
                                        }
                                    }
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                    }
                    
                    // Move-in Chart
                    GlassCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Label("สถิติผู้เช่าใหม่รายเดือน", systemImage: "person.crop.circle.badge.plus")
                                .font(.custom("SukhumvitSet-Bold", size: 14))
                                .foregroundColor(.blue)
                            
                            Chart(viewModel.moveInStats) { stat in
                                BarMark(
                                    x: .value("เดือน", stat.name),
                                    y: .value("จำนวน", stat.newResidents)
                                )
                                .foregroundStyle(Color.blue)
                                .cornerRadius(4)
                            }
                            .frame(height: 180)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                    }
                    
                    // Occupancy Chart
                    GlassCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Label("สถานะห้องพัก", systemImage: "bed.double.fill")
                                .font(.custom("SukhumvitSet-Bold", size: 14))
                                .foregroundColor(.indigo)
                            
                            let totalRooms = viewModel.stats.total_residents + viewModel.stats.empty_rooms
                            let occData: [(String, Int, Color)] = [
                                ("มีผู้เช่า", viewModel.stats.total_residents, .blue),
                                ("ห้องว่าง", viewModel.stats.empty_rooms, .gray)
                            ]
                            
                            if totalRooms > 0 {
                                Chart(occData, id: \.0) { item in
                                    SectorMark(
                                        angle: .value("จำนวน", item.1),
                                        innerRadius: .ratio(0.6),
                                        angularInset: 1.5
                                    )
                                    .foregroundStyle(item.2)
                                    .cornerRadius(5)
                                }
                                .frame(height: 180)
                                .chartLegend(position: .bottom, alignment: .center)
                            } else {
                                Text("ไม่มีข้อมูลห้องพัก")
                                    .font(.custom("SukhumvitSet-Text", size: 12))
                                    .foregroundColor(.secondary)
                                    .frame(height: 180)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                    }
                    
                    // Maintenance Chart
                    GlassCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Label("สถิติการแจ้งซ่อม", systemImage: "wrench.and.screwdriver.fill")
                                .font(.custom("SukhumvitSet-Bold", size: 14))
                                .foregroundColor(.orange)
                            
                            let maintData: [(String, Int, Color)] = [
                                ("รอดำเนินการ", viewModel.pendingMaints, .red),
                                ("กำลังซ่อม", viewModel.inProgressMaints, .orange),
                                ("เสร็จสิ้น", viewModel.completedMaints, .green)
                            ]
                            
                            Chart(maintData, id: \.0) { item in
                                BarMark(
                                    x: .value("สถานะ", item.0),
                                    y: .value("จำนวน", item.1)
                                )
                                .foregroundStyle(item.2)
                                .cornerRadius(4)
                            }
                            .frame(height: 180)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                    }
                }
                .padding(.horizontal, 20)
                
                // Lists Section
                VStack(spacing: 20) {
                    // Pending Bills
                    GlassCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Label("รอชำระเงิน (\(viewModel.pendingUsers.count))", systemImage: "clock.fill")
                                .font(.custom("SukhumvitSet-Bold", size: 14))
                                .foregroundColor(.red)
                            
                            if viewModel.pendingUsers.isEmpty {
                                Text("ไม่มีบิลค้างชำระ")
                                    .font(.custom("SukhumvitSet-Text", size: 12))
                                    .foregroundColor(.secondary)
                                    .padding(.vertical, 10)
                            } else {
                                ForEach(viewModel.pendingUsers) { user in
                                    HStack {
                                        Text("ห้อง \(user.room_number ?? "-")")
                                            .font(.custom("SukhumvitSet-Bold", size: 14))
                                        Spacer()
                                        Text("รอชำระ")
                                            .font(.custom("SukhumvitSet-Medium", size: 12))
                                            .foregroundColor(.red)
                                    }
                                    Divider()
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
            }
            .padding(.top, 110)
        }
        .background(Color("AppBackground").ignoresSafeArea())
        .onAppear {
            Task {
                await viewModel.fetchAllData()
            }
        }
    }
}
