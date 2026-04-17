package main

import (
	"log"
	"net/http"
	"os"

	"github.com/gorilla/websocket"
)

// ── WebSocket Upgrader ────────────────────────────────────────────────────────

// upgrader promotes HTTP connections to WebSocket connections.
// CheckOrigin allows all origins — restrict this in production.
var upgrader = websocket.Upgrader{
	CheckOrigin: func(r *http.Request) bool {
		return true 
	},
}

// ── CORS Middleware ───────────────────────────────────────────────────────────

// corsMiddleware allows the browser to talk to our backend from a different domain.
// Without this, browsers block all requests coming from the Flutter web app.
// It wraps every route handler and adds the necessary "permission" headers.
func corsMiddleware(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {

        // Tell the browser: "Any website is allowed to call this server"
        w.Header().Set("Access-Control-Allow-Origin", "*")

        // Tell the browser: "These are the HTTP methods we accept"
        w.Header().Set("Access-Control-Allow-Methods", "GET, POST, OPTIONS")

        // Tell the browser: "Content-Type header is allowed in requests"
        w.Header().Set("Access-Control-Allow-Headers", "Content-Type")

        // Before every real request, the browser sends a "preflight" OPTIONS request
        // to check if the server allows the call. We just say yes and stop here.
        if r.Method == http.MethodOptions {
            w.WriteHeader(http.StatusOK)
            return
        }

        // If it is a normal request (not OPTIONS), pass it to the actual handler
        next.ServeHTTP(w, r)
    })
}

// ── Entry Point ───────────────────────────────────────────────────────────────

func main() {
	// Default to port 8080 if PORT environment variable is not set
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	gameManager := NewGameManager()

	// ── Routes ────────────────────────────────────────────────────────────────
	// defining a health check endpoint for web services
	http.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		w.Write([]byte("ok"))
	})

	http.HandleFunc("/create", gameManager.HandleCreate) // creates a new private game room
	http.HandleFunc("/practice", gameManager.HandlePractice) // starts a solo practice session against the bot
	http.HandleFunc("/rooms", gameManager.HandleLobby) // lobby WebSocket for matchmaking and invites
	http.HandleFunc("/rooms/", gameManager.HandleGame) // /rooms/{id} game WebSocket for an active match

	log.Printf("Server starting on port %s", port)
	
	if err := http.ListenAndServe(":"+port, corsMiddleware(http.DefaultServeMux)); err != nil {
		log.Fatal("ListenAndServe: ", err)
	}
}
