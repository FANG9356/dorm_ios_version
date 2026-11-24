package handlers

import (
	"encoding/json"
	"fmt"
	"net/http"
	"net/url"
	"sync"
	"time"
)

var (
	cachedWebhookMu   sync.RWMutex
	cachedWebhookURL  string
	cachedWebhookTime time.Time
)

// GetBaseURLFromWebhook fetches the active webhook endpoint from LINE API and extracts the base URL
func GetBaseURLFromWebhook() string {
	cachedWebhookMu.RLock()
	cached := cachedWebhookURL
	fresh := cached != "" && time.Since(cachedWebhookTime) < 5*time.Minute
	cachedWebhookMu.RUnlock()
	if fresh {
		return cached
	}

	token := getLineToken()
	if token == "" {
		return ""
	}

	req, err := http.NewRequest("GET", "https://api.line.me/v2/bot/channel/webhook/endpoint", nil)
	if err != nil {
		return cached
	}
	req.Header.Set("Authorization", "Bearer "+token)

	client := &http.Client{Timeout: 5 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		return cached
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return cached
	}

	var data map[string]interface{}
	if err := json.NewDecoder(resp.Body).Decode(&data); err != nil {
		return cached
	}

	if endpoint, ok := data["endpoint"].(string); ok && endpoint != "" {
		parsedURL, err := url.Parse(endpoint)
		if err == nil && (parsedURL.Scheme == "https" || parsedURL.Scheme == "http") && parsedURL.Host != "" {
			baseURL := fmt.Sprintf("%s://%s", parsedURL.Scheme, parsedURL.Host)
			cachedWebhookMu.Lock()
			cachedWebhookURL = baseURL
			cachedWebhookTime = time.Now()
			cachedWebhookMu.Unlock()
			return baseURL
		}
	}

	return cached
}
