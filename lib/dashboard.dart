// dashboard.dart
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

const Color azulProfundo = Color(0xFF1E3A8A);
const Color naranjaAndino = Color(0xFFF59E0B);
const Color verdeQuillu = Color(0xFF4CAF50);
const Color beigeCalido = Color(0xFFF4EBD0);

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  int _getEventTimestamp(Map ev) {
    final t = ev['timestamp'];
    if (t is int) return t;
    if (t is num) return t.toInt();

    final s = (ev['startTime'] ?? ev['endTime'] ?? ev['createdAt'])?.toString();
    if (s != null) {
      try {
        return DateTime.parse(s).millisecondsSinceEpoch;
      } catch (_) {
        try {
          final cleaned = s.replaceAll('"', '');
          final dt2 = DateTime.tryParse(cleaned);
          if (dt2 != null) return dt2.millisecondsSinceEpoch;
        } catch (_) {}
      }
    }
    return DateTime.now().millisecondsSinceEpoch;
  }

  String _formatDateTime(DateTime? dt) {
    if (dt == null) return 'Nunca';
    final local = dt.toLocal();
    return '${local.year.toString().padLeft(4, '0')}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)!.settings.arguments;
    final deviceId = (args is String) ? args : 'esp01';

    final db = FirebaseDatabase.instance.ref();

    return Scaffold(
      backgroundColor: beigeCalido,
      appBar: AppBar(
        title: const Text('Dashboards'),
        backgroundColor: azulProfundo,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: StreamBuilder<DatabaseEvent>(
          stream: db.child('events/$deviceId').limitToLast(500).onValue,
          builder: (context, snap) {
            if (snap.hasError) {
              return Center(child: Text('Error: ${snap.error}'));
            }
            if (!snap.hasData || snap.data!.snapshot.value == null) {
              return const Center(child: CircularProgressIndicator());
            }

            final Map eventsMap = snap.data!.snapshot.value as Map<dynamic, dynamic>;
            final docs = <Map<String, dynamic>>[];
            for (final entry in eventsMap.entries) {
              final ev = Map<String, dynamic>.from(entry.value as Map);
              final ts = _getEventTimestamp(ev);
              docs.add({
                'type': (ev['type'] ?? 'evento').toString(),
                'timestamp': ts,
                'temp': (ev['temp_c'] is num) ? (ev['temp_c'] as num).toDouble() : (ev['value'] is num ? (ev['value'] as num).toDouble() : null),
                'duration_s': ev['duration_s'],
              });
            }
            // order descending
            docs.sort((a, b) => b['timestamp'].compareTo(a['timestamp']));

            final now = DateTime.now().toUtc();
            final boundary24h = now.subtract(const Duration(hours: 24)).millisecondsSinceEpoch;

            int motions24h = 0;
            int alarms24h = 0;
            int systemChanges24h = 0;
            DateTime? lastMotion;
            DateTime? lastAlarm;
            DateTime? lastSystem;
            final temps = <double>[];

            for (final d in docs) {
              final type = d['type'] as String;
              final ts = d['timestamp'] as int;
              if (type == 'motion' || type == 'pir_motion' || type.contains('pir')) {
                if (ts >= boundary24h) motions24h++;
                if (lastMotion == null) lastMotion = DateTime.fromMillisecondsSinceEpoch(ts);
              } else if (type == 'alarm' || type == 'alarm_test' || type == 'alarm_trigger') {
                if (ts >= boundary24h) alarms24h++;
                if (lastAlarm == null) lastAlarm = DateTime.fromMillisecondsSinceEpoch(ts);
              } else if (type == 'pir_toggle' || type.startsWith('system') || type.startsWith('security')) {
                if (ts >= boundary24h) systemChanges24h++;
                if (lastSystem == null) lastSystem = DateTime.fromMillisecondsSinceEpoch(ts);
              }

              if (d['temp'] != null) {
                temps.add(d['temp'] as double);
              }
            }

            final lastMotionStr = _formatDateTime(lastMotion);
            final lastAlarmStr = _formatDateTime(lastAlarm);
            final lastSystemStr = _formatDateTime(lastSystem);

            return Column(
              children: [
                Row(
                  children: [
                    Expanded(child: _SummaryCard(title: 'Movimientos (24h)', value: motions24h.toString(), subtitle: 'Último: $lastMotionStr')),
                    const SizedBox(width: 8),
                    Expanded(child: _SummaryCard(title: 'Alarmas (24h)', value: alarms24h.toString(), subtitle: 'Último: $lastAlarmStr')),
                    const SizedBox(width: 8),
                    Expanded(child: _SummaryCard(title: 'Sistema (cambios 24h)', value: systemChanges24h.toString(), subtitle: 'Último: $lastSystemStr')),
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
                        Text('Temperatura - últimas lecturas', style: TextStyle(fontWeight: FontWeight.bold, color: azulProfundo)),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 180,
                          child: temps.isEmpty
                              ? Center(child: Text('No hay datos de temperatura', style: TextStyle(color: azulProfundo.withOpacity(0.8))))
                              : Center(child: Text('Sugerencia: dibujar gráfica con ${temps.length} muestras')),
                        ),
                        const SizedBox(height: 8),
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Muestras: ${temps.length}', style: TextStyle(color: azulProfundo)), if (temps.isNotEmpty) Text('Última: ${temps.last.toStringAsFixed(1)} °C', style: TextStyle(color: azulProfundo))]),
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
                      final timeStr = '${ts.year}-${ts.month.toString().padLeft(2,'0')}-${ts.day.toString().padLeft(2,'0')} ${ts.hour.toString().padLeft(2,'0')}:${ts.minute.toString().padLeft(2,'0')}';
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
          },
        ),
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
      child: Padding(padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10), child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [Text(title, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)), const SizedBox(height: 8), Text(value, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: azulProfundo)), const SizedBox(height: 4), Text(subtitle, textAlign: TextAlign.center, style: TextStyle(color: azulProfundo.withOpacity(0.8), fontSize: 12))])),
    );
  }
}
