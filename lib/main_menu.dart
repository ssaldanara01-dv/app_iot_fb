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

  // 🎨 Paleta YanaGuard
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
      // ✅ Asegura sesión activa
      User? user = _auth.currentUser;
      if (user == null) {
        final cred = await _auth.signInAnonymously();
        user = cred.user;
      }

      final uid = user!.uid;
      print('UID activo: $uid');

      // 🔍 Busca dispositivo del usuario
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar datos: $e')),
      );
    }
  }

  Future<void> _setPirEnabled(bool enabled) async {
    if (deviceId.isEmpty) return;
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    try {
      await _db.child('devices/$deviceId').update({'pirEnabled': enabled});
      await _db.child('events/$deviceId').push().set({
        'type': 'pir_toggle',
        'value': enabled,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'ownerUid': uid,
      });
    } catch (e) {
      _showError('Sin permisos para modificar PIR.');
    }
  }

  Future<void> _triggerAlarmTest() async {
    if (deviceId.isEmpty) return;
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    try {
      await _db.child('devices/$deviceId').update({'alarm': true});
      await _db.child('events/$deviceId').push().set({
        'type': 'alarm_test',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'ownerUid': uid,
      });
      Future.delayed(const Duration(seconds: 3), () {
        _db.child('devices/$deviceId').update({'alarm': false});
      });
    } catch (e) {
      _showError('No se pudo activar la alarma.');
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _signOut() async {
    await _auth.signOut();
  }

  String _formatTs(int? ms) {
    if (ms == null || ms == 0) return 'Nunca';
    final dt = DateTime.fromMillisecondsSinceEpoch(ms).toLocal();
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
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
                if (!snapshot.hasData || snapshot.data?.snapshot.value == null) {
                  return const Center(child: CircularProgressIndicator());
                }

                final Map data = snapshot.data!.snapshot.value as Map;
                final bool pirEnabled = data['pirEnabled'] == true;
                final bool pirMotion = data['pirMotion'] == true;
                final bool alarm = data['alarm'] == true;
                final double? temperature =
                    (data['temperature'] is num) ? (data['temperature'] as num).toDouble() : null;

                return Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: ListView(
                    children: [
                      _buildSensorCard(pirEnabled, pirMotion),
                      _buildAlarmCard(alarm),
                      _buildTempCard(temperature),
                      const SizedBox(height: 12),
                      Text(
                        'Últimos eventos',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: azulProfundo,
                        ),
                      ),
                      const SizedBox(height: 6),
                      _buildEventsList(),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _buildSensorCard(bool pirEnabled, bool pirMotion) {
    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 6,
      child: ListTile(
        leading: Icon(
          Icons.motion_photos_on,
          color: pirMotion ? naranjaAndino : azulProfundo,
        ),
        title: Text('Sensor PIR', style: TextStyle(color: azulProfundo, fontWeight: FontWeight.bold)),
        subtitle: Text(
          'Habilitado: ${pirEnabled ? "Sí" : "No"}\n'
          'Movimiento: ${pirMotion ? "Detectado" : "No detectado"}',
          style: const TextStyle(height: 1.4),
        ),
        isThreeLine: true,
        trailing: Switch(
          value: pirEnabled,
          activeColor: naranjaAndino,
          onChanged: (v) => _setPirEnabled(v),
        ),
      ),
    );
  }

  Widget _buildAlarmCard(bool alarm) {
    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 6,
      child: ListTile(
        leading: Icon(Icons.alarm, color: alarm ? naranjaAndino : azulProfundo),
        title: Text('Alarma', style: TextStyle(color: azulProfundo, fontWeight: FontWeight.bold)),
        subtitle: Text('Estado: ${alarm ? "Encendida" : "Apagada"}'),
        trailing: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: naranjaAndino,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: _triggerAlarmTest,
          child: const Text('Probar'),
        ),
      ),
    );
  }

  Widget _buildTempCard(double? temperature) {
    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 6,
      child: ListTile(
        leading: Icon(Icons.thermostat, color: verdeQuillu),
        title: Text('Temperatura',
            style: TextStyle(color: azulProfundo, fontWeight: FontWeight.bold)),
        subtitle: Text(temperature != null
            ? '${temperature.toStringAsFixed(1)} °C'
            : 'Sin lectura'),
      ),
    );
  }

  Widget _buildEventsList() {
    return StreamBuilder<DatabaseEvent>(
      stream: _db.child('events/$deviceId').limitToLast(20).onValue,
      builder: (context, eventSnap) {
        if (!eventSnap.hasData || eventSnap.data?.snapshot.value == null) {
          return const Text('Sin eventos recientes.');
        }

        final Map eventsMap = eventSnap.data!.snapshot.value as Map<dynamic, dynamic>;
        final eventsList = eventsMap.entries.map((entry) {
          final ev = entry.value as Map;
          final ts = (ev['timestamp'] is int)
              ? ev['timestamp']
              : int.tryParse(ev['timestamp'].toString()) ?? 0;
          return {
            'type': ev['type'] ?? 'desconocido',
            'timestamp': ts,
          };
        }).toList();

        eventsList.sort((a, b) => b['timestamp'].compareTo(a['timestamp']));

        return Column(
          children: eventsList.take(10).map((ev) {
            return ListTile(
              leading: Icon(Icons.event, color: azulProfundo),
              title: Text(ev['type'].toString()),
              subtitle: Text(_formatTs(ev['timestamp'])),
            );
          }).toList(),
        );
      },
    );
  }
}
