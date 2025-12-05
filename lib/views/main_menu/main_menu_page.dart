import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/main_menu_viewmodel.dart';
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
  late final MainMenuViewModel vm;

  @override
  void initState() {
    super.initState();
    // Se inicializa en build dentro del provider create, o si registraste globalmente,
    // obtén la instancia y llama vm.init() aquí.
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<MainMenuViewModel>(
      create: (_) {
        final m = MainMenuViewModel();
        m.init();
        return m;
      },
      child: Consumer<MainMenuViewModel>(
        builder: (context, vm, _) {
          // Loading inicial (detectando dispositivo)
          if (vm.loadingDeviceDetect) {
            return Scaffold(
              backgroundColor: beigeCalido,
              appBar: AppBar(
                  title: const Text('Menú Principal'),
                  backgroundColor: azulProfundo),
              body: const Center(child: CircularProgressIndicator()),
            );
          }

          // Error en detección
          if (vm.error != null) {
            return Scaffold(
              backgroundColor: beigeCalido,
              appBar: AppBar(
                title: const Text('Menú Principal'),
                backgroundColor: azulProfundo,
              ),
              body: Center(child: Text('Error: ${vm.error}')),
            );
          }

          // UI principal
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
                    if (vm.deviceId.isNotEmpty) {
                      Navigator.pushNamed(context, '/dashboard', arguments: vm.deviceId);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Aún no se detectó el dispositivo.')),
                      );
                    }
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.logout),
                  tooltip: 'Cerrar sesión',
                  onPressed: () async {
                    await vm.signOut();
                  },
                ),
              ],
            ),
            body: vm.deviceId.isEmpty
                ? const Center(child: Text('Buscando dispositivo vinculado...'))
                : StreamBuilder<DatabaseEvent>(
                    stream: vm.deviceStream,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Center(child: Text('Error: ${snapshot.error}'));
                      }

                      final deviceMap = snapshot.data?.snapshot.value as Map<dynamic, dynamic>?;

                      final bool pirEnabled = deviceMap?['pirEnabled'] == true;
                      final bool alarm = deviceMap?['alarm'] == true;
                      final double? temperature = (deviceMap != null && deviceMap['temperature'] is num)
                          ? (deviceMap['temperature'] as num).toDouble()
                          : null;

                      return Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: ListView(
                          children: [
                            // PIR
                            Card(
                              color: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              elevation: 6,
                              child: ListTile(
                                leading: Icon(Icons.motion_photos_on, color: pirEnabled ? naranjaAndino : azulProfundo),
                                title: Text('Sensor PIR', style: TextStyle(color: azulProfundo, fontWeight: FontWeight.bold)),
                                subtitle: Text('Habilitado: ${pirEnabled ? "Sí" : "No"}'),
                                trailing: Switch(
                                  value: pirEnabled,
                                  activeColor: naranjaAndino,
                                  onChanged: (v) async {
                                    try {
                                      await vm.setPirEnabled(v);
                                    } catch (e) {
                                      if (!mounted) return;
                                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error actualizando PIR: $e')));
                                    }
                                  },
                                ),
                              ),
                            ),

                            // Alarma
                            Card(
                              color: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              elevation: 6,
                              child: ListTile(
                                leading: Icon(Icons.alarm, color: alarm ? naranjaAndino : azulProfundo),
                                title: Text('Alarma', style: TextStyle(color: azulProfundo, fontWeight: FontWeight.bold)),
                                subtitle: Text('Estado: ${alarm ? "Encendida" : "Apagada"}'),
                                trailing: ElevatedButton(
                                  onPressed: () async {
                                    try {
                                      await vm.triggerAlarmTest();
                                    } catch (e) {
                                      if (!mounted) return;
                                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error activando alarma: $e')));
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(backgroundColor: naranjaAndino),
                                  child: const Text('Probar'),
                                ),
                              ),
                            ),

                            // Temperatura
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

                            // Lista de eventos: usamos el stream provisto por el VM
                            StreamBuilder<DatabaseEvent>(
                              stream: vm.eventsStream,
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
                                  final ts = vm.getEventTimestamp(ev);
                                  final label = vm.labelForType(ev['type']?.toString() ?? '');
                                  final value = ev['temp_c'] ?? ev['value'] ?? ev['temperature'] ?? '-';
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
                                    final dt = DateTime.fromMillisecondsSinceEpoch(ev['timestamp']).toLocal();
                                    final timestr =
                                        '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
                                    return Card(
                                      margin: const EdgeInsets.symmetric(vertical: 6),
                                      child: ListTile(
                                        leading: Icon(Icons.event, color: azulProfundo),
                                        title: Text(ev['label'], style: TextStyle(color: azulProfundo, fontWeight: FontWeight.w600)),
                                        subtitle: Text('${ev['value'] != null ? ev['value'].toString() + '\n' : ''}$timestr'),
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
        },
      ),
    );
  }
}
