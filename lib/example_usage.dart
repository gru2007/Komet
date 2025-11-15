import 'package:flutter/material.dart';
import 'api_service_simple.dart';
import 'connection/connection_state.dart' as conn_state;


class ConnectionExample extends StatefulWidget {
  const ConnectionExample({super.key});

  @override
  State<ConnectionExample> createState() => _ConnectionExampleState();
}

class _ConnectionExampleState extends State<ConnectionExample> {
  final ApiServiceSimple _apiService = ApiServiceSimple.instance;
  conn_state.ConnectionInfo? _currentState;
  String _logs = '';

  @override
  void initState() {
    super.initState();
    _initializeService();
    _setupListeners();
  }

  Future<void> _initializeService() async {
    try {
      await _apiService.initialize();
      _addLog('✅ Сервис инициализирован');
    } catch (e) {
      _addLog('❌ Ошибка инициализации: $e');
    }
  }

  void _setupListeners() {

    _apiService.connectionState.listen((state) {
      setState(() {
        _currentState = state;
      });
      _addLog('🔄 Состояние: ${_getStateText(state.state)}');
    });


    _apiService.logs.listen((log) {
      _addLog('📝 ${log.toString()}');
    });


    _apiService.healthMetrics.listen((health) {
      _addLog(
        '🏥 Здоровье: ${health.healthScore}/100 (${health.quality.name})',
      );
    });
  }

  void _addLog(String message) {
    setState(() {
      _logs +=
          '${DateTime.now().toIso8601String().substring(11, 23)} $message\n';
    });
  }

  String _getStateText(conn_state.ConnectionState state) {
    switch (state) {
      case conn_state.ConnectionState.disconnected:
        return 'Отключен';
      case conn_state.ConnectionState.connecting:
        return 'Подключение...';
      case conn_state.ConnectionState.connected:
        return 'Подключен';
      case conn_state.ConnectionState.ready:
        return 'Готов';
      case conn_state.ConnectionState.reconnecting:
        return 'Переподключение...';
      case conn_state.ConnectionState.error:
        return 'Ошибка';
      case conn_state.ConnectionState.disabled:
        return 'Отключен';
    }
  }

  Color _getStateColor(conn_state.ConnectionState state) {
    switch (state) {
      case conn_state.ConnectionState.ready:
        return Colors.green;
      case conn_state.ConnectionState.connected:
        return Colors.blue;
      case conn_state.ConnectionState.connecting:
      case conn_state.ConnectionState.reconnecting:
        return Colors.orange;
      case conn_state.ConnectionState.error:
        return Colors.red;
      case conn_state.ConnectionState.disconnected:
      case conn_state.ConnectionState.disabled:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Пример подключения'),
        backgroundColor: _currentState != null
            ? _getStateColor(_currentState!.state)
            : Colors.grey,
      ),
      body: Column(
        children: [

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: _currentState != null
                ? _getStateColor(_currentState!.state).withOpacity(0.1)
                : Colors.grey.withOpacity(0.1),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Статус: ${_currentState != null ? _getStateText(_currentState!.state) : 'Неизвестно'}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_currentState?.message != null) ...[
                  const SizedBox(height: 4),
                  Text('Сообщение: ${_currentState!.message}'),
                ],
                if (_currentState?.serverUrl != null) ...[
                  const SizedBox(height: 4),
                  Text('Сервер: ${_currentState!.serverUrl}'),
                ],
                if (_currentState?.latency != null) ...[
                  const SizedBox(height: 4),
                  Text('Задержка: ${_currentState!.latency}ms'),
                ],
              ],
            ),
          ),


          Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton(
                  onPressed: _connect,
                  child: const Text('Подключиться'),
                ),
                ElevatedButton(
                  onPressed: _disconnect,
                  child: const Text('Отключиться'),
                ),
                ElevatedButton(
                  onPressed: _reconnect,
                  child: const Text('Переподключиться'),
                ),
                ElevatedButton(
                  onPressed: _clearLogs,
                  child: const Text('Очистить логи'),
                ),
                ElevatedButton(
                  onPressed: _showStats,
                  child: const Text('Статистика'),
                ),
              ],
            ),
          ),


          Expanded(
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: SingleChildScrollView(
                child: Text(
                  _logs.isEmpty ? 'Логи появятся здесь...' : _logs,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _connect() async {
    try {
      _addLog('🔄 Попытка подключения...');
      await _apiService.connect();
      _addLog('✅ Подключение успешно');
    } catch (e) {
      _addLog('❌ Ошибка подключения: $e');
    }
  }

  Future<void> _disconnect() async {
    try {
      _addLog('🔄 Отключение...');
      await _apiService.disconnect();
      _addLog('✅ Отключение успешно');
    } catch (e) {
      _addLog('❌ Ошибка отключения: $e');
    }
  }

  Future<void> _reconnect() async {
    try {
      _addLog('🔄 Переподключение...');
      await _apiService.reconnect();
      _addLog('✅ Переподключение успешно');
    } catch (e) {
      _addLog('❌ Ошибка переподключения: $e');
    }
  }

  void _clearLogs() {
    setState(() {
      _logs = '';
    });
    _addLog('🧹 Логи очищены');
  }

  void _showStats() {
    final stats = _apiService.getStatistics();
    _addLog('📊 Статистика: ${stats.toString()}');


    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Статистика'),
        content: SingleChildScrollView(
          child: Text(
            stats.toString(),
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Закрыть'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _apiService.dispose();
    super.dispose();
  }
}
