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

  // Ajusta este deviceId al ID que uses en tu ESP
  final String deviceId = 'esp01';

  DocumentReference<Map<String, dynamic>> get deviceRef =>
      _fs.collection('devices').doc(deviceId);

  Future<void> _setPirEnabled(bool enabled) async {
    await deviceRef.set({'pirEnabled': enabled}, SetOptions(merge: true));
    // Optionally write event
    await deviceRef.collection('events').add({
      'type': 'pir_toggle',
      'value': enabled,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _triggerAlarmTest() async {
    // We do a temporary toggle for alarm test; ESP listens to 'alarm' field
    await deviceRef.set({'alarm': true}, SetOptions(merge: true));
    await deviceRef.collection('events').add({
      'type': 'alarm_test',
      'timestamp': FieldValue.serverTimestamp(),
    });
    // It's common for device to auto-reset 'alarm' or you can do after delay:
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
      appBar: AppBar(
        title: const Text('Menú - Proyecto IoT'),
        actions: [
          IconButton(
            icon: const Icon(Icons.dashboard),
            onPressed: () => Navigator.pushNamed(context, '/dashboard'),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
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
                Card(
                  child: ListTile(
                    title: const Text('Sensor PIR'),
                    subtitle:
                        Text('Habilitado: ${pirEnabled ? "Sí" : "No"}\n'
                            'Movimiento: ${pirMotion ? "Detectado" : "No detectado"}'),
                    isThreeLine: true,
                    trailing: Switch(
                      value: pirEnabled,
                      onChanged: (v) => _setPirEnabled(v),
                    ),
                  ),
                ),
                Card(
                  child: ListTile(
                    title: const Text('Alarma'),
                    subtitle: Text('Estado: ${alarm ? "Encendida" : "Apagada"}'),
                    trailing: ElevatedButton(
                      child: const Text('Probar alarma'),
                      onPressed: _triggerAlarmTest,
                    ),
                  ),
                ),
                Card(
                  child: ListTile(
                    title: const Text('Temperatura'),
                    subtitle: Text(temperature != null
                        ? '${temperature.toStringAsFixed(1)} °C'
                        : 'Sin lectura'),
                    trailing: IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: () {
                        // Forzar refresh: set local timestamp? Usually snapshot updates automatically
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Refrescando...')),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Text('Últimos eventos', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                ListTile(
                  leading: const Icon(Icons.motion_photos_on),
                  title: const Text('Último movimiento'),
                  subtitle: Text(_formatTs(lastMotion)),
                ),
                ListTile(
                  leading: const Icon(Icons.alarm),
                  title: const Text('Última alarma'),
                  subtitle: Text(_formatTs(lastAlarm)),
                ),
                ListTile(
                  leading: const Icon(Icons.thermostat),
                  title: const Text('Última temperatura alta'),
                  subtitle: Text(_formatTs(lastTempHigh)),
                ),
                const SizedBox(height: 12),
                Card(
                  child: ListTile(
                    title: const Text('Historial reciente'),
                    subtitle: const Text('Ver eventos registrados (últimas 20)'),
                    trailing: ElevatedButton(
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
