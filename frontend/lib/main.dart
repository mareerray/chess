import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/websocket_service.dart';
import 'screens/main_menu.dart';
import 'screens/lobby.dart';
import 'screens/game_board.dart';

void main() {
  runApp(
    Provider<WebSocketService>(
      create: (_) => WebSocketService(),
      dispose: (_, service) => service.dispose(),
      child: const ChessApp(),
    ),
  );
}

class ChessApp extends StatelessWidget {
  const ChessApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chess Mobile',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color(0xFFE94560),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFE94560),
          secondary: Color(0xFFC0392B),
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const MainMenuScreen(),
        '/lobby': (context) => const LobbyScreen(),
        '/game': (context) => const GameBoardScreen(),
      },
    );
  }
}
