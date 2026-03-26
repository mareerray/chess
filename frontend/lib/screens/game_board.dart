import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:chess/chess.dart' as chess_lib;
import '../services/websocket_service.dart';

class GameBoardScreen extends StatefulWidget {
  const GameBoardScreen({super.key});

  @override
  State<GameBoardScreen> createState() => _GameBoardScreenState();
}

class _GameBoardScreenState extends State<GameBoardScreen> {
  late WebSocketService _wsService;
  late chess_lib.Chess _chess;
  String? _roomID;
  String _myColor = "";
  String _turn = "white";
  String? _selectedSquare;
  List<String> _possibleMoves = [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _roomID = ModalRoute.of(context)!.settings.arguments as String?;
    if (_roomID != null) {
      _wsService = Provider.of<WebSocketService>(context, listen: false);
      _wsService.connectToGame('ws://192.168.1.57:8080/rooms/$_roomID');
      _setupListeners();
    }
    _chess = chess_lib.Chess();
  }

  void _setupListeners() {
    _wsService.gameStream.listen((message) {
      if (mounted) {
        setState(() {
          if (message == "white" || message == "black") {
            _myColor = message;
          } else if (message.startsWith("BOARD:")) {
            final fen = message.substring(6);
            _chess.load(fen);
          } else if (message.startsWith("TURN:")) {
            _turn = message.substring(5);
          } else if (message.startsWith("GAMEOVER:")) {
            _showGameOver(message.substring(9));
          } else if (message.startsWith("ERROR:")) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(message)),
            );
          }
        });
      }
    });
  }

  void _onSquareTap(String square) {
    if (_turn != _myColor) return;

    setState(() {
      if (_selectedSquare == null) {
        // Select piece
        final piece = _chess.get(square);
        if (piece != null && piece.color == (_myColor == "white" ? chess_lib.Color.WHITE : chess_lib.Color.BLACK)) {
          _selectedSquare = square;
          _possibleMoves = _chess.moves({"square": square, "verbose": true}).map((m) => m["to"] as String).toList();
        }
      } else {
        // Try move
        if (_possibleMoves.contains(square)) {
          final moveStr = "$_selectedSquare$square";
          _wsService.sendMove(moveStr);
          _selectedSquare = null;
          _possibleMoves = [];
        } else {
          // Deselect or select another piece
          final piece = _chess.get(square);
          if (piece != null && piece.color == (_myColor == "white" ? chess_lib.Color.WHITE : chess_lib.Color.BLACK)) {
            _selectedSquare = square;
            _possibleMoves = _chess.moves({"square": square, "verbose": true}).map((m) => m["to"] as String).toList();
          } else {
            _selectedSquare = null;
            _possibleMoves = [];
          }
        }
      }
    });
  }

  void _showGameOver(String reason) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text("Game Over"),
        content: Text(reason),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            child: const Text("EXIT"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        title: Text("Playing as $_myColor"),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildPlayerInfo(_myColor == "white" ? "Opponent (Black)" : "Opponent (White)", _turn != _myColor),
          const Spacer(),
          _buildBoard(),
          const Spacer(),
          _buildPlayerInfo("You ($_myColor)", _turn == _myColor),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildPlayerInfo(String label, bool isTurn) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: isTurn ? const Color(0xFFE94560).withOpacity(0.2) : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isTurn) const Padding(
            padding: EdgeInsets.only(right: 8),
            child: Icon(Icons.timer, color: Color(0xFFE94560), size: 16),
          ),
          Text(
            label,
            style: TextStyle(
              color: isTurn ? const Color(0xFFE94560) : Colors.white70,
              fontWeight: isTurn ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBoard() {
    double size = MediaQuery.of(context).size.width - 32;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white24, width: 4),
      ),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 8),
        itemCount: 64,
        physics: const NeverScrollableScrollPhysics(),
        itemBuilder: (context, index) {
          int row = index ~/ 8;
          int col = index % 8;
          
          // Flip board for black
          if (_myColor == "black") {
            row = 7 - row;
            col = 7 - col;
          } else {
            row = 7 - row;
          }

          final square = "${String.fromCharCode(97 + col)}${row + 1}";
          final isDark = (row + col) % 2 == 0;
          final isSelected = _selectedSquare == square;
          final isPossible = _possibleMoves.contains(square);

          return GestureDetector(
            onTap: () => _onSquareTap(square),
            child: Container(
              color: isSelected 
                ? Colors.yellow.withOpacity(0.5) 
                : isPossible 
                  ? Colors.green.withOpacity(0.5)
                  : (isDark ? const Color(0xFF16213E) : const Color(0xFF0F3460)),
              child: _buildPiece(square),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPiece(String square) {
    final piece = _chess.get(square);
    if (piece == null) return const SizedBox();

    // For now use text icons if assets aren't ready, but let's try to handle both
    return Center(
      child: Text(
        _getPieceSymbol(piece),
        style: TextStyle(
          fontSize: 32,
          color: piece.color == chess_lib.Color.WHITE ? Colors.white : Colors.black,
          shadows: [
            if (piece.color == chess_lib.Color.BLACK) const Shadow(color: Colors.white, blurRadius: 2),
          ],
        ),
      ),
    );
  }

  String _getPieceSymbol(chess_lib.Piece piece) {
    switch (piece.type) {
      case chess_lib.PieceType.PAWN: return "♟";
      case chess_lib.PieceType.ROOK: return "♜";
      case chess_lib.PieceType.KNIGHT: return "♞";
      case chess_lib.PieceType.BISHOP: return "♝";
      case chess_lib.PieceType.QUEEN: return "♛";
      case chess_lib.PieceType.KING: return "♚";
      default: return "";
    }
  }
}
