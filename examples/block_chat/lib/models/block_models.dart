/// Public-facing working title; never treat invitation alone as a verified address.
class NeighbourhoodBlock {
  const NeighbourhoodBlock({
    required this.id, required this.name, required this.role, required this.status,
  });

  final String id;
  final String name;
  final String role;
  final String status;
  bool get approved => status == 'approved';
  bool get administrator => approved && (role == 'owner' || role == 'admin');
}

class ChatChannel {
  const ChatChannel(this.key, this.name, this.description);
  final String key;
  final String name;
  final String description;
  static const all = [
    ChatChannel('general', 'Chat', 'Talk with your neighbours'),
    ChatChannel('announcements', 'Notices', 'Updates posted by Block administrators'),
    ChatChannel('help', 'Help', 'Lend or request a hand'),
    ChatChannel('events', 'Events', 'Plan neighbourhood gatherings'),
  ];
}

class ChatValidation {
  static String nickname(String raw) {
    final text = raw.trim();
    if (text.length < 2 || text.length > 60) {
      throw const FormatException('Use a display name between 2 and 60 characters');
    }
    return text;
  }
  static String blockName(String raw) {
    final text = raw.trim();
    if (text.length < 3 || text.length > 60) {
      throw const FormatException('Use a Block name between 3 and 60 characters');
    }
    return text;
  }
  static String message(String raw) {
    final text = raw.trim();
    if (text.isEmpty || text.length > 1000) {
      throw const FormatException('Enter a message of up to 1000 characters');
    }
    return text;
  }
  static String invitation(String raw) {
    final token = raw.trim().toLowerCase();
    if (!RegExp(r'^[a-f0-9]{40}$').hasMatch(token)) {
      throw const FormatException('Invitation code must contain 40 hexadecimal characters');
    }
    return token;
  }
}
