// main_menu.dart (versión limpia)
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

/// 🎨 Paleta YanaGuard
const Color azulProfundo = Color(0xFF1E3A8A);
const Color naranjaAndino = Color(0xFFF59E0B);
const Color verdeQuillu = Color(0xFF4CAF50);
const Color beigeCalido = Color(0xFFF4EBD0);

class MainMenuPage extends StatefulWidget {
  const MainMenuPage({super.key});
  @override
  State<MainMenuPage> createState() => _MainMenuPageState();
}

class _MainMenuPageState extends State<MainMenuPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  String deviceId = '';
  bool loadingDeviceDetect = true;

  @override
  void initState() {
    super.initState();
    _ensureSignedInAndDetectDevice();
  }

  Future<void> _ensureSignedInAndDetectDevice() async {
    try {
      User? user = _auth.currentUser;
      if (user == null) {
        final cred = await _auth.signInAnonymously();
        user = cred.user;
      }
      final uid = user!.uid;

      final snap = await _db
          .child('devices')
          .orderByChild('ownerUid')
          .equalTo(uid)
          .get();

      if (snap.exists && snap.value != null) {
        final Map map = Map<dynamic, dynamic>.from(snap.value as Map);
        deviceId = map.keys.first.toString();
      }
    } catch (_) {
      // Sin debug
    } finally {
      setState(() => loadingDeviceDetect = false);
    }
  }

  Future<void> _setPirEnabled(bool enabled) async {
    if (deviceId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay dispositivo vinculado.')),
      );
      return;
    }
    try {
      await _db.child('devices/$deviceId').update({
        'pirEnabled': enabled,
        'lastUpdatedBy': _auth.currentUser?.uid ?? ''
      });

      await _db.child('events/$deviceId').push().set({
        'type': 'pir_toggle',
        'value': enabled,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error actualizando PIR: $e')),
      );
    }
  }

  Future<void> _triggerAlarmTest() async {
    if (deviceId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay dispositivo vinculado.')),
      );
      return;
    }
    try {
      await _db.child('devices/$deviceId').update({'alarm': true});

      await _db.child('events/$deviceId').push().set({
        'type': 'alarm_test',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });

      Future.delayed(const Duration(seconds: 3), () {
        _db.child('devices/$deviceId').update({'alarm': false});
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error activando alarma: $e')),
      );
    }
  }

  String _labelForType(String raw) {
    final r = raw.toLowerCase();
    if (r.contains('pir')) return 'Sensor PIR';
    if (r.contains('mov') || r == 'motion') return 'Movimiento detectado';
    if (r.contains('temp')) return 'Temperatura alta';
    if (r.contains('alarm')) return 'Alarma activada';
    return raw.isEmpty ? 'Evento' : raw[0].toUpperCase() + raw.substring(1);
  }

  int _getEventTimestamp(Map ev) {
    final t = ev['timestamp'];
    if (t is int) return t;
    if (t is num) return t.toInt();
    final iso = (ev['startTime'] ?? ev['endTime'])?.toString();
    if (iso != null) {
      try {
        return DateTime.parse(iso).millisecondsSinceEpoch;
      } catch (_) {}
    }
    return DateTime.now().millisecondsSinceEpoch;
  }

  Widget _buildEventsList(String deviceId) {
    return StreamBuilder<DatabaseEvent>(
      stream: _db.child('events').child(deviceId).limitToLast(50).onValue,
      builder: (context, evSnap) {
        if (evSnap.hasError) {
          return Text('Error events: ${evSnap.error}');
        }
        if (!evSnap.hasData || evSnap.data?.snapshot.value == null) {
          return const Text('Sin eventos recientes.');
        }

        final raw = evSnap.data!.snapshot.value;
        final Map eventsMap = Map<dynamic, dynamic>.from(raw as Map);
        final eventsList = <Map<String, dynamic>>[];

        eventsMap.forEach((k, v) {
          final ev = Map<String, dynamic>.from(v as Map);
          final ts = _getEventTimestamp(ev);
          final label = _labelForType(ev['type']?.toString() ?? '');
          final value =
              ev['temp_c'] ?? ev['value'] ?? ev['temperature'] ?? '-';
          eventsList.add({
            'type': ev['type'] ?? 'evento',
            'label': label,
            'timestamp': ts,
            'value': value,
            'duration_s': ev['duration_s'],
          });
        });

        eventsList.sort((a, b) => b['timestamp'].compareTo(a['timestamp']));

        return Column(
          children: eventsList.take(20).map((ev) {
            final dt = DateTime.fromMillisecondsSinceEpoch(ev['timestamp'])
                .toLocal();
            final timestr =
                '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
                '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 6),
              child: ListTile(
                leading: Icon(Icons.event, color: azulProfundo),
                title: Text(
                  ev['label'],
                  style: TextStyle(
                      color: azulProfundo, fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  '${ev['value'] != null ? ev['value'].toString() + '\n' : ''}$timestr',
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loadingDeviceDetect) {
      return Scaffold(
        backgroundColor: beigeCalido,
        appBar:
            AppBar(title: const Text('Menú Principal'), backgroundColor: azulProfundo),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

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
                Navigator.pushNamed(context, '/dashboard',
                    arguments: deviceId);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Aún no se detectó el dispositivo.')),
                );
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar sesión',
            onPressed: () async {
              await _auth.signOut();
            },
          ),
        ],
      ),
      body: deviceId.isEmpty
          ? const Center(
              child: Text('Buscando dispositivo vinculado...'),
            )
          : StreamBuilder<DatabaseEvent>(
              stream: _db.child('devices/$deviceId').onValue,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final deviceMap =
                    snapshot.data?.snapshot.value as Map<dynamic, dynamic>?;

                final bool pirEnabled = deviceMap?['pirEnabled'] == true;
                final bool alarm = deviceMap?['alarm'] == true;
                final double? temperature = (deviceMap != null &&
                        deviceMap['temperature'] is num)
                    ? (deviceMap['temperature'] as num).toDouble()
                    : null;

                return Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: ListView(
                    children: [
                      // PIR
                      Card(
                        color: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        elevation: 6,
                        child: ListTile(
                          leading: Icon(Icons.motion_photos_on,
                              color: pirEnabled
                                  ? naranjaAndino
                                  : azulProfundo),
                          title: Text(
                            'Sensor PIR',
                            style: TextStyle(
                                color: azulProfundo,
                                fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                              'Habilitado: ${pirEnabled ? "Sí" : "No"}'),
                          trailing: Switch(
                              value: pirEnabled,
                              activeColor: naranjaAndino,
                              onChanged: _setPirEnabled),
                        ),
                      ),

                      // Alarma
                      Card(
                        color: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        elevation: 6,
                        child: ListTile(
                          leading: Icon(Icons.alarm,
                              color:
                                  alarm ? naranjaAndino : azulProfundo),
                          title: Text(
                            'Alarma',
                            style: TextStyle(
                                color: azulProfundo,
                                fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                              'Estado: ${alarm ? "Encendida" : "Apagada"}'),
                          trailing: ElevatedButton(
                            onPressed: _triggerAlarmTest,
                            style: ElevatedButton.styleFrom(
                                backgroundColor: naranjaAndino),
                            child: const Text('Probar'),
                          ),
                        ),
                      ),

                      // Temperatura
                      Card(
                        color: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        elevation: 6,
                        child: ListTile(
                          leading:
                              Icon(Icons.thermostat, color: verdeQuillu),
                          title: Text(
                            'Temperatura',
                            style: TextStyle(
                                color: azulProfundo,
                                fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            temperature != null
                                ? '${temperature.toStringAsFixed(1)} °C'
                                : 'Sin lectura',
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),
                      Text(
                        'Últimos eventos',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: azulProfundo),
                      ),
                      const SizedBox(height: 6),

                      _buildEventsList(deviceId),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
