import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_database/firebase_database.dart';

class DashboardViewModel extends ChangeNotifier {
  final String deviceId;
  final DatabaseReference _rootRef = FirebaseDatabase.instance.ref();

  StreamSubscription<DatabaseEvent>? _sub;

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  /// Lista de eventos ya parseados y ordenados por timestamp (desc)
  List<Map<String, dynamic>> _docs = [];
  List<Map<String, dynamic>> get docs => _docs;

  List<double> _temps = [];
  List<double> get temps => _temps;

  int motions24h = 0;
  int alarms24h = 0;
  int systemChanges24h = 0;
  DateTime? lastMotion;
  DateTime? lastAlarm;
  DateTime? lastSystem;

  // Para gráfico de pastel: conteo total de tipos de eventos
  Map<String, int> _eventTypeCount = {};
  Map<String, int> get eventTypeCount => _eventTypeCount;

  DashboardViewModel({required this.deviceId});

  void init() {
    _setLoading(true);
    _sub = _rootRef.child('events/$deviceId').limitToLast(500).onValue.listen(
      _onData,
      onError: (e) {
        _error = e.toString();
        _setLoading(false);
      },
    );
  }

  void _onData(DatabaseEvent event) {
    try {
      final snapVal = event.snapshot.value;
      if (snapVal == null) {
        _docs = [];
        _temps = [];
        _resetCounters();
        _setLoading(false);
        return;
      }

      final Map eventsMap = snapVal as Map<dynamic, dynamic>;
      final List<Map<String, dynamic>> parsed = [];

      for (final entry in eventsMap.entries) {
        final raw = Map<String, dynamic>.from(entry.value as Map);
        final ts = _getEventTimestamp(raw);
        parsed.add({
          'type': (raw['type'] ?? 'evento').toString(),
          'timestamp': ts,
          'temp': (raw['temp_c'] is num)
              ? (raw['temp_c'] as num).toDouble()
              : (raw['value'] is num ? (raw['value'] as num).toDouble() : null),
          'duration_s': raw['duration_s'],
        });
      }

      // ordenar descendente por timestamp
      parsed.sort((a, b) => b['timestamp'].compareTo(a['timestamp']));
      _docs = parsed;

      // calcular métricas
      _computeMetrics();

      _error = null;
    } catch (e) {
      _error = 'Error parseando datos: $e';
    } finally {
      _setLoading(false);
    }
  }

  void _resetCounters() {
    motions24h = 0;
    alarms24h = 0;
    systemChanges24h = 0;
    lastMotion = null;
    lastAlarm = null;
    lastSystem = null;
    _temps = [];
    _eventTypeCount = {};
  }

  void _computeMetrics() {
    _resetCounters();
    final now = DateTime.now().toUtc();
    final boundary24h = now.subtract(const Duration(hours: 24)).millisecondsSinceEpoch;
    final tempsLocal = <double>[];

    for (final d in _docs) {
      final type = (d['type'] as String).toLowerCase();
      final ts = d['timestamp'] as int;

      // Contar tipos de eventos para el gráfico de pastel
      String groupedType = 'Otro';
      if (type == 'motion' || type == 'pir_motion' || type.contains('pir')) {
        groupedType = 'Movimiento';
        if (ts >= boundary24h) motions24h++;
        lastMotion ??= DateTime.fromMillisecondsSinceEpoch(ts);
      } else if (type == 'alarm' || type == 'alarm_test' || type == 'alarm_trigger') {
        groupedType = 'Alarma';
        if (ts >= boundary24h) alarms24h++;
        lastAlarm ??= DateTime.fromMillisecondsSinceEpoch(ts);
      } else if (type == 'pir_toggle' || type.startsWith('system') || type.startsWith('security')) {
        groupedType = 'Sistema';
        if (ts >= boundary24h) systemChanges24h++;
        lastSystem ??= DateTime.fromMillisecondsSinceEpoch(ts);
      } else if (type.contains('temp') || type == 'temperature') {
        groupedType = 'Temperatura';
      }
      
      _eventTypeCount[groupedType] = (_eventTypeCount[groupedType] ?? 0) + 1;

      if (d['temp'] != null) {
        tempsLocal.add(d['temp'] as double);
      }
    }

    _temps = tempsLocal;
  }

  int _getEventTimestamp(Map ev) {
    final t = ev['timestamp'];
    if (t is int) {
      if (t > 946684800000) { // 2000-01-01 en ms
        return t;
      }
    }
    if (t is num) {
      final intT = t.toInt();
      if (intT > 946684800000) {
        return intT;
      }
    }

    final s = (ev['startTime'] ?? ev['endTime'] ?? ev['createdAt'])?.toString();
    if (s != null) {
      try {
        final parsed = DateTime.parse(s).millisecondsSinceEpoch;
        if (parsed > 946684800000) {
          return parsed;
        }
      } catch (_) {
        try {
          final cleaned = s.replaceAll('"', '');
          final dt2 = DateTime.tryParse(cleaned);
          if (dt2 != null) {
            final parsed = dt2.millisecondsSinceEpoch;
            if (parsed > 946684800000) {
              return parsed;
            }
          }
        } catch (_) {}
      }
    }
    return DateTime.now().millisecondsSinceEpoch;
  }

  String formatDateTime(DateTime? dt) {
    if (dt == null) return 'Nunca';
    final local = dt.toLocal();
    return '${local.year.toString().padLeft(4, '0')}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  void _setLoading(bool v) {
    _isLoading = v;
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
