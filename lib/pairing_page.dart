import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

/// 🎨 Paleta YanaGuard
const Color azulProfundo = Color(0xFF1E3A8A);
const Color naranjaAndino = Color(0xFFF59E0B);
const Color verdeQuillu = Color(0xFF4CAF50);
const Color beigeCalido = Color(0xFFF4EBD0);
const Color azulNoche = Color(0xFF0F172A);

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

  /// Asegura que el usuario esté autenticado antes de cualquier lectura
  Future<void> _ensureSignedIn() async {
    final user = _auth.currentUser;
    if (user == null) {
      await _auth.signInAnonymously();
      await Future.delayed(const Duration(milliseconds: 500));
    }
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
      final pairingRef = FirebaseDatabase.instance.ref('pairing');
      final snap = await pairingRef.orderByChild('code').equalTo(code).get();

      if (!snap.exists || snap.value == null) {
        setState(() {
          _errorMessage = 'Código inválido o no encontrado.';
          _loading = false;
        });
        return;
      }

      final Map pairingData = snap.value as Map;
      final entry = pairingData.entries.first;
      final deviceId = entry.key;

      final deviceRef = _db.child('devices/$deviceId');
      await deviceRef.update({
        'ownerUid': uid,
        'pairedAt': DateTime.now().millisecondsSinceEpoch,
      });

      await _db.child('pairing/$deviceId').remove();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('✅ Dispositivo emparejado exitosamente'),
            backgroundColor: verdeQuillu,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
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
      backgroundColor: beigeCalido,
      appBar: AppBar(
        title: const Text('Emparejar dispositivo'),
        backgroundColor: azulProfundo,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Card(
          elevation: 5,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                const SizedBox(height: 10),
                Text(
                  'Ingresa el código de emparejamiento',
                  style: TextStyle(
                    fontSize: 18,
                    color: azulProfundo,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _codeController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  cursorColor: azulProfundo,
                  decoration: InputDecoration(
                    labelText: 'Código de emparejamiento (6 dígitos)',
                    labelStyle: TextStyle(color: azulProfundo.withOpacity(0.8)),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: azulProfundo.withOpacity(0.5)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: azulProfundo, width: 2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  icon: const Icon(Icons.link, color: Colors.white),
                  label: Text(
                    _loading ? 'Emparejando...' : 'Reclamar dispositivo',
                    style: const TextStyle(color: Colors.white),
                  ),
                  onPressed: _loading ? null : _pairDevice,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: naranjaAndino,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 12),
                if (_errorMessage.isNotEmpty)
                  Text(
                    _errorMessage,
                    style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w500),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
