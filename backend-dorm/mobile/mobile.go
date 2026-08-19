package mobile

import "dorm_os/core"

// StartServer initializes the Go HTTP server for Capacitor to talk to locally.
// This function can be called from iOS Swift or Android Java/Kotlin.
func StartServer() {
	// core.RunServer blocks and starts listening on port 4282 (or PORT env)
	go core.RunServer()
}
