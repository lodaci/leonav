import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';

import '../../config.dart';
import '../../modelli.dart';

/// Mappa di una tratta: percorso registrato (o linea tra le fermate), fermate e navetta.
class MappaLinea extends StatelessWidget {
  const MappaLinea({
    super.key,
    required this.fermate,
    required this.colore,
    this.percorso,
    this.navetta,
    this.evidenziata,
    this.io,
    this.controller,
  });

  final List<Fermata> fermate;
  final int colore;
  final List<LatLng>? percorso;
  final LatLng? navetta;
  final int? evidenziata;

  /// Posizione del telefono (usata dal rilevatore).
  final LatLng? io;
  final MapController? controller;

  @override
  Widget build(BuildContext context) {
    final punti = [for (final f in fermate) ?f.posizione];
    final linea = (percorso != null && percorso!.length > 1) ? percorso! : punti;
    final tutti = [...punti, ?navetta, ?io];
    final colorePrimario = Theme.of(context).colorScheme.primary;
    return FlutterMap(
      mapController: controller,
      options: MapOptions(
        initialCenter: tutti.isEmpty ? const LatLng(Config.latDefault, Config.lngDefault) : tutti.first,
        initialZoom: 12,
        initialCameraFit: tutti.length > 1
            ? CameraFit.bounds(bounds: LatLngBounds.fromPoints(tutti), padding: const EdgeInsets.all(40))
            : null,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'it.leonav.leonav',
        ),
        if (linea.length > 1)
          PolylineLayer(
            polylines: [Polyline(points: linea, strokeWidth: 5, color: Color(colore).withValues(alpha: 0.8))],
          ),
        MarkerLayer(
          markers: [
            for (final f in fermate)
              if (f.posizione != null)
                Marker(
                  point: f.posizione!,
                  width: f.id == evidenziata ? 36 : 18,
                  height: f.id == evidenziata ? 36 : 18,
                  child: f.id == evidenziata
                      ? Icon(Icons.location_on, color: colorePrimario, size: 36)
                      : DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: Color(colore), width: 4),
                          ),
                        ),
                ),
            if (io != null)
              Marker(
                point: io!,
                width: 22,
                height: 22,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                  ),
                ),
              ),
            if (navetta != null)
              Marker(
                point: navetta!,
                width: 44,
                height: 44,
                child: CircleAvatar(
                  backgroundColor: Color(colore),
                  child: const Icon(Icons.directions_bus, color: Colors.white),
                ),
              ),
          ],
        ),
        const RichAttributionWidget(attributions: [TextSourceAttribution('OpenStreetMap contributors')]),
      ],
    );
  }
}
