package handlers

import "testing"

func TestValidateMaintenanceAppTransitionRequiresQuoteApproval(t *testing.T) {
	tests := []struct {
		name       string
		from       string
		to         string
		cost       float64
		approved   bool
		shouldFail bool
	}{
		{name: "paid repair enters quote", from: "กำลังติดต่อช่าง", to: "รออนุมัติค่าใช้จ่าย", cost: 500},
		{name: "zero quote rejected", from: "กำลังติดต่อช่าง", to: "รออนุมัติค่าใช้จ่าย", shouldFail: true},
		{name: "paid repair cannot skip quote", from: "กำลังติดต่อช่าง", to: "กำลังซ่อม", cost: 500, shouldFail: true},
		{name: "approved paid repair can start", from: "กำลังติดต่อช่าง", to: "กำลังซ่อม", cost: 500, approved: true},
		{name: "free repair can skip quote", from: "กำลังติดต่อช่าง", to: "กำลังซ่อม"},
		{name: "free repair can skip payment", from: "กำลังซ่อม", to: "เสร็จสิ้น"},
		{name: "paid repair cannot skip payment", from: "กำลังซ่อม", to: "เสร็จสิ้น", cost: 500, shouldFail: true},
		{name: "admin cannot approve quote", from: "รออนุมัติค่าใช้จ่าย", to: "กำลังซ่อม", cost: 500, shouldFail: true},
		{name: "resident can reject prepared quote", from: "กำลังติดต่อช่าง", to: "ปฏิเสธค่าใช้จ่าย", cost: 500},
		{name: "resident can reject pending quote", from: "รออนุมัติค่าใช้จ่าย", to: "ปฏิเสธค่าใช้จ่าย", cost: 500},
		{name: "rejected quote is terminal", from: "ปฏิเสธค่าใช้จ่าย", to: "กำลังซ่อม", cost: 500, shouldFail: true},
		{name: "unrelated state cannot reject quote", from: "กำลังซ่อม", to: "ปฏิเสธค่าใช้จ่าย", cost: 500, shouldFail: true},
		{name: "cannot skip to payment", from: "กำลังติดต่อช่าง", to: "รอตรวจสอบชำระเงิน", cost: 500, shouldFail: true},
	}
	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			err := validateMaintenanceAppTransition(test.from, test.to, test.cost, test.approved)
			if test.shouldFail && err == nil {
				t.Fatal("expected transition rejection")
			}
			if !test.shouldFail && err != nil {
				t.Fatalf("unexpected transition rejection: %v", err)
			}
		})
	}
}

func TestValidateMaintenanceCostChangeLocksQuotedAmount(t *testing.T) {
	tests := []struct {
		name       string
		from       string
		to         string
		shouldFail bool
		approved   bool
	}{
		{name: "draft amount can change", from: "กำลังติดต่อช่าง", to: "กำลังติดต่อช่าง"},
		{name: "approved amount is locked while contacting", from: "กำลังติดต่อช่าง", to: "กำลังติดต่อช่าง", approved: true, shouldFail: true},
		{name: "approved amount can be replaced with new quote", from: "กำลังติดต่อช่าง", to: "รออนุมัติค่าใช้จ่าย", approved: true},
		{name: "pending quote amount is locked", from: "รออนุมัติค่าใช้จ่าย", to: "รออนุมัติค่าใช้จ่าย", shouldFail: true},
		{name: "approved repair amount is locked", from: "กำลังซ่อม", to: "รอตรวจสอบชำระเงิน", shouldFail: true},
		{name: "repair can issue replacement quote", from: "กำลังซ่อม", to: "รออนุมัติค่าใช้จ่าย"},
		{name: "quote can return to draft with changed amount", from: "รออนุมัติค่าใช้จ่าย", to: "กำลังติดต่อช่าง"},
	}
	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			err := validateMaintenanceCostChange(test.from, test.to, 500, 650, test.approved)
			if test.shouldFail && err == nil {
				t.Fatal("expected cost change rejection")
			}
			if !test.shouldFail && err != nil {
				t.Fatalf("unexpected cost change rejection: %v", err)
			}
		})
	}
}
