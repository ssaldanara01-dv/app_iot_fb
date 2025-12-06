// lib/views/pairing/pairing_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/pairing_view_model.dart';
import 'package:app_iot_db/theme/app_colors.dart';

class PairingPage extends StatelessWidget {
  const PairingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.beigeCalido,
      appBar: AppBar(
        title: const Text('Emparejar dispositivo'),
        backgroundColor: AppColors.azulProfundo,
        foregroundColor: Colors.white,
      ),
      body: Consumer<PairingViewModel>(
        builder: (_, vm, __) => ListView(
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
                        color: AppColors.azulProfundo,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      maxLength: 6,
                      keyboardType: TextInputType.number,
                      onChanged: vm.updateCode,
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.link),
                      label: Text(
                        vm.loading ? 'Emparejando...' : 'Reclamar dispositivo',
                      ),
                      onPressed: vm.loading
                          ? null
                          : () async {
                              final ok = await vm.pairDevice();
                              if (ok && context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                        '✅ Dispositivo emparejado exitosamente'),
                                  ),
                                );
                                Navigator.pop(context);
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.naranjaAndino,
                      ),
                    ),
                    if (vm.error.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          vm.error,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
