import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MainMenuPage extends StatefulWidget {
  const MainMenuPage({super.key});
  @override
  State<MainMenuPage> createState() => _MainMenuPageState();
}

class _MainMenuPageState extends State<MainMenuPage> {
  final FirebaseFirestore _fs = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  // Paleta YanaGuard 🎨
  final Color azulProfundo = const Color(0xFF1E3A8A);
  final Color naranjaAndino = const Color(0xFFF59E0B);
  final Color verdeQuillu = const Color(0xFF4CAF50);
  final Color beigeCalido = const Color(0xFFF4EBD0);
  final Color azulNoche = const Color(0xFF0F172A);

  // ID del dispositivo IoT
  final String deviceId = 'esp01';

  DocumentReference<Map<String, dynamic>> get deviceRef =>
      _fs.collection('devices').doc(deviceId);

  Future<void> _setPirEnabled(bool enabled) async {
    await deviceRef.set({'pirEnabled': enabled}, SetOptions(merge: true));
    await deviceRef.collection('events').add({
      'type': 'pir_toggle',
      'value': enabled,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _triggerAlarmTest() async {
    await deviceRef.set({'alarm': true}, SetOptions(merge: true));
    await deviceRef.collection('events').add({
      'type': 'alarm_test',
      'timestamp': FieldValue.serverTimestamp(),
    });
    Future.delayed(const Duration(seconds: 3), () {
      deviceRef.set({'alarm': false}, SetOptions(merge: true));
    });
  }

  Future<void> _signOut() => _auth.signOut();

  String _formatTs(Timestamp? ts) {
    if (ts == null) return 'Nunca';
    final dt = ts.toDate().toLocal();
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
            icon: const Icon(Icons.dashboard_outlined),
            tooltip: 'Ver Dashboard',
            onPressed: () => Navigator.pushNamed(context, '/dashboard'),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar sesión',
            onPressed: () async {
              await _signOut();
            },
          )
        ],
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: deviceRef.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data!.data() ?? {};
          final pirEnabled = data['pirEnabled'] as bool? ?? false;
          final pirMotion = data['pirMotion'] as bool? ?? false;
          final alarm = data['alarm'] as bool? ?? false;
          final temperature = (data['temperature'] as num?)?.toDouble();
          final lastMotion = data['lastMotion'] as Timestamp?;
          final lastAlarm = data['lastAlarm'] as Timestamp?;
          final lastTempHigh = data['lastTempHigh'] as Timestamp?;

          return Padding(
            padding: const EdgeInsets.all(12.0),
            child: ListView(
              children: [
                // Sensor PIR
                Card(
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 6,
                  child: ListTile(
                    leading: Icon(Icons.motion_photos_on,
                        color: pirMotion ? naranjaAndino : azulProfundo),
                    title: Text('Sensor PIR',
                        style: TextStyle(
                            color: azulProfundo,
                            fontWeight: FontWeight.bold)),
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
                ),

                // Alarma
                Card(
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  elevation: 6,
                  child: ListTile(
                    leading: Icon(Icons.alarm,
                        color: alarm ? naranjaAndino : azulProfundo),
                    title: Text('Alarma',
                        style: TextStyle(
                            color: azulProfundo,
                            fontWeight: FontWeight.bold)),
                    subtitle:
                        Text('Estado: ${alarm ? "Encendida" : "Apagada"}'),
                    trailing: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: naranjaAndino,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Probar'),
                      onPressed: _triggerAlarmTest,
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
                    leading: Icon(Icons.thermostat, color: verdeQuillu),
                    title: Text('Temperatura',
                        style: TextStyle(
                            color: azulProfundo,
                            fontWeight: FontWeight.bold)),
                    subtitle: Text(
                      temperature != null
                          ? '${temperature.toStringAsFixed(1)} °C'
                          : 'Sin lectura',
                    ),
                    trailing: IconButton(
                      icon: Icon(Icons.refresh, color: azulProfundo),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Refrescando datos...')),
                        );
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 12),
                Text('Últimos eventos',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: azulProfundo)),
                const SizedBox(height: 6),

                ListTile(
                  leading: Icon(Icons.motion_photos_on, color: naranjaAndino),
                  title: const Text('Último movimiento'),
                  subtitle: Text(_formatTs(lastMotion)),
                ),
                ListTile(
                  leading: Icon(Icons.alarm, color: naranjaAndino),
                  title: const Text('Última alarma'),
                  subtitle: Text(_formatTs(lastAlarm)),
                ),
                ListTile(
                  leading: Icon(Icons.thermostat, color: verdeQuillu),
                  title: const Text('Última temperatura alta'),
                  subtitle: Text(_formatTs(lastTempHigh)),
                ),

                const SizedBox(height: 12),
                Card(
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 6,
                  child: ListTile(
                    leading: Icon(Icons.history, color: azulProfundo),
                    title: const Text('Historial reciente'),
                    subtitle:
                        const Text('Ver los últimos 20 eventos registrados'),
                    trailing: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: azulProfundo,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Ver'),
                      onPressed: () {
                        Navigator.pushNamed(context, '/dashboard');
                      },
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
