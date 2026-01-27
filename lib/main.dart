import 'package:flutter/material.dart';

void main() {
  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Trainingsplanung Fechten MvK',
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Trainingsplanung Fechten MvK'),
        ),
        body: const Center(
          child: Text(
            'App läuft erfolgreich ✅',
            style: TextStyle(fontSize: 18),
          ),
        ),
      ),
    );
  }
}
