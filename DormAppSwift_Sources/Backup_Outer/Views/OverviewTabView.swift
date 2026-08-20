import SwiftUI
import Charts

// Models for Charts
struct RevenueData: Identifiable {
    var id = UUID()
    var month: String
    var amount: Double
}

struct OccupancyData: Identifiable {
    var id = UUID()
    var type: String
    var count: Int
}

struct OverviewTabView: View {
    // Sample Data
    let revenueData = [
        RevenueData(month: "Jan", amount: 150000),
        RevenueData(month: "Feb", amount: 145000),
        RevenueData(month: "Mar", amount: 160000),
        RevenueData(month: "Apr", amount: 158000),
        RevenueData(month: "May", amount: 165000)
    ]
    
    let occupancyData = [
        OccupancyData(type: "ว่าง", count: 12),
        OccupancyData(type: "มีผู้เช่า", count: 68),
        OccupancyData(type: "ค้างชำระ", count: 5)
    ]
    
    var body: some View {
        VStack(spacing: 20) {

            
            // Summary Cards
            HStack(spacing: 15) {
                GlassSummaryCard(title: "รายได้เดือนนี้", value: "฿ 165,000", icon: "arrow.up.right.circle.fill", color: .green)
                GlassSummaryCard(title: "ห้องว่าง", value: "12", icon: "bed.double.fill", color: .blue)
            }
            .padding(.horizontal, 20)
            
            // Bar Chart: Revenue
            GlassCard {
                VStack(alignment: .leading, spacing: 10) {
                    Text("สถิติรายได้ (5 เดือนล่าสุด)")
                        .font(.custom("SukhumvitSet-Bold", size: 17))
                        .foregroundColor(.primary)
                    
                    Chart(revenueData) { item in
                        BarMark(
                            x: .value("เดือน", item.month),
                            y: .value("รายได้", item.amount)
                        )
                        .foregroundStyle(LinearGradient(colors: [.indigo, .purple], startPoint: .bottom, endPoint: .top))
                        .cornerRadius(8)
                    }
                    .frame(height: 200)
                    .chartYAxis {
                        AxisMarks(position: .leading)
                    }
                }
                .padding()
            }
            .padding(.horizontal, 20)
            
            // Pie Chart / Bar: Occupancy
            GlassCard {
                VStack(alignment: .leading, spacing: 10) {
                    Text("สถานะห้องพักทั้งหมด (85 ห้อง)")
                        .font(.custom("SukhumvitSet-Bold", size: 17))
                        .foregroundColor(.primary)
                    
                    Chart(occupancyData) { item in
                        SectorMark(
                            angle: .value("จำนวน", item.count),
                            innerRadius: .ratio(0.6),
                            angularInset: 1.5
                        )
                        .foregroundStyle(by: .value("สถานะ", item.type))
                        .cornerRadius(5)
                    }
                    .frame(height: 200)
                    .chartLegend(position: .bottom, alignment: .center)
                }
                .padding()
            }
            .padding(.horizontal, 20)
            
            Spacer().frame(height: 40)
        }
        .padding(.top, 110) // Push content below the floating header
    }
}
