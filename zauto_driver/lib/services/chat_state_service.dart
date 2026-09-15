class ChatStateService {

  ChatStateService._();


  static final ChatStateService instance =
  ChatStateService._();


  String? _currentGroupId;


  String? get currentGroupId =>
      _currentGroupId;


  void openGroup(
      String groupId,
      ) {

    _currentGroupId =
        groupId;
  }


  void closeGroup() {

    _currentGroupId =
    null;
  }


  bool isOpeningGroup(
      String groupId,
      ) {

    return _currentGroupId ==
        groupId;
  }
}