// lib/view_models/pairing/pairing_view_model.dart
import 'package:flutter/foundation.dart';
import '../services/device/pairing_service.dart';

class PairingViewModel extends ChangeNotifier {
  final PairingService _service;
  PairingViewModel(this._service);

  bool loading = false;
  String error = '';
  String code = '';

  void updateCode(String value) {
    code = value;
    notifyListeners();
  }

  Future<bool> pairDevice() async {
    if (code.length != 6) {
      error = 'El código debe tener 6 dígitos.';
      notifyListeners();
      return false;
    }

    loading = true;
    error = '';
    notifyListeners();

    try {
      final user = await _service.ensureSignedIn();
      if (user == null) {
        error = "No se pudo autenticar al usuario.";
        loading = false;
        notifyListeners();
        return false;
      }

      final deviceId = await _service.findDeviceByCode(code);
      if (deviceId == null) {
        error = 'Código inválido o no encontrado.';
        loading = false;
        notifyListeners();
        return false;
      }

      await _service.linkDeviceToUser(deviceId, user.uid);

      loading = false;
      notifyListeners();
      return true;
    } catch (e) {
      error = "Error inesperado: $e";
      loading = false;
      notifyListeners();
      return false;
    }
  }
}
