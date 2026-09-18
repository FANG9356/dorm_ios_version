package models

type User struct {
	ID                     int      `json:"id"`
	Prefix                 string   `json:"prefix"`
	FirstName              string   `json:"first_name"`
	LastName               string   `json:"last_name"`
	RoomNumber             string   `json:"room_number"`
	Status                 string   `json:"status"`
	NationalID             string   `json:"national_id"`
	Phone                  string   `json:"phone"`
	Address                string   `json:"address"`
	MoveInDate             string   `json:"move_in_date"`
	ContractEndDate        string   `json:"contract_end_date"`
	Deposit                float64  `json:"deposit"`
	BookingStatus          string   `json:"booking_status"`
	PaymentMethod          string   `json:"payment_method"`
	IndefiniteContract     int      `json:"indefinite_contract"`
	BookingSlips           []string `json:"booking_slips"`
	AdditionalAppliances   string   `json:"additional_appliances"`
	AdditionalApplianceFee float64  `json:"additional_appliance_fee"`
	AdditionalDetails      string   `json:"additional_details"`
}

type Payment struct {
	ID                int      `json:"id"`
	UserID            int      `json:"user_id"`
	RoomNumber        string   `json:"room_number"`
	RentFee           float64  `json:"rent_fee"`
	WaterFee          float64  `json:"water_fee"`
	ElectricFee       float64  `json:"electric_fee"`
	CommonFee         float64  `json:"common_fee"`
	LateFee           float64  `json:"late_fee"`
	ApplianceFee      float64  `json:"appliance_fee"`
	Amount            float64  `json:"amount"`
	Month             string   `json:"month"`
	PaymentDate       string   `json:"payment_date"`
	Method            string   `json:"method"`
	SlipPath          string   `json:"slip_path"`
	WaterMeterPrev    float64  `json:"water_meter_prev"`
	WaterMeterCurr    float64  `json:"water_meter_curr"`
	ElectricMeterPrev float64  `json:"electric_meter_prev"`
	ElectricMeterCurr float64  `json:"electric_meter_curr"`
	PaymentPlan       string   `json:"payment_plan"`
	InstallmentPhase  int      `json:"installment_phase"`
	DueDate           string   `json:"due_date"`
	PaymentStatus     string   `json:"payment_status"`
	SlipPathArray     []string `json:"slip_path_array"`
	PaidAmount        float64  `json:"paid_amount"`
}

type Room struct {
	ID         int    `json:"id"`
	RoomNumber string `json:"room_number"`
	RoomType   string `json:"room_type"`
}

type SystemLog struct {
	ID        int    `json:"id"`
	Action    string `json:"action_type"`
	Details   string `json:"details"`
	Timestamp string `json:"timestamp"`
}

type RoomTypeDef struct {
	ID          int     `json:"id"`
	Name        string  `json:"name"`
	Price       float64 `json:"price"`
	WaterFee    float64 `json:"water_fee"`
	ElectricFee float64 `json:"electric_fee"`
	CommonFee   float64 `json:"common_fee"`
	LateFee     float64 `json:"late_fee"`
}

type DepositRefund struct {
	ID              int     `json:"id"`
	UserID          int     `json:"user_id"`
	RoomNumber      string  `json:"room_number"`
	OriginalDeposit float64 `json:"original_deposit"`
	CleaningFee     float64 `json:"cleaning_fee"`
	DamageFee       float64 `json:"damage_fee"`
	NetRefund       float64 `json:"net_refund"`
	RefundDate      string  `json:"refund_date"`
}

type DashboardStats struct {
	TotalResidents     int     `json:"total_residents"`
	EmptyRooms         int     `json:"empty_rooms"`
	IncomeThisMonth    float64 `json:"income_this_month"`
	BillingCycleIncome float64 `json:"billing_cycle_income"`
	PendingBills       int     `json:"pending_bills"`
}

type RoomCondition struct {
	ID         int    `json:"id"`
	UserID     string `json:"user_id"`
	RoomNumber string `json:"room_number"`
	ImagePath  string `json:"image_path"`
	UploadedAt string `json:"uploaded_at"`
}

type Maintenance struct {
	ID              int     `json:"id"`
	RoomNumber      string  `json:"room_number"`
	Issue           string  `json:"issue"`
	Status          string  `json:"status"`
	Cost            float64 `json:"cost"`
	ReportedAt      string  `json:"reported_at"`
	ResolvedAt      string  `json:"resolved_at"`
	PaymentMethod   string  `json:"payment_method"`
	SlipPath        string  `json:"slip_path"`
	IssueImage      string  `json:"issue_image"`
	LastUpdated     string  `json:"last_updated"`
	QuoteApprovedAt string  `json:"quote_approved_at"`
	ExternalID      string  `json:"external_id"`
}
