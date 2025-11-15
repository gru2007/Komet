import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import 'connection/connection_manager_simple.dart';
import 'connection/connection_logger.dart';
import 'connection/connection_state.dart';
import 'connection/health_monitor.dart';
import 'models/message.dart';
import 'models/contact.dart';


class ApiServiceSimple {
  ApiServiceSimple._privateConstructor();
  static final ApiServiceSimple instance =
      ApiServiceSimple._privateConstructor();


  final ConnectionManagerSimple _connectionManager = ConnectionManagerSimple();


  final ConnectionLogger _logger = ConnectionLogger();


  String? _authToken;
  bool _isInitialized = false;


  final Map<int, List<Message>> _messageCache = {};
  final Map<int, Contact> _contactCache = {};
  Map<String, dynamic>? _lastChatsPayload;
  DateTime? _lastChatsAt;
  final Duration _chatsCacheTtl = const Duration(seconds: 5);
  bool _chatsFetchedInThisSession = false;


  final Map<String, dynamic> _presenceData = {};


  final StreamController<Contact> _contactUpdatesController =
      StreamController<Contact>.broadcast();
  final StreamController<Map<String, dynamic>> _messageController =
      StreamController<Map<String, dynamic>>.broadcast();


  Stream<Map<String, dynamic>> get messages => _messageController.stream;


  Stream<Contact> get contactUpdates => _contactUpdatesController.stream;


  Stream<ConnectionInfo> get connectionState => _connectionManager.stateStream;


  Stream<LogEntry> get logs => _connectionManager.logStream;


  Stream<HealthMetrics> get healthMetrics =>
      _connectionManager.healthMetricsStream;


  ConnectionInfo get currentState => _connectionManager.currentState;


  bool get isOnline => _connectionManager.isConnected;


  bool get canSendMessages => _connectionManager.canSendMessages;


  Future<void> initialize() async {
    if (_isInitialized) {
      _logger.logConnection('ApiServiceSimple уже инициализирован');
      return;
    }

    _logger.logConnection('Инициализация ApiServiceSimple');

    try {
      await _connectionManager.initialize();
      _setupMessageHandlers();
      _isInitialized = true;

      _logger.logConnection('ApiServiceSimple успешно инициализирован');
    } catch (e) {
      _logger.logError('Ошибка инициализации ApiServiceSimple', error: e);
      rethrow;
    }
  }


  void _setupMessageHandlers() {
    _connectionManager.messageStream.listen((message) {
      _handleIncomingMessage(message);
    });
  }


  void _handleIncomingMessage(Map<String, dynamic> message) {
    try {
      _logger.logMessage('IN', message);


      if (message['opcode'] == 128 && message['payload'] != null) {
        _handleContactUpdate(message['payload']);
      }


      if (message['opcode'] == 129 && message['payload'] != null) {
        _handlePresenceUpdate(message['payload']);
      }


      _messageController.add(message);
    } catch (e) {
      _logger.logError(
        'Ошибка обработки входящего сообщения',
        data: {'message': message, 'error': e.toString()},
      );
    }
  }


  void _handleContactUpdate(Map<String, dynamic> payload) {
    try {
      final contact = Contact.fromJson(payload);
      _contactCache[contact.id] = contact;
      _contactUpdatesController.add(contact);

      _logger.logConnection(
        'Контакт обновлен',
        data: {'contact_id': contact.id, 'contact_name': contact.name},
      );
    } catch (e) {
      _logger.logError(
        'Ошибка обработки обновления контакта',
        data: {'payload': payload, 'error': e.toString()},
      );
    }
  }


  void _handlePresenceUpdate(Map<String, dynamic> payload) {
    try {
      _presenceData.addAll(payload);
      _logger.logConnection(
        'Presence данные обновлены',
        data: {'keys': payload.keys.toList()},
      );
    } catch (e) {
      _logger.logError(
        'Ошибка обработки presence данных',
        data: {'payload': payload, 'error': e.toString()},
      );
    }
  }


  Future<void> connect() async {
    _logger.logConnection('Запрос подключения к серверу');

    try {
      await _connectionManager.connect(authToken: _authToken);
      _logger.logConnection('Подключение к серверу успешно');
    } catch (e) {
      _logger.logError('Ошибка подключения к серверу', error: e);
      rethrow;
    }
  }


  Future<void> reconnect() async {
    _logger.logConnection('Запрос переподключения');

    try {
      await _connectionManager.connect(authToken: _authToken);
      _logger.logConnection('Переподключение успешно');
    } catch (e) {
      _logger.logError('Ошибка переподключения', error: e);
      rethrow;
    }
  }


  Future<void> disconnect() async {
    _logger.logConnection('Отключение от сервера');

    try {
      await _connectionManager.disconnect();
      _logger.logConnection('Отключение от сервера успешно');
    } catch (e) {
      _logger.logError('Ошибка отключения', error: e);
    }
  }


  int _sendMessage(int opcode, Map<String, dynamic> payload) {
    if (!canSendMessages) {
      _logger.logConnection(
        'Сообщение не отправлено - соединение не готово',
        data: {'opcode': opcode, 'payload': payload},
      );
      return -1;
    }

    try {
      final seq = _connectionManager.sendMessage(opcode, payload);
      _logger.logConnection(
        'Сообщение отправлено',
        data: {'opcode': opcode, 'seq': seq, 'payload': payload},
      );
      return seq;
    } catch (e) {
      _logger.logError(
        'Ошибка отправки сообщения',
        data: {'opcode': opcode, 'payload': payload, 'error': e.toString()},
      );
      return -1;
    }
  }


  Future<void> sendHandshake() async {
    _logger.logConnection('Отправка handshake');

    final payload = {
      "userAgent": {
        "deviceType": "WEB",
        "locale": "ru",
        "deviceLocale": "ru",
        "osVersion": "Windows",
        "deviceName": "Chrome",
        "headerUserAgent":
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
        "appVersion": "25.9.15",
        "screen": "1920x1080 1.0x",
        "timezone": "Europe/Moscow",
      },
      "deviceId": _generateDeviceId(),
    };

    _sendMessage(6, payload);
  }


  void requestOtp(String phoneNumber) {
    _logger.logConnection('Запрос OTP', data: {'phone': phoneNumber});

    final payload = {
      "phone": phoneNumber,
      "type": "START_AUTH",
      "language": "ru",
    };
    _sendMessage(17, payload);
  }


  void verifyCode(String token, String code) {
    _logger.logConnection(
      'Проверка кода',
      data: {'token': token, 'code': code},
    );

    final payload = {
      "token": token,
      "verifyCode": code,
      "authTokenType": "CHECK_CODE",
    };
    _sendMessage(18, payload);
  }


  Future<Map<String, dynamic>> authenticateWithToken(String token) async {
    _logger.logConnection('Аутентификация с токеном');

    _authToken = token;
    await saveToken(token);

    final payload = {"interactive": true, "token": token, "chatsCount": 100};

    final seq = _sendMessage(19, payload);

    try {
      final response = await messages
          .firstWhere((msg) => msg['seq'] == seq)
          .timeout(const Duration(seconds: 30));

      _logger.logConnection(
        'Аутентификация успешна',
        data: {'seq': seq, 'response_cmd': response['cmd']},
      );

      return response['payload'] ?? {};
    } catch (e) {
      _logger.logError(
        'Ошибка аутентификации',
        data: {'token': token, 'error': e.toString()},
      );
      rethrow;
    }
  }


  Future<Map<String, dynamic>> getChatsAndContacts({bool force = false}) async {
    _logger.logConnection('Запрос чатов и контактов', data: {'force': force});


    if (!force && _lastChatsPayload != null && _lastChatsAt != null) {
      if (DateTime.now().difference(_lastChatsAt!) < _chatsCacheTtl) {
        _logger.logConnection('Возвращаем данные из кэша');
        return _lastChatsPayload!;
      }
    }

    try {
      final payload = {"chatsCount": 100};
      final seq = _sendMessage(48, payload);

      final response = await messages
          .firstWhere((msg) => msg['seq'] == seq)
          .timeout(const Duration(seconds: 30));

      final List<dynamic> chatListJson = response['payload']?['chats'] ?? [];

      if (chatListJson.isEmpty) {
        final result = {'chats': [], 'contacts': [], 'profile': null};
        _lastChatsPayload = result;
        _lastChatsAt = DateTime.now();
        return result;
      }


      final contactIds = <int>{};
      for (var chatJson in chatListJson) {
        final participants =
            chatJson['participants'] as Map<String, dynamic>? ?? {};
        contactIds.addAll(participants.keys.map((id) => int.parse(id)));
      }

      final contactSeq = _sendMessage(32, {"contactIds": contactIds.toList()});

      final contactResponse = await messages
          .firstWhere((msg) => msg['seq'] == contactSeq)
          .timeout(const Duration(seconds: 30));

      final List<dynamic> contactListJson =
          contactResponse['payload']?['contacts'] ?? [];

      final result = {
        'chats': chatListJson,
        'contacts': contactListJson,
        'profile': null,
        'presence': null,
      };

      _lastChatsPayload = result;
      _lastChatsAt = DateTime.now();
      _chatsFetchedInThisSession = true;


      final contacts = contactListJson
          .map((json) => Contact.fromJson(json))
          .toList();
      updateContactCache(contacts);

      _logger.logConnection(
        'Чаты и контакты получены',
        data: {
          'chats_count': chatListJson.length,
          'contacts_count': contactListJson.length,
        },
      );

      return result;
    } catch (e) {
      _logger.logError('Ошибка получения чатов и контактов', error: e);
      rethrow;
    }
  }


  Future<List<Message>> getMessageHistory(
    int chatId, {
    bool force = false,
  }) async {
    _logger.logConnection(
      'Запрос истории сообщений',
      data: {'chat_id': chatId, 'force': force},
    );

    if (!force && _messageCache.containsKey(chatId)) {
      _logger.logConnection('История сообщений загружена из кэша');
      return _messageCache[chatId]!;
    }

    try {
      final payload = {
        "chatId": chatId,
        "from": DateTime.now()
            .add(const Duration(days: 1))
            .millisecondsSinceEpoch,
        "forward": 0,
        "backward": 1000,
        "getMessages": true,
      };

      final seq = _sendMessage(49, payload);

      final response = await messages
          .firstWhere((msg) => msg['seq'] == seq)
          .timeout(const Duration(seconds: 30));

      if (response['cmd'] == 3) {
        final error = response['payload'];
        _logger.logError(
          'Ошибка получения истории сообщений',
          data: {'chat_id': chatId, 'error': error},
        );
        throw Exception('Ошибка получения истории: ${error['message']}');
      }

      final List<dynamic> messagesJson = response['payload']?['messages'] ?? [];
      final messagesList =
          messagesJson.map((json) => Message.fromJson(json)).toList()
            ..sort((a, b) => a.time.compareTo(b.time));

      _messageCache[chatId] = messagesList;

      _logger.logConnection(
        'История сообщений получена',
        data: {'chat_id': chatId, 'messages_count': messagesList.length},
      );

      return messagesList;
    } catch (e) {
      _logger.logError(
        'Ошибка получения истории сообщений',
        data: {'chat_id': chatId, 'error': e.toString()},
      );
      return [];
    }
  }


  void sendMessage(int chatId, String text, {String? replyToMessageId}) {
    _logger.logConnection(
      'Отправка сообщения',
      data: {
        'chat_id': chatId,
        'text_length': text.length,
        'reply_to': replyToMessageId,
      },
    );

    final int clientMessageId = DateTime.now().millisecondsSinceEpoch;
    final payload = {
      "chatId": chatId,
      "message": {
        "text": text,
        "cid": clientMessageId,
        "elements": [],
        "attaches": [],
        if (replyToMessageId != null)
          "link": {"type": "REPLY", "messageId": replyToMessageId},
      },
      "notify": true,
    };

    clearChatsCache();
    _sendMessage(64, payload);
  }


  Future<void> sendPhotoMessage(
    int chatId, {
    String? localPath,
    String? caption,
    int? cidOverride,
    int? senderId,
  }) async {
    _logger.logConnection(
      'Отправка фото',
      data: {'chat_id': chatId, 'local_path': localPath, 'caption': caption},
    );

    try {
      XFile? image;
      if (localPath != null) {
        image = XFile(localPath);
      } else {
        final picker = ImagePicker();
        image = await picker.pickImage(source: ImageSource.gallery);
        if (image == null) return;
      }


      final seq80 = _sendMessage(80, {"count": 1});
      final resp80 = await messages
          .firstWhere((m) => m['seq'] == seq80)
          .timeout(const Duration(seconds: 30));

      final String uploadUrl = resp80['payload']['url'];


      var request = http.MultipartRequest('POST', Uri.parse(uploadUrl));
      request.files.add(await http.MultipartFile.fromPath('file', image.path));
      var streamed = await request.send();
      var httpResp = await http.Response.fromStream(streamed);

      if (httpResp.statusCode != 200) {
        throw Exception(
          'Ошибка загрузки фото: ${httpResp.statusCode} ${httpResp.body}',
        );
      }

      final uploadJson = jsonDecode(httpResp.body) as Map<String, dynamic>;
      final Map photos = uploadJson['photos'] as Map;
      if (photos.isEmpty) throw Exception('Не получен токен фото');
      final String photoToken = (photos.values.first as Map)['token'];


      final int cid = cidOverride ?? DateTime.now().millisecondsSinceEpoch;
      final payload = {
        "chatId": chatId,
        "message": {
          "text": caption?.trim() ?? "",
          "cid": cid,
          "elements": [],
          "attaches": [
            {"_type": "PHOTO", "photoToken": photoToken},
          ],
        },
        "notify": true,
      };

      clearChatsCache();
      _sendMessage(64, payload);

      _logger.logConnection(
        'Фото отправлено',
        data: {'chat_id': chatId, 'photo_token': photoToken},
      );
    } catch (e) {
      _logger.logError(
        'Ошибка отправки фото',
        data: {'chat_id': chatId, 'error': e.toString()},
      );
    }
  }


  Future<void> blockContact(int contactId) async {
    _logger.logConnection(
      'Блокировка контакта',
      data: {'contact_id': contactId},
    );
    _sendMessage(34, {'contactId': contactId, 'action': 'BLOCK'});
  }


  Future<void> unblockContact(int contactId) async {
    _logger.logConnection(
      'Разблокировка контакта',
      data: {'contact_id': contactId},
    );
    _sendMessage(34, {'contactId': contactId, 'action': 'UNBLOCK'});
  }


  void getBlockedContacts() {
    _logger.logConnection('Запрос заблокированных контактов');
    _sendMessage(36, {'status': 'BLOCKED', 'count': 100, 'from': 0});
  }


  void createGroup(String name, List<int> participantIds) {
    _logger.logConnection(
      'Создание группы',
      data: {'name': name, 'participants': participantIds},
    );

    final payload = {"name": name, "participantIds": participantIds};
    _sendMessage(48, payload);
  }


  void addGroupMember(
    int chatId,
    List<int> userIds, {
    bool showHistory = true,
  }) {
    _logger.logConnection(
      'Добавление участника в группу',
      data: {'chat_id': chatId, 'user_ids': userIds},
    );

    final payload = {
      "chatId": chatId,
      "userIds": userIds,
      "showHistory": showHistory,
      "operation": "add",
    };
    _sendMessage(77, payload);
  }


  void removeGroupMember(
    int chatId,
    List<int> userIds, {
    int cleanMsgPeriod = 0,
  }) {
    _logger.logConnection(
      'Удаление участника из группы',
      data: {'chat_id': chatId, 'user_ids': userIds},
    );

    final payload = {
      "chatId": chatId,
      "userIds": userIds,
      "operation": "remove",
      "cleanMsgPeriod": cleanMsgPeriod,
    };
    _sendMessage(77, payload);
  }


  void leaveGroup(int chatId) {
    _logger.logConnection('Выход из группы', data: {'chat_id': chatId});
    _sendMessage(58, {"chatId": chatId});
  }


  void sendReaction(int chatId, String messageId, String emoji) {
    _logger.logConnection(
      'Отправка реакции',
      data: {'chat_id': chatId, 'message_id': messageId, 'emoji': emoji},
    );

    final payload = {
      "chatId": chatId,
      "messageId": messageId,
      "reaction": {"reactionType": "EMOJI", "id": emoji},
    };
    _sendMessage(178, payload);
  }


  void removeReaction(int chatId, String messageId) {
    _logger.logConnection(
      'Удаление реакции',
      data: {'chat_id': chatId, 'message_id': messageId},
    );

    final payload = {"chatId": chatId, "messageId": messageId};
    _sendMessage(179, payload);
  }


  void sendTyping(int chatId, {String type = "TEXT"}) {
    final payload = {"chatId": chatId, "type": type};
    _sendMessage(65, payload);
  }


  DateTime? getLastSeen(int userId) {
    final userPresence = _presenceData[userId.toString()];
    if (userPresence != null && userPresence['seen'] != null) {
      final seenTimestamp = userPresence['seen'] as int;
      return DateTime.fromMillisecondsSinceEpoch(seenTimestamp * 1000);
    }
    return null;
  }


  void updateContactCache(List<Contact> contacts) {
    _contactCache.clear();
    for (final contact in contacts) {
      _contactCache[contact.id] = contact;
    }
    _logger.logConnection(
      'Кэш контактов обновлен',
      data: {'contacts_count': contacts.length},
    );
  }


  Contact? getCachedContact(int contactId) {
    return _contactCache[contactId];
  }


  void clearChatsCache() {
    _lastChatsPayload = null;
    _lastChatsAt = null;
    _chatsFetchedInThisSession = false;
    _logger.logConnection('Кэш чатов очищен');
  }


  void clearMessageCache(int chatId) {
    _messageCache.remove(chatId);
    _logger.logConnection('Кэш сообщений очищен', data: {'chat_id': chatId});
  }


  void clearAllCaches() {
    _messageCache.clear();
    _contactCache.clear();
    clearChatsCache();
    _logger.logConnection('Все кэши очищены');
  }


  Future<void> saveToken(String token) async {
    _authToken = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('authToken', token);
    _logger.logConnection('Токен сохранен');
  }


  Future<bool> hasToken() async {
    final prefs = await SharedPreferences.getInstance();
    _authToken = prefs.getString('authToken');
    return _authToken != null;
  }


  Future<void> logout() async {
    _logger.logConnection('Выход из системы');

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('authToken');
      _authToken = null;
      clearAllCaches();
      await disconnect();
      _logger.logConnection('Выход из системы выполнен');
    } catch (e) {
      _logger.logError('Ошибка при выходе из системы', error: e);
    }
  }


  String _generateDeviceId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = (timestamp % 1000000).toString().padLeft(6, '0');
    return "$timestamp$random";
  }


  Map<String, dynamic> getStatistics() {
    return {
      'api_service': {
        'is_initialized': _isInitialized,
        'has_auth_token': _authToken != null,
        'message_cache_size': _messageCache.length,
        'contact_cache_size': _contactCache.length,
        'chats_fetched_in_session': _chatsFetchedInThisSession,
      },
      'connection': _connectionManager.getStatistics(),
    };
  }


  void dispose() {
    _logger.logConnection('Освобождение ресурсов ApiServiceSimple');
    _connectionManager.dispose();
    _messageController.close();
    _contactUpdatesController.close();
  }
}
