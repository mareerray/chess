import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/websocket_service.dart';

class LobbyScreen extends StatefulWidget {
  const LobbyScreen({super.key});

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  late WebSocketService _wsService;

  @override
  void initState() {
    super.initState();
    _wsService = Provider.of<WebSocketService>(context, listen: false);
    _wsService.connectToLobby('ws://192.168.1.57:8080/rooms');
    
    _wsService.roomStream.listen((roomID) {
      if (mounted) {
        Navigator.pushReplacementNamed(
          context, 
          '/game', 
          arguments: roomID,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              color: Color(0xFFE94560),
            ),
            const SizedBox(height: 32),
            const Text(
              'FINDING OPPONENT...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                letterSpacing: 2,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 64),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'CANCEL',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
