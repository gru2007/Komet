part of 'api_service.dart';

extension ApiServiceConnection on ApiService {
  Future<void> _connectWithFallback() async {
    _log('Начало подключения...');
    _updateConnectionState(
      conn_state.ConnectionState.connecting,
      message: 'Поиск доступного сервера',
    );

    while (_currentUrlIndex < _wsUrls.length) {
      final currentUrl = _wsUrls[_currentUrlIndex];
      final logMessage =
          'Попытка ${_currentUrlIndex + 1}/${_wsUrls.length}: $currentUrl';
      _log(logMessage);
      _connectionLogController.add(logMessage);

      try {
        await _connectToUrl(currentUrl);
        final successMessage = _currentUrlIndex == 0
            ? 'Подключено к основному серверу'
            : 'Подключено через резервный сервер';
        _connectionLogController.add('✅ $successMessage');
        _updateConnectionState(
          conn_state.ConnectionState.connecting,
          message: 'Соединение установлено, ожидание handshake',
          metadata: {'server': currentUrl},
        );
        if (_currentUrlIndex > 0) {
          _connectionStatusController.add('Подключено через резервный сервер');
        }
        return;
      } catch (e) {
        final errorMessage = '❌ Ошибка: ${e.toString().split(':').first}';
        _connectionLogController.add(errorMessage);
        _healthMonitor.onError(errorMessage);
        _currentUrlIndex++;

        if (_currentUrlIndex < _wsUrls.length) {
          await Future.delayed(const Duration(milliseconds: 500));
        }
      }
    }

    _log('❌ Все серверы недоступны');
    _connectionStatusController.add('Все серверы недоступны');
    _updateConnectionState(
      conn_state.ConnectionState.error,
      message: 'Все серверы недоступны',
    );
    _stopHealthMonitoring();
    throw Exception('Не удалось подключиться ни к одному серверу');
  }

  Future<void> _connectToUrl(String url) async {
    _isSessionOnline = false;
    _onlineCompleter = Completer<void>();
    _currentServerUrl = url;
    final bool hadChatsFetched = _chatsFetchedInThisSession;
    final bool hasValidToken = authToken != null;

    if (!hasValidToken) {
      _chatsFetchedInThisSession = false;
    } else {
      _chatsFetchedInThisSession = hadChatsFetched;
    }

    _connectionStatusController.add('connecting');

    final uri = Uri.parse(url);

    final spoofedData = await SpoofingService.getSpoofedSessionData();
    final userAgent =
        spoofedData?['useragent'] as String? ??
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

    final headers = <String, String>{
      'Origin': AppUrls.webOrigin,
      'User-Agent': userAgent,
      'Sec-WebSocket-Extensions': 'permessage-deflate',
    };

    final proxySettings = await ProxyService.instance.loadProxySettings();

    if (proxySettings.isEnabled && proxySettings.host.isNotEmpty) {
      final customHttpClient = await ProxyService.instance
          .getHttpClientWithProxy();
      _channel = IOWebSocketChannel.connect(
        uri,
        headers: headers,
        customClient: customHttpClient,
      );
    } else {
      _channel = IOWebSocketChannel.connect(uri, headers: headers);
    }

    await _channel!.ready;
    _listen();
    await _sendHandshake();
    _startPinging();
  }

  void _handleSessionTerminated() {
    _isSessionOnline = false;
    _isSessionReady = false;
    _stopHealthMonitoring();
    _updateConnectionState(
      conn_state.ConnectionState.disconnected,
      message: 'Сессия завершена сервером',
    );

    authToken = null;

    clearAllCaches();

    _messageController.add({
      'type': 'session_terminated',
      'message': 'Твоя сессия больше не активна, войди снова',
    });
  }

  void _handleInvalidToken() async {
    _isSessionOnline = false;
    _isSessionReady = false;
    _stopHealthMonitoring();
    _healthMonitor.onError('invalid_token');
    _updateConnectionState(
      conn_state.ConnectionState.error,
      message: 'Недействительный токен',
    );

    authToken = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('authToken');

    clearAllCaches();

    _channel?.sink.close();
    _channel = null;
    _pingTimer?.cancel();

    _messageController.add({
      'type': 'invalid_token',
      'message': 'Токен недействителен, требуется повторная авторизация',
    });
  }

  Future<void> _sendHandshake() async {
    if (_handshakeSent) {
      return;
    }

    final userAgentPayload = await _buildUserAgentPayload();

    final prefs = await SharedPreferences.getInstance();
    final deviceId =
        prefs.getString('spoof_deviceid') ?? generateRandomDeviceId();

    if (prefs.getString('spoof_deviceid') == null) {
      await prefs.setString('spoof_deviceid', deviceId);
    }

    final payload = {'deviceId': deviceId, 'userAgent': userAgentPayload};

    _sendMessage(6, payload);
    _handshakeSent = true;
  }

  void _startPinging() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 25), (timer) {
      if (_isSessionOnline && _isSessionReady && _isAppInForeground) {
        _sendMessage(1, {"interactive": true});
      }
    });
  }

  Future<void> connect() async {
    if (_channel != null && _isSessionOnline) {
      return;
    }

    _isSessionOnline = false;
    _isSessionReady = false;

    _connectionStatusController.add("connecting");
    _updateConnectionState(
      conn_state.ConnectionState.connecting,
      message: 'Инициализация подключения',
    );
    await _connectWithFallback();
  }

  Future<void> reconnect() async {
    _reconnectAttempts = 0;
    _currentUrlIndex = 0;

    _connectionStatusController.add("connecting");
    await _connectWithFallback();
  }

  void sendFullJsonRequest(String jsonString) {
    if (_channel == null) {
      throw Exception('WebSocket is not connected. Connect first.');
    }
    try {
      final decoded = jsonDecode(jsonString) as Map<String, dynamic>;
      final opcode = decoded['opcode'];
      final payload = decoded['payload'];
      _log('➡️ SEND: opcode=$opcode, payload=$payload');
    } catch (_) {
      _log('➡️ SEND (raw): $jsonString');
    }
    _channel!.sink.add(jsonString);
  }

  int sendRawRequest(int opcode, Map<String, dynamic> payload) {
    if (_channel == null) {
      print('WebSocket не подключен!');
      throw Exception('WebSocket is not connected. Connect first.');
    }

    return _sendMessage(opcode, payload);
  }

  int sendAndTrackFullJsonRequest(String jsonString) {
    if (_channel == null) {
      throw Exception('WebSocket is not connected. Connect first.');
    }

    final message = jsonDecode(jsonString) as Map<String, dynamic>;

    final int currentSeq = _seq++;

    message['seq'] = currentSeq;

    final encodedMessage = jsonEncode(message);

    final opcode = message['opcode'];
    print('→ opcode=$opcode seq=$currentSeq');

    _channel!.sink.add(encodedMessage);

    return currentSeq;
  }

  int _sendMessage(int opcode, Map<String, dynamic> payload) {
    if (_channel == null) {
      return -1;
    }
    final message = {
      "ver": 11,
      "cmd": 0,
      "seq": _seq,
      "opcode": opcode,
      "payload": payload,
    };
    final encodedMessage = jsonEncode(message);
    print('→ opcode=$opcode seq=${_seq}');
    _channel!.sink.add(encodedMessage);
    return _seq++;
  }

  void _listen() async {
    if (_channel == null) {
      return;
    }

    
    if (_streamSubscription != null) {
      return;
    }

    _streamSubscription = _channel!.stream.listen(
      (message) {
        if (message == null) return;
        if (message is String && message.trim().isEmpty) {
          return;
        }

        try {
          final decoded = jsonDecode(message) as Map<String, dynamic>;
          final opcode = decoded['opcode'];
          final cmd = decoded['cmd'];
          final seq = decoded['seq'];

          if (opcode == 2) {
            _healthMonitor.onPongReceived();
          }

          if (opcode != 19) {
            final payload = decoded['payload'];
            print('← opcode=$opcode cmd=$cmd seq=$seq payload=$payload');
          }
        } catch (_) {}

        try {
          final decodedMessage = message is String
              ? jsonDecode(message)
              : message;

          if (decodedMessage is Map &&
              decodedMessage['opcode'] == 97 &&
              decodedMessage['cmd'] == 1 &&
              decodedMessage['payload'] != null &&
              decodedMessage['payload']['token'] != null) {
            _handleSessionTerminated();
            return;
          }

          if (decodedMessage is Map &&
              decodedMessage['opcode'] == 6 &&
              decodedMessage['cmd'] == 1) {
            _isSessionOnline = true;
            _isSessionReady = false;
            _reconnectDelaySeconds = 2;
            _connectionStatusController.add("authorizing");
            _updateConnectionState(
              conn_state.ConnectionState.connected,
              message: 'Handshake успешен',
            );
            _startHealthMonitoring();

            _startPinging();
            _processMessageQueue();

            if (authToken != null && !_chatsFetchedInThisSession) {
              unawaited(_sendAuthRequestAfterHandshake());
            } else if (authToken == null) {
              _isSessionReady = true;
              if (_onlineCompleter != null && !_onlineCompleter!.isCompleted) {
                _onlineCompleter!.complete();
              }
            }
          }

          if (decodedMessage is Map && decodedMessage['cmd'] == 3) {
            final error = decodedMessage['payload'];
            final errorMsg = error?['message'] ?? error?['error'] ?? 'server_error';
            print('← ERROR: $errorMsg');
            _healthMonitor.onError(errorMsg);
            _updateConnectionState(
              conn_state.ConnectionState.error,
              message: error?['message'],
            );

            if (error != null && error['localizedMessage'] != null) {
              _errorController.add(error['localizedMessage']);
            } else if (error != null && error['message'] != null) {
              _errorController.add(error['message']);
            }

            if (error != null && error['message'] == 'FAIL_WRONG_PASSWORD') {
              _errorController.add('FAIL_WRONG_PASSWORD');
            }

            if (error != null && error['error'] == 'password.invalid') {
              _errorController.add('Неверный пароль');
            }

            if (error != null && error['error'] == 'proto.state') {
              _chatsFetchedInThisSession = false;
              _reconnect();
              return;
            }

            if (error != null && error['error'] == 'login.token') {
              _handleInvalidToken();
              return;
            }

            if (error != null && error['message'] == 'FAIL_WRONG_PASSWORD') {
              _clearAuthToken().then((_) {
                _chatsFetchedInThisSession = false;
                _messageController.add({
                  'type': 'invalid_token',
                  'message':
                      'Токен авторизации недействителен. Требуется повторная авторизация.',
                });
                _reconnect();
              });
              return;
            }
          }

          if (decodedMessage is Map &&
              decodedMessage['opcode'] == 18 &&
              decodedMessage['cmd'] == 1 &&
              decodedMessage['payload'] != null) {
            final payload = decodedMessage['payload'];
            if (payload['passwordChallenge'] != null) {
              final challenge = payload['passwordChallenge'];
              _currentPasswordTrackId = challenge['trackId'];
              _currentPasswordHint = challenge['hint'];
              _currentPasswordEmail = challenge['email'];


              _messageController.add({
                'type': 'password_required',
                'trackId': _currentPasswordTrackId,
                'hint': _currentPasswordHint,
                'email': _currentPasswordEmail,
              });
              return;
            }
          }

          if (decodedMessage is Map &&
              decodedMessage['opcode'] == 22 &&
              decodedMessage['cmd'] == 1) {
            final payload = decodedMessage['payload'];
            _messageController.add({
              'type': 'privacy_settings_updated',
              'settings': payload,
            });
          }

          if (decodedMessage is Map &&
              decodedMessage['opcode'] == 116 &&
              decodedMessage['cmd'] == 1) {
            final payload = decodedMessage['payload'];
            _messageController.add({
              'type': 'password_set_success',
              'payload': payload,
            });
          }

          if (decodedMessage is Map &&
              decodedMessage['opcode'] == 57 &&
              decodedMessage['cmd'] == 1) {
            final payload = decodedMessage['payload'];
            _messageController.add({
              'type': 'group_join_success',
              'payload': payload,
            });
          }

          if (decodedMessage is Map &&
              decodedMessage['opcode'] == 46 &&
              decodedMessage['cmd'] == 1) {
            final payload = decodedMessage['payload'];
            _messageController.add({
              'type': 'contact_found',
              'payload': payload,
            });
          }

          if (decodedMessage is Map &&
              decodedMessage['opcode'] == 46 &&
              decodedMessage['cmd'] == 3) {
            final payload = decodedMessage['payload'];
            _messageController.add({
              'type': 'contact_not_found',
              'payload': payload,
            });
          }

          if (decodedMessage is Map &&
              decodedMessage['opcode'] == 32 &&
              decodedMessage['cmd'] == 1) {
            final payload = decodedMessage['payload'];
            _messageController.add({
              'type': 'channels_found',
              'payload': payload,
            });
          }

          if (decodedMessage is Map &&
              decodedMessage['opcode'] == 32 &&
              decodedMessage['cmd'] == 3) {
            final payload = decodedMessage['payload'];
            _messageController.add({
              'type': 'channels_not_found',
              'payload': payload,
            });
          }

          if (decodedMessage is Map &&
              decodedMessage['opcode'] == 89 &&
              decodedMessage['cmd'] == 1) {
            final payload = decodedMessage['payload'];
            final chat = payload['chat'] as Map<String, dynamic>?;
            
            if (chat != null) {
              final chatType = chat['type'] as String?;
              if (chatType == 'CHAT') {
                _messageController.add({
                  'type': 'group_join_success',
                  'payload': payload,
                });
              } else {
                _messageController.add({
                  'type': 'channel_entered',
                  'payload': payload,
                });
              }
            } else {
              _messageController.add({
                'type': 'channel_entered',
                'payload': payload,
              });
            }
          }

          if (decodedMessage is Map &&
              decodedMessage['opcode'] == 89 &&
              decodedMessage['cmd'] == 3) {
            final payload = decodedMessage['payload'];
            _messageController.add({
              'type': 'channel_error',
              'payload': payload,
            });
          }

          if (decodedMessage is Map &&
              decodedMessage['opcode'] == 57 &&
              decodedMessage['cmd'] == 1) {
            final payload = decodedMessage['payload'];
            _messageController.add({
              'type': 'channel_subscribed',
              'payload': payload,
            });
          }

          if (decodedMessage is Map &&
              decodedMessage['opcode'] == 57 &&
              decodedMessage['cmd'] == 3) {
            final payload = decodedMessage['payload'];
            _messageController.add({
              'type': 'channel_error',
              'payload': payload,
            });
          }

          if (decodedMessage is Map &&
              decodedMessage['opcode'] == 59 &&
              decodedMessage['cmd'] == 1) {
            final payload = decodedMessage['payload'];
            _messageController.add({
              'type': 'group_members',
              'payload': payload,
            });
          }

          if (decodedMessage is Map &&
              decodedMessage['opcode'] == 162 &&
              decodedMessage['cmd'] == 1) {
            final payload = decodedMessage['payload'];
            try {
              final complaintData = ComplaintData.fromJson(payload);
              _messageController.add({
                'type': 'complaints_data',
                'complaintData': complaintData,
              });
            } catch (e) {
              print('← ERROR parsing complaints: $e');
            }
          }

          if (decodedMessage is Map<String, dynamic>) {
            _messageController.add(decodedMessage);
          }
        } catch (e) {
          print('← ERROR invalid message: $e');
        }
      },
      onError: (error) {
        print('← ERROR WebSocket: $error');
        _isSessionOnline = false;
        _isSessionReady = false;
        _healthMonitor.onError(error.toString());
        _updateConnectionState(
          conn_state.ConnectionState.error,
          message: error.toString(),
        );
        _reconnect();
      },
      onDone: () {
        print('← WebSocket closed');
        _isSessionOnline = false;
        _isSessionReady = false;
        _stopHealthMonitoring();
        _updateConnectionState(
          conn_state.ConnectionState.disconnected,
          message: 'Соединение закрыто',
        );

        if (!_isSessionReady) {
          _reconnect();
        }
      },
      cancelOnError: true,
    );
  }

  void _reconnect() {
    if (_isReconnecting) return;

    _isReconnecting = true;
    _reconnectAttempts++;
    _healthMonitor.onReconnect();

    if (_reconnectAttempts > ApiService._maxReconnectAttempts) {
      print("← ERROR max reconnect attempts");
      _connectionStatusController.add("disconnected");
      _isReconnecting = false;
      _updateConnectionState(
        conn_state.ConnectionState.error,
        message: 'Превышено число попыток переподключения',
      );
      return;
    }

    _pingTimer?.cancel();
    _reconnectTimer?.cancel();
    _streamSubscription?.cancel();

    if (_channel != null) {
      try {
        _channel!.sink.close(status.goingAway);
      } catch (e) {}
      _channel = null;
    }

    _isSessionOnline = false;
    _isSessionReady = false;
    _handshakeSent = false;
    _onlineCompleter = Completer<void>();
    _chatsFetchedInThisSession = false;

    _currentUrlIndex = 0;

    _reconnectDelaySeconds = (_reconnectDelaySeconds * 2).clamp(1, 30);
    final jitter = (DateTime.now().millisecondsSinceEpoch % 1000) / 1000.0;
    final delay = Duration(seconds: _reconnectDelaySeconds + jitter.round());

    _reconnectTimer = Timer(delay, () {
      _isReconnecting = false;
      _updateConnectionState(
        conn_state.ConnectionState.reconnecting,
        attemptNumber: _reconnectAttempts,
        reconnectDelay: delay,
      );
      _connectWithFallback();
    });
  }

  void _processMessageQueue() {
    if (_messageQueue.isEmpty) return;
    for (var message in _messageQueue) {
      _sendMessage(message['opcode'], message['payload']);
    }
    _messageQueue.clear();
  }

  void forceReconnect() {
    _pingTimer?.cancel();
    _reconnectTimer?.cancel();
    if (_channel != null) {
      _channel!.sink.close(status.goingAway);
      _channel = null;
    }

    _isReconnecting = false;
    _reconnectAttempts = 0;
    _reconnectDelaySeconds = 2;
    _isSessionOnline = false;
    _isSessionReady = false;
    _chatsFetchedInThisSession = false;
    _currentUrlIndex = 0;
    _onlineCompleter = Completer<void>();

    _messageQueue.clear();
    _presenceData.clear();

    _connectionStatusController.add("connecting");
    _log("Запускаем новую сессию подключения...");

    _connectWithFallback();
  }

  Future<void> performFullReconnection() async {
    try {
      _pingTimer?.cancel();
      _reconnectTimer?.cancel();

      _streamSubscription?.cancel();
      _streamSubscription = null;

      if (_channel != null) {
        try {
          _channel!.sink.close(status.goingAway);
        } catch (e) {}
        _channel = null;
      }

      _isReconnecting = false;
      _reconnectAttempts = 0;
      _reconnectDelaySeconds = 2;
      _isSessionOnline = false;
      _isSessionReady = false;
      _handshakeSent = false;
      _chatsFetchedInThisSession = false;
      _currentUrlIndex = 0;
      _onlineCompleter = Completer<void>();
      _seq = 0;

      _lastChatsPayload = null;
      _lastChatsAt = null;

      _connectionStatusController.add("disconnected");

      await connect();

      await Future.delayed(const Duration(milliseconds: 1500));

      if (!_reconnectionCompleteController.isClosed) {
        _reconnectionCompleteController.add(null);
      }
    } catch (e) {
      print("← ERROR full reconnect: $e");
      rethrow;
    }
  }

  void disconnect() {
    _pingTimer?.cancel();
    _reconnectTimer?.cancel();
    _streamSubscription?.cancel();
    _isSessionOnline = false;
    _isSessionReady = false;
    _handshakeSent = false;
    _onlineCompleter = Completer<void>();
    _chatsFetchedInThisSession = false;
    _stopHealthMonitoring();
    _updateConnectionState(
      conn_state.ConnectionState.disconnected,
      message: 'Отключено пользователем',
    );

    _channel?.sink.close(status.goingAway);
    _channel = null;
    _streamSubscription = null;

    _connectionStatusController.add("disconnected");
  }
}
