// main_menu.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class MainMenuPage extends StatefulWidget {
  const MainMenuPage({super.key});
  @override
  State<MainMenuPage> createState() => _MainMenuPageState();
}

class _MainMenuPageState extends State<MainMenuPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  String deviceId = '';

  // Paleta YanaGuard 🎨
  final Color azulProfundo = const Color(0xFF1E3A8A);
  final Color naranjaAndino = const Color(0xFFF59E0B);
  final Color verdeQuillu = const Color(0xFF4CAF50);
  final Color beigeCalido = const Color(0xFFF4EBD0);

  @override
  void initState() {
    super.initState();
    _initializeUserAndDevice();
  }

  Future<void> _initializeUserAndDevice() async {
    try {
      User? user = _auth.currentUser;
      if (user == null) {
        final cred = await _auth.signInAnonymously();
        user = cred.user;
      }
      final uid = user!.uid;
      print('UID activo: $uid');

      final snap = await _db.child('devices').orderByChild('ownerUid').equalTo(uid).get();
      if (snap.exists && snap.value != null) {
        final Map map = snap.value as Map;
        deviceId = map.keys.first.toString();
        print('✅ Dispositivo vinculado: $deviceId');
        setState(() {});
      } else {
        print('⚠️ No se encontró dispositivo vinculado.');
      }
    } catch (e) {
      print('❌ Error al inicializar: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar datos: $e')),
        );
      }
    }
  }

  // Utilities: convert event to epoch ms (prefer numeric timestamp, fallback to ISO startTime/endTime)
  int _getEventTimestamp(Map ev) {
    final t = ev['timestamp'];
    if (t is int) return t;
    if (t is num) return t.toInt();

    final s = (ev['startTime'] ?? ev['endTime'] ?? ev['createdAt'])?.toString();
    if (s != null) {
      try {
        final dt = DateTime.parse(s);
        return dt.millisecondsSinceEpoch;
      } catch (_) {
        // try more lenient parse
        try {
          final cleaned = s.replaceAll('"', '');
          final dt2 = DateTime.tryParse(cleaned);
          if (dt2 != null) return dt2.millisecondsSinceEpoch;
        } catch (_) {}
      }
    }
    return DateTime.now().millisecondsSinceEpoch;
  }

  // If device node lacks pirMotion/lastMotion, infer from last motion event (consider motion ongoing if last motion < threshold ms)
  Future<bool> _inferPirMotionFromEvents({int thresholdMs = 10000}) async {
    if (deviceId.isEmpty) return false;
    try {
      final evSnap = await _db.child('events/$deviceId').orderByChild('startTime').limitToLast(20).get();
      if (!evSnap.exists || evSnap.value == null) return false;
      final Map eventsMap = evSnap.value as Map<dynamic, dynamic>;
      int lastTs = 0;
      for (final entry in eventsMap.entries) {
        final ev = Map.from(entry.value as Map);
        final type = (ev['type'] ?? '').toString().toLowerCase();
        if (type == 'motion' || type.contains('pir')) {
          final ts = _getEventTimestamp(ev);
          if (ts > lastTs) lastTs = ts;
        }
      }
      if (lastTs == 0) return false;
      final age = DateTime.now().millisecondsSinceEpoch - lastTs;
      return age < thresholdMs;
    } catch (e) {
      print('Error infiriendo pirMotion: $e');
      return false;
    }
  }

  Future<void> _setPirEnabled(bool enabled) async {
    if (deviceId.isEmpty) {
      _showError('No hay dispositivo vinculado.');
      return;
    }
    try {
      await _db.child('devices/$deviceId').update({'pirEnabled': enabled});
      await _db.child('events/$deviceId').push().set({
        'type': 'pir_toggle',
        'value': enabled,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'ownerUid': _auth.currentUser?.uid ?? ''
      });
    } catch (e) {
      _showError('Error al actualizar PIR: $e');
    }
  }

  Future<void> _triggerAlarmTest() async {
    if (deviceId.isEmpty) {
      _showError('No hay dispositivo vinculado.');
      return;
    }
    try {
      await _db.child('devices/$deviceId').update({'alarm': true});
      await _db.child('events/$deviceId').push().set({
        'type': 'alarm_test',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'ownerUid': _auth.currentUser?.uid ?? ''
      });
      Future.delayed(const Duration(seconds: 3), () {
        _db.child('devices/$deviceId').update({'alarm': false});
      });
    } catch (e) {
      _showError('No se pudo activar la alarma.');
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _signOut() async {
    await _auth.signOut();
  }

  String _formatTs(int? ms) {
    if (ms == null || ms == 0) return 'Nunca';
    final dt = DateTime.fromMillisecondsSinceEpoch(ms).toLocal();
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: beigeCalido,
      appBar: AppBar(
        title: const Text('Menú Principal'),
        backgroundColor: azulProfundo,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.vpn_key),
            tooltip: 'Emparejar dispositivo',
            onPressed: () => Navigator.pushNamed(context, '/pairing'),
          ),
          IconButton(
            icon: const Icon(Icons.dashboard_outlined),
            tooltip: 'Ver Dashboard',
            onPressed: () {
              if (deviceId.isNotEmpty) {
                Navigator.pushNamed(context, '/dashboard', arguments: deviceId);
              } else {
                _showError('Aún no se detectó el dispositivo.');
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar sesión',
            onPressed: _signOut,
          ),
        ],
      ),
      body: deviceId.isEmpty
          ? const Center(child: Text('Buscando dispositivo vinculado...'))
          : StreamBuilder<DatabaseEvent>(
              stream: _db.child('devices/$deviceId').onValue,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                // Device snapshot might be null but events may exist
                final deviceMap = snapshot.data?.snapshot.value as Map<dynamic, dynamic>?;
                final bool hasDeviceData = deviceMap != null;
                final bool pirEnabled = hasDeviceData && deviceMap['pirEnabled'] == true;
                final bool alarmCfg = hasDeviceData && deviceMap['alarm'] == true;
                final double? temperature = (hasDeviceData && deviceMap['temperature'] is num)
                    ? (deviceMap['temperature'] as num).toDouble()
                    : null;

                return Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: ListView(
                    children: [
                      // Sensor PIR card (we'll combine device data + inference)
                      FutureBuilder<bool>(
                        future: hasDeviceData && deviceMap.containsKey('pirMotion')
                            ? Future.value(deviceMap['pirMotion'] == true)
                            : _inferPirMotionFromEvents(),
                        builder: (context, pirSnap) {
                          final pirMotion = pirSnap.data ?? false;
                          return Card(
                            color: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 6,
                            child: ListTile(
                              leading: Icon(Icons.motion_photos_on, color: pirMotion ? naranjaAndino : azulProfundo),
                              title: Text('Sensor PIR', style: TextStyle(color: azulProfundo, fontWeight: FontWeight.bold)),
                              subtitle: Text('Habilitado: ${pirEnabled ? "Sí" : "No"}\nMovimiento: ${pirMotion ? "Detectado" : "No detectado"}', style: const TextStyle(height: 1.4)),
                              isThreeLine: true,
                              trailing: Switch(value: pirEnabled, activeColor: naranjaAndino, onChanged: (v) => _setPirEnabled(v)),
                            ),
                          );
                        },
                      ),

                      // Alarm card
                      Card(
                        color: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 6,
                        child: ListTile(
                          leading: Icon(Icons.alarm, color: alarmCfg ? naranjaAndino : azulProfundo),
                          title: Text('Alarma', style: TextStyle(color: azulProfundo, fontWeight: FontWeight.bold)),
                          subtitle: Text('Estado: ${alarmCfg ? "Encendida" : "Apagada"}'),
                          trailing: ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: naranjaAndino, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                            onPressed: _triggerAlarmTest,
                            child: const Text('Probar'),
                          ),
                        ),
                      ),

                      // Temperature
                      Card(
                        color: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 6,
                        child: ListTile(
                          leading: Icon(Icons.thermostat, color: verdeQuillu),
                          title: Text('Temperatura', style: TextStyle(color: azulProfundo, fontWeight: FontWeight.bold)),
                          subtitle: Text(temperature != null ? '${temperature.toStringAsFixed(1)} °C' : 'Sin lectura'),
                        ),
                      ),

                      const SizedBox(height: 12),
                      Text('Últimos eventos', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: azulProfundo)),
                      const SizedBox(height: 6),

                      // Events list (stream)
                      StreamBuilder<DatabaseEvent>(
                        stream: _db.child('events/$deviceId').limitToLast(20).onValue,
                        builder: (context, evSnap) {
                          if (!evSnap.hasData || evSnap.data?.snapshot.value == null) {
                            return const Text('Sin eventos recientes.');
                          }
                          final Map eventsMap = evSnap.data!.snapshot.value as Map<dynamic, dynamic>;
                          final eventsList = <Map<String, dynamic>>[];
                          for (final entry in eventsMap.entries) {
                            final ev = Map<String, dynamic>.from(entry.value as Map);
                            final ts = _getEventTimestamp(ev);
                            eventsList.add({
                              'type': ev['type'] ?? 'evento',
                              'timestamp': ts,
                              'duration_s': ev['duration_s'],
                              'buzzerUsed': ev['buzzerUsed'] ?? false,
                            });
                          }
                          eventsList.sort((a, b) => b['timestamp'].compareTo(a['timestamp']));
                          return Column(
                            children: eventsList.take(10).map((ev) {
                              return Card(
                                color: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                elevation: 2,
                                margin: const EdgeInsets.symmetric(vertical: 6),
                                child: ListTile(
                                  leading: Icon(Icons.event, color: azulProfundo),
                                  title: Text(ev['type'].toString(), style: TextStyle(color: azulProfundo, fontWeight: FontWeight.w600)),
                                  subtitle: Text('${ev['duration_s'] != null ? 'Dur: ${ev['duration_s']}s · ' : ''}${_formatTs(ev['timestamp'])}'),
                                ),
                              );
                            }).toList(),
                          );
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}