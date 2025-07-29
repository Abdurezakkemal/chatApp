import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/user_model.dart';
import '../providers/user_provider.dart';

class TypingIndicator extends StatelessWidget {
  final List<String> typingUserIds;

  const TypingIndicator({Key? key, required this.typingUserIds}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (typingUserIds.isEmpty) {
      return const SizedBox.shrink();
    }

    final userProvider = Provider.of<UserProvider>(context, listen: false);

    return FutureBuilder<List<UserModel>>(
      future: userProvider.getUsersFromIds(typingUserIds),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }

        final typingUsers = snapshot.data!;
        final names = typingUsers.map((user) => user.name).toList();

        String text;
        if (names.length == 1) {
          text = '${names[0]} is typing...';
        } else if (names.length == 2) {
          text = '${names[0]} and ${names[1]} are typing...';
        } else {
          text = '${names.length} people are typing...';
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
          child: Text(
            text,
            style: const TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
          ),
        );
      },
    );
  }
}
