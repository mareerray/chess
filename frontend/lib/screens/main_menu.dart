import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import '../services/profile_service.dart';
import '../services/websocket_service.dart';

class MainMenuScreen extends StatefulWidget {
  const MainMenuScreen({super.key});

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen> {
  final String baseUrl = 'https://colory-kaci-dreadingly.ngrok-free.dev';
  final ProfileService _profileService = ProfileService();
  late WebSocketService _wsService;
  StreamSubscription? _roomSubscription;
  List<dynamic> _onlinePlayers = [];

  @override
  void initState() {
    super.initState();
    _wsService = Provider.of<WebSocketService>(context, listen: false);
    _wsService.connectLobby();

    _roomSubscription = _wsService.roomStream.listen((message) {
      if (!mounted) return;

      if (message.startsWith('ONLINE_PLAYERS:')) {
        final jsonStr = message.substring('ONLINE_PLAYERS:'.length);
        setState(() {
          _onlinePlayers = json.decode(jsonStr);
        });
      } else if (message.startsWith('INVITE_FROM:')) {
        final parts = message.split(':');
        if (parts.length >= 4) {
          _showInviteDialog(parts[1], parts[2], parts[3]);
        }
      } else if (message.startsWith('INVITE_DECLINED:')) {
        final name = message.split(':')[1];
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$name declined your invitation'), backgroundColor: const Color(0xFFE94560)),
        );
      } else if (message.startsWith('JOIN:')) {
        final parts = message.split(':');
        if (parts.length >= 3) {
          final roomID = parts[1];
          final color = parts[2];
          // Only handle invite rooms here — public match is handled by LobbyScreen
          if (roomID.endsWith('_INV')) {
            Navigator.pushNamed(context, '/game', arguments: '$roomID:$color');
          }
        }
      }    
    });
  }

  @override
  void dispose() {
    _roomSubscription?.cancel();
    super.dispose();
  }

  int get numOfOpponents {
    return _onlinePlayers.where((player) => player['id'] != _profileService.deviceId).length;
  }

  void _showInviteDialog(String challengerId, String challengerName, String challengerAvatar) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF262421),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('New Challenge!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80, height: 80,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), shape: BoxShape.circle),
              child: SvgPicture.string(ProfileService.getAvailableAvatars()[int.parse(challengerAvatar)]),
            ),
            const SizedBox(height: 16),
            Text('$challengerName wants to play with you!', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              _wsService.respondToInvite(challengerId, false);
              Navigator.pop(context);
            },
            child: const Text('DECLINE', style: TextStyle(color: Colors.white38)),
          ),
          ElevatedButton(
            onPressed: () {
              _wsService.respondToInvite(challengerId, true);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE94560),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('ACCEPT', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showOnlinePlayers() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1B1A17),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 24), decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(2))),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('ONLINE PLAYERS', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.2)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
                    child: Text('$numOfOpponents', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Expanded(
                child: _onlinePlayers.isEmpty || (_onlinePlayers.length == 1 && _onlinePlayers[0]['id'] == _profileService.deviceId)
                  ? const Center(child: Text('No other players online', style: TextStyle(color: Colors.white38)))
                  : ListView.builder(
                      controller: scrollController,
                      itemCount: _onlinePlayers.length,
                      itemBuilder: (context, index) {
                        final player = _onlinePlayers[index];
                        if (player['id'] == _profileService.deviceId) return const SizedBox.shrink();
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(16)),
                          child: Row(
                            children: [
                              Container(
                                width: 48, height: 48, padding: const EdgeInsets.all(8),
                                decoration: const BoxDecoration(color: Colors.black26, shape: BoxShape.circle),
                                child: SvgPicture.string(ProfileService.getAvailableAvatars()[int.parse(player['avatar'])]),
                              ),
                              const SizedBox(width: 16),
                              Expanded(child: Text(player['name'] ?? 'Anonymous', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold))),
                              ElevatedButton(
                                onPressed: () {
                                  _wsService.sendInvite(player['id']);
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Invitation sent to ${player['name']}'), backgroundColor: const Color(0xFFE94560)),
                                  );
                                },
                                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE94560), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                                child: const Text('INVITE', style: TextStyle(color: Colors.white)),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _createRoom(BuildContext context) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/create'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final roomID = data['roomID'];
        if (context.mounted) {
          Navigator.pushNamed(context, '/game', arguments: '$roomID:white');
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating room: $e')),
        );
      }
    }
  }

  Future<void> _startPractice(BuildContext context) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/practice'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final roomID = data['roomID'];
        if (context.mounted) {
          Navigator.pushNamed(context, '/game', arguments: '$roomID:white');
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error starting practice: $e')),
        );
      }
    }
  }

  void _showJoinDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('JOIN PRIVATE GAME'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Enter Room Code'),
          textCapitalization: TextCapitalization.characters,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () {
              final code = controller.text.trim().toUpperCase();
              if (code.isNotEmpty) {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/game', arguments: '$code:black');
              }
            },
            child: const Text('JOIN'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF262421), Color(0xFF21201D)],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // Online Players Button in Top Right
              Positioned(
                top: 16,
                right: 16,
                child: IconButton.filled(
                  onPressed: _showOnlinePlayers,
                  icon: const Icon(Icons.people),
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFFE94560),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.all(12),
                  ),
                ),
              ),
              if (_onlinePlayers.isNotEmpty)
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                    child: Text(
                      '$numOfOpponents',
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              Center(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Profile Header
                      GestureDetector(
                        onTap: () => Navigator.pushNamed(context, '/setup'),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE94560).withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                                border: Border.all(color: const Color(0xFFE94560).withValues(alpha: 0.3), width: 2),
                              ),
                              child: SvgPicture.string(
                                _profileService.avatarSvg,
                                width: 60,
                                height: 60,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _profileService.nickname,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const Text(
                              'tap to edit profile',
                              style: TextStyle(fontSize: 12, color: Colors.white38),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 48),
                      const Text(
                        'CHESS',
                        style: TextStyle(
                          fontSize: 56,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 12,
                        ),
                      ),
                      const SizedBox(height: 48),
                      _MenuButton(
                        title: 'PUBLIC MATCH',
                        onPressed: () => Navigator.pushNamed(context, '/lobby'),
                      ),
                      const SizedBox(height: 16),
                      _MenuButton(
                        title: 'CREATE PRIVATE',
                        onPressed: () => _createRoom(context),
                      ),
                      const SizedBox(height: 16),
                      _MenuButton(
                        title: 'JOIN PRIVATE',
                        onPressed: () => _showJoinDialog(context),
                      ),
                      const SizedBox(height: 16),
                      _MenuButton(
                        title: 'PLAY WITH BOT',
                        onPressed: () => _startPractice(context),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuButton extends StatelessWidget {
  final String title;
  final VoidCallback onPressed;

  const _MenuButton({required this.title, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250,
      height: 60,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          colors: [Color(0xFF27AE60), Color(0xFF1E8449)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF27AE60).withValues(alpha: 0.2),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
        onPressed: onPressed,
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
