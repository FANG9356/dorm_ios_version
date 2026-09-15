package core

import (
	"io/fs"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func TestLiffHandlerServesEndpointAndAssets(t *testing.T) {
	assets, err := embeddedLiffFiles.ReadFile("liff/app.js")
	if err != nil || len(assets) == 0 {
		t.Fatalf("embedded app.js unavailable: %v", err)
	}

	fileServer := http.FileServer(http.FS(mustLiffSubFS(t)))
	handler := withLiffHeaders(http.StripPrefix("/liff/", fileServer))

	for _, path := range []string{"/liff", "/liff/"} {
		recorder := httptest.NewRecorder()
		handler.ServeHTTP(recorder, httptest.NewRequest(http.MethodGet, path, nil))
		if recorder.Code != http.StatusOK {
			t.Fatalf("GET %s status = %d", path, recorder.Code)
		}
		if !strings.Contains(recorder.Body.String(), "ผูกบัญชีหอพัก") {
			t.Fatalf("GET %s did not serve LIFF page", path)
		}
		if strings.Contains(recorder.Body.String(), `id="room"`) {
			t.Fatalf("GET %s still exposes a room selector", path)
		}
		if recorder.Header().Get("Content-Security-Policy") == "" {
			t.Fatalf("GET %s missing CSP", path)
		}
	}
	recorder := httptest.NewRecorder()
	handler.ServeHTTP(recorder, httptest.NewRequest(http.MethodGet, "/liff/app.js", nil))
	if recorder.Code != http.StatusOK || !strings.Contains(recorder.Body.String(), "2010525486-cUOKPsCJ") {
		t.Fatalf("GET /liff/app.js did not serve the configured LIFF client")
	}
	if strings.Contains(recorder.Body.String(), "/api/liff/rooms") {
		t.Fatal("GET /liff/app.js still loads the public room list")
	}

	request := httptest.NewRequest(http.MethodPost, "/liff", nil)
	recorder = httptest.NewRecorder()
	handler.ServeHTTP(recorder, request)
	if recorder.Code != http.StatusMethodNotAllowed {
		t.Fatalf("POST /liff status = %d", recorder.Code)
	}
}

func mustLiffSubFS(t *testing.T) fs.FS {
	t.Helper()
	sub, err := fs.Sub(embeddedLiffFiles, "liff")
	if err != nil {
		t.Fatal(err)
	}
	return sub
}
