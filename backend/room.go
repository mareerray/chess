package main

import (
	"fmt"
	"log"
	"net/http"
	"strings"
	"sync"
	"time"

	"github.com/google/uuid"
	"github.com/gorilla/websocket"
)

type GameManager struct {
	rooms       map[string]*Room
	waitingRoom chan *websocket.Conn
	mu          sync.Mutex
}

func NewGameManager() *GameManager {
	gm := &GameManager{
		rooms:       make(map[string]*Room),
		waitingRoom: make(chan *websocket.Conn, 10),
	}
	go gm.matchmaking()
	return gm
}

func (gm *GameManager) matchmaking() {
	for {
		player1 := <-gm.waitingRoom
		// Check if player1 is still connected
		if err := player1.WriteControl(websocket.PingMessage, []byte{}, time.Now().Add(time.Second)); err != nil {
			log.Println("Skipping disconnected player1 in matchmaking")
			player1.Close()
			continue
		}

		player2 := <-gm.waitingRoom
		// Check if player2 is still connected
		if err := player2.WriteControl(websocket.PingMessage, []byte{}, time.Now().Add(time.Second)); err != nil {
			log.Println("Skipping disconnected player2 in matchmaking")
			player2.Close()
			// Put player1 back to wait for another opponent
			go func() { gm.waitingRoom <- player1 }()
			continue
		}

		roomID := strings.ToUpper(uuid.New().String())
		room := NewRoom(roomID)

		gm.mu.Lock()
		gm.rooms[roomID] = room
		gm.mu.Unlock()

		log.Printf("Match found! Creating room %s\n", roomID)

		// Notify both players of the room ID and their colors
		err1 := player1.WriteMessage(websocket.TextMessage, []byte("JOIN:"+roomID+":white"))
		err2 := player2.WriteMessage(websocket.TextMessage, []byte("JOIN:"+roomID+":black"))

		if err1 != nil {
			log.Printf("Failed to notify player 1: %v\n", err1)
			// Match failed, room will be cleaned up eventually or remain empty
		}
		if err2 != nil {
			log.Printf("Failed to notify player 2: %v\n", err2)
		}
	}
}

func (gm *GameManager) HandleLobby(w http.ResponseWriter, r *http.Request) {
	conn, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		log.Println("Upgrade error:", err)
		return
	}
	log.Println("Player entered lobby")
	
	gm.waitingRoom <- conn

	// Wait for disconnection/joining game
	for {
		_, _, err := conn.ReadMessage()
		if err != nil {
			break
		}
	}
}

func (gm *GameManager) HandleCreate(w http.ResponseWriter, r *http.Request) {
	roomID := strings.ToUpper(uuid.New().String()[:6]) // Short code for easier sharing
	room := NewRoom(roomID)

	gm.mu.Lock()
	gm.rooms[roomID] = room
	gm.mu.Unlock()

	log.Printf("Private room created: %s\n", roomID)
	w.Header().Set("Content-Type", "application/json")
	fmt.Fprintf(w, `{"roomID": "%s"}`, roomID)
}

func (gm *GameManager) HandlePractice(w http.ResponseWriter, r *http.Request) {
	roomID := strings.ToUpper(uuid.New().String()[:6]) + "_BOT"
	room := NewRoom(roomID)
	room.IsBotGame = true
	room.BotColor = "black"

	gm.mu.Lock()
	gm.rooms[roomID] = room
	gm.mu.Unlock()

	log.Printf("Practice room created: %s", roomID)
	w.Header().Set("Content-Type", "application/json")
	fmt.Fprintf(w, `{"roomID": "%s"}`, roomID)
}

func (gm *GameManager) HandleGame(w http.ResponseWriter, r *http.Request) {
	path := r.URL.Path
	roomID := strings.ToUpper(strings.TrimPrefix(path, "/rooms/"))
	if roomID == "" {
		http.Error(w, "Room ID required", http.StatusBadRequest)
		return
	}

	requestedColor := r.URL.Query().Get("color")

	gm.mu.Lock()
	room, exists := gm.rooms[roomID]
	gm.mu.Unlock()

	if !exists {
		log.Printf("Join failed: Room %s not found\n", roomID)
		http.Error(w, "Room not found", http.StatusNotFound)
		return
	}

	conn, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		log.Println("Upgrade error:", err)
		return
	}

	room.Join(conn, requestedColor)
}
