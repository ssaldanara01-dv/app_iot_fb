import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class PairingPage extends StatefulWidget {
  const PairingPage({super.key});

  @override
  State<PairingPage> createState() => _PairingPageState();
}

class _PairingPageState extends State<PairingPage> {
  final TextEditingController _codeController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  bool _loading = false;
  String _errorMessage = '';
  String _debugLog = '';

  @override
  void initState() {
    super.initState();
    _ensureSignedIn();
  }

  /// Asegura que el usuario esté autenticado antes de cualquier lectura
  Future<void> _ensureSignedIn() async {
    final user = _auth.currentUser;
    if (user == null) {
      await _auth.signInAnonymously();
      await Future.delayed(const Duration(milliseconds: 500));
    }
    final uid = _auth.currentUser?.uid;
    _log('Usuario autenticado UID=$uid');
  }

  void _log(String text) {
    setState(() {
      _debugLog += '\n${DateTime.now()} - $text';
    });
    debugPrint('📘 DEBUG: $text');
  }

  Future<void> _pairDevice() async {
    final code = _codeController.text.trim();

    if (code.length != 6) {
      setState(() {
        _errorMessage = 'El código debe tener 6 dígitos.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _errorMessage = '';
    });

    await _ensureSignedIn();
    final uid = _auth.currentUser!.uid;

    try {
      _log('Buscando código de emparejamiento "$code"...');

      // 🔐 Asegúrate de que solo lees dentro de /pairing
      final pairingRef = FirebaseDatabase.instance.ref('pairing');
      final snap = await pairingRef.orderByChild('code').equalTo(code).get();

      if (!snap.exists || snap.value == null) {
        setState(() {
          _errorMessage = 'Código inválido o no encontrado.';
          _loading = false;
        });
        _log('No se encontró el código "$code".');
        return;
      }

      // Encontrar el primer dispositivo que coincide
      final Map pairingData = snap.value as Map;
      final entry = pairingData.entries.first;
      final deviceId = entry.key;
      final deviceData = entry.value as Map?;

      _log('Código válido para deviceId=$deviceId');

      // 🔥 Vincular el dispositivo al usuario
      final deviceRef = _db.child('devices/$deviceId');

      await deviceRef.update({
        'ownerUid': uid,
        'pairedAt': DateTime.now().millisecondsSinceEpoch,
      });

      _log('Dispositivo $deviceId vinculado correctamente.');

      // Eliminar el código de pairing para evitar reutilización
      await _db.child('pairing/$deviceId').remove();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Dispositivo emparejado exitosamente')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      _log('Exception: $e');
      setState(() {
        _errorMessage =
            'Error: permiso denegado. Revisa reglas RTDB (¿.read en /pairing?)';
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Emparejar dispositivo'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _codeController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: const InputDecoration(
                labelText: 'Código de emparejamiento (6 dígitos)',
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.link),
              label: Text(_loading ? 'Emparejando...' : 'Reclamar dispositivo'),
              onPressed: _loading ? null : _pairDevice,
            ),
            const SizedBox(height: 12),
            if (_errorMessage.isNotEmpty)
              Text(
                _errorMessage,
                style: const TextStyle(color: Colors.red),
              ),
            const SizedBox(height: 12),
            const Text(
              'DEBUG LOG:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  _debugLog,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
