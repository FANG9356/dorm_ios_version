import re

filepath = "/Volumes/FangB/dorm_project/DormAppSwift_Sources/DormiNetX/DormiNetX/Views/MaintenanceTabView.swift"

with open(filepath, 'r') as f:
    content = f.read()

# 1. Update MaintenanceRow
row_patch = """
    private var hasCost: Bool {
        maintenance.cost > 0 || ["รออนุมัติค่าใช้จ่าย", "ปฏิเสธค่าใช้จ่าย", "รอตรวจสอบชำระเงิน"].contains(maintenance.status)
    }

    private var currentStatusIndex: Int {
        MaintenanceWorkflow.statuses(hasCost: hasCost).firstIndex(of: status) ?? 0
    }
"""
content = re.sub(
    r'    private var currentStatusIndex: Int \{\n        MaintenanceWorkflow\.statuses.*?\}',
    row_patch.strip('\n'),
    content,
    flags=re.DOTALL
)

# In MaintenanceRow body, replace MaintenanceProgressView(currentIndex: currentStatusIndex) with MaintenanceProgressView(currentIndex: currentStatusIndex, hasCost: hasCost)
content = re.sub(
    r'MaintenanceProgressView\(currentIndex: currentStatusIndex\)',
    r'MaintenanceProgressView(currentIndex: currentStatusIndex, hasCost: hasCost)',
    content
)

# 2. Update MaintenanceProgressView
prog_patch = """private struct MaintenanceProgressView: View {
    let currentIndex: Int
    let hasCost: Bool

    private var currentFlow: [String] {
        MaintenanceWorkflow.statuses(hasCost: hasCost)
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 0) {
                ForEach(Array(currentFlow.indices), id: \.self) { index in
                    HStack(spacing: 0) {
                        Rectangle()
                            .fill(index == 0 ? Color.clear : connectorColor(at: index - 1))
                            .frame(height: 2)

                        Circle()
                            .fill(dotFill(at: index))
                            .frame(width: index == currentIndex ? 13 : 9, height: index == currentIndex ? 13 : 9)
                            .overlay {
                                if index == currentIndex {
                                    Circle()
                                        .stroke(Color.indigo.opacity(0.28), lineWidth: 5)
                                }
                            }

                        Rectangle()
                            .fill(index == currentFlow.count - 1 ? Color.clear : connectorColor(at: index))
                            .frame(height: 2)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 18)

            HStack(spacing: 0) {
                ForEach(Array(currentFlow.enumerated()), id: \.offset) { index, item in
                    Text(MaintenanceWorkflow.shortTitle(for: item))
                        .font(.custom("SukhumvitSet-Medium", size: 12))
                        .foregroundStyle(index == currentIndex ? Color.primary : Color.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.68)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }"""
content = re.sub(
    r'private struct MaintenanceProgressView: View \{.*?        \}\n    \}',
    prog_patch,
    content,
    flags=re.DOTALL,
    count=1
)

# 3. Update MaintenanceEditor State and init
editor_init_search = r'    @State private var quoteApprovedAt: String\n    @State private var selectedDetent: PresentationDetent = .large'
editor_init_replace = r"""    @State private var quoteApprovedAt: String
    @State private var hasCost: Bool
    @State private var selectedDetent: PresentationDetent = .large"""
content = content.replace(editor_init_search, editor_init_replace)

editor_init_setup_search = r'_quoteApprovedAt = State\(initialValue: maintenance\?\.quoteApprovedAt \?\? ""\)'
editor_init_setup_replace = r"""_quoteApprovedAt = State(initialValue: maintenance?.quoteApprovedAt ?? "")
        let initialCost = maintenance?.cost ?? 0
        let status = maintenance?.status ?? ""
        _hasCost = State(initialValue: initialCost > 0 || ["รออนุมัติค่าใช้จ่าย", "ปฏิเสธค่าใช้จ่าย", "รอตรวจสอบชำระเงิน"].contains(status))"""
content = content.replace(editor_init_setup_search, editor_init_setup_replace)

# 4. Update status loop in MaintenanceEditor
status_loop_search = r'ForEach\(Array\(MaintenanceWorkflow\.statuses\.enumerated\(\)\), id: \\\.offset\) \{ index, item in'
status_loop_replace = r'ForEach(Array(MaintenanceWorkflow.statuses(hasCost: hasCost).enumerated()), id: \.offset) { index, item in'
content = content.replace(status_loop_search, status_loop_replace)

# 5. Fix statusRow function signature and logic
statusRow_search = r'    private func statusRow\(item: String, index: Int\) -> some View \{[\s\S]*?    \}'
statusRow_replace = r"""    private func statusRow(item: String, index: Int) -> some View {
        let selected = status == item
        let persisted = originalStatus == item
        let available = MaintenanceWorkflow.canTransition(from: originalStatus, to: item, hasCost: hasCost)

        let flow = MaintenanceWorkflow.statuses(hasCost: hasCost)

        return Button {
            status = item
        } label: {
            HStack(spacing: 13) {
                VStack(spacing: 0) {
                    Rectangle()
                        .fill(index == 0 ? Color.clear : statusConnectorColor(before: index, flow: flow))
                        .frame(width: 2, height: 17)
                    Circle()
                        .fill(selected ? Color.indigo : persisted ? Color.primary.opacity(0.7) : Color.secondary.opacity(available ? 0.35 : 0.16))
                        .frame(width: selected ? 13 : 9, height: selected ? 13 : 9)
                        .overlay {
                            if selected {
                                Circle().stroke(Color.indigo.opacity(0.20), lineWidth: 5)
                            }
                        }
                    Rectangle()
                        .fill(index == flow.count - 1 ? Color.clear : statusConnectorColor(before: index + 1, flow: flow))
                        .frame(width: 2, height: 17)
                }
                .frame(width: 18, height: 47)

                Text(item)
                    .font(.custom("SukhumvitSet-Medium", size: 14))
                    .foregroundStyle(available ? Color.primary : Color.secondary.opacity(0.48))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                Spacer()

                if selected && !persisted {
                    Text("สถานะใหม่")
                        .foregroundStyle(.indigo)
                } else if persisted {
                    Text("ปัจจุบัน")
                        .foregroundStyle(.secondary)
                } else if !available {
                    Image(systemName: "lock.fill")
                        .foregroundStyle(.tertiary)
                } else {
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.tertiary)
                }
            }
            .font(.custom("SukhumvitSet-Text", size: 11))
            .padding(.horizontal, 14)
            .frame(minHeight: 58)
            .background(selected ? Color.indigo.opacity(0.09) : Color.clear, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                if selected {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.indigo.opacity(0.18), lineWidth: 0.75)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!available || selected)
        .accessibilityHint(available ? "เลือกสถานะนี้ได้" : "ต้องบันทึกสถานะตามลำดับก่อน")
    }"""
content = re.sub(statusRow_search, statusRow_replace, content)

# 6. Fix statusConnectorColor
connector_search = r'    private func statusConnectorColor\(before index: Int\) -> Color \{[\s\S]*?    \}'
connector_replace = r"""    private func statusConnectorColor(before index: Int, flow: [String]) -> Color {
        let original = originalStatus == "ปฏิเสธค่าใช้จ่าย" ? "รออนุมัติค่าใช้จ่าย" : originalStatus
        guard let originalIndex = flow.firstIndex(of: original) else {
            return .secondary.opacity(0.12)
        }
        return index <= originalIndex ? .primary.opacity(0.24) : .secondary.opacity(0.12)
    }"""
content = re.sub(connector_search, connector_replace, content)

# 7. Add Toggle and Hide Cost Card content in MaintenanceEditorCard "ค่าใช้จ่าย"
cost_card_search = r'                    MaintenanceEditorCard\(title: "ค่าใช้จ่าย", systemImage: "banknote"\) \{([\s\S]*?)                    \}'
cost_card_content = re.search(cost_card_search, content).group(1)
cost_card_replace = r"""                    MaintenanceEditorCard(title: "ค่าใช้จ่าย", systemImage: "banknote") {
                        Toggle(isOn: $hasCost.animation()) {
                            Text("มีค่าใช้จ่ายเพิ่มเติม")
                                .font(.custom("SukhumvitSet-Medium", size: 15))
                        }
                        .tint(.indigo)
                        .onChange(of: hasCost) { _, newValue in
                            if !newValue {
                                cost = ""
                                paymentMethod = ""
                            }
                        }

                        if hasCost {
                            Divider().overlay(Color.primary.opacity(0.08))
""" + cost_card_content.replace('\n                        ', '\n                            ') + """                        }
                    }"""
content = re.sub(cost_card_search, cost_card_replace, content)

# 8. Fix Toolbar Save Button
save_button_search = r'MaintenanceWorkflow\.canTransition\(from: originalStatus, to: status, cost: Double\(cost\) \?\? 0, quoteApproved: !quoteApprovedAt\.isEmpty\)'
save_button_replace = r'MaintenanceWorkflow.canTransition(from: originalStatus, to: status, hasCost: hasCost)'
content = content.replace(save_button_search, save_button_replace)

save_button_search_2 = r'MaintenanceWorkflow\.canTransition\(from: originalStatus, to: status, cost: parsedCost, quoteApproved: !quoteApprovedAt\.isEmpty\)'
save_button_replace_2 = r'MaintenanceWorkflow.canTransition(from: originalStatus, to: status, hasCost: hasCost)'
content = content.replace(save_button_search_2, save_button_replace_2)


# 9. Fix canEditCost logic
canEditCost_search = r'    private var canEditCost: Bool \{[\s\S]*?    \}'
canEditCost_replace = r"""    private var canEditCost: Bool {
        let flow = MaintenanceWorkflow.statuses(hasCost: hasCost)
        guard let originalIndex = flow.firstIndex(of: originalStatus),
              let selectedIndex = flow.firstIndex(of: status) else { return true }
        
        let quoteIndex = flow.firstIndex(of: "รออนุมัติค่าใช้จ่าย") ?? 2
        if !quoteApprovedAt.isEmpty && originalStatus == "กำลังติดต่อช่าง" && status != "รออนุมัติค่าใช้จ่าย" {
            return false
        }
        return originalIndex < quoteIndex || selectedIndex < quoteIndex || (selectedIndex == quoteIndex && originalIndex != quoteIndex)
    }"""
content = re.sub(canEditCost_search, canEditCost_replace, content)


with open(filepath, 'w') as f:
    f.write(content)

print("Patched.")
