package handlers

import (
	"bytes"
	"context"
	"database/sql"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"golang.org/x/crypto/bcrypt"
)

func securityTestDB(t *testing.T) *sql.DB {
	t.Helper()
	db, err := sql.Open("sqlite3", filepath.Join(t.TempDir(), "auth.db")+"?_busy_timeout=5000")
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { db.Close() })
	if _, err = db.Exec(`CREATE TABLE admins (
		id INTEGER PRIMARY KEY, username TEXT UNIQUE, password TEXT, role TEXT,
		email TEXT, backup_email TEXT, profile_image TEXT, must_change_password INTEGER,
		last_active TEXT, promptpay_id TEXT, dorm_code TEXT
	);
	CREATE TABLE sessions (id INTEGER PRIMARY KEY, admin_id INTEGER, token TEXT UNIQUE);`); err != nil {
		t.Fatal(err)
	}
	hash, err := bcrypt.GenerateFromPassword([]byte("OldPassword1"), bcrypt.MinCost)
	if err != nil {
		t.Fatal(err)
	}
	if _, err = db.Exec("INSERT INTO admins VALUES (1, 'owner', ?, 'superadmin', 'owner@example.test', '', '', 0, NULL, '', '')", string(hash)); err != nil {
		t.Fatal(err)
	}
	previousSecret := jwtSecretKey
	jwtSecretKey = []byte("test-only-secret-that-is-long-enough")
	t.Cleanup(func() { jwtSecretKey = previousSecret })
	return db
}

func TestAuthMiddlewareRejectsMalformedClaimsWithoutPanicking(t *testing.T) {
	db := securityTestDB(t)
	token, err := jwt.NewWithClaims(jwt.SigningMethodHS256, jwt.MapClaims{
		"username": "owner",
		"exp":      time.Now().Add(time.Hour).Unix(),
	}).SignedString(getJWTSecret())
	if err != nil {
		t.Fatal(err)
	}
	req := httptest.NewRequest(http.MethodGet, "/api/private", nil)
	req.Header.Set("Authorization", "Bearer "+token)
	w := httptest.NewRecorder()
	AuthMiddleware(db, http.HandlerFunc(func(http.ResponseWriter, *http.Request) {
		t.Fatal("malformed token reached protected handler")
	})).ServeHTTP(w, req)
	if w.Code != http.StatusUnauthorized {
		t.Fatalf("got %d, want 401", w.Code)
	}
}

func TestAuthMiddlewareUsesCurrentDatabaseRoleAndRequiresHeader(t *testing.T) {
	db := securityTestDB(t)
	token, err := issueSessionToken(db, 1, "owner", "superadmin", time.Hour)
	if err != nil {
		t.Fatal(err)
	}
	if _, err = db.Exec("UPDATE admins SET role = 'dorm' WHERE id = 1"); err != nil {
		t.Fatal(err)
	}
	handler := AuthMiddleware(db, http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if IsServicesRole(r) {
			t.Fatal("stale role from JWT granted elevated access")
		}
		w.WriteHeader(http.StatusNoContent)
	}))

	req := httptest.NewRequest(http.MethodGet, "/api/private", nil)
	req.Header.Set("Authorization", "Bearer "+token)
	w := httptest.NewRecorder()
	handler.ServeHTTP(w, req)
	if w.Code != http.StatusNoContent {
		t.Fatalf("header token: got %d", w.Code)
	}

	queryReq := httptest.NewRequest(http.MethodGet, "/api/private?token="+token, nil)
	queryW := httptest.NewRecorder()
	handler.ServeHTTP(queryW, queryReq)
	if queryW.Code != http.StatusUnauthorized {
		t.Fatalf("query token: got %d, want 401", queryW.Code)
	}
}

func TestChangePasswordRevokesSessionsAndDoesNotLeakDebugDetails(t *testing.T) {
	db := securityTestDB(t)
	if _, err := issueSessionToken(db, 1, "owner", "superadmin", time.Hour); err != nil {
		t.Fatal(err)
	}

	request := func(oldPassword, newPassword string) *httptest.ResponseRecorder {
		body, err := json.Marshal(map[string]string{
			"username": "owner", "old_password": oldPassword,
			"new_username": "owner", "new_password": newPassword,
		})
		if err != nil {
			t.Fatal(err)
		}
		w := httptest.NewRecorder()
		ChangePasswordHandler(db)(w, httptest.NewRequest(http.MethodPost, "/api/change-password", bytes.NewReader(body)))
		return w
	}

	denied := request("wrong", "NewPassword1")
	if denied.Code != http.StatusUnauthorized || strings.Contains(denied.Body.String(), "DEBUG") {
		t.Fatalf("invalid password response: %d %q", denied.Code, denied.Body.String())
	}

	accepted := request("OldPassword1", "NewPassword1")
	if accepted.Code != http.StatusOK {
		t.Fatalf("change password: %d %s", accepted.Code, accepted.Body.String())
	}
	var sessions int
	if err := db.QueryRow("SELECT COUNT(*) FROM sessions WHERE admin_id = 1").Scan(&sessions); err != nil {
		t.Fatal(err)
	}
	if sessions != 0 {
		t.Fatalf("sessions remain after password change: %d", sessions)
	}
}

func TestGetAdminsRequiresAccountScopeAndDoesNotFallBackToAllAdmins(t *testing.T) {
	db := securityTestDB(t)
	if _, err := db.Exec(`INSERT INTO admins VALUES
		(2, 'staff', '', 'admin', 'owner@example.test', 'staff@example.test', '', 0, NULL, '', ''),
		(3, 'other', '', 'superadmin', 'other@example.test', '', '', 0, NULL, '', '')`); err != nil {
		t.Fatal(err)
	}

	withoutScope := httptest.NewRecorder()
	GetAdminsHandler(db)(withoutScope, httptest.NewRequest(http.MethodGet, "/api/admins", nil))
	if withoutScope.Code != http.StatusUnauthorized {
		t.Fatalf("missing scope: got %d, want 401", withoutScope.Code)
	}

	req := httptest.NewRequest(http.MethodGet, "/api/admins", nil)
	req = req.WithContext(context.WithValue(req.Context(), "admin_id", 1))
	w := httptest.NewRecorder()
	GetAdminsHandler(db)(w, req)
	if w.Code != http.StatusOK {
		t.Fatalf("scoped request: %d %s", w.Code, w.Body.String())
	}
	var admins []Admin
	if err := json.Unmarshal(w.Body.Bytes(), &admins); err != nil {
		t.Fatal(err)
	}
	if len(admins) != 2 || admins[0].Username != "owner" || admins[1].Username != "staff" {
		t.Fatalf("unexpected account scope: %#v", admins)
	}
}

func TestQRLoginIssuesRevocableSession(t *testing.T) {
	db := securityTestDB(t)
	qrToken, err := jwt.NewWithClaims(jwt.SigningMethodHS256, jwt.MapClaims{
		"username": "owner",
		"role":     "login_qr",
		"exp":      time.Now().Add(time.Minute).Unix(),
	}).SignedString(getJWTSecret())
	if err != nil {
		t.Fatal(err)
	}
	body, err := json.Marshal(map[string]string{"login_token": qrToken})
	if err != nil {
		t.Fatal(err)
	}
	w := httptest.NewRecorder()
	LoginWithQRHandler(db)(w, httptest.NewRequest(http.MethodPost, "/api/login/qr", bytes.NewReader(body)))
	if w.Code != http.StatusOK {
		t.Fatalf("QR login: %d %s", w.Code, w.Body.String())
	}
	var response struct {
		Token string `json:"token"`
	}
	if err := json.Unmarshal(w.Body.Bytes(), &response); err != nil || response.Token == "" {
		t.Fatalf("missing session token: %v %s", err, w.Body.String())
	}
	if _, _, err := authenticateSession(db, response.Token); err != nil {
		t.Fatalf("issued token is not a revocable session: %v", err)
	}
}

func scopedAdminRequest(t *testing.T, method, path string, adminID int, body map[string]string) *http.Request {
	t.Helper()
	var input *bytes.Reader
	if body == nil {
		input = bytes.NewReader(nil)
	} else {
		encoded, err := json.Marshal(body)
		if err != nil {
			t.Fatal(err)
		}
		input = bytes.NewReader(encoded)
	}
	req := httptest.NewRequest(method, path, input)
	return req.WithContext(context.WithValue(req.Context(), "admin_id", adminID))
}

func TestAdminMutationsStayInsideOwnerAccount(t *testing.T) {
	db := securityTestDB(t)
	if _, err := db.Exec(`INSERT INTO admins VALUES
		(2, 'staff', '', 'admin', 'owner@example.test', 'staff@example.test', '', 0, NULL, '', ''),
		(3, 'other', '', 'superadmin', 'other@example.test', '', '', 0, NULL, '', '')`); err != nil {
		t.Fatal(err)
	}

	crossUpdate := httptest.NewRecorder()
	UpdateAdminHandler(db)(crossUpdate, scopedAdminRequest(t, http.MethodPut, "/api/admins/3", 1, map[string]string{"role": "services"}))
	if crossUpdate.Code != http.StatusForbidden {
		t.Fatalf("cross-account update: got %d, want 403", crossUpdate.Code)
	}

	crossDelete := httptest.NewRecorder()
	DeleteAdminHandler(db)(crossDelete, scopedAdminRequest(t, http.MethodDelete, "/api/admins/3", 1, nil))
	if crossDelete.Code != http.StatusForbidden {
		t.Fatalf("cross-account delete: got %d, want 403", crossDelete.Code)
	}

	crossProfile := httptest.NewRecorder()
	UpdateProfileImageHandler(db)(crossProfile, scopedAdminRequest(t, http.MethodPost, "/api/admins/profile-image?id=3", 1, nil))
	if crossProfile.Code != http.StatusForbidden {
		t.Fatalf("cross-account profile upload: got %d, want 403", crossProfile.Code)
	}

	staffDelete := httptest.NewRecorder()
	DeleteAdminHandler(db)(staffDelete, scopedAdminRequest(t, http.MethodDelete, "/api/admins/2", 2, nil))
	if staffDelete.Code != http.StatusForbidden {
		t.Fatalf("staff delete: got %d, want 403", staffDelete.Code)
	}
}

func TestAdminRoleOrPasswordChangeRevokesTargetSessions(t *testing.T) {
	db := securityTestDB(t)
	if _, err := db.Exec(`INSERT INTO admins VALUES
		(2, 'staff', '', 'admin', 'owner@example.test', 'staff@example.test', '', 0, NULL, '', '');
		INSERT INTO sessions VALUES (5, 2, 'staff-session')`); err != nil {
		t.Fatal(err)
	}

	w := httptest.NewRecorder()
	UpdateAdminHandler(db)(w, scopedAdminRequest(t, http.MethodPut, "/api/admins/2", 1, map[string]string{"role": "services"}))
	if w.Code != http.StatusOK {
		t.Fatalf("owner role update: %d %s", w.Code, w.Body.String())
	}
	var sessions int
	if err := db.QueryRow("SELECT COUNT(*) FROM sessions WHERE admin_id = 2").Scan(&sessions); err != nil {
		t.Fatal(err)
	}
	if sessions != 0 {
		t.Fatalf("target sessions remain: %d", sessions)
	}

	selfWithoutPassword := httptest.NewRecorder()
	UpdateAdminHandler(db)(selfWithoutPassword, scopedAdminRequest(t, http.MethodPut, "/api/admins/1", 1, map[string]string{"new_password": "AnotherPassword1"}))
	if selfWithoutPassword.Code != http.StatusBadRequest {
		t.Fatalf("self password change without old password: got %d, want 400", selfWithoutPassword.Code)
	}
}

func TestUpdateAdminCanClearPromptPayIDWhenFieldIsPresent(t *testing.T) {
	db := securityTestDB(t)
	if _, err := db.Exec("UPDATE admins SET promptpay_id = ? WHERE id = 1", "0812345678"); err != nil {
		t.Fatal(err)
	}

	w := httptest.NewRecorder()
	UpdateAdminHandler(db)(w, scopedAdminRequest(t, http.MethodPut, "/api/admins/1", 1, map[string]string{"promptpay_id": ""}))
	if w.Code != http.StatusOK {
		t.Fatalf("clear PromptPay: %d %s", w.Code, w.Body.String())
	}

	var promptPayID string
	if err := db.QueryRow("SELECT promptpay_id FROM admins WHERE id = 1").Scan(&promptPayID); err != nil {
		t.Fatal(err)
	}
	if promptPayID != "" {
		t.Fatalf("PromptPay was not cleared: %q", promptPayID)
	}
}

func TestCreateAdminUsesOwnerScopeAndRejectsPrivilegeEscalation(t *testing.T) {
	db := securityTestDB(t)

	elevated := httptest.NewRecorder()
	CreateAdminHandler(db)(elevated, scopedAdminRequest(t, http.MethodPost, "/api/admins", 1, map[string]string{
		"username": "newowner", "email": "staff@example.test", "password": "Temporary1", "role": "superadmin",
	}))
	if elevated.Code != http.StatusBadRequest {
		t.Fatalf("superadmin creation: got %d, want 400", elevated.Code)
	}

	created := httptest.NewRecorder()
	CreateAdminHandler(db)(created, scopedAdminRequest(t, http.MethodPost, "/api/admins", 1, map[string]string{
		"username": "newstaff", "email": "staff@example.test", "password": "Temporary1", "role": "admin",
	}))
	if created.Code != http.StatusOK {
		t.Fatalf("staff creation: %d %s", created.Code, created.Body.String())
	}
	var primary, recovery, role, passwordHash string
	if err := db.QueryRow("SELECT email, backup_email, role, password FROM admins WHERE username = 'newstaff'").Scan(&primary, &recovery, &role, &passwordHash); err != nil {
		t.Fatal(err)
	}
	if primary != "owner@example.test" || recovery != "staff@example.test" || role != "admin" {
		t.Fatalf("created scope = %q/%q/%q", primary, recovery, role)
	}
	if err := bcrypt.CompareHashAndPassword([]byte(passwordHash), []byte("Temporary1")); err != nil {
		t.Fatal("staff password was not stored from the authenticated request")
	}
}

func TestPublicLoginAndRegistrationAreRateLimitedAndValidatePasswords(t *testing.T) {
	db := securityTestDB(t)
	requestRateMu.Lock()
	previous := requestRateWindows
	requestRateWindows = make(map[string]requestRateWindow)
	requestRateMu.Unlock()
	t.Cleanup(func() {
		requestRateMu.Lock()
		requestRateWindows = previous
		requestRateMu.Unlock()
	})

	for attempt := 1; attempt <= 11; attempt++ {
		body, _ := json.Marshal(map[string]string{"username": "owner", "password": "wrong"})
		req := httptest.NewRequest(http.MethodPost, "/api/login", bytes.NewReader(body))
		req.RemoteAddr = "198.51.100.88:1234"
		w := httptest.NewRecorder()
		LoginHandler(db)(w, req)
		if attempt <= 10 && w.Code != http.StatusUnauthorized {
			t.Fatalf("login attempt %d: got %d, want 401", attempt, w.Code)
		}
		if attempt == 11 && w.Code != http.StatusTooManyRequests {
			t.Fatalf("login attempt %d: got %d, want 429", attempt, w.Code)
		}
	}

	weakBody, _ := json.Marshal(map[string]string{
		"name": "public-user", "email": "public@example.test", "password": "1234",
	})
	weakReq := httptest.NewRequest(http.MethodPost, "/api/register", bytes.NewReader(weakBody))
	weakReq.RemoteAddr = "198.51.100.89:1234"
	weakW := httptest.NewRecorder()
	RegisterHandler(db)(weakW, weakReq)
	if weakW.Code != http.StatusBadRequest {
		t.Fatalf("weak registration password: got %d, want 400", weakW.Code)
	}
}

func TestSystemOperatorRequiresConfiguredSuperadminID(t *testing.T) {
	t.Setenv("SYSTEM_OPERATOR_ADMIN_ID", "1")
	req := httptest.NewRequest(http.MethodGet, "/api/system/backups", nil)
	ctx := context.WithValue(req.Context(), "admin_id", 1)
	ctx = context.WithValue(ctx, "admin_role", "superadmin")
	if !IsSystemOperator(req.WithContext(ctx)) {
		t.Fatal("configured superadmin was not recognized as system operator")
	}

	otherCtx := context.WithValue(req.Context(), "admin_id", 2)
	otherCtx = context.WithValue(otherCtx, "admin_role", "superadmin")
	if IsSystemOperator(req.WithContext(otherCtx)) {
		t.Fatal("different tenant superadmin was treated as system operator")
	}

	staffCtx := context.WithValue(req.Context(), "admin_id", 1)
	staffCtx = context.WithValue(staffCtx, "admin_role", "admin")
	if IsSystemOperator(req.WithContext(staffCtx)) {
		t.Fatal("staff role was treated as system operator")
	}
}
