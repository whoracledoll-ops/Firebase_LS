import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import '../models/tester_message.dart';
import '../widgets/launcher_drawer.dart';

class TesterMessagesManagerScreen extends StatefulWidget {
  const TesterMessagesManagerScreen({super.key});

  @override
  State<TesterMessagesManagerScreen> createState() => _TesterMessagesManagerScreenState();
}

class _TesterMessagesManagerScreenState extends State<TesterMessagesManagerScreen> {
  List<TesterMessage> messages = [];
  bool isLoading = false;
  bool isPublishing = false;

  // ★ Firebase プロジェクト ID
  static const String projectId = 'your-firebase-project-id';

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      'https://www.googleapis.com/auth/firebase.remoteconfig',
    ],
  );

  @override
  void initState() {
    super.initState();
    // 起動時に Firebase から最新データを自動取得
    _fetchFromFirebase();
  }

  // 📥 Firebase Remote Config から直接データを取得 (GET)
  Future<void> _fetchFromFirebase() async {
    setState(() => isLoading = true);

    try {
      final account = await _googleSignIn.signIn();
      if (account == null) {
        setState(() => isLoading = false);
        return;
      }

      final authenticatedClient = await _googleSignIn.authenticatedClient();
      if (authenticatedClient == null) {
        throw Exception('認証クライアントの取得に失敗しました。');
      }

      // Remote Config テンプレートの取得
      final getUrl = Uri.parse('https://firebaseremoteconfig.googleapis.com/v1/projects/$projectId/remoteConfig');
      final getResponse = await authenticatedClient.get(getUrl);

      if (getResponse.statusCode == 200) {
        final templateJson = json.decode(getResponse.body) as Map<String, dynamic>;
        final parameters = templateJson['parameters'] as Map<String, dynamic>? ?? {};

        if (parameters.containsKey('tester_messages')) {
          final defaultValue = parameters['tester_messages']['defaultValue'];
          final jsonStr = defaultValue != null ? defaultValue['value'] as String? : null;

          if (jsonStr != null && jsonStr.isNotEmpty) {
            setState(() {
              messages = TesterMessage.decodeList(jsonStr);
            });
          } else {
            setState(() => messages = []);
          }
        } else {
          // パラメータが Firebase 上に未作成の場合
          setState(() => messages = []);
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('📥 Firebase から最新のデータを読み込みました'),
              backgroundColor: Colors.blue,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        throw Exception('取得失敗 (${getResponse.statusCode}): ${getResponse.body}');
      }

      authenticatedClient.close();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ 取得エラー: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // 🚀 Firebase Remote Config へ直接書き換え・即時公開 (PUT)
  Future<void> _publishToFirebase() async {
    setState(() => isPublishing = true);

    try {
      final account = await _googleSignIn.signIn();
      if (account == null) {
        setState(() => isPublishing = false);
        return;
      }

      final authenticatedClient = await _googleSignIn.authenticatedClient();
      if (authenticatedClient == null) {
        throw Exception('認証クライアントの取得に失敗しました。');
      }

      // 1. 最新のテンプレートと ETag の取得
      final getUrl = Uri.parse('https://firebaseremoteconfig.googleapis.com/v1/projects/$projectId/remoteConfig');
      final getResponse = await authenticatedClient.get(getUrl);

      if (getResponse.statusCode != 200) {
        throw Exception('テンプレート取得失敗: ${getResponse.body}');
      }

      final templateJson = json.decode(getResponse.body) as Map<String, dynamic>;
      final etag = getResponse.headers['etag'] ?? '*';

      // 2. tester_messages の更新
      final newJsonString = TesterMessage.encodeList(messages);
      final parameters = templateJson['parameters'] as Map<String, dynamic>? ?? {};

      parameters['tester_messages'] = {
        'defaultValue': {
          'value': newJsonString,
        },
        'valueType': 'JSON',
      };
      templateJson['parameters'] = parameters;

      // 3. 反映＆公開
      final putResponse = await authenticatedClient.put(
        getUrl,
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'If-Match': etag,
        },
        body: json.encode(templateJson),
      );

      authenticatedClient.close();

      if (putResponse.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🚀 Firebase Remote Config への反映・即時公開が完了しました！'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw Exception('更新失敗 (${putResponse.statusCode}): ${putResponse.body}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ 送信エラー: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => isPublishing = false);
    }
  }

  // 📋 全件 JSON をクリップボードにコピー
  void _copyJsonToClipboard() {
    final jsonStr = TesterMessage.encodeList(messages);
    Clipboard.setData(ClipboardData(text: jsonStr));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('📢 JSON をコピーしました'),
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
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('📢 tester_messages 管理'),
        backgroundColor: Colors.blueGrey[800],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Firebaseから再読み込み',
            onPressed: isLoading ? null : _fetchFromFirebase,
          ),
          IconButton(
            icon: const Icon(Icons.code),
            tooltip: 'JSONプレビュー',
            onPressed: _showJsonPreviewDialog,
          ),
          IconButton(
            icon: const Icon(Icons.copy_all),
            tooltip: 'JSONコピー',
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
      body: isLoading
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Firebase からデータを読み込み中...'),
                ],
              ),
            )
          : Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  color: Colors.blueGrey[50],
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '件数: ${messages.length} 件',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey[900]),
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: isPublishing ? null : _publishToFirebase,
                        style: FilledButton.styleFrom(backgroundColor: Colors.deepOrange),
                        icon: isPublishing
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.cloud_upload),
                        label: Text(isPublishing ? '反映中...' : '🚀 Firebaseへ直接反映'),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: messages.isEmpty
                      ? const Center(
                          child: Text(
                            'Firebase 上にメッセージが存在しないか、空です。\n「+」ボタンから追加して Firebase へ反映してください。',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey, height: 1.5),
                          ),
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
                ),
              ],
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