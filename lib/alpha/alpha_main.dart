import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'alpha_game.dart';

void main() {
  runApp(const AlphaApp());
}

class AlphaApp extends StatelessWidget {
  const AlphaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: GameWidget(game: AlphaGame()),
      ),
    );
  }
}
