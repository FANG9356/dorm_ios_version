package handlers

import (
	"crypto/sha256"
	"database/sql"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"time"
)

const maxSyncRequestBytes = 16 << 20

// HandleSyncPush accepts a snapshot only if the client's base is still current.
// One conditional INSERT makes the version check atomic across concurrent writers.
func HandleSyncPush(db *sql.DB) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost {
			http.Error(w, "Method Not Allowed", http.StatusMethodNotAllowed)
			return
		}
		adminID, accountID, email, err := resolveSyncAccount(db, r)
		if err != nil {
			http.Error(w, "Unauthorized", http.StatusUnauthorized)
			return
		}
		r.Body = http.MaxBytesReader(w, r.Body, maxSyncRequestBytes)
		decoder := json.NewDecoder(r.Body)
		var req SyncSnapshotRequest
		if err := decoder.Decode(&req); err != nil {
			http.Error(w, "Invalid sync request", http.StatusBadRequest)
			return
		}
		if decoder.Decode(new(interface{})) != io.EOF {
			http.Error(w, "Expected one sync request", http.StatusBadRequest)
			return
		}
		if req.BaseVersion == nil {
			http.Error(w, "Update the app before syncing (base_version required)", http.StatusPreconditionRequired)
			return
		}
		if *req.BaseVersion < 0 || req.DeviceID == "" || len(req.DeviceID) > 200 {
			http.Error(w, "Invalid sync version or device", http.StatusBadRequest)
			return
		}
		payload := []byte(req.Payload)
		if req.PayloadBase64 != "" {
			payload, err = base64.StdEncoding.DecodeString(req.PayloadBase64)
			if err != nil {
				http.Error(w, "Invalid encoded snapshot", http.StatusBadRequest)
				return
			}
		}
		var envelope struct {
			AccountID int `json:"accountID"`
		}
		if json.Unmarshal(payload, &envelope) != nil || (envelope.AccountID != adminID && envelope.AccountID != accountID) {
			http.Error(w, "Snapshot account does not match session", http.StatusBadRequest)
			return
		}
		// Reject workflow-invalid snapshots before the immutable snapshot is
		// inserted. Otherwise a stale local maintenance record can become the
		// latest snapshot even though tenant materialization rejects it, leaving
		// the client checkpoint behind an accepted snapshot that always returns
		// HTTP 500.
		if err := validateLineSnapshotForPush(accountID, payload); err != nil {
			log.Printf("sync push for account %d rejected before storage: %v", accountID, err)
			http.Error(w, "Newer LINE data conflicts with a local workflow change. Refresh and merge the latest data.", http.StatusConflict)
			return
		}
		sum := sha256.Sum256(payload)
		checksum := hex.EncodeToString(sum[:])
		nextVersion := *req.BaseVersion + 1
		if nextVersion <= 0 {
			http.Error(w, "Invalid sync version", http.StatusBadRequest)
			return
		}
		createdAt := time.Now().UTC().Format(time.RFC3339)
		snapshotID := fmt.Sprintf("acct-%d-v%d-%s", accountID, nextVersion, checksum[:12])
		result, err := db.Exec(`INSERT INTO sync_snapshots
			(snapshot_id, account_id, version, payload, checksum, size, device_id, created_at, created_by_admin_id)
			SELECT ?, ?, ?, ?, ?, ?, ?, ?, ?
			WHERE (SELECT COALESCE(MAX(version), 0) FROM sync_snapshots WHERE account_id = ?) = ?`,
			snapshotID, accountID, nextVersion, string(payload), checksum, len(payload), req.DeviceID, createdAt, adminID, accountID, *req.BaseVersion)
		if err != nil {
			http.Error(w, "Sync push failed", http.StatusInternalServerError)
			return
		}
		rows, err := result.RowsAffected()
		if err != nil {
			http.Error(w, "Sync push failed", http.StatusInternalServerError)
			return
		}
		if rows == 0 {
			// A retry after a lost response is successful only for the exact same write.
			var storedChecksum, storedDevice string
			err := db.QueryRow(`SELECT checksum, device_id FROM sync_snapshots WHERE account_id = ? AND version = ?`, accountID, nextVersion).Scan(&storedChecksum, &storedDevice)
			if err != nil || storedChecksum != checksum || storedDevice != req.DeviceID {
				http.Error(w, "Newer data exists on another device. Local changes were not overwritten.", http.StatusConflict)
				return
			}
		}
		if err := MaterializeLineSnapshotAndNotify(db, accountID, payload); err != nil {
			log.Printf("sync snapshot %s stored but LINE materialization failed: %v", snapshotID, err)
			http.Error(w, "Sync stored, but LINE data preparation failed", http.StatusInternalServerError)
			return
		}
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]interface{}{
			"status": "success", "version": nextVersion, "account_id": accountID,
			"email": email, "checksum": checksum, "snapshot_id": snapshotID,
		})
	}
}
