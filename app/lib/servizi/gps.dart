import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// Chiede i permessi di posizione. Restituisce un messaggio se mancano, null se e' tutto a posto.
Future<String?> verificaPermessiPosizione() async {
  if (!await Geolocator.isLocationServiceEnabled()) {
    return 'Attiva la localizzazione del telefono';
  }
  var permesso = await Geolocator.checkPermission();
  if (permesso == LocationPermission.denied) {
    permesso = await Geolocator.requestPermission();
  }
  if (permesso == LocationPermission.denied) {
    return 'Serve il permesso di posizione';
  }
  if (permesso == LocationPermission.deniedForever) {
    return 'Il permesso di posizione è negato: abilitalo dalle impostazioni del telefono';
  }
  return null;
}

/// Impostazioni per seguire la posizione anche con lo schermo spento.
/// Su Android parte un servizio in primo piano con una notifica visibile.
LocationSettings impostazioniTracciamento({required String titoloNotifica, int distanzaMinima = 10}) {
  if (kIsWeb) {
    return WebSettings(accuracy: LocationAccuracy.high, distanceFilter: distanzaMinima);
  }
  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: distanzaMinima,
        intervalDuration: const Duration(seconds: 4),
        foregroundNotificationConfig: ForegroundNotificationConfig(
          notificationTitle: titoloNotifica,
          notificationText: 'LeoNav sta condividendo la posizione della navetta',
          enableWakeLock: true,
          setOngoing: true,
        ),
      );
    case TargetPlatform.iOS:
      return AppleSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        activityType: ActivityType.automotiveNavigation,
        distanceFilter: distanzaMinima,
        pauseLocationUpdatesAutomatically: false,
        allowBackgroundLocationUpdates: true,
        showBackgroundLocationIndicator: true,
      );
    default:
      return LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: distanzaMinima);
  }
}

/// Segue la posizione e la passa a [suPosizione] al massimo ogni [intervallo].
class Tracciamento {
  Tracciamento({required this.intervallo, required this.suPosizione, this.suErrore});

  final Duration intervallo;
  final Future<void> Function(Position) suPosizione;
  final void Function(Object)? suErrore;

  StreamSubscription<Position>? _sub;
  DateTime? _ultimoInvio;
  Position? ultima;

  bool get attivo => _sub != null;

  void avvia(LocationSettings impostazioni) {
    _sub?.cancel();
    _sub = Geolocator.getPositionStream(locationSettings: impostazioni).listen((p) async {
      ultima = p;
      final adesso = DateTime.now();
      if (_ultimoInvio != null && adesso.difference(_ultimoInvio!) < intervallo) return;
      _ultimoInvio = adesso;
      try {
        await suPosizione(p);
      } catch (e) {
        suErrore?.call(e);
      }
    }, onError: (Object e) => suErrore?.call(e));
  }

  Future<void> ferma() async {
    await _sub?.cancel();
    _sub = null;
  }
}
