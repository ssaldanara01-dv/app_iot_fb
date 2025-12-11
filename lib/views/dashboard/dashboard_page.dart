import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/dashboard_viewmodel.dart';
import 'package:app_iot_db/theme/app_colors.dart';
import 'package:fl_chart/fl_chart.dart';

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
            backgroundColor: AppColors.beigeCalido,
            appBar: AppBar(
              title: const Text('Dashboards'),
              backgroundColor: AppColors.azulProfundo,
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
                                style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.azulProfundo)),
                            const SizedBox(height: 8),
                            SizedBox(
                              height: 180,
                              child: temps.isEmpty
                                  ? Center(
                                      child: Text('No hay datos de temperatura',
                                          style: TextStyle(color: AppColors.azulProfundo.withOpacity(0.8))))
                                  : _TemperatureBarChart(temperatures: temps),
                            ),
                            const SizedBox(height: 8),
                            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                              Text('Muestras: ${temps.length}', style: TextStyle(color: AppColors.azulProfundo)),
                              if (temps.isNotEmpty) Text('Última: ${temps.last.toStringAsFixed(1)} °C',
                                  style: TextStyle(color: AppColors.azulProfundo))
                            ]),
                          ],
                        ),
                      ),
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
                            Text('Distribución de eventos',
                                style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.azulProfundo)),
                            const SizedBox(height: 8),
                            SizedBox(
                              height: 100,
                              child: vm.eventTypeCount.isEmpty
                                  ? Center(
                                      child: Text('Sin eventos',
                                          style: TextStyle(color: AppColors.azulProfundo.withOpacity(0.8))))
                                  : _EventDistributionPieChart(eventTypeCount: vm.eventTypeCount),
                            ),
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
                          final ts = DateTime.fromMillisecondsSinceEpoch(d['timestamp'] as int, isUtc: true).subtract(const Duration(hours: 5));
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
                              title: Text(_labelForType(type), style: TextStyle(color: AppColors.azulProfundo, fontWeight: FontWeight.w600)),
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
        return AppColors.verdeQuillu;
      case 'pir_motion':
      case 'pir_detec':
      case 'motion':
        return AppColors.naranjaAndino;
      case 'alarm_test':
      case 'alarm':
      case 'alarm_trigger':
        return Colors.redAccent;
      default:
        return AppColors.azulProfundo.withOpacity(0.8);
    }
  }
}

class _TemperatureBarChart extends StatelessWidget {
  final List<double> temperatures;

  const _TemperatureBarChart({required this.temperatures});

  @override
  Widget build(BuildContext context) {
    if (temperatures.isEmpty) {
      return const Center(child: Text('Sin datos'));
    }

    // Limitar a los últimos 30 datos para mejor visualización
    final displayTemps = temperatures.length > 30
        ? temperatures.sublist(temperatures.length - 30)
        : temperatures;

    // Encontrar min y max para escala
    final minTemp = displayTemps.reduce((a, b) => a < b ? a : b);
    final maxTemp = displayTemps.reduce((a, b) => a > b ? a : b);
    final padding = (maxTemp - minTemp) * 0.1;
    final minY = ((minTemp - padding).clamp(0.0, double.infinity)) as double;
    final maxY = maxTemp + padding;

    return BarChart(
      BarChartData(
        maxY: maxY,
        minY: minY,
        barGroups: List.generate(
          displayTemps.length,
          (index) => BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: displayTemps[index],
                color: AppColors.verdeQuillu,
                width: 6,
              ),
            ],
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index % (displayTemps.length > 10 ? displayTemps.length ~/ 5 : 1) == 0 && index < displayTemps.length) {
                  return Text(
                    index.toString(),
                    style: const TextStyle(fontSize: 8),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                return Text(
                  '${value.toStringAsFixed(0)}°',
                  style: const TextStyle(fontSize: 9),
                );
              },
              reservedSize: 35,
            ),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: (maxY - minY) / 4,
        ),
        borderData: FlBorderData(show: false),
      ),
    );
  }
}

class _EventDistributionPieChart extends StatelessWidget {
  final Map<String, int> eventTypeCount;

  const _EventDistributionPieChart({required this.eventTypeCount});

  @override
  Widget build(BuildContext context) {
    if (eventTypeCount.isEmpty) {
      return const Center(child: Text('Sin datos'));
    }

    final colors = {
      'Movimiento': AppColors.naranjaAndino,
      'Alarma': Colors.redAccent,
      'Sistema': AppColors.azulProfundo,
      'Temperatura': AppColors.verdeQuillu,
      'Otro': Colors.grey,
    };

    final total = eventTypeCount.values.fold<int>(0, (a, b) => a + b);

    return SingleChildScrollView(
      child: Column(
        children: eventTypeCount.entries
            .map((entry) {
              final percentage = ((entry.value / total) * 100).toStringAsFixed(1);
              return Padding(
                padding: const EdgeInsets.only(bottom: 6.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: colors[entry.key] ?? Colors.grey,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              entry.key,
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        Text(
                          '${entry.value} ($percentage%)',
                          style: const TextStyle(fontSize: 10),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: entry.value / total,
                        minHeight: 12,
                        backgroundColor: Colors.grey.shade300,
                        valueColor: AlwaysStoppedAnimation(
                          colors[entry.key] ?? Colors.grey,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            })
            .toList(),
      ),
    );
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
          Text(value, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.azulProfundo)),
          const SizedBox(height: 4),
          Text(subtitle, textAlign: TextAlign.center, style: TextStyle(color: AppColors.azulProfundo.withOpacity(0.8), fontSize: 12))
        ]),
      ),
    );
  }
}
