import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/dashboard_viewmodel.dart';

// 🎨 Colores (mismo look que tenías)
const Color azulProfundo = Color(0xFF1E3A8A);
const Color naranjaAndino = Color(0xFFF59E0B);
const Color verdeQuillu = Color(0xFF4CAF50);
const Color beigeCalido = Color(0xFFF4EBD0);

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late final String deviceId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)!.settings.arguments;
    deviceId = (args is String) ? args : 'esp01';
  }

  @override
  Widget build(BuildContext context) {
    // Provider local para que el ViewModel tenga lifecycle ligado a esta page
    return ChangeNotifierProvider<DashboardViewModel>(
      create: (_) {
        final vm = DashboardViewModel(deviceId: deviceId);
        vm.init();
        return vm;
      },
      child: Consumer<DashboardViewModel>(
        builder: (context, vm, _) {
          return Scaffold(
            backgroundColor: beigeCalido,
            appBar: AppBar(
              title: const Text('Dashboards'),
              backgroundColor: azulProfundo,
              foregroundColor: Colors.white,
            ),
            body: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Builder(builder: (context) {
                if (vm.error != null) {
                  return Center(child: Text('Error: ${vm.error}'));
                }
                if (vm.isLoading && vm.docs.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = vm.docs;
                final temps = vm.temps;

                final lastMotionStr = vm.formatDateTime(vm.lastMotion);
                final lastAlarmStr = vm.formatDateTime(vm.lastAlarm);
                final lastSystemStr = vm.formatDateTime(vm.lastSystem);

                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _SummaryCard(
                            title: 'Movimientos (24h)',
                            value: vm.motions24h.toString(),
                            subtitle: 'Último: $lastMotionStr',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _SummaryCard(
                            title: 'Alarmas (24h)',
                            value: vm.alarms24h.toString(),
                            subtitle: 'Último: $lastAlarmStr',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _SummaryCard(
                            title: 'Sistema (cambios 24h)',
                            value: vm.systemChanges24h.toString(),
                            subtitle: 'Último: $lastSystemStr',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Card(
                      color: Colors.white,
                      elevation: 6,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Temperatura - últimas lecturas',
                                style: TextStyle(fontWeight: FontWeight.bold, color: azulProfundo)),
                            const SizedBox(height: 8),
                            SizedBox(
                              height: 180,
                              child: temps.isEmpty
                                  ? Center(
                                      child: Text('No hay datos de temperatura',
                                          style: TextStyle(color: azulProfundo.withOpacity(0.8))))
                                  : Center(child: Text('Sugerencia: dibujar gráfica con ${temps.length} muestras')),
                            ),
                            const SizedBox(height: 8),
                            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                              Text('Muestras: ${temps.length}', style: TextStyle(color: azulProfundo)),
                              if (temps.isNotEmpty) Text('Última: ${temps.last.toStringAsFixed(1)} °C',
                                  style: TextStyle(color: azulProfundo))
                            ]),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Align(alignment: Alignment.centerLeft, child: Text('Eventos recientes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView.builder(
                        itemCount: docs.length,
                        itemBuilder: (context, i) {
                          final d = docs[i];
                          final ts = DateTime.fromMillisecondsSinceEpoch(d['timestamp'] as int).toLocal();
                          final timeStr =
                              '${ts.year}-${ts.month.toString().padLeft(2, '0')}-${ts.day.toString().padLeft(2, '0')} ${ts.hour.toString().padLeft(2, '0')}:${ts.minute.toString().padLeft(2, '0')}';
                          final type = d['type'] as String;
                          final value = d['duration_s'] ?? '-';
                          return Card(
                            color: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            elevation: 2,
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            child: ListTile(
                              leading: Icon(_iconForType(type), color: _colorForType(type)),
                              title: Text(_labelForType(type), style: TextStyle(color: azulProfundo, fontWeight: FontWeight.w600)),
                              subtitle: Text('Dur: ${value.toString()} · $timeStr'),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              }),
            ),
          );
        },
      ),
    );
  }

  String _labelForType(String raw) {
    switch (raw) {
      case 'temperature':
        return 'Temperatura';
      case 'pir_motion':
      case 'pir_detec':
      case 'motion':
        return 'Movimiento detectado';
      case 'alarm':
      case 'alarm_test':
      case 'alarm_trigger':
        return 'Alarma activada';
      case 'system_armed':
        return 'Sistema armado';
      case 'system_disarmed':
        return 'Sistema desarmado';
      case 'pir_toggle':
        return 'Sensor PIR (toggle)';
      default:
        return raw.isEmpty ? 'Evento' : raw[0].toUpperCase() + raw.substring(1);
    }
  }

  IconData _iconForType(String? type) {
    switch (type) {
      case 'temperature':
        return Icons.thermostat;
      case 'pir_motion':
      case 'pir_detec':
      case 'motion':
        return Icons.motion_photos_on;
      case 'alarm_test':
      case 'alarm':
      case 'alarm_trigger':
        return Icons.alarm;
      case 'system_armed':
      case 'system_disarmed':
      case 'security_activated':
        return Icons.security;
      case 'pir_toggle':
        return Icons.toggle_on;
      default:
        return Icons.event;
    }
  }

  Color _colorForType(String? type) {
    switch (type) {
      case 'temperature':
        return verdeQuillu;
      case 'pir_motion':
      case 'pir_detec':
      case 'motion':
        return naranjaAndino;
      case 'alarm_test':
      case 'alarm':
      case 'alarm_trigger':
        return Colors.redAccent;
      default:
        return azulProfundo.withOpacity(0.8);
    }
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  const _SummaryCard({required this.title, required this.value, required this.subtitle, super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Text(title, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: azulProfundo)),
          const SizedBox(height: 4),
          Text(subtitle, textAlign: TextAlign.center, style: TextStyle(color: azulProfundo.withOpacity(0.8), fontSize: 12))
        ]),
      ),
    );
  }
}
