class ChatStateService {
  ChatStateService._();

  static final ChatStateService instance =
      ChatStateService._();

  final List<String> _openGroupIds = <String>[];

  String? get currentGroupId =>
      _openGroupIds.isEmpty ? null : _openGroupIds.last;

  void openGroup(String groupId) {
    final safeGroupId = groupId.trim();

    if (safeGroupId.isEmpty) {
      return;
    }

    // Moi ChatPage la mot route rieng.
    // Cho phep cung group ton tai nhieu lan
    // neu route bi push lap.
    _openGroupIds.add(safeGroupId);
  }

  void closeGroup(String groupId) {
    final safeGroupId = groupId.trim();

    if (safeGroupId.isEmpty) {
      return;
    }

    // Chi remove instance gan nhat cua route/group
    // dang dong. Neu con ChatPage khac ben duoi,
    // group do se tu tro thanh current.
    final index = _openGroupIds.lastIndexOf(safeGroupId);

    if (index >= 0) {
      _openGroupIds.removeAt(index);
    }
  }

  bool isOpeningGroup(String groupId) {
    return currentGroupId == groupId.trim();
  }

  // Test helper.
  void clear() {
    _openGroupIds.clear();
  }
}
