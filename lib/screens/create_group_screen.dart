import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/user_model.dart';
import '../services/firestore_service.dart';
import 'chat_screen.dart';

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({Key? key}) : super(key: key);

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final _groupNameController = TextEditingController();
  final List<UserModel> _selectedUsers = [];
  final User? currentUser = FirebaseAuth.instance.currentUser;

    void _toggleUserSelection(UserModel user) {
    HapticFeedback.lightImpact();
    setState(() {
      if (_selectedUsers.any((u) => u.id == user.id)) {
        _selectedUsers.removeWhere((u) => u.id == user.id);
      } else {
        _selectedUsers.add(user);
      }
    });
  }

    Future<void> _createGroup() async {
    HapticFeedback.mediumImpact();
    if (_groupNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a group name.')),
      );
      return;
    }

    if (_selectedUsers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one member.')),
      );
      return;
    }

    if (currentUser == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final List<String> memberIds = [
        currentUser!.uid,
        ..._selectedUsers.map((user) => user.id),
      ];

      final chatId = await FirestoreService.createChat(
        members: memberIds,
        isGroup: true,
        groupName: _groupNameController.text.trim(),
      );

      if (mounted) Navigator.of(context).pop(); // Dismiss loading dialog

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => ChatScreen(
              chatId: chatId,
              chatName: _groupNameController.text.trim(),
            ),
          ),
          (route) => route.isFirst,
        );
      }
    } catch (e) {
      if (mounted) Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create group: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create New Group'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
            child: TextField(
              controller: _groupNameController,
              decoration: const InputDecoration(
                labelText: 'Group Name',
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
            child: Text('Select Members', style: textTheme.titleLarge),
          ),
          Expanded(
            child: StreamBuilder<List<UserModel>>(
              stream: FirestoreService.getUsersStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('No users found.'));
                }

                final users = snapshot.data!
                    .where((user) => user.id != currentUser?.uid)
                    .toList();

                return ListView.separated(
                  itemCount: users.length,
                  separatorBuilder: (context, index) => Divider(indent: 72, height: 1),
                  itemBuilder: (context, index) {
                    final user = users[index];
                    final isSelected = _selectedUsers.any((u) => u.id == user.id);

                    return ListTile(
                      onTap: () => _toggleUserSelection(user),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                      leading: CircleAvatar(
                        radius: 28,
                        backgroundImage: user.photoUrl.isNotEmpty ? NetworkImage(user.photoUrl) : null,
                        child: user.photoUrl.isEmpty ? Text(user.name.isNotEmpty ? user.name[0].toUpperCase() : '') : null,
                      ),
                      title: Text(user.name, style: textTheme.titleMedium),
                      subtitle: Text(user.email, style: textTheme.bodySmall),
                      trailing: Checkbox(
                        value: isSelected,
                        onChanged: (bool? value) => _toggleUserSelection(user),
                        activeColor: colorScheme.primary,
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ElevatedButton(
          onPressed: _createGroup,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
          ),
          child: const Text('Create Group'),
        ),
      ),
    );
  }
}
