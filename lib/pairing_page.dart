import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

/// 🎨 Paleta YanaGuard
const Color azulProfundo = Color(0xFF1E3A8A);
const Color naranjaAndino = Color(0xFFF59E0B);
const Color verdeQuillu = Color(0xFF4CAF50);
const Color beigeCalido = Color(0xFFF4EBD0);

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

  @override
  void initState() {
    super.initState();
    _ensureSignedIn();
  }

  Future<void> _ensureSignedIn() async {
    final user = _auth.currentUser;
    if (user == null) {
      try {
        await _auth.signInAnonymously();
      } catch (e) {
        // sin debug
      }
    }
  }

  Future<void> _pairDevice() async {
    final code = _codeController.text.trim();
    if (code.length != 6) {
      setState(() => _errorMessage = 'El código debe tener 6 dígitos.');
      return;
    }

    setState(() {
      _loading = true;
      _errorMessage = '';
    });

    await _ensureSignedIn();
    final uid = _auth.currentUser?.uid;

    try {
      final pairingSnap = await _db.child('pairing').get();

      if (!pairingSnap.exists) {
        setState(() {
          _errorMessage = 'No existen dispositivos en espera.';
          _loading = false;
        });
        return;
      }

      Map<dynamic, dynamic> pairingMap = Map<dynamic, dynamic>.from(
        pairingSnap.value as Map,
      );

      String? foundDeviceId;

      pairingMap.forEach((key, value) {
        if (value is Map && value['code'] == code) {
          foundDeviceId = key.toString();
        }
      });

      if (foundDeviceId == null) {
        setState(() {
          _errorMessage = 'Código inválido o no encontrado.';
          _loading = false;
        });
        return;
      }

      final deviceId = foundDeviceId!;

      await _db.child('devices').child(deviceId).update({
        'ownerUid': uid,
        'pairedAt': DateTime.now().millisecondsSinceEpoch,
      });

      await _db.child('pairing').child(deviceId).remove();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Dispositivo emparejado exitosamente'),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() => _errorMessage = 'Error inesperado: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: beigeCalido,
      appBar: AppBar(
        title: const Text('Emparejar dispositivo'),
        backgroundColor: azulProfundo,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    'Ingresa el código de emparejamiento',
                    style: TextStyle(
                      color: azulProfundo,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _codeController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.link),
                    label: Text(
                      _loading ? 'Emparejando...' : 'Reclamar dispositivo',
                    ),
                    onPressed: _loading ? null : _pairDevice,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: naranjaAndino,
                    ),
                  ),
                  if (_errorMessage.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        _errorMessage,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
