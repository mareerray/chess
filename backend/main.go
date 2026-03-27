package main

import (
	"log"
	"net/http"
	"os"

	"github.com/gorilla/websocket"
)

var upgrader = websocket.Upgrader{
	CheckOrigin: func(r *http.Request) bool {
		return true // Allow all origins for development
	},
}

func main() {
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	gameManager := NewGameManager()

	http.HandleFunc("/create", gameManager.HandleCreate)
	http.HandleFunc("/practice", gameManager.HandlePractice)
	http.HandleFunc("/rooms", gameManager.HandleLobby)
	http.HandleFunc("/rooms/", gameManager.HandleGame)

	log.Printf("Server starting on port %s", port)
	err := http.ListenAndServe(":"+port, nil)
	if err != nil {
		log.Fatal("ListenAndServe: ", err)
	}
}
