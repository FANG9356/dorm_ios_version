import SwiftUI

// รูปทรงโครงตึก 2 ตึกเชื่อมด้วยเส้นเดียวแบบต่อเนื่อง (Continuous Stroke)
struct TwinBuildingsOutline: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        let tallW: CGFloat = 52
        let gap: CGFloat = 6
        let smallW: CGFloat = 28
        let scaleX = rect.width / 86
        
        let smallH: CGFloat = 76
        let scaleY = rect.height / 100
        
        let r: CGFloat = 8 // มุมโค้ง
        
        // 1. เริ่มจากมุมล่างซ้ายสุดของตึกใหญ่
        path.move(to: CGPoint(x: 0, y: 100 * scaleY))
        
        // 2. ลากขึ้นไปหลังคาตึกใหญ่ฝั่งซ้าย
        path.addLine(to: CGPoint(x: 0, y: r * scaleY))
        path.addQuadCurve(to: CGPoint(x: r * scaleX, y: 0), control: CGPoint(x: 0, y: 0))
        
        // 3. ลากผ่านหลังคาตึกใหญ่ไปฝั่งขวา
        path.addLine(to: CGPoint(x: (tallW - r) * scaleX, y: 0))
        path.addQuadCurve(to: CGPoint(x: tallW * scaleX, y: r * scaleY), control: CGPoint(x: tallW * scaleX, y: 0))
        
        // 4. ลากลงมาที่พื้นของตึกใหญ่
        path.addLine(to: CGPoint(x: tallW * scaleX, y: 100 * scaleY))
        
        // 5. ลากเชื่อมตามพื้นไปยังตึกเล็ก (เพื่อให้เป็นเส้นเดียวกันไม่ขาดตอน)
        let smallStartX = tallW + gap
        path.addLine(to: CGPoint(x: smallStartX * scaleX, y: 100 * scaleY))
        
        // 6. ลากขึ้นไปหลังคาตึกเล็ก
        let smallTopY = 100 - smallH
        path.addLine(to: CGPoint(x: smallStartX * scaleX, y: (smallTopY + r) * scaleY))
        path.addQuadCurve(to: CGPoint(x: (smallStartX + r) * scaleX, y: smallTopY * scaleY), 
                          control: CGPoint(x: smallStartX * scaleX, y: smallTopY * scaleY))
        
        // 7. ลากผ่านหลังคาตึกเล็ก
        let smallEndX = smallStartX + smallW
        path.addLine(to: CGPoint(x: (smallEndX - r) * scaleX, y: smallTopY * scaleY))
        path.addQuadCurve(to: CGPoint(x: smallEndX * scaleX, y: (smallTopY + r) * scaleY), 
                          control: CGPoint(x: smallEndX * scaleX, y: smallTopY * scaleY))
        
        // 8. ลากลงมาจบที่มุมล่างขวาสุดของตึกเล็ก
        path.addLine(to: CGPoint(x: smallEndX * scaleX, y: 100 * scaleY))
        
        return path
    }
}

struct SplashView: View {
    @State private var isActive = false
    
    // ตึกใหญ่ฝั่งซ้าย (8 จุด)
    let scatteredOffsets: [CGSize] = [
        CGSize(width: -200, height: -250),
        CGSize(width: -100, height: -300),
        CGSize(width: -250, height: -80),
        CGSize(width: -150, height: -120),
        CGSize(width: -300, height: 80),
        CGSize(width: -200, height: 100),
        CGSize(width: -250, height: 250),
        CGSize(width: -100, height: 200)
    ]
    @State private var dotOffsets: [CGSize] = []
    @State private var dotOpacities: [Double] = Array(repeating: 0.0, count: 8)
    
    // ตึกเล็กฝั่งขวา (3 จุด)
    let scatteredOffsets2: [CGSize] = [
        CGSize(width: 250, height: -200),
        CGSize(width: 200, height: 50),
        CGSize(width: 300, height: 250)
    ]
    @State private var dotOffsets2: [CGSize] = []
    @State private var dotOpacities2: [Double] = Array(repeating: 0.0, count: 3)
    
    // เส้นเดียวที่วาดต่อเนื่องครอบทั้งสองตึก
    @State private var outlineProgress: CGFloat = 0.0
    
    init() {
        _dotOffsets = State(initialValue: scatteredOffsets)
        _dotOffsets2 = State(initialValue: scatteredOffsets2)
    }
    
    var body: some View {
        ZStack {
            if isActive {
                ContentView()
                    .transition(.opacity)
            } else {
                ZStack {
                    // พื้นหลัง
                    Color(red: 0.95, green: 0.96, blue: 0.98).ignoresSafeArea()
                    
                    // กรอบรวมขนาด 86x100 เพื่อให้จุดและเส้นครอบซ้อนกันตรงเป๊ะ
                    ZStack(alignment: .bottomLeading) {
                        
                        // 1. หน้าต่างตึกใหญ่ 8 บาน
                        LazyVGrid(columns: [GridItem(.fixed(16)), GridItem(.fixed(16))], spacing: 10) {
                            ForEach(0..<8, id: \.self) { index in
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.indigo)
                                    .frame(width: 14, height: 14)
                                    .offset(dotOffsets[index])
                                    .opacity(dotOpacities[index])
                            }
                        }
                        .frame(width: 38, height: 86)
                        .offset(x: 7, y: -7) // Padding 7px
                        
                        // 2. หน้าต่างตึกเล็ก 3 บาน
                        LazyVGrid(columns: [GridItem(.fixed(16))], spacing: 10) {
                            ForEach(0..<3, id: \.self) { index in
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.indigo)
                                    .frame(width: 14, height: 14)
                                    .offset(dotOffsets2[index])
                                    .opacity(dotOpacities2[index])
                            }
                        }
                        .frame(width: 14, height: 62)
                        .offset(x: 65, y: -7) // 52 (ตึกซ้าย) + 6 (ช่องว่าง) + 7 (Padding) = 65
                        
                        // 3. เส้นเดียววาดต่อเนื่องรอบ 2 ตึก
                        TwinBuildingsOutline()
                            .trim(from: 0, to: outlineProgress)
                            .stroke(Color.indigo, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                            .frame(width: 86, height: 100)
                    }
                }
                .transition(.opacity)
                .onAppear {
                    // เฟส 1: หน้าต่างทั้งสองตึกบินเข้ามา (ช้าลงและนุ่มขึ้น)
                    for i in 0..<8 {
                        withAnimation(.spring(response: 0.9, dampingFraction: 0.7).delay(Double(i) * 0.08)) {
                            dotOffsets[i] = .zero
                            dotOpacities[i] = 1.0
                        }
                    }
                    for i in 0..<3 {
                        withAnimation(.spring(response: 0.9, dampingFraction: 0.7).delay(Double(i) * 0.12 + 0.2)) {
                            dotOffsets2[i] = .zero
                            dotOpacities2[i] = 1.0
                        }
                    }
                    
                    // เฟส 2: วาดเส้นโครงตึกต่อเนื่องเป็นเส้นเดียว (วาดช้าลงและละมุนขึ้น)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        withAnimation(.easeInOut(duration: 1.5)) {
                            outlineProgress = 1.0
                        }
                    }
                    
                    // เฟส 3: เส้นย้อนกลับ และจุดบินกลับที่เดิม (ค้างไว้ให้ดูนานขึ้น แล้วค่อยคลายออกช้าๆ)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                        // วาดลบเส้นย้อนกลับแบบช้าๆ
                        withAnimation(.easeInOut(duration: 1.2)) {
                            outlineProgress = 0.0
                        }
                        
                        // จุดตึกซ้ายบินออกแบบช้าๆ
                        for i in 0..<8 {
                            withAnimation(.spring(response: 0.9, dampingFraction: 0.8).delay(Double(7 - i) * 0.05)) {
                                dotOffsets[i] = scatteredOffsets[i]
                                dotOpacities[i] = 0.0
                            }
                        }
                        // จุดตึกขวาบินออกแบบช้าๆ
                        for i in 0..<3 {
                            withAnimation(.spring(response: 0.9, dampingFraction: 0.8).delay(Double(2 - i) * 0.07)) {
                                dotOffsets2[i] = scatteredOffsets2[i]
                                dotOpacities2[i] = 0.0
                            }
                        }
                    }
                    
                    // เฟส 4: สลับเข้าสู่แอพหลัก
                    DispatchQueue.main.asyncAfter(deadline: .now() + 5.8) {
                        isActive = true
                    }
                }
            }
        }
        // ทำให้ตอนตัดฉากเข้าหน้า Login หรือกลับกัน ค่อยๆ เฟดแบบนุ่มนวล
        .animation(.easeInOut(duration: 1.2), value: isActive)
    }
}
