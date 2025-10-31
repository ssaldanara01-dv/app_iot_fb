import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

/// Paleta YanaGuard (valores reutilizables)
const Color azulProfundo = Color(0xFF1E3A8A);
const Color naranjaAndino = Color(0xFFF59E0B);
const Color verdeQuillu = Color(0xFF4CAF50);
const Color beigeCalido = Color(0xFFF4EBD0);
const Color azulNoche = Color(0xFF0F172A);

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});
  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late final DatabaseReference _db;
  String deviceId = 'esp01'; // valor por defecto si no vienen args

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is String && args.isNotEmpty) deviceId = args;
    _db = FirebaseDatabase.instance.ref();
  }

  // Helper: get events stream (limitToLast 500)
  Stream<DatabaseEvent> _eventsStream() {
    return _db
        .child('events')
        .child(deviceId)
        .orderByChild('timestamp')
        .limitToLast(500)
        .onValue;
  }

  // Parse events map -> list of maps ordered desc by timestamp
  List<Map<String, dynamic>> _eventsFromSnapshot(DatabaseEvent? ev) {
    if (ev == null) return [];
    final snap = ev.snapshot;
    if (!snap.exists || snap.value == null) return [];
    final raw = snap.value as Map<dynamic, dynamic>;
    final List<Map<String, dynamic>> items = [];
    raw.forEach((k, v) {
      final m = Map<String, dynamic>.from(v as Map);
      m['_key'] = k;
      // normalize timestamp to int ms
      final t = m['timestamp'];
      int ts = 0;
      if (t is int)
        ts = t;
      else if (t is num)
        ts = (t as num).toInt();
      else if (t is String)
        ts = int.tryParse(t) ?? 0;
      m['_ts'] = ts;
      items.add(m);
    });
    // sort descending
    items.sort((a, b) => (b['_ts'] as int).compareTo(a['_ts'] as int));
    return items;
  }

  // Extract temps (last N) in chronological order (old->new)
  List<double> _extractTempsFromEvents(
    List<Map<String, dynamic>> events, {
    int max = 40,
  }) {
    final temps = <double>[];
    for (final e in events) {
      final type = (e['type'] ?? '').toString();
      if (type == 'temperature' || type == 'temp' || type == 'temp_high') {
        final dyn = e['temp_c'] ?? e['value'] ?? e['temperature'];
        double? v;
        if (dyn is num)
          v = dyn.toDouble();
        else if (dyn is String)
          v = double.tryParse(dyn);
        if (v != null) temps.add(v);
        if (temps.length >= max) break;
      }
    }
    // currently events list is desc; we want chronological for chart -> reverse
    return temps.reversed.toList();
  }

  DateTime? _lastEventTimeOfTypes(
    List<Map<String, dynamic>> events,
    List<String> types,
  ) {
    for (final e in events) {
      final t = (e['type'] ?? '').toString();
      if (types.contains(t)) {
        final ts = e['_ts'] as int?;
        if (ts != null && ts > 0)
          return DateTime.fromMillisecondsSinceEpoch(ts).toLocal();
      }
    }
    return null;
  }

  int _countEventsInLastHours(
    List<Map<String, dynamic>> events,
    List<String> types, {
    int hours = 24,
  }) {
    final boundary = DateTime.now()
        .toUtc()
        .subtract(Duration(hours: hours))
        .millisecondsSinceEpoch;
    int cnt = 0;
    for (final e in events) {
      final t = (e['type'] ?? '').toString();
      if (!types.contains(t)) continue;
      final ts = e['_ts'] as int? ?? 0;
      if (ts > 0 && ts >= boundary) cnt++;
    }
    return cnt;
  }

  String _formatDateTime(DateTime? dt) {
    if (dt == null) return 'Nunca';
    final local = dt.toLocal();
    return '${local.year.toString().padLeft(4, '0')}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} '
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: beigeCalido,
      appBar: AppBar(
        title: const Text('Dashboards'),
        backgroundColor: azulProfundo,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<DatabaseEvent>(
        stream: _eventsStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final events = _eventsFromSnapshot(snapshot.data);
          final temps = _extractTempsFromEvents(events);

          final motionTypes = ['pir_motion', 'pir_detec', 'motion'];
          final alarmTypes = ['alarm', 'alarm_test', 'alarm_trigger'];
          final systemTypes = [
            'system_armed',
            'system_disarmed',
            'security_activated',
            'pir_toggle',
          ];

          final lastMotion = _lastEventTimeOfTypes(events, motionTypes);
          final lastAlarm = _lastEventTimeOfTypes(events, alarmTypes);
          final lastSystem = _lastEventTimeOfTypes(events, systemTypes);

          final motions24h = _countEventsInLastHours(
            events,
            motionTypes,
            hours: 24,
          );
          final alarms24h = _countEventsInLastHours(
            events,
            alarmTypes,
            hours: 24,
          );
          final systemChanges24h = _countEventsInLastHours(
            events,
            systemTypes,
            hours: 24,
          );

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
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _SummaryCard(
                        title: 'Alarmas (24h)',
                        value: alarms24h.toString(),
                        subtitle: 'Último: ${_formatDateTime(lastAlarm)}',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _SummaryCard(
                        title: 'Sistema (cambios 24h)',
                        value: systemChanges24h.toString(),
                        subtitle: 'Último: ${_formatDateTime(lastSystem)}',
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Card temperatura
                Card(
                  color: Colors.white,
                  elevation: 6,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
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
                                    style: TextStyle(
                                      color: azulProfundo.withOpacity(0.8),
                                    ),
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
                            Text(
                              'Muestras: ${temps.length}',
                              style: TextStyle(color: azulProfundo),
                            ),
                            if (temps.isNotEmpty)
                              Text(
                                'Última: ${temps.last.toStringAsFixed(1)} °C',
                                style: TextStyle(color: azulProfundo),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Eventos recientes',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 8),

                Expanded(
                  child: ListView.builder(
                    itemCount: events.length,
                    itemBuilder: (context, i) {
                      final d = events[i];
                      final ts =
                          (d['_ts'] as int?) == null || (d['_ts'] as int) == 0
                          ? null
                          : DateTime.fromMillisecondsSinceEpoch(
                              d['_ts'] as int,
                            ).toLocal();
                      final timeStr = ts == null ? '—' : '${ts.toLocal()}';
                      final rawType = d['type']?.toString() ?? 'evento';
                      final label = _labelForType(rawType);
                      final value = d['value'] ?? d['temp_c'] ?? '-';
                      return Card(
                        color: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 2,
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        child: ListTile(
                          leading: Icon(
                            _iconForType(rawType),
                            color: _colorForType(rawType),
                          ),
                          title: Text(
                            label,
                            style: TextStyle(
                              color: azulProfundo,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
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
}

/// Widget de resumen (tarjeta pequeña usada arriba, sin íconos)
class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.subtitle,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: azulProfundo,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: azulProfundo.withOpacity(0.8),
                fontSize: 12,
              ),
            ),
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
        text: TextSpan(
          text: 'Sin datos',
          style: TextStyle(color: labelColor.withOpacity(0.7)),
        ),
        textDirection: TextDirection.ltr,
      );
      tp.layout();
      tp.paint(
        canvas,
        Offset((size.width - tp.width) / 2, (size.height - tp.height) / 2),
      );
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
        style: TextStyle(
          fontSize: 12,
          color: labelColor,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    final labelOffset = Offset(
      (lastP.dx - tp.width - 4).clamp(padding, size.width - tp.width - padding),
      (lastP.dy - tp.height - 6).clamp(
        padding,
        size.height - tp.height - padding,
      ),
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
