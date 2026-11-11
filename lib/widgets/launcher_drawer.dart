import 'package:flutter/material.dart';

class LauncherDrawer extends StatelessWidget {
  final String currentScreen;
  final Function(String screenKey) onSelectScreen;

  const LauncherDrawer({
    super.key,
    required this.currentScreen,
    required this.onSelectScreen,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              width: double.infinity,
              color: Colors.blueGrey[800],
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '🐝 PostHive RC Manager',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Remote Config 編集ツール',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  const Padding(
                    padding: const EdgeInsets.only(left: 16, top: 12, bottom: 4),
                    child: Text(
                      'リモートパラメータ',
                      style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.campaign, color: Colors.amber),
                    title: const Text('tester_messages', style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text('テスター向けお知らせメッセージ'),
                    selected: currentScreen == 'tester_messages',
                    selectedTileColor: Colors.amber.shade50,
                    onTap: () {
                      onSelectScreen('tester_messages');
                      Navigator.pop(context);
                    },
                  ),
                  const Divider(),
                  const Padding(
                    padding: const EdgeInsets.only(left: 16, top: 8, bottom: 4),
                    child: Text(
                      'システム / ツール',
                      style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.code, color: Colors.blue),
                    title: const Text('JSON 全件プレビュー'),
                    onTap: () {
                      Navigator.pop(context);
                      onSelectScreen('preview_json');
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}