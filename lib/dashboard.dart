import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Paleta YanaGuard (valores reutilizables)
const Color azulProfundo = Color(0xFF1E3A8A);
const Color naranjaAndino = Color(0xFFF59E0B);
const Color verdeQuillu = Color(0xFF4CAF50);
const Color beigeCalido = Color(0xFFF4EBD0);
const Color azulNoche = Color(0xFF0F172A);

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});
  final String deviceId = 'esp01';

  Stream<QuerySnapshot<Map<String, dynamic>>> _eventsStream() {
    return FirebaseFirestore.instance
        .collection('devices')
        .doc(deviceId)
        .collection('events')
        .orderBy('timestamp', descending: true)
        .limit(500)
        .snapshots();
  }

  List<double> _extractTemps(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs, {int max = 40}) {
    final temps = <double>[];
    for (var d in docs) {
      final data = d.data();
      if (data['type'] == 'temperature') {
        final v = data['value'];
        if (v is num) temps.add(v.toDouble());
      }
      if (temps.length >= max) break;
    }
    return temps.reversed.toList();
  }

  DateTime? _lastEventTimeOfTypes(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs, List<String> types) {
    for (var d in docs) {
      final t = d.data()['type']?.toString();
      if (t != null && types.contains(t)) {
        final ts = (d.data()['timestamp'] as Timestamp?);
        if (ts != null) return ts.toDate();
      }
    }
    return null;
  }

  int _countEventsInLastHours(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs, List<String> types, {int hours = 24}) {
    final boundary = DateTime.now().toUtc().subtract(Duration(hours: hours));
    int count = 0;
    for (var d in docs) {
      final t = d.data()['type']?.toString();
      if (t == null) continue;
      if (!types.contains(t)) continue;
      final ts = (d.data()['timestamp'] as Timestamp?);
      if (ts == null) continue;
      if (ts.toDate().toUtc().isAfter(boundary)) count++;
    }
    return count;
  }

  String _formatDateTime(DateTime? dt) {
    if (dt == null) return 'Nunca';
    final local = dt.toLocal();
    return '${local.year.toString().padLeft(4, '0')}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} '
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: beigeCalido,
      appBar: AppBar(
        title: const Text('Dashboards'),
        backgroundColor: azulProfundo,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _eventsStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;
          final temps = _extractTemps(docs);

          final motionTypes = ['pir_motion', 'pir_detec', 'motion'];
          final alarmTypes = ['alarm', 'alarm_test', 'alarm_trigger'];
          final systemTypes = ['system_armed', 'system_disarmed', 'security_activated', 'security_deactivated', 'pir_toggle'];

          final lastMotion = _lastEventTimeOfTypes(docs, motionTypes);
          final lastAlarm = _lastEventTimeOfTypes(docs, alarmTypes);
          final lastSystem = _lastEventTimeOfTypes(docs, systemTypes);

          final motions24h = _countEventsInLastHours(docs, motionTypes, hours: 24);
          final alarms24h = _countEventsInLastHours(docs, alarmTypes, hours: 24);
          final systemChanges24h = _countEventsInLastHours(docs, systemTypes, hours: 24);

          return Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              children: [
                // resumen superior
                Row(
                  children: [
                    Expanded(
                      child: _SummaryCard(
                        title: 'Movimientos (24h)',
                        value: motions24h.toString(),
                        subtitle: 'Último: ${_formatDateTime(lastMotion)}',
                        icon: Icons.motion_photos_on,
                        iconColor: naranjaAndino,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _SummaryCard(
                        title: 'Alarmas (24h)',
                        value: alarms24h.toString(),
                        subtitle: 'Último: ${_formatDateTime(lastAlarm)}',
                        icon: Icons.alarm,
                        iconColor: Colors.redAccent,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _SummaryCard(
                        title: 'Sistema (cambios 24h)',
                        value: systemChanges24h.toString(),
                        subtitle: 'Último: ${_formatDateTime(lastSystem)}',
                        icon: Icons.security,
                        iconColor: azulProfundo,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Card temperatura
                Card(
                  color: Colors.white,
                  elevation: 6,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Temperatura - últimas lecturas',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: azulProfundo,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 180,
                          child: temps.isEmpty
                              ? Center(
                                  child: Text(
                                    'No hay datos de temperatura',
                                    style: TextStyle(color: azulProfundo.withOpacity(0.8)),
                                  ),
                                )
                              : TemperatureChart(
                                  temps: temps,
                                  lineColor: azulProfundo,
                                  fillColor: azulProfundo.withOpacity(0.12),
                                  gridColor: azulProfundo.withOpacity(0.18),
                                  labelColor: azulProfundo,
                                ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Muestras: ${temps.length}', style: TextStyle(color: azulProfundo)),
                            if (temps.isNotEmpty) Text('Última: ${temps.last.toStringAsFixed(1)} °C', style: TextStyle(color: azulProfundo)),
                          ],
                        )
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Eventos recientes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 8),

                Expanded(
                  child: ListView.builder(
                    itemCount: docs.length,
                    itemBuilder: (context, i) {
                      final d = docs[i].data();
                      final ts = (d['timestamp'] as Timestamp?)?.toDate();
                      final timeStr = ts == null ? '—' : '${ts.toLocal()}';
                      final rawType = d['type']?.toString() ?? 'evento';
                      final label = _labelForType(rawType);
                      final value = d['value'] ?? '-';
                      return Card(
                        color: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 2,
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        child: ListTile(
                          leading: Icon(_iconForType(rawType), color: _colorForType(rawType)),
                          title: Text(label, style: TextStyle(color: azulProfundo, fontWeight: FontWeight.w600)),
                          subtitle: Text('$value\n$timeStr'),
                          isThreeLine: true,
                        ),
                      );
                    },
                  ),
                ),
              ],
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
      case 'system_armed':
      case 'system_disarmed':
      case 'security_activated':
        return azulProfundo;
      case 'pir_toggle':
        return azulProfundo;
      default:
        return azulProfundo.withOpacity(0.8);
    }
  }
}

/// Widget de resumen (tarjeta pequeña usada arriba)
class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color iconColor;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.all(8),
                  child: Icon(icon, color: iconColor),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600))),
              ],
            ),
            const SizedBox(height: 12),
            Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: azulProfundo)),
            const SizedBox(height: 6),
            Text(subtitle, style: TextStyle(color: azulProfundo.withOpacity(0.8))),
          ],
        ),
      ),
    );
  }
}

/// Temperature chart (unchanged)
class TemperatureChart extends StatelessWidget {
  final List<double> temps;
  final Color lineColor;
  final Color fillColor;
  final Color gridColor;
  final Color labelColor;

  const TemperatureChart({
    super.key,
    required this.temps,
    required this.lineColor,
    required this.fillColor,
    required this.gridColor,
    required this.labelColor,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.infinite,
      painter: _TemperaturePainter(
        temps,
        lineColor: lineColor,
        fillColor: fillColor,
        gridColor: gridColor,
        labelColor: labelColor,
      ),
    );
  }
}

class _TemperaturePainter extends CustomPainter {
  final List<double> temps;
  final Color lineColor;
  final Color fillColor;
  final Color gridColor;
  final Color labelColor;

  _TemperaturePainter(
    this.temps, {
    required this.lineColor,
    required this.fillColor,
    required this.gridColor,
    required this.labelColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paintGrid = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6
      ..color = gridColor;

    final paintLine = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = lineColor;

    final paintFill = Paint()
      ..style = PaintingStyle.fill
      ..strokeWidth = 0.5
      ..color = fillColor;

    final padding = 8.0;
    final w = size.width - padding * 2;
    final h = size.height - padding * 2;

    if (temps.isEmpty) {
      final tp = TextPainter(
          text: TextSpan(text: 'Sin datos', style: TextStyle(color: labelColor.withOpacity(0.7))),
          textDirection: TextDirection.ltr);
      tp.layout();
      tp.paint(canvas, Offset((size.width - tp.width) / 2, (size.height - tp.height) / 2));
      return;
    }

    double minY = temps.reduce((a, b) => a < b ? a : b);
    double maxY = temps.reduce((a, b) => a > b ? a : b);
    if (minY == maxY) {
      minY -= 1;
      maxY += 1;
    }

    for (int i = 0; i <= 4; i++) {
      final y = padding + (h / 4) * i;
      canvas.drawLine(Offset(padding, y), Offset(padding + w, y), paintGrid);
    }

    final stepX = w / (temps.length - 1 == 0 ? 1 : (temps.length - 1));
    final points = <Offset>[];
    for (int i = 0; i < temps.length; i++) {
      final x = padding + stepX * i;
      final t = temps[i];
      final normalized = (t - minY) / (maxY - minY);
      final y = padding + h - (normalized * h);
      points.add(Offset(x, y));
    }

    final path = Path();
    path.moveTo(points.first.dx, size.height - padding);
    for (final p in points) path.lineTo(p.dx, p.dy);
    path.lineTo(points.last.dx, size.height - padding);
    path.close();

    canvas.drawPath(path, paintFill);

    final pathLine = Path();
    pathLine.moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      pathLine.lineTo(points[i].dx, points[i].dy);
    }
    canvas.drawPath(pathLine, paintLine);

    final last = temps.last;
    final lastP = points.last;
    final tp = TextPainter(
      text: TextSpan(
        text: '${last.toStringAsFixed(1)}°C',
        style: TextStyle(fontSize: 12, color: labelColor, fontWeight: FontWeight.w600),
      ),
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    final labelOffset = Offset(
      (lastP.dx - tp.width - 4).clamp(padding, size.width - tp.width - padding),
      (lastP.dy - tp.height - 6).clamp(padding, size.height - tp.height - padding),
    );
    tp.paint(canvas, labelOffset);
  }

  @override
  bool shouldRepaint(covariant _TemperaturePainter oldDelegate) {
    return oldDelegate.temps != temps ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.fillColor != fillColor ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.labelColor != labelColor;
  }
}
