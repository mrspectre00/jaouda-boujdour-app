import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:uuid/uuid.dart';

import '../../../widgets/app_drawer.dart';
import '../../../models/market.dart';
import '../providers/maps_fixed_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../widgets/app_layout.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final MapController _mapController = MapController();
  Market? _selectedMarket;
  List<LatLng> _routePoints = [];
  bool _isDrawingRoute = false;

  @override
  void initState() {
    super.initState();
    _selectedMarket = null;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(mapsProvider.notifier).initialize();
      await ref.read(mapsProvider.notifier).getCurrentLocation();
    });
  }

  void _selectMarketById(String marketId) {
    final markets = ref.read(mapsProvider).markets;
    final market = markets.firstWhere(
      (m) => m.id == marketId,
      orElse: () => Market(
        id: marketId,
        name: 'Unknown Market',
        address: '',
        latitude: 0,
        longitude: 0,
        status: MarketStatus.toVisit,
      ),
    );

    setState(() {
      _selectedMarket = market;
    });
    ref.read(mapsProvider.notifier).selectMarket(market);
  }

  Future<void> _navigateToNextMarket() async {
    final currentLocation = ref.read(mapsProvider).currentLocation;
    if (currentLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Waiting for current location...')),
      );
      await ref.read(mapsProvider.notifier).getCurrentLocation();
      return;
    }

    final markets = ref.read(mapsProvider).markets;
    final unvisitedMarkets =
        markets.where((m) => m.status == MarketStatus.toVisit).toList();

    if (unvisitedMarkets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No unvisited markets found')),
      );
      return;
    }

    Market closestMarket = unvisitedMarkets.first;
    double minDistance = double.infinity;

    for (final market in unvisitedMarkets) {
      final distance = Geolocator.distanceBetween(
        currentLocation.latitude,
        currentLocation.longitude,
        market.latitude ?? 0,
        market.longitude ?? 0,
      );

      if (distance < minDistance) {
        minDistance = distance;
        closestMarket = market;
      }
    }

    setState(() {
      _selectedMarket = closestMarket;
    });

    ref.read(mapsProvider.notifier).selectMarket(closestMarket);

    try {
      await ref
          .read(mapsProvider.notifier)
          .generateRoute(currentLocation, closestMarket.location);

      // Center the map to show both points
      final bounds = LatLngBounds.fromPoints([
        currentLocation,
        closestMarket.location,
      ]);
      _mapController.fitBounds(
        bounds,
        options: const FitBoundsOptions(padding: EdgeInsets.all(50.0)),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to generate route: $e')));
    }
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  Color _getStatusColor(MarketStatus status) {
    switch (status) {
      case MarketStatus.toVisit:
        return Colors.yellow;
      case MarketStatus.saleMade:
        return Colors.green;
      case MarketStatus.closed:
        return Colors.red;
      case MarketStatus.noNeed:
        return Colors.grey;
      case MarketStatus.visited:
        return Colors.blue;
    }
  }

  String _getStatusText(MarketStatus status) {
    switch (status) {
      case MarketStatus.toVisit:
        return 'To Visit';
      case MarketStatus.saleMade:
        return 'Sale Made';
      case MarketStatus.closed:
        return 'Closed';
      case MarketStatus.noNeed:
        return 'No Need';
      case MarketStatus.visited:
        return 'Visited';
    }
  }

  double _calculateDistance(LatLng start, LatLng end) {
    return const Distance().as(LengthUnit.Kilometer, start, end);
  }

  Market _createNewMarket() {
    return Market(
      id: const Uuid().v4(),
      name: '',
      address: '',
      latitude: 0,
      longitude: 0,
      status: MarketStatus.toVisit,
    );
  }

  List<Market> _getMarketsToShow() {
    return ref
        .read(mapsProvider)
        .markets
        .where((m) => m.status != MarketStatus.saleMade)
        .toList();
  }

  Widget _buildMarketPopup(Market market) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              market.name,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            if (market.address != null) Text(market.address!),
            const SizedBox(height: 8),
            Text(
              _getStatusText(market.status),
              style: TextStyle(
                color: _getStatusColor(market.status),
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            if (market.assignedProducts.isNotEmpty)
              Text(
                'Products: ${market.assignedProducts.join(', ')}',
                style: const TextStyle(fontSize: 12),
              ),
            const SizedBox(height: 8),
            if (ref.read(mapsProvider).currentLocation != null)
              Text(
                'Distance: ${_calculateDistance(ref.read(mapsProvider).currentLocation!, market.location).toStringAsFixed(1)} km',
                style: const TextStyle(fontSize: 12),
              ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.navigation),
                  label: const Text('Navigate'),
                  onPressed: () async {
                    try {
                      await ref.read(mapsProvider.notifier).generateRoute(
                            ref.read(mapsProvider).currentLocation!,
                            market.location,
                          );
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Failed to generate route: $e'),
                          ),
                        );
                      }
                    }
                  },
                ),
                ElevatedButton.icon(
                  onPressed: () => ref
                      .read(mapsProvider.notifier)
                      .updateMarketStatus(market.id, MarketStatus.saleMade),
                  icon: const Icon(Icons.check),
                  label: const Text('Sale Made'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => ref
                      .read(mapsProvider.notifier)
                      .updateMarketStatus(market.id, MarketStatus.closed),
                  icon: const Icon(Icons.close),
                  label: const Text('Closed'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _centerOnCurrentLocation() {
    final currentLocation = ref.read(mapsProvider).currentLocation;
    if (currentLocation != null) {
      _mapController.move(currentLocation, _mapController.zoom);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mapState = ref.watch(mapsProvider);
    final authState = ref.watch(authProvider);

    return AppLayout(
      title: 'Markets Map',
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: const LatLng(27.1253, -13.1875),
              initialZoom: 13.0,
              onTap: (_, __) {
                setState(() {
                  _selectedMarket = null;
                });
                ref.read(mapsProvider.notifier).selectMarket(null);
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.jaouda.boujdour',
                tileProvider: CancellableNetworkTileProvider(),
              ),
              if (mapState.currentLocation != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: LatLng(
                        mapState.currentLocation!.latitude,
                        mapState.currentLocation!.longitude,
                      ),
                      child: const Icon(
                        Icons.location_on,
                        color: Colors.blue,
                        size: 40,
                      ),
                    ),
                  ],
                ),
              if (mapState.routePoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: mapState.routePoints,
                      color: Colors.blue,
                      strokeWidth: 4,
                    ),
                  ],
                ),
              MarkerLayer(
                markers: mapState.markets.map((market) {
                  Color markerColor;
                  switch (market.status) {
                    case MarketStatus.toVisit:
                      markerColor = Colors.yellow;
                      break;
                    case MarketStatus.saleMade:
                      markerColor = Colors.green;
                      break;
                    case MarketStatus.closed:
                      markerColor = Colors.red;
                      break;
                    case MarketStatus.noNeed:
                      markerColor = Colors.grey;
                      break;
                    case MarketStatus.visited:
                      markerColor = Colors.blue;
                      break;
                  }

                  return Marker(
                    point: market.location,
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedMarket = market;
                        });
                        ref.read(mapsProvider.notifier).selectMarket(market);
                      },
                      child: Icon(
                        Icons.location_on,
                        color: markerColor,
                        size: 40,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          Positioned(
            top: 16,
            right: 16,
            child: Column(
              children: [
                FloatingActionButton(
                  mini: true,
                  onPressed: _centerOnCurrentLocation,
                  tooltip: 'My Location',
                  child: const Icon(Icons.my_location),
                ),
                const SizedBox(height: 8),
                FloatingActionButton(
                  mini: true,
                  onPressed: _navigateToNextMarket,
                  tooltip: 'Navigate to Next Market',
                  child: const Icon(Icons.navigation),
                ),
                const SizedBox(height: 8),
                FloatingActionButton(
                  mini: true,
                  onPressed: () => context.push('/add-market'),
                  tooltip: 'Add Market',
                  child: const Icon(Icons.add_location_alt),
                ),
                const SizedBox(height: 8),
                FloatingActionButton(
                  mini: true,
                  onPressed: () {
                    ref.read(mapsProvider.notifier).loadMarkets();
                    ref.read(mapsProvider.notifier).getCurrentLocation();
                    setState(() {
                      _isDrawingRoute = false;
                      _routePoints = [];
                    });
                  },
                  tooltip: 'Refresh',
                  child: const Icon(Icons.refresh),
                ),
              ],
            ),
          ),
          if (_selectedMarket != null)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildMarketPopup(_selectedMarket!),
            ),
        ],
      ),
    );
  }
}
