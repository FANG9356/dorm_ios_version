package handlers

import (
	"net/http"
	"net/http/httptest"
	"testing"
	"time"
)

func TestRequestClientIPTrustsCloudflareOnlyBehindLocalProxy(t *testing.T) {
	proxied := httptest.NewRequest(http.MethodPost, "/api/liff/verify-tenant", nil)
	proxied.RemoteAddr = "127.0.0.1:1234"
	proxied.Header.Set("CF-Connecting-IP", "203.0.113.8")
	if got := requestClientIP(proxied); got != "203.0.113.8" {
		t.Fatalf("proxied IP = %q", got)
	}

	direct := httptest.NewRequest(http.MethodPost, "/api/liff/verify-tenant", nil)
	direct.RemoteAddr = "198.51.100.4:1234"
	direct.Header.Set("CF-Connecting-IP", "203.0.113.9")
	if got := requestClientIP(direct); got != "198.51.100.4" {
		t.Fatalf("direct IP trusted spoofed header: %q", got)
	}
}

func TestRequestRateLimitBlocksAfterConfiguredAttempts(t *testing.T) {
	requestRateMu.Lock()
	previous := requestRateWindows
	requestRateWindows = make(map[string]requestRateWindow)
	requestRateMu.Unlock()
	t.Cleanup(func() {
		requestRateMu.Lock()
		requestRateWindows = previous
		requestRateMu.Unlock()
	})

	req := httptest.NewRequest(http.MethodPost, "/api/liff/verify-tenant", nil)
	req.RemoteAddr = "192.0.2.10:4321"
	for attempt := 1; attempt <= 2; attempt++ {
		if !allowRequestAttempt(req, "verify-test", 2, time.Minute) {
			t.Fatalf("attempt %d rejected early", attempt)
		}
	}
	if allowRequestAttempt(req, "verify-test", 2, time.Minute) {
		t.Fatal("rate limit did not reject excess attempt")
	}
}
