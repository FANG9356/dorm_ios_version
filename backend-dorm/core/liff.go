package core

import (
	"embed"
	"io/fs"
	"net/http"
	"strings"
)

// Keep the LIFF client inside the server binary so a backend deployment cannot
// accidentally leave the public account-linking page behind.
//
//go:embed liff/index.html liff/app.js liff/styles.css
var embeddedLiffFiles embed.FS

func setupLiffHandler() {
	assets, err := fs.Sub(embeddedLiffFiles, "liff")
	if err != nil {
		panic(err)
	}
	fileServer := http.FileServer(http.FS(assets))

	http.Handle("/liff", withLiffHeaders(fileServer))
	http.Handle("/liff/", withLiffHeaders(http.StripPrefix("/liff/", fileServer)))
}

func withLiffHeaders(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodGet && r.Method != http.MethodHead {
			http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
			return
		}
		w.Header().Set("Content-Security-Policy", "default-src 'self'; script-src 'self' https://static.line-scdn.net; style-src 'self'; connect-src 'self' https://*.line.me https://*.line-scdn.net; img-src 'self' data: https:; base-uri 'none'; frame-ancestors 'none'; form-action 'self'")
		w.Header().Set("Referrer-Policy", "no-referrer")
		w.Header().Set("X-Content-Type-Options", "nosniff")
		w.Header().Set("Cache-Control", "no-store")

		// FileServer redirects a directory request. Serve the embedded index at
		// both endpoint spellings so LINE can use /liff or /liff/ directly.
		if strings.TrimSuffix(r.URL.Path, "/") == "/liff" {
			contents, readErr := embeddedLiffFiles.ReadFile("liff/index.html")
			if readErr != nil {
				http.Error(w, "LIFF page unavailable", http.StatusInternalServerError)
				return
			}
			w.Header().Set("Content-Type", "text/html; charset=utf-8")
			_, _ = w.Write(contents)
			return
		}
		next.ServeHTTP(w, r)
	})
}
