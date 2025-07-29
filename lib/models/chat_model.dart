import 'package:cloud_firestore/cloud_firestore.dart';

class ChatModel {
  final String id;
  final bool isGroup;
  final List<String> members;
  final String lastMessage;
  final String lastMessageSenderId;
  final Timestamp lastMessageTime;
  final Map<String, int> unreadCounts;
  final String? groupName;
  final String? groupPhotoUrl;
  final List<String> typing;

  ChatModel({
    required this.id,
    required this.isGroup,
    required this.members,
    required this.lastMessage,
    required this.lastMessageSenderId,
    required this.lastMessageTime,
    required this.unreadCounts,
    this.groupName,
    this.groupPhotoUrl,
    required this.typing,
  });

  factory ChatModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return ChatModel(
      id: doc.id,
      isGroup: data['isGroup'] ?? false,
      members: List<String>.from(data['members'] ?? []),
      lastMessage: data['lastMessage'] ?? '',
      lastMessageSenderId: data['lastMessageSenderId'] ?? '',
      lastMessageTime: data['lastMessageTime'] ?? Timestamp.now(),
      unreadCounts: Map<String, int>.from(data['unreadCounts'] ?? {}),
      groupName: data['groupName'],
      groupPhotoUrl: data['groupPhotoUrl'],
      typing: List<String>.from(data['typing'] ?? []),

    );
  }

  Map<String, dynamic> toJson() {
    return {
      'isGroup': isGroup,
      'members': members,
      'lastMessage': lastMessage,
      'lastMessageSenderId': lastMessageSenderId,
      'lastMessageTime': lastMessageTime,
      'unreadCounts': unreadCounts,
      'groupName': groupName,
      'groupPhotoUrl': groupPhotoUrl,
      'typing': typing,
    };
  }
}
