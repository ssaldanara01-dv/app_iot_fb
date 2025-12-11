import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class MainMenuViewModel extends ChangeNotifier {
  final FirebaseAuth _auth;
  final DatabaseReference _dbRoot;

  MainMenuViewModel({
    FirebaseAuth? auth,
    DatabaseReference? dbRoot,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _dbRoot = dbRoot ?? FirebaseDatabase.instance.ref();

  String _deviceId = '';
  String get deviceId => _deviceId;

  bool _loadingDeviceDetect = true;
  bool get loadingDeviceDetect => _loadingDeviceDetect;

  String? _error;
  String? get error => _error;

  Stream<DatabaseEvent>? _deviceStream;
  Stream<DatabaseEvent>? _eventsStream;
  double? _lastHumidity;
  double? _lastTemperature;

  double? get lastHumidity => _lastHumidity;
  double? get lastTemperature => _lastTemperature;

  /// Inicializa: asegura sesión (anon) y detecta dispositivo del usuario.
  Future<void> init() async {
    _setLoading(true);
    try {
      User? user = _auth.currentUser;
      if (user == null) {
        final cred = await _auth.signInAnonymously();
        user = cred.user;
      }
      final uid = user?.uid;
      if (uid == null) {
        _error = 'Usuario no disponible';
        _setLoading(false);
        return;
      }

      final snap = await _dbRoot.child('devices').orderByChild('ownerUid').equalTo(uid).get();
      if (snap.exists && snap.value != null) {
        final Map map = Map<dynamic, dynamic>.from(snap.value as Map);
        _deviceId = map.keys.first.toString();
        _deviceStream = _dbRoot.child('devices/$_deviceId').onValue;
        _eventsStream = _dbRoot.child('events/$_deviceId').limitToLast(50).onValue;
        await _loadLastSensorData();
      } else {
        _deviceId = '';
        _deviceStream = null;
        _eventsStream = null;
      }
      _error = null;
    } catch (e) {
      debugPrint('Error detectando dispositivo: $e');
      _error = e.toString();
      _deviceId = '';
      _deviceStream = null;
      _eventsStream = null;
    } finally {
      _setLoading(false);
    }
  }

  Stream<DatabaseEvent>? get deviceStream => _deviceStream;
  Stream<DatabaseEvent>? get eventsStream => _eventsStream;

  Future<void> _loadLastSensorData() async {
    if (_deviceId.isEmpty) return;
    try {
      final snap = await _dbRoot.child('events/$_deviceId').limitToLast(20).get();
      if (snap.exists && snap.value != null) {
        final Map events = Map<dynamic, dynamic>.from(snap.value as Map);
        
        events.forEach((k, v) {
          final event = Map<String, dynamic>.from(v as Map);
          
          // Buscar últimas lecturas de humedad
          if (event['hum'] != null && event['hum'] is num) {
            _lastHumidity = (event['hum'] as num).toDouble();
          }
          
          // Buscar últimas lecturas de temperatura
          if (event['temp_c'] != null && event['temp_c'] is num) {
            _lastTemperature = (event['temp_c'] as num).toDouble();
          }
        });
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error cargando datos de sensores: $e');
    }
  }

  Future<void> refreshDeviceDetection() async {
    await init();
  }

  Future<void> setPirEnabled(bool enabled) async {
    if (_deviceId.isEmpty) {
      throw Exception('No hay dispositivo vinculado.');
    }
    try {
      await _dbRoot.child('devices/$_deviceId').update({
        'pirEnabled': enabled,
        'lastUpdatedBy': _auth.currentUser?.uid ?? ''
      });

      await _dbRoot.child('events/$_deviceId').push().set({
        'type': 'pir_toggle',
        'value': enabled,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (e) {
      debugPrint('Error actualizando PIR: $e');
      rethrow;
    }
  }

  Future<void> triggerAlarmTest() async {
    if (_deviceId.isEmpty) {
      throw Exception('No hay dispositivo vinculado.');
    }
    try {
      await _dbRoot.child('devices/$_deviceId').update({'alarm': true});

      await _dbRoot.child('events/$_deviceId').push().set({
        'type': 'alarm_test',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });

      Future.delayed(const Duration(seconds: 3), () {
        _dbRoot.child('devices/$_deviceId').update({'alarm': false});
      });
    } catch (e) {
      debugPrint('Error activando alarma: $e');
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  int _getEventTimestamp(Map ev) {
    final t = ev['timestamp'];
    if (t is int) {
      // Si es un timestamp válido (después del 2000), retornarlo
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
    
    // Intentar parsear startTime o endTime
    final iso = (ev['startTime'] ?? ev['endTime'])?.toString();
    if (iso != null) {
      try {
        final parsed = DateTime.parse(iso).millisecondsSinceEpoch;
        if (parsed > 946684800000) {
          return parsed;
        }
      } catch (_) {}
    }
    
    // Si nada funciona, usar ahora
    return DateTime.now().millisecondsSinceEpoch;
  }

  String _labelForType(String raw) {
    final r = raw.toLowerCase();
    if (r.contains('pir')) return 'Sensor PIR';
    if (r.contains('mov') || r == 'motion') return 'Movimiento';
    if (r.contains('temp')) return 'Nivel de Temperatura';
    if (r.contains('alarm')) return 'Alarma';
    return raw.isEmpty ? 'Evento' : raw[0].toUpperCase() + raw.substring(1);
  }

  // helpers públicos opcionales si la vista prefiere usarlos desde VM:
  String labelForType(String raw) => _labelForType(raw);
  int getEventTimestamp(Map ev) => _getEventTimestamp(ev);

  void _setLoading(bool v) {
    _loadingDeviceDetect = v;
    notifyListeners();
  }

  @override
  void dispose() {
    super.dispose();
  }
}

