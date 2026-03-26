package main

import (
	"log"
	"net/http"
	"strings"
	"sync"

	"github.com/google/uuid"
	"github.com/gorilla/websocket"
)

type GameManager struct {
	rooms      map[string]*Room
	waitingRoom chan *websocket.Conn
	mu         sync.Mutex
}

func NewGameManager() *GameManager {
	gm := &GameManager{
		rooms:      make(map[string]*Room),
		waitingRoom: make(chan *websocket.Conn, 1),
	}
	go gm.matchmaking()
	return gm
}

func (gm *GameManager) matchmaking() {
	for {
		player1 := <-gm.waitingRoom
		player2 := <-gm.waitingRoom

		roomID := uuid.New().String()
		room := NewRoom(roomID)

		gm.mu.Lock()
		gm.rooms[roomID] = room
		gm.mu.Unlock()

		// Notify both players of the room ID
		player1.WriteMessage(websocket.TextMessage, []byte(roomID))
		player2.WriteMessage(websocket.TextMessage, []byte(roomID))

		// Close lobby connections after sending room ID
		player1.Close()
		player2.Close()
	}
}

func (gm *GameManager) HandleLobby(w http.ResponseWriter, r *http.Request) {
	conn, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		log.Println("Upgrade error:", err)
		return
	}
	gm.waitingRoom <- conn
}

func (gm *GameManager) HandleGame(w http.ResponseWriter, r *http.Request) {
	path := r.URL.Path
	roomID := strings.TrimPrefix(path, "/rooms/")
	if roomID == "" {
		http.Error(w, "Room ID required", http.StatusBadRequest)
		return
	}

	gm.mu.Lock()
	room, exists := gm.rooms[roomID]
	gm.mu.Unlock()

	if !exists {
		http.Error(w, "Room not found", http.StatusNotFound)
		return
	}

	conn, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		log.Println("Upgrade error:", err)
		return
	}

	room.Join(conn)
}
