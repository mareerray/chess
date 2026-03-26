package main

import (
	"fmt"
	"log"
	"sync"

	"github.com/gorilla/websocket"
	"github.com/notnil/chess"
)

type Room struct {
	ID      string
	Game    *chess.Game
	Players map[*websocket.Conn]string // Conn -> Color (white or black)
	mu      sync.Mutex
	started bool
}

func NewRoom(id string) *Room {
	return &Room{
		ID:      id,
		Game:    chess.NewGame(),
		Players: make(map[*websocket.Conn]string),
	}
}

func (r *Room) Join(conn *websocket.Conn) {
	r.mu.Lock()
	defer r.mu.Unlock()

	if len(r.Players) >= 2 {
		conn.WriteMessage(websocket.TextMessage, []byte("Room full"))
		conn.Close()
		return
	}

	color := "white"
	if len(r.Players) == 1 {
		color = "black"
	}
	r.Players[conn] = color

	log.Printf("Player joined room %s as %s", r.ID, color)

	if len(r.Players) == 2 {
		r.started = true
		r.broadcastColors()
		go r.handleGame()
	}
}

func (r *Room) broadcastColors() {
	for conn, color := range r.Players {
		conn.WriteMessage(websocket.TextMessage, []byte(color))
	}
	// Also send initial board state
	r.broadcastBoard()
}

func (r *Room) broadcastBoard() {
	fen := r.Game.Position().String()
	for conn := range r.Players {
		conn.WriteMessage(websocket.TextMessage, []byte("BOARD:"+fen))
	}
}

func (r *Room) handleGame() {
	for conn := range r.Players {
		go func(c *websocket.Conn) {
			for {
				_, msg, err := c.ReadMessage()
				if err != nil {
					log.Println("Read error:", err)
					return
				}

				r.processMove(c, string(msg))
			}
		}(conn)
	}
}

func (r *Room) processMove(conn *websocket.Conn, moveStr string) {
	r.mu.Lock()
	defer r.mu.Unlock()

	color := r.Players[conn]
	if (color == "white" && r.Game.Position().Turn() != chess.White) ||
		(color == "black" && r.Game.Position().Turn() != chess.Black) {
		conn.WriteMessage(websocket.TextMessage, []byte("ERROR:Not your turn"))
		return
	}

	// Expecting move in long algebraic notation (e.g. e2e4)
	err := r.Game.MoveStr(moveStr)
	if err != nil {
		conn.WriteMessage(websocket.TextMessage, []byte("ERROR:Invalid move: "+err.Error()))
		return
	}

	// Move successful, broadcast new state
	r.broadcastBoard()

	// Check if game ended
	if r.Game.Outcome() != chess.NoOutcome {
		r.broadcastGameOver()
	} else {
		// Notify whose turn it is
		r.notifyTurn()
	}
}

func (r *Room) notifyTurn() {
	turn := "white"
	if r.Game.Position().Turn() == chess.Black {
		turn = "black"
	}
	for conn := range r.Players {
		conn.WriteMessage(websocket.TextMessage, []byte("TURN:"+turn))
	}
}

func (r *Room) broadcastGameOver() {
	outcome := r.Game.Outcome()
	method := r.Game.Method()
	msg := fmt.Sprintf("GAMEOVER:%s by %s", outcome, method)
	for conn := range r.Players {
		conn.WriteMessage(websocket.TextMessage, []byte(msg))
	}
}
