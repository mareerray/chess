import 'dart:async';
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
  StreamSubscription? _roomSubscription;

  @override
  void initState() {
    super.initState();
    _wsService = Provider.of<WebSocketService>(context, listen: false);
    _wsService.connectToLobby('ws://192.168.1.57:8080/rooms');
    
    _roomSubscription = _wsService.roomStream.listen((message) {
      if (!mounted) return;
      
      final parts = message.split(':');
      if (parts.length >= 3 && parts[0] == 'JOIN') {
        final roomID = parts[1];
        final assignedColor = parts[2];
        Navigator.pushReplacementNamed(
          context, 
          '/game', 
          arguments: '$roomID:$assignedColor',
        );
      }
    });
  }

  @override
  void dispose() {
    _roomSubscription?.cancel();
    _wsService.disconnectLobby();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF262421),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              "Searching for opponent...",
              style: TextStyle(color: Colors.white70, fontSize: 18),
            ),
            const SizedBox(height: 32),
            const CircularProgressIndicator(color: Color(0xFFE94560)),
            const SizedBox(height: 32),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE94560),
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text("CANCEL"),
            ),
          ],
        ),
      ),
    );
  }
}
