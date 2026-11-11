import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/tester_message.dart';
import '../widgets/launcher_drawer.dart';

class TesterMessagesManagerScreen extends StatefulWidget {
  const TesterMessagesManagerScreen({super.key});

  @override
  State<TesterMessagesManagerScreen> createState() => _TesterMessagesManagerScreenState();
}

class _TesterMessagesManagerScreenState extends State<TesterMessagesManagerScreen> {
  List<TesterMessage> messages = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  // 💾 ローカル保存
  Future<void> _saveMessages() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('rc_tester_messages', TesterMessage.encodeList(messages));
  }

  // 💾 読み込み（初回はサンプルデータを挿入）
  Future<void> _loadMessages() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString('rc_tester_messages');

    if (jsonStr != null && jsonStr.isNotEmpty) {
      messages = TesterMessage.decodeList(jsonStr);
    } else {
      // 初期サンプルデータ
      messages = [
        TesterMessage(
          id: 'msg_20261110_01',
          title: 'テスター版へようこそ',
          date: '2026-11-10',
          body: 'ListenSpeak テスター版のご利用ありがとうございます。お気付きの点があればお気軽にお知らせください。',
          isImportant: false,
        ),
      ];
      await _saveMessages();
    }

    setState(() => isLoading = false);
  }

  // 📋 全件 JSON をクリップボードにコピー（Firebase 貼り付け用）
  void _copyJsonToClipboard() {
    final jsonStr = TesterMessage.encodeList(messages);
    Clipboard.setData(ClipboardData(text: jsonStr));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('📢 Firebase Remote Config 用の JSON をコピーしました！'),
        backgroundColor: Colors.green,
      ),
    );
  }

  // ➕/✏️ メッセージ作成・編集モーダル
  Future<void> _openEditModal([TesterMessage? existingMsg]) async {
    final isEdit = existingMsg != null;
    final now = DateTime.now();
    final defaultId = 'msg_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_01';

    final idController = TextEditingController(text: isEdit ? existingMsg.id : defaultId);
    final titleController = TextEditingController(text: isEdit ? existingMsg.title : '');
    final dateController = TextEditingController(text: isEdit ? existingMsg.date : '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}');
    final bodyController = TextEditingController(text: isEdit ? existingMsg.body : '');
    bool isImportant = isEdit ? existingMsg.isImportant : false;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: Text(isEdit ? 'メッセージの編集' : '新しいメッセージの追加'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: idController,
                      decoration: const InputDecoration(labelText: 'ID (一意のキー)', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(labelText: 'タイトル', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: dateController,
                      decoration: const InputDecoration(labelText: '日付 (YYYY-MM-DD)', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: bodyController,
                      maxLines: 4,
                      decoration: const InputDecoration(labelText: '本文', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      title: const Text('重要メッセージ (ハイライト表示)'),
                      value: isImportant,
                      activeColor: Colors.amber,
                      onChanged: (val) => setModalState(() => isImportant = val),
                    ),
                  ],
                ),
              ),
              actions: [
                if (isEdit)
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () {
                      setState(() => messages.removeWhere((m) => m.id == existingMsg.id));
                      _saveMessages();
                      Navigator.pop(context);
                    },
                  ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('キャンセル'),
                ),
                FilledButton(
                  onPressed: () {
                    if (titleController.text.trim().isNotEmpty) {
                      setState(() {
                        if (isEdit) {
                          existingMsg.id = idController.text.trim();
                          existingMsg.title = titleController.text.trim();
                          existingMsg.date = dateController.text.trim();
                          existingMsg.body = bodyController.text.trim();
                          existingMsg.isImportant = isImportant;
                        } else {
                          messages.insert(
                            0,
                            TesterMessage(
                              id: idController.text.trim(),
                              title: titleController.text.trim(),
                              date: dateController.text.trim(),
                              body: bodyController.text.trim(),
                              isImportant: isImportant,
                            ),
                          );
                        }
                      });
                      _saveMessages();
                      Navigator.pop(context);
                    }
                  },
                  child: const Text('保存'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // 📋 JSON プレビューダイアログ
  void _showJsonPreviewDialog() {
    final jsonStr = const JsonEncoder.withIndent('  ').convert(messages.map((m) => m.toJson()).toList());
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('JSON 全件プレビュー'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: SelectableText(
              jsonStr,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('閉じる')),
          FilledButton.icon(
            icon: const Icon(Icons.copy, size: 18),
            label: const Text('JSONをコピー'),
            onPressed: () {
              _copyJsonToClipboard();
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('📢 tester_messages 管理'),
        backgroundColor: Colors.blueGrey[800],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.code),
            tooltip: 'JSONプレビュー',
            onPressed: _showJsonPreviewDialog,
          ),
          IconButton(
            icon: const Icon(Icons.copy_all),
            tooltip: 'Firebase用にJSONコピー',
            onPressed: _copyJsonToClipboard,
          ),
        ],
      ),
      drawer: LauncherDrawer(
        currentScreen: 'tester_messages',
        onSelectScreen: (screenKey) {
          if (screenKey == 'preview_json') {
            _showJsonPreviewDialog();
          }
        },
      ),
      body: messages.isEmpty
          ? const Center(
              child: Text('メッセージがありません。「+」ボタンから作成してください。', style: TextStyle(color: Colors.grey)),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final msg = messages[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: msg.isImportant ? 3 : 1,
                  color: msg.isImportant ? Colors.amber.shade50 : Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: msg.isImportant ? Colors.amber.shade400 : Colors.grey.shade300,
                      width: msg.isImportant ? 2 : 1,
                    ),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _openEditModal(msg),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                msg.date,
                                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                              ),
                              Row(
                                children: [
                                  if (msg.isImportant)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      margin: const EdgeInsets.only(right: 8),
                                      decoration: BoxDecoration(
                                        color: Colors.amber[800],
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Text('重要', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                    ),
                                  Text(
                                    'ID: ${msg.id}',
                                    style: TextStyle(fontSize: 11, color: Colors.grey[500], fontFamily: 'monospace'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            msg.title,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            msg.body,
                            style: TextStyle(fontSize: 14, color: Colors.grey[800], height: 1.4),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditModal(),
        backgroundColor: Colors.blueGrey[800],
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('メッセージ追加'),
      ),
    );
  }
}