import 'dart:convert';

class TesterMessage {
  String id;
  String title;
  String date;
  String body;
  bool isImportant;

  TesterMessage({
    required this.id,
    required this.title,
    required this.date,
    required this.body,
    this.isImportant = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'date': date,
    'body': body,
    'isImportant': isImportant,
  };

  factory TesterMessage.fromJson(Map<String, dynamic> json) => TesterMessage(
    id: json['id']?.toString() ?? '',
    title: json['title']?.toString() ?? '',
    date: json['date']?.toString() ?? '',
    body: json['body']?.toString() ?? '',
    isImportant: json['isImportant'] == true,
  );

  static String encodeList(List<TesterMessage> list) =>
      jsonEncode(list.map((m) => m.toJson()).toList());

  static List<TesterMessage> decodeList(String jsonString) {
    if (jsonString.isEmpty) return [];
    try {
      final List<dynamic> list = jsonDecode(jsonString);
      return list.map((item) => TesterMessage.fromJson(Map<String, dynamic>.from(item))).toList();
    } catch (_) {
      return [];
    }
  }
}