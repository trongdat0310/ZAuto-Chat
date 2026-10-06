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

    // Neu cung group duoc mo lai o route moi,
    // route moi phai tro thanh route hien tai.
    _openGroupIds.removeWhere(
      (item) => item == safeGroupId,
    );

    _openGroupIds.add(safeGroupId);
  }

  void closeGroup(String groupId) {
    final safeGroupId = groupId.trim();

    if (safeGroupId.isEmpty) {
      return;
    }

    // Chi remove route/group dang dong.
    // Neu con ChatPage khac ben duoi,
    // group do se tu tro thanh current.
    _openGroupIds.removeWhere(
      (item) => item == safeGroupId,
    );
  }

  bool isOpeningGroup(String groupId) {
    return currentGroupId == groupId.trim();
  }

  // Test helper.
  void clear() {
    _openGroupIds.clear();
  }
}
