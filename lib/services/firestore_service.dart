
import 'package:cloud_firestore/cloud_firestore.dart';


import '../models/chat_model.dart';
import '../models/message_model.dart';
import '../models/user_model.dart';

class FirestoreService {

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Create a new user document in Firestore after sign-up
  static Future<void> createUserDocument({
    required String userId,
    required String name,
    required String email,
    String? phone,
    String? imageUrl,
  }) async {
    try {
      await _firestore.collection('users').doc(userId).set({
        'name': name,
        'email': email,
        'phone': phone ?? '',
        'photoUrl': imageUrl ?? '',
        'status': 'Hey there! I\'m using Chat App',
        'lastSeen': FieldValue.serverTimestamp(),
        'settings': {
          'notifications': true,
          'readReceipts': true,
          'theme': 'light',
        },
      });
      print('User document created successfully for: $userId');
    } catch (e) {
      print('Error creating user document: $e');
      throw e;
    }
  }

  /// Update user's last seen timestamp
  static Future<void> updateLastSeen(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'lastSeen': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating last seen: $e');
    }
  }

  /// Get user document by ID
  static Future<UserModel?> getUser(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        return UserModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      print('Error getting user: $e');
      return null;
    }
  }

  static Stream<List<MessageModel>> getChatMessages(String chatId) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => MessageModel.fromFirestore(doc))
          .toList();
    });
  }

  static Future<void> sendMessage(
      String chatId, String senderId, String messageText) async {
    if (messageText.trim().isEmpty) return;

    final messageData = {
      'senderId': senderId,
      'text': messageText.trim(),
      'timestamp': FieldValue.serverTimestamp(),
      'readBy': [senderId], // Sender has read the message by default
      'reactions': {},
    };

    // Add the message to the messages subcollection
    await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .add(messageData);

    // Update the last message in the chat document
    await _firestore.collection('chats').doc(chatId).update({
      'lastMessage': messageText.trim(),
      'lastMessageSenderId': senderId,
      'lastMessageTime': FieldValue.serverTimestamp(),
      // TODO: Handle unread counts
    });
  }

  /// Check if user document exists
  static Future<bool> userDocumentExists(String userId) async {
    try {
      DocumentSnapshot doc =
          await _firestore.collection('users').doc(userId).get();
      return doc.exists;
    } catch (e) {
      print('Error checking user document: $e');
      return false;
    }
  }

  /// Get user's chats (where user is a member)
  static Stream<List<ChatModel>> getUserChats(String userId) {
    return _firestore
        .collection('chats')
        .where('members', arrayContains: userId)
        .orderBy('lastMessageTime', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => ChatModel.fromFirestore(doc)).toList();
    });
  }

  /// Create a new chat between users
  static Future<String> createChat({
    required List<String> members,
    bool isGroup = false,
    String? groupName,
    String? groupPhotoUrl,
  }) async {
    try {
      DocumentReference chatRef = _firestore.collection('chats').doc();

      Map<String, int> unreadCounts = {
        for (var memberId in members) memberId: 0
      };

      Map<String, dynamic> chatData = {
        'isGroup': isGroup,
        'members': members,
        'lastMessage': '',
        'lastMessageSenderId': '',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'unreadCounts': unreadCounts,
        'typing': [],
      };

      if (isGroup) {
        chatData['groupName'] = groupName ?? 'New Group';
        chatData['groupPhotoUrl'] = groupPhotoUrl ?? '';
      }

      await chatRef.set(chatData);
      return chatRef.id;
    } catch (e) {
      print('Error creating chat: $e');
      throw e;
    }
  }

  /// Get a stream of all users
  static Stream<List<UserModel>> getUsersStream() {
    return _firestore.collection('users').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => UserModel.fromFirestore(doc)).toList();
    });
  }

  /// Find an existing private chat between two users, returns the chat document or null.
  static Future<ChatModel?> findPrivateChat(
      String currentUserId, String otherUserId) async {
    try {
      final querySnapshot = await _firestore
          .collection('chats')
          .where('isGroup', isEqualTo: false)
          .where('members', arrayContains: currentUserId)
          .get();

      final chats = querySnapshot.docs.where((doc) {
        final members = List<String>.from(doc['members']);
        return members.contains(otherUserId) && members.length == 2;
      });

      if (chats.isNotEmpty) {
        return ChatModel.fromFirestore(chats.first);
      }
      return null;
    } catch (e) {
      print('Error finding private chat: $e');
      return null;
    }
  }

  /// Update user's typing status in a chat
  static Future<void> updateTypingStatus({
    required String chatId,
    required String userId,
    required bool isTyping,
  }) async {
    try {
      await _firestore.collection('chats').doc(chatId).update({
        'typing': isTyping
            ? FieldValue.arrayUnion([userId])
            : FieldValue.arrayRemove([userId]),
      });
    } catch (e) {
      print('Error updating typing status: $e');
    }
  }

  /// Get a stream of a single chat document
  static Stream<ChatModel> getChatStream(String chatId) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .snapshots()
        .map((doc) => ChatModel.fromFirestore(doc));
  }

  /// Marks a message as read by the current user
  static Future<void> markMessageAsRead({
    required String chatId,
    required String messageId,
    required String userId,
  }) async {
    try {
      await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc(messageId)
          .update({
        'readBy': FieldValue.arrayUnion([userId]),
      });
    } catch (e) {
      print('Error marking message as read: $e');
    }
  }

  /// Adds, updates, or removes a reaction from a message.
  static Future<void> toggleMessageReaction({
    required String chatId,
    required String messageId,
    required String userId,
    required String reaction, // The emoji
  }) async {
    try {
      final messageRef = _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc(messageId);

      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(messageRef);
        if (!snapshot.exists) {
          throw Exception("Message does not exist!");
        }

        final currentReactions =
            Map<String, String>.from(snapshot.data()!['reactions'] ?? {});

        // If the user has already reacted with the same emoji, remove the reaction.
        if (currentReactions[userId] == reaction) {
          currentReactions.remove(userId);
        } else {
          // Otherwise, add or update the reaction.
          currentReactions[userId] = reaction;
        }

        transaction.update(messageRef, {'reactions': currentReactions});
      });
    } catch (e) {
      print('Error toggling message reaction: $e');
    }
  }

  /// Update user's profile data (e.g., name)
  static Future<void> updateUserProfile(
    String userId, {
    String? name,
    String? imageUrl,
  }) async {
    final dataToUpdate = <String, dynamic>{};
    if (name != null) dataToUpdate['name'] = name;
    if (imageUrl != null) dataToUpdate['photoUrl'] = imageUrl;

    if (dataToUpdate.isEmpty) return;

    try {
      await _firestore.collection('users').doc(userId).update(dataToUpdate);
    } catch (e) {
      print('Error updating user profile: $e');
      rethrow;
    }
  }

  /// Get multiple user documents from a list of IDs
  static Future<List<UserModel>> getUsersFromIds(List<String> userIds) async {
    if (userIds.isEmpty) return [];
    try {
      final querySnapshot = await _firestore
          .collection('users')
          .where(FieldPath.documentId, whereIn: userIds)
          .get();
      return querySnapshot.docs
          .map((doc) => UserModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('Error getting users from IDs: $e');
      return [];
    }
  }
}
