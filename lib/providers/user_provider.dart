import 'package:flutter/material.dart';

import '../models/user_model.dart';
import '../services/firestore_service.dart';

class UserProvider with ChangeNotifier {
  final Map<String, UserModel> _userCache = {};
  UserModel? _currentUser;

  UserModel? get currentUser => _currentUser;

  Future<void> fetchCurrentUser(String userId) async {
    _currentUser = await FirestoreService.getUser(userId);
    notifyListeners();
  }

  void clearUser() {
    _currentUser = null;
    notifyListeners();
  }

  Future<void> updateUserProfile(String userId, {String? name, String? imageUrl}) async {
    if (_currentUser == null) return;

    try {
      await FirestoreService.updateUserProfile(userId, name: name, imageUrl: imageUrl);
      if (name != null) {
        _currentUser = _currentUser!.copyWith(name: name);
      }
      if (imageUrl != null) {
        _currentUser = _currentUser!.copyWith(photoUrl: imageUrl);
      }
      notifyListeners();
    } catch (e) {
      // Handle or throw the error as needed
      print('Error updating user profile in provider: $e');
      rethrow;
    }
  }

  UserModel? getUserFromCache(String userId) => _userCache[userId];

  Future<void> fetchAndCacheUsers(List<String> userIds) async {
    final idsToFetch = userIds.where((id) => !_userCache.containsKey(id)).toList();
    if (idsToFetch.isEmpty) return;

    try {
      final users = await FirestoreService.getUsersFromIds(idsToFetch);
      for (var user in users) {
        _userCache[user.id] = user;
      }
      // No need to notify listeners, as this is a background caching operation.
    } catch (e) {
      print('Error fetching and caching users: $e');
    }
  }

  Stream<List<UserModel>> getUsersStream() {
    return FirestoreService.getUsersStream();
  }

  Future<List<UserModel>> getUsersFromIds(List<String> userIds) async {
    return await FirestoreService.getUsersFromIds(userIds);
  }


}
