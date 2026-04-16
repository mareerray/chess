import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/websocket_service.dart';
import 'services/profile_service.dart';
import 'screens/main_menu.dart';
import 'screens/lobby.dart';
import 'screens/game_board.dart';
import 'screens/profile_setup.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

// ── Entry Point ───────────────────────────────────────────────────────────────
void main() async {
  // Required before any async work in main()
  WidgetsFlutterBinding.ensureInitialized();
    
  // Load profile from storage before the app renders
  await ProfileService().init();

  runApp(
    // WebSocketService is provided globally so any screen can access it
    Provider<WebSocketService>(
      create: (_) => WebSocketService(),
      dispose: (_, service) => service.dispose(),
      child: const ChessApp(),
    ),
  );
}

// ── Shared Shell with Footer ──────────────────────────────────────────────────
class AppShell extends StatelessWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  Future<void> _openLink(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child, // 👈 the actual screen goes here
      bottomNavigationBar: Container(
        color: Colors.black.withValues(alpha: 0.92),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: SafeArea(
          top: false,
          child: Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            runSpacing: 4,
            children: [
              Text(
                '© 2026',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              Text(
                'Kateryna Ovsiienko',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              GestureDetector(
                onTap: () => _openLink('https://github.com/mavka1207'), 
                child: const FaIcon(FontAwesomeIcons.github, color: Colors.white, size: 16),
              ),
              Text(
                '&',
                style: TextStyle(color: Colors.white38, fontSize: 14),
              ),
              Text(
                'Mayuree Reunsati',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              GestureDetector(
                onTap: () => _openLink('https://github.com/mareerray'),
                child: const FaIcon(FontAwesomeIcons.github, color: Colors.white, size: 16),
              ),
            ],
          ),        
        ),
      ),
    );
  }
}

// ── App ───────────────────────────────────────────────────────────────────────

class ChessApp extends StatelessWidget {
  const ChessApp({super.key});

  @override
  Widget build(BuildContext context) {
    final profileService = ProfileService();
    
    return MaterialApp(
      title: 'Chess Mobile',
      debugShowCheckedModeBanner: false,

      // ── Theme ──────────────────────────────────────────────────────────────
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color(0xFFE94560),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFE94560),
          secondary: Color(0xFFC0392B),
        ),
      ),

      // ── Routing ────────────────────────────────────────────────────────────
      // Send new players to setup; returning players go straight to main menu
      initialRoute: profileService.isProfileSet ? '/' : '/setup',
      routes: {
        '/': (context) => const AppShell(child: MainMenuScreen()),
        '/setup': (context) => const AppShell(child: ProfileSetupScreen()),
        '/lobby': (context) => const AppShell(child: LobbyScreen()),
        '/game': (context) => const AppShell(child: GameBoardScreen()),
      },
    );
  }
}
