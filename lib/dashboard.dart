import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});
  final String deviceId = 'esp01';

  Stream<QuerySnapshot<Map<String, dynamic>>> _eventsStream() {
    return FirebaseFirestore.instance
        .collection('devices')
        .doc(deviceId)
        .collection('events')
        .orderBy('timestamp', descending: true)
        .limit(200)
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
    // events are ordered descending, so reverse to chronological
    return temps.reversed.toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dashboards')),
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

          return Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              children: [
                // Card con gráfico de temperatura
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Temperatura - últimas lecturas', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 180,
                          child: temps.isEmpty
                              ? const Center(child: Text('No hay datos de temperatura'))
                              : TemperatureChart(temps: temps),
                        ),
                        const SizedBox(height: 8),
                        // reporte resumen
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Muestras: ${temps.length}'),
                            if (temps.isNotEmpty)
                              Text('Última: ${temps.last.toStringAsFixed(1)} °C'),
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
                      return ListTile(
                        leading: Icon(_iconForType(d['type'] as String?)),
                        title: Text(d['type']?.toString() ?? 'evento'),
                        subtitle: Text('Value: ${d['value'] ?? '-'} \n$timeStr'),
                        isThreeLine: true,
                      );
                    },
                  ),
                )
              ],
            ),
          );
        },
      ),
    );
  }

  IconData _iconForType(String? type) {
    switch (type) {
      case 'temperature':
        return Icons.thermostat;
      case 'pir_motion':
        return Icons.motion_photos_on;
      case 'alarm_test':
      case 'alarm':
        return Icons.alarm;
      case 'pir_toggle':
        return Icons.toggle_on;
      default:
        return Icons.event;
    }
  }
}

/// Widget que dibuja una línea de temperatura simple con CustomPainter
class TemperatureChart extends StatelessWidget {
  final List<double> temps;
  const TemperatureChart({super.key, required this.temps});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.infinite,
      painter: _TemperaturePainter(temps),
    );
  }
}

class _TemperaturePainter extends CustomPainter {
  final List<double> temps;
  _TemperaturePainter(this.temps);

  @override
  void paint(Canvas canvas, Size size) {
    final paintGrid = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6;

    final paintLine = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final paintFill = Paint()
      ..style = PaintingStyle.fill
      ..strokeWidth = 0.5
      ..color = Colors.blue.withOpacity(0.12);

    final padding = 8.0;
    final w = size.width - padding * 2;
    final h = size.height - padding * 2;

    if (temps.isEmpty) {
      // texto de ausencia
      final tp = TextPainter(
          text: const TextSpan(text: 'Sin datos', style: TextStyle(color: Colors.black54)),
          textDirection: TextDirection.ltr);
      tp.layout();
      tp.paint(canvas, Offset((size.width - tp.width) / 2, (size.height - tp.height) / 2));
      return;
    }

    // calcular min/max y
    double minY = temps.reduce((a, b) => a < b ? a : b);
    double maxY = temps.reduce((a, b) => a > b ? a : b);
    if (minY == maxY) {
      // evita división por cero
      minY -= 1;
      maxY += 1;
    }

    // cuadricula horizontal 4 líneas
    for (int i = 0; i <= 4; i++) {
      final y = padding + (h / 4) * i;
      canvas.drawLine(Offset(padding, y), Offset(padding + w, y), paintGrid..color = Colors.grey.withOpacity(0.18));
    }

    // puntos x
    final stepX = w / (temps.length - 1 == 0 ? 1 : (temps.length - 1));
    final points = <Offset>[];
    for (int i = 0; i < temps.length; i++) {
      final x = padding + stepX * i;
      final t = temps[i];
      final normalized = (t - minY) / (maxY - minY); // 0..1
      final y = padding + h - (normalized * h);
      points.add(Offset(x, y));
    }

    // path para fill (area bajo la curva)
    final path = Path();
    path.moveTo(points.first.dx, size.height - padding);
    for (final p in points) path.lineTo(p.dx, p.dy);
    path.lineTo(points.last.dx, size.height - padding);
    path.close();

    canvas.drawPath(path, paintFill);

    // dibujar línea
    final pathLine = Path();
    pathLine.moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      pathLine.lineTo(points[i].dx, points[i].dy);
    }
    canvas.drawPath(pathLine, paintLine..color = Colors.blue);

    // dibujar último valor como etiqueta
    final last = temps.last;
    final lastP = points.last;
    final tp = TextPainter(
      text: TextSpan(
        text: '${last.toStringAsFixed(1)}°C',
        style: const TextStyle(fontSize: 12, color: Colors.black87, fontWeight: FontWeight.w600),
      ),
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    final labelOffset = Offset(lastP.dx - tp.width - 4, lastP.dy - tp.height - 6);
    tp.paint(canvas, labelOffset);
  }

  @override
  bool shouldRepaint(covariant _TemperaturePainter oldDelegate) {
    return oldDelegate.temps != temps;
  }
}
