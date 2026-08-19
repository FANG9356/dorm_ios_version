package handlers

import (
	"archive/zip"
	"bytes"
	"database/sql"
	"dorm_os/models"
	"dorm_os/utils"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"os"
	"path/filepath"
	"strings"
	"time"
)

func PerformRestore(db *sql.DB, filePath string) error {
	zipReader, err := zip.OpenReader(filePath)
	if err != nil {
		return fmt.Errorf("Invalid zip format: %v", err)
	}
	defer zipReader.Close()

	var data struct {
		Users          []models.User          `json:"users"`
		Rooms          []models.Room          `json:"rooms"`
		RoomTypes      []models.RoomTypeDef   `json:"room_types"`
		Payments       []models.Payment       `json:"payments"`
		RoomConditions []models.RoomCondition `json:"room_conditions"`
		DepositRefunds []models.DepositRefund `json:"deposit_refunds"`
		Maintenances   []models.Maintenance   `json:"maintenances"`
		Admins []struct {
			ID           int    `json:"id"`
			Username     string `json:"username"`
			Password     string `json:"password"`
			Role         string `json:"role"`
			Email        string `json:"email"`
			ProfileImage string `json:"profile_image"`
			LineUserID   string `json:"line_user_id"`
		} `json:"admins"`
	}

	uploadEntries := make(map[string][]byte)
	foundDataJSON := false
	for _, zf := range zipReader.File {
		safeName, ok := utils.IsSafeZipEntry(zf.Name)
		if !ok {
			continue
		}
		rc, err := zf.Open()
		if err != nil {
			continue
		}
		lr := io.LimitReader(rc, 50<<20) // Limit to 50MB per file to prevent Zip Bombs
		content, err := io.ReadAll(lr)
		rc.Close()
		if err != nil {
			continue
		}
		if safeName == "data.json" {
			if err := json.Unmarshal(content, &data); err != nil {
				return fmt.Errorf("Invalid backup data")
			}
			foundDataJSON = true
		} else {
			if !utils.IsAllowedUploadExt(filepath.Base(safeName)) {
				continue
			}
			uploadEntries[safeName] = content
		}
	}
	if !foundDataJSON {
		return fmt.Errorf("Backup missing data.json")
	}

	os.RemoveAll("./uploads")
	os.MkdirAll("./uploads", os.ModePerm)
	for name, content := range uploadEntries {
		outPath := filepath.Join(".", name)
		if err := os.MkdirAll(filepath.Dir(outPath), os.ModePerm); err != nil {
			return fmt.Errorf("Restore uploads failed")
		}
		if err := os.WriteFile(outPath, content, 0644); err != nil {
			return fmt.Errorf("Restore uploads failed")
		}
	}

	tx, err := db.Begin()
	if err != nil {
		return fmt.Errorf("Database error")
	}
	defer utils.RollbackOnErr(tx, &err)

	if _, err = tx.Exec("DELETE FROM payments"); err != nil {
		return fmt.Errorf("Restore payments failed: %v", err)
	}
	if _, err = tx.Exec("DELETE FROM users"); err != nil {
		return fmt.Errorf("Restore users failed: %v", err)
	}
	if _, err = tx.Exec("DELETE FROM rooms"); err != nil {
		return fmt.Errorf("Restore rooms failed: %v", err)
	}
	if _, err = tx.Exec("DELETE FROM room_types"); err != nil {
		return fmt.Errorf("Restore room_types failed: %v", err)
	}
	tx.Exec("DELETE FROM sqlite_sequence")
	if _, err = tx.Exec("DELETE FROM room_conditions"); err != nil {
		return fmt.Errorf("Restore room_conditions failed: %v", err)
	}
	if _, err = tx.Exec("DELETE FROM deposit_refunds"); err != nil {
		return fmt.Errorf("Restore deposit_refunds failed: %v", err)
	}
	if _, err = tx.Exec("DELETE FROM maintenances"); err != nil {
		return fmt.Errorf("Restore maintenances failed: %v", err)
	}

	if len(data.Admins) > 0 {
		if _, err = tx.Exec("DELETE FROM admins"); err != nil {
			return fmt.Errorf("Restore admins failed: %v", err)
		}
		for _, a := range data.Admins {
			if _, err = tx.Exec("INSERT INTO admins (id, username, password, role, email, profile_image, line_user_id) VALUES (?, ?, ?, ?, ?, ?, ?)",
				a.ID, a.Username, a.Password, a.Role, a.Email, a.ProfileImage, a.LineUserID); err != nil {
				return fmt.Errorf("Restore admins insert failed: %v", err)
			}
		}
	}

	for _, rt := range data.RoomTypes {
		if _, err = tx.Exec("INSERT INTO room_types (id, name, price, water_fee_default, electric_fee_default, common_fee_default, late_fee_default) VALUES (?, ?, ?, ?, ?, ?, ?)", rt.ID, rt.Name, rt.Price, rt.WaterFee, rt.ElectricFee, rt.CommonFee, rt.LateFee); err != nil {
			return fmt.Errorf("Restore room_types insert failed: %v", err)
		}
	}
	for _, rm := range data.Rooms {
		if _, err = tx.Exec("INSERT INTO rooms (room_id, room_number, room_type) VALUES (?, ?, ?)", rm.ID, rm.RoomNumber, rm.RoomType); err != nil {
			return fmt.Errorf("Restore rooms insert failed: %v", err)
		}
	}
	for _, u := range data.Users {
		slipsBytes, _ := json.Marshal(u.BookingSlips)
		if _, err = tx.Exec("INSERT INTO users (user_id, prefix, first_name, last_name, full_name, room_number, status, national_id, phone, address, move_in_date, contract_end_date, deposit, booking_status, payment_method, indefinite_contract, booking_slips, additional_appliances, additional_appliance_fee, additional_details) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
			u.ID, u.Prefix, u.FirstName, u.LastName, u.Prefix+u.FirstName+" "+u.LastName, u.RoomNumber, u.Status, u.NationalID, u.Phone, u.Address, u.MoveInDate, u.ContractEndDate, u.Deposit, u.BookingStatus, u.PaymentMethod, u.IndefiniteContract, string(slipsBytes), u.AdditionalAppliances, u.AdditionalApplianceFee, u.AdditionalDetails); err != nil {
			return fmt.Errorf("Restore users insert failed: %v", err)
		}
	}
	for _, p := range data.Payments {
		if _, err = tx.Exec("INSERT INTO payments (payment_id, user_id, room_number, rent_fee, water_fee, electric_fee, common_fee, late_fee, appliance_fee, amount, month, payment_date, method, slip_path, water_meter_prev, water_meter_curr, electric_meter_prev, electric_meter_curr, payment_plan, installment_phase, due_date, payment_status, slip_path_array, paid_amount) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
			p.ID, p.UserID, p.RoomNumber, p.RentFee, p.WaterFee, p.ElectricFee, p.CommonFee, p.LateFee, p.ApplianceFee, p.Amount, p.Month, p.PaymentDate, p.Method, p.SlipPath, p.WaterMeterPrev, p.WaterMeterCurr, p.ElectricMeterPrev, p.ElectricMeterCurr, p.PaymentPlan, p.InstallmentPhase, p.DueDate, p.PaymentStatus, strings.Join(p.SlipPathArray, ","), p.PaidAmount); err != nil {
			return fmt.Errorf("Restore payments insert failed: %v", err)
		}
	}
	for _, c := range data.RoomConditions {
		if _, err = tx.Exec("INSERT INTO room_conditions (id, user_id, room_number, image_path, uploaded_at) VALUES (?, ?, ?, ?, ?)", c.ID, c.UserID, c.RoomNumber, c.ImagePath, c.UploadedAt); err != nil {
			return fmt.Errorf("Restore room_conditions insert failed: %v", err)
		}
	}
	for _, d := range data.DepositRefunds {
		if _, err = tx.Exec("INSERT INTO deposit_refunds (id, user_id, room_number, original_deposit, cleaning_fee, damage_fee, net_refund, refund_date) VALUES (?, ?, ?, ?, ?, ?, ?, ?)", d.ID, d.UserID, d.RoomNumber, d.OriginalDeposit, d.CleaningFee, d.DamageFee, d.NetRefund, d.RefundDate); err != nil {
			return fmt.Errorf("Restore deposit_refunds insert failed: %v", err)
		}
	}
	for _, m := range data.Maintenances {
		if _, err = tx.Exec("INSERT INTO maintenances (id, room_number, issue, status, cost, reported_at, resolved_at, payment_method, slip_path, issue_image) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)", m.ID, m.RoomNumber, m.Issue, m.Status, m.Cost, m.ReportedAt, m.ResolvedAt, m.PaymentMethod, m.SlipPath, m.IssueImage); err != nil {
			log.Printf("Restore Maintenance error: %v", err)
		}
	}

	if _, err = tx.Exec("INSERT INTO system_logs (action_type, details, timestamp) VALUES ('System Restore', 'กู้คืนข้อมูลระบบและรูปภาพจากไฟล์ ZIP', ?)", time.Now().Format("2006-01-02 15:04:05")); err != nil {
		return fmt.Errorf("Restore failed")
	}
	if err = tx.Commit(); err != nil {
		return fmt.Errorf("Restore failed")
	}
	return nil
}

func StartBackupScheduler(db *sql.DB, dbPath, uploadsDir, backupBaseDir string) {
	for {
		now := time.Now()
		// Get next 10 PM (22:00:00)
		nextBackupTime := time.Date(now.Year(), now.Month(), now.Day(), 22, 0, 0, 0, now.Location())
		if now.After(nextBackupTime) {
			// If 10 PM today has already passed, schedule for 10 PM tomorrow
			nextBackupTime = nextBackupTime.Add(24 * time.Hour)
		}

		duration := time.Until(nextBackupTime)
		log.Printf("[Backup Scheduler] Next automatic backup scheduled at %s (in %s)", nextBackupTime.Format("2006-01-02 15:04:05"), duration)

		time.Sleep(duration)

		log.Println("[Backup Scheduler] Starting automatic backup...")

		if err := PerformZipBackup(db, "./backups_zip"); err != nil {
			log.Printf("[Backup Scheduler] Error performing ZIP backup: %v", err)
		} else {
			log.Println("[Backup Scheduler] Automatic ZIP backup completed successfully.")
		}
	}
}

func PerformZipBackup(db *sql.DB, backupZipDir string) error {
	if err := os.MkdirAll(backupZipDir, os.ModePerm); err != nil {
		return fmt.Errorf("failed to create zip backup directory: %w", err)
	}

	zipData, err := GenerateZipBackupData(db)
	if err != nil {
		return err
	}

	fileName := fmt.Sprintf("backup_%s.zip", time.Now().Format("2006-01-02_15-04-05"))
	filePath := filepath.Join(backupZipDir, fileName)

	if err := os.WriteFile(filePath, zipData, 0644); err != nil {
		return fmt.Errorf("failed to write zip backup file: %w", err)
	}

	log.Printf("[Backup Scheduler] ZIP backup saved to %s", filePath)
	return nil
}

func GenerateZipBackupData(db *sql.DB) ([]byte, error) {
	var data struct {
		Users          []models.User          `json:"users"`
		Rooms          []models.Room          `json:"rooms"`
		RoomTypes      []models.RoomTypeDef   `json:"room_types"`
		Payments       []models.Payment       `json:"payments"`
		RoomConditions []models.RoomCondition `json:"room_conditions"`
		DepositRefunds []models.DepositRefund `json:"deposit_refunds"`
		Maintenances   []models.Maintenance   `json:"maintenances"`
		Admins []struct {
			ID           int    `json:"id"`
			Username     string `json:"username"`
			Password     string `json:"password"`
			Role         string `json:"role"`
			Email        string `json:"email"`
			ProfileImage string `json:"profile_image"`
			LineUserID   string `json:"line_user_id"`
		} `json:"admins"`
	}

	uploadFiles := []string{}

	rowsU, err := db.Query("SELECT user_id, prefix, first_name, last_name, room_number, status, national_id, phone, address, move_in_date, contract_end_date, deposit, COALESCE(booking_status,''), COALESCE(payment_method,''), COALESCE(indefinite_contract,0), COALESCE(booking_slips,''), COALESCE(additional_appliances,''), COALESCE(additional_appliance_fee,0), COALESCE(additional_details,'') FROM users")
	if err != nil {
		return nil, err
	}
	defer rowsU.Close()

	for rowsU.Next() {
		var u models.User
		var slipsStr string
		rowsU.Scan(&u.ID, &u.Prefix, &u.FirstName, &u.LastName, &u.RoomNumber, &u.Status, &u.NationalID, &u.Phone, &u.Address, &u.MoveInDate, &u.ContractEndDate, &u.Deposit, &u.BookingStatus, &u.PaymentMethod, &u.IndefiniteContract, &slipsStr, &u.AdditionalAppliances, &u.AdditionalApplianceFee, &u.AdditionalDetails)
		if slipsStr != "" {
			json.Unmarshal([]byte(slipsStr), &u.BookingSlips)
		}
		data.Users = append(data.Users, u)
	}

	rowsR, errR := db.Query("SELECT room_id, room_number, room_type FROM rooms")
	if errR == nil {
		for rowsR.Next() {
			var rm models.Room
			rowsR.Scan(&rm.ID, &rm.RoomNumber, &rm.RoomType)
			data.Rooms = append(data.Rooms, rm)
		}
		rowsR.Close()
	}
	rowsRT, errRT := db.Query("SELECT id, name, price, COALESCE(water_fee_default, 0), COALESCE(electric_fee_default, 0), COALESCE(common_fee_default, 0), COALESCE(late_fee_default, 0) FROM room_types")
	if errRT == nil {
		for rowsRT.Next() {
			var rt models.RoomTypeDef
			rowsRT.Scan(&rt.ID, &rt.Name, &rt.Price, &rt.WaterFee, &rt.ElectricFee, &rt.CommonFee, &rt.LateFee)
			data.RoomTypes = append(data.RoomTypes, rt)
		}
		rowsRT.Close()
	}

	rowsP, errP := db.Query("SELECT payment_id, user_id, room_number, COALESCE(CAST(NULLIF(rent_fee,'') AS REAL),0), COALESCE(CAST(NULLIF(water_fee,'') AS REAL),0), COALESCE(CAST(NULLIF(electric_fee,'') AS REAL),0), COALESCE(CAST(NULLIF(common_fee,'') AS REAL),0), COALESCE(CAST(NULLIF(late_fee,'') AS REAL),0), COALESCE(CAST(NULLIF(appliance_fee,'') AS REAL),0), COALESCE(CAST(NULLIF(amount,'') AS REAL),0), month, payment_date, method, slip_path, COALESCE(CAST(NULLIF(water_meter_prev,'') AS REAL),0), COALESCE(CAST(NULLIF(water_meter_curr,'') AS REAL),0), COALESCE(CAST(NULLIF(electric_meter_prev,'') AS REAL),0), COALESCE(CAST(NULLIF(electric_meter_curr,'') AS REAL),0), COALESCE(payment_plan,''), CAST(COALESCE(NULLIF(installment_phase,''),0) AS INTEGER), COALESCE(due_date,''), COALESCE(payment_status,'pending'), COALESCE(slip_path_array,''), COALESCE(CAST(NULLIF(paid_amount,'') AS REAL),0) FROM payments")
	if errP == nil {
		defer rowsP.Close()
		for rowsP.Next() {
			var p models.Payment
			var slipPathArrayStr string
			rowsP.Scan(&p.ID, &p.UserID, &p.RoomNumber, &p.RentFee, &p.WaterFee, &p.ElectricFee, &p.CommonFee, &p.LateFee, &p.ApplianceFee, &p.Amount, &p.Month, &p.PaymentDate, &p.Method, &p.SlipPath, &p.WaterMeterPrev, &p.WaterMeterCurr, &p.ElectricMeterPrev, &p.ElectricMeterCurr, &p.PaymentPlan, &p.InstallmentPhase, &p.DueDate, &p.PaymentStatus, &slipPathArrayStr, &p.PaidAmount)
			if slipPathArrayStr != "" {
				p.SlipPathArray = strings.Split(slipPathArrayStr, ",")
			}
			data.Payments = append(data.Payments, p)
			if p.SlipPath != "" {
				uploadFiles = append(uploadFiles, p.SlipPath)
			}
			for _, img := range p.SlipPathArray {
				if img != "" {
					uploadFiles = append(uploadFiles, img)
				}
			}
		}
	}

	rowsC, errC := db.Query("SELECT id, user_id, room_number, image_path, uploaded_at FROM room_conditions")
	if errC == nil {
		for rowsC.Next() {
			var c models.RoomCondition
			rowsC.Scan(&c.ID, &c.UserID, &c.RoomNumber, &c.ImagePath, &c.UploadedAt)
			data.RoomConditions = append(data.RoomConditions, c)
		}
		rowsC.Close()
	}

	rowsD, errD := db.Query("SELECT id, user_id, room_number, original_deposit, cleaning_fee, damage_fee, net_refund, refund_date FROM deposit_refunds")
	if errD == nil {
		for rowsD.Next() {
			var d models.DepositRefund
			rowsD.Scan(&d.ID, &d.UserID, &d.RoomNumber, &d.OriginalDeposit, &d.CleaningFee, &d.DamageFee, &d.NetRefund, &d.RefundDate)
			data.DepositRefunds = append(data.DepositRefunds, d)
		}
		rowsD.Close()
	}

	rowsM, errM := db.Query("SELECT id, room_number, issue, status, cost, reported_at, COALESCE(resolved_at, ''), COALESCE(payment_method, ''), COALESCE(slip_path, ''), COALESCE(issue_image, '') FROM maintenances")
	if errM == nil {
		defer rowsM.Close()
		for rowsM.Next() {
			var m models.Maintenance
			rowsM.Scan(&m.ID, &m.RoomNumber, &m.Issue, &m.Status, &m.Cost, &m.ReportedAt, &m.ResolvedAt, &m.PaymentMethod, &m.SlipPath, &m.IssueImage)
			data.Maintenances = append(data.Maintenances, m)
			if m.SlipPath != "" {
				uploadFiles = append(uploadFiles, m.SlipPath)
			}
			if m.IssueImage != "" {
				imgName := m.IssueImage
				if strings.HasPrefix(imgName, "/uploads/") {
					imgName = strings.TrimPrefix(imgName, "/uploads/")
				}
				uploadFiles = append(uploadFiles, imgName)
			}
		}
	}

	rowsA, errA := db.Query("SELECT id, username, password, COALESCE(role, 'services'), COALESCE(email, ''), COALESCE(profile_image, ''), COALESCE(line_user_id, '') FROM admins")
	if errA == nil {
		for rowsA.Next() {
			var a struct {
				ID           int    `json:"id"`
				Username     string `json:"username"`
				Password     string `json:"password"`
				Role         string `json:"role"`
				Email        string `json:"email"`
				ProfileImage string `json:"profile_image"`
				LineUserID   string `json:"line_user_id"`
			}
			rowsA.Scan(&a.ID, &a.Username, &a.Password, &a.Role, &a.Email, &a.ProfileImage, &a.LineUserID)
			data.Admins = append(data.Admins, a)
		}
		rowsA.Close()
	}

	buf := new(bytes.Buffer)
	zipWriter := zip.NewWriter(buf)

	jsonData, _ := json.MarshalIndent(data, "", "  ")
	jsonFile, _ := zipWriter.Create("data.json")
	jsonFile.Write(jsonData)

	filepath.Walk("./uploads", func(path string, info os.FileInfo, err error) error {
		if err == nil && !info.IsDir() {
			fileContent, err := os.ReadFile(path)
			if err == nil {
				relPath := filepath.ToSlash(path)
				zipFile, _ := zipWriter.Create(relPath)
				zipFile.Write(fileContent)
			}
		}
		return nil
	})
	zipWriter.Close()
	return buf.Bytes(), nil
}

func copyFile(src, dst string) error {
	in, err := os.Open(src)
	if err != nil {
		return err
	}
	defer in.Close()

	out, err := os.Create(dst)
	if err != nil {
		return err
	}
	defer out.Close()

	_, err = io.Copy(out, in)
	return err
}
