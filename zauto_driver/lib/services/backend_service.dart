import 'auth_service.dart';

import 'backend/realtime_api.dart';
import 'backend/message_api.dart';
import 'backend/media_api.dart';
import 'backend/conversation_api.dart';
import 'backend/account_api.dart';
import 'backend/group_api.dart';
import 'backend/settings_api.dart';
import 'backend/trip_api.dart';

class BackendService {
  final String baseUrl;

  final AuthService auth = AuthService();

  late final RealtimeApi realtimeApi;
  late final MessageApi messageApi;
  late final MediaApi mediaApi;
  late final ConversationApi conversationApi;
  late final AccountApi accountApi;
  late final GroupApi groupApi;
  late final SettingsApi settingsApi;
  late final TripApi tripApi;

  BackendService({required this.baseUrl}) {
    realtimeApi = RealtimeApi(auth: auth, webSocketUrl: _createWebSocketUrl());
    messageApi = MessageApi(baseUrl: baseUrl, auth: auth);
    mediaApi = MediaApi(baseUrl: baseUrl, auth: auth);
    conversationApi = ConversationApi(baseUrl: baseUrl, auth: auth);
    accountApi = AccountApi(baseUrl: baseUrl, auth: auth);
    groupApi = GroupApi(baseUrl: baseUrl, auth: auth);
    settingsApi = SettingsApi(baseUrl: baseUrl, auth: auth);
    tripApi = TripApi(baseUrl: baseUrl, auth: auth);
  }

  String _createWebSocketUrl() {
    if (baseUrl.startsWith('https://')) {
      return '${baseUrl.replaceFirst('https://', 'wss://')}/ws';
    }

    return '${baseUrl.replaceFirst('http://', 'ws://')}/ws';
  }

  Stream<Map<String, dynamic>> connectRealtime() {
    return realtimeApi.connectRealtime();
  }

  Future<Map<String, dynamic>> acceptMessage(
    String messageId, {

    String replyText = 'ok',
  }) {
    return tripApi.acceptMessage(messageId, replyText: replyText);
  }

  void disconnect() {
    realtimeApi.disconnect();
  }

  Future<List<Map<String, dynamic>>> getGroups() {
    return groupApi.getGroups();
  }

  Future<bool> toggleGroup(String groupId, bool enabled) {
    return groupApi.toggleGroup(groupId, enabled);
  }

  Future<Map<String, dynamic>> getFilters() {
    return settingsApi.getFilters();
  }

  Future<Map<String, dynamic>> updateFilters({
    required List<String> includeKeywords,

    required List<String> excludeKeywords,

    required bool enabled,
  }) async {
    return settingsApi.updateFilters(
      includeKeywords: includeKeywords,

      excludeKeywords: excludeKeywords,

      enabled: enabled,
    );
  }

  Future<List<Map<String, dynamic>>> getMessages({int limit = 100}) {
    return tripApi.getMessages(limit: limit);
  }

  Future<Map<String, dynamic>> ignoreMessage(String messageId) {
    return tripApi.ignoreMessage(messageId);
  }

  Future<void> registerDevice({
    required String token,
    required String platform,
  }) {
    return accountApi.registerDevice(token: token, platform: platform);
  }

  Future<void> unregisterDevice(String token) {
    return accountApi.unregisterDevice(token);
  }

  Future<Map<String, dynamic>> getProfile() {
    return accountApi.getProfile();
  }

  // ========================================
  // UNLINK ZALO
  // ========================================

  Future<void> unlinkZalo() {
    return accountApi.unlinkZalo();
  }

  Future<Map<String, dynamic>> updateProfileName(String name) {
    return accountApi.updateProfileName(name);
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) {
    return accountApi.changePassword(
      currentPassword: currentPassword,

      newPassword: newPassword,
    );
  }

  // ========================================
  // DELETE ACCOUNT
  // ========================================

  Future<void> deleteAccount(String password) {
    return accountApi.deleteAccount(password);
  }

  // ========================================
  // GET ALL CONVERSATIONS
  // ========================================

  Future<List<Map<String, dynamic>>> getConversations() {
    return conversationApi.getConversations();
  }

  Future<Map<String, dynamic>> setConversationPinned({
    required String groupId,
    required bool pinned,
  }) {
    return conversationApi.setConversationPinned(
      groupId: groupId,
      pinned: pinned,
    );
  }

  // ========================================
  // MARK CONVERSATION AS READ
  // ========================================

  Future<Map<String, dynamic>> markConversationRead({required String groupId}) {
    return conversationApi.markConversationRead(groupId: groupId);
  }

  // ========================================
  // GET CONVERSATION MESSAGES
  // ========================================

  Future<List<Map<String, dynamic>>> getConversationMessages({
    required String groupId,
    int limit = 100,
  }) {
    return messageApi.getConversationMessages(groupId: groupId, limit: limit);
  }

  Future<Map<String, dynamic>> getConversationMessagesPage({
    required String groupId,
    int limit = 50,
    String? beforeId,
    String? afterId,
  }) {
    return messageApi.getConversationMessagesPage(
      groupId: groupId,
      limit: limit,
      beforeId: beforeId,
      afterId: afterId,
    );
  }

  Future<Map<String, dynamic>> findConversationMessage({
    required String groupId,
    String? msgId,
    String? cliMsgId,
  }) async {
    return messageApi.findConversationMessage(
      groupId: groupId,
      msgId: msgId,
      cliMsgId: cliMsgId,
    );
  }

  Future<void> undoConversationMessage({
    required String groupId,
    required String msgId,
    required String cliMsgId,
  }) async {
    return messageApi.undoConversationMessage(
      groupId: groupId,
      msgId: msgId,
      cliMsgId: cliMsgId,
    );
  }

  Future<void> deleteConversationMessage({
    required String groupId,
    String? msgId,
    String? cliMsgId,
  }) async {
    return messageApi.deleteConversationMessage(
      groupId: groupId,
      msgId: msgId,
      cliMsgId: cliMsgId,
    );
  }

  Future<void> sendConversationMessage({
    required String groupId,
    required String text,

    String? replyToMsgId,
    String? replyToCliMsgId,
  }) async {
    return messageApi.sendConversationMessage(
      groupId: groupId,
      text: text,
      replyToMsgId: replyToMsgId,
      replyToCliMsgId: replyToCliMsgId,
    );
  }

  Future<Map<String, dynamic>> getConversationMessageContext({
    required String groupId,
    String? msgId,
    String? cliMsgId,
    int before = 60,
    int after = 60,
  }) {
    return messageApi.getConversationMessageContext(
      groupId: groupId,

      msgId: msgId,

      cliMsgId: cliMsgId,

      before: before,

      after: after,
    );
  }

  Future<Map<String, dynamic>> syncConversations() {
    return conversationApi.syncConversations();
  }

  Future<List<Map<String, dynamic>>> syncAndGetConversations() {
    return conversationApi.syncAndGetConversations();
  }

  Future<List<Map<String, dynamic>>> getAcceptedTrips() {
    return tripApi.getAcceptedTrips();
  }

  Future<Map<String, dynamic>> getMessageSettings() {
    return settingsApi.getMessageSettings();
  }

  Future<Map<String, dynamic>> updateMessageSettings({
    bool? deduplicateMessages,

    int? dedupeWindowSeconds,
  }) {
    return settingsApi.updateMessageSettings(
      deduplicateMessages: deduplicateMessages,

      dedupeWindowSeconds: dedupeWindowSeconds,
    );
  }

  Future<void> sendConversationPhoto({
    required String groupId,
    required String filePath,
  }) async {
    return mediaApi.sendConversationPhoto(groupId: groupId, filePath: filePath);
  }

  Future<void> sendConversationPhotos({
    required String groupId,
    required List<String> filePaths,
  }) async {
    return mediaApi.sendConversationPhotos(
      groupId: groupId,
      filePaths: filePaths,
    );
  }

  Future<void> deleteConversation({required String groupId}) {
    return conversationApi.deleteConversation(groupId: groupId);
  }
}
