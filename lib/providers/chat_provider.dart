import 'package:flutter/material.dart';

import '../models/chat_model.dart';
import '../models/message_model.dart';
import '../services/firestore_service.dart';

class ChatProvider with ChangeNotifier {
  Stream<List<ChatModel>> getUserChatsStream(String userId) {
    return FirestoreService.getUserChats(userId);
  }

  Stream<ChatModel> getChatStream(String chatId) {
    return FirestoreService.getChatStream(chatId);
  }

  Stream<List<MessageModel>> getChatMessagesStream(String chatId) {
    return FirestoreService.getChatMessages(chatId);
  }

  Future<void> sendMessage(String chatId, String senderId, String messageText) async {
    await FirestoreService.sendMessage(chatId, senderId, messageText);
  }

  Future<void> updateTypingStatus({
    required String chatId,
    required String userId,
    required bool isTyping,
  }) async {
    await FirestoreService.updateTypingStatus(
      chatId: chatId,
      userId: userId,
      isTyping: isTyping,
    );
  }

  Future<void> markMessageAsRead({
    required String chatId,
    required String messageId,
    required String userId,
  }) async {
    await FirestoreService.markMessageAsRead(
      chatId: chatId,
      messageId: messageId,
      userId: userId,
    );
  }

  Future<void> toggleMessageReaction({
    required String chatId,
    required String messageId,
    required String userId,
    required String reaction,
  }) async {
    await FirestoreService.toggleMessageReaction(
      chatId: chatId,
      messageId: messageId,
      userId: userId,
      reaction: reaction,
    );
  }

  Future<String> findOrCreatePrivateChat(String currentUserId, String otherUserId) async {
    try {
      final existingChat = await FirestoreService.findPrivateChat(currentUserId, otherUserId);
      if (existingChat != null) {
        return existingChat.id;
      } else {
        final chatId = await FirestoreService.createChat(
          members: [currentUserId, otherUserId],
        );
        return chatId;
      }
    } catch (e) {
      print('Error finding or creating private chat in provider: $e');
      rethrow;
    }
  }
}
