import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class MainMenuScreen extends StatelessWidget {
  const MainMenuScreen({super.key});

  final String baseUrl = 'http://192.168.1.57:8080';

  Future<void> _createRoom(BuildContext context) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/create'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final roomID = data['roomID'];
        if (context.mounted) {
          Navigator.pushNamed(context, '/game', arguments: roomID);
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
          Navigator.pushNamed(context, '/game', arguments: roomID);
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
                Navigator.pushNamed(context, '/game', arguments: code);
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
            colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'CHESS',
                    style: TextStyle(
                      fontSize: 64,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 8,
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
                    title: 'PRACTICE',
                    onPressed: () => _startPractice(context),
                  ),
                ],
              ),
            ),
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
          colors: [Color(0xFFE94560), Color(0xFFC0392B)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE94560).withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
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
