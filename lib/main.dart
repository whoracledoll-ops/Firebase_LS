import 'package:flutter/material.dart';
import 'screens/tester_messages_manager_screen.dart';

void main() {
  runApp(const PostHiveRcManagerApp());
}

class PostHiveRcManagerApp extends StatelessWidget {
  const PostHiveRcManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PostHive RC Manager',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blueGrey,
      ),
      home: const TesterMessagesManagerScreen(),
    );
  }
}