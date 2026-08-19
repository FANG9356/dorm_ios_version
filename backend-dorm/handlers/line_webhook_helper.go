package handlers

import (
	"encoding/json"
	"fmt"
	"net/http"
	"net/url"
	"time"
)

var cachedWebhookURL string
var cachedWebhookTime time.Time

// GetBaseURLFromWebhook fetches the active webhook endpoint from LINE API and extracts the base URL
func GetBaseURLFromWebhook() string {
	// Simple caching to avoid hitting LINE API too often
	if cachedWebhookURL != "" && time.Since(cachedWebhookTime) < 5*time.Minute {
		return cachedWebhookURL
	}

	token := getLineToken()
	if token == "" {
		return ""
	}

	req, _ := http.NewRequest("GET", "https://api.line.me/v2/bot/channel/webhook/endpoint", nil)
	req.Header.Set("Authorization", "Bearer "+token)

	client := &http.Client{Timeout: 5 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		return cachedWebhookURL // Fallback to cache if request fails
	}
	defer resp.Body.Close()

	var data map[string]interface{}
	json.NewDecoder(resp.Body).Decode(&data)
	
	if endpoint, ok := data["endpoint"].(string); ok && endpoint != "" {
		parsedURL, err := url.Parse(endpoint)
		if err == nil {
			baseURL := fmt.Sprintf("%s://%s", parsedURL.Scheme, parsedURL.Host)
			cachedWebhookURL = baseURL
			cachedWebhookTime = time.Now()
			return baseURL
		}
	}

	return cachedWebhookURL // Fallback
}
