import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:jaouda_boujdour_app/models/market.dart';
import 'package:jaouda_boujdour_app/services/route_service.dart';
import 'package:jaouda_boujdour_app/features/maps/providers/maps_fixed_provider.dart';
import 'package:jaouda_boujdour_app/services/supabase_client.dart';
import 'package:flutter_map_heatmap/flutter_map_heatmap.dart';

import '../../../widgets/app_layout.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';

// ignore_for_file: unused_field, unused_element, unused_local_variable, use_build_context_synchronously

class EnhancedMapScreen extends ConsumerStatefulWidget {
  const EnhancedMapScreen({super.key});

  @override
  ConsumerState<EnhancedMapScreen> createState() => _EnhancedMapScreenState();
}

class _EnhancedMapScreenState extends ConsumerState<EnhancedMapScreen> {
  final MapController _mapController = MapController();
  final RouteService _routeService = RouteService();
  final TextEditingController _searchController = TextEditingController();
  final PopupController _popupController = PopupController();
  final StreamController<void> _rebuildStream = StreamController.broadcast();
  @pragma('vm:prefer-inline')
  List<LatLng>? _routePoints;
  final String _selectedFilter = 'all';
  final String _searchQuery = '';
  @pragma('vm:prefer-inline')
  final List<Market> _selectedMarkets = [];
  bool _showHeatmap = false;
  bool _showRouteInfo = false;
  int _gradientIndex = 0;
  double _opacity = 0.1;
  double _radius = 30.0;

  final List<Map<double, MaterialColor>> _gradients = [
    // Default gradient - Green to Red
    {0.4: Colors.green, 0.65: Colors.yellow, 1.0: Colors.red},

    // Cool gradient - Blue to Purple
    {
      0.25: Colors.blue,
      0.55: Colors.red,
      0.85: Colors.pink,
      1.0: Colors.purple,
    },

    // Warm gradient - Blue to Yellow
    {0.0: Colors.blue, 0.5: Colors.green, 1.0: Colors.yellow},

    // Traffic gradient - Green to Red
    {
      0.0: Colors.green,
      0.3: Colors.lightGreen,
      0.5: Colors.yellow,
      0.7: Colors.orange,
      1.0: Colors.red,
    },

    // Ocean gradient - Blue to Teal
    {0.0: Colors.blue, 0.3: Colors.blue, 0.6: Colors.cyan, 1.0: Colors.teal},

    // Sunset gradient - Purple to Orange
    {
      0.0: Colors.purple,
      0.3: Colors.pink,
      0.6: Colors.deepOrange,
      1.0: Colors.orange,
    },

    // Forest gradient - Green to Brown
    {
      0.0: Colors.green,
      0.3: Colors.green,
      0.6: Colors.lightGreen,
      1.0: Colors.brown,
    },

    // Rainbow gradient
    {
      0.0: Colors.red,
      0.2: Colors.orange,
      0.4: Colors.yellow,
      0.6: Colors.green,
      0.8: Colors.blue,
      1.0: Colors.purple,
    },
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        // Initialize map state
        await ref.read(mapsProvider.notifier).initialize();

        // Get current location
        await ref.read(mapsProvider.notifier).getCurrentLocation();

        // Set initial map center if we have a location
        final state = ref.read(mapsProvider);
        if (state.currentLocation != null) {
          _mapController.move(state.currentLocation!, 15.0);
        } else {
          // Fallback to a default location if current location is not available
          _mapController.move(
            const LatLng(26.1333, -14.4833),
            15.0,
          ); // Boujdour coordinates
        }
      } catch (e) {
        debugPrint('Error initializing map: $e');
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error initializing map: $e')));
        }
      }
    });
  }

  @override
  void dispose() {
    _mapController.dispose();
    _searchController.dispose();
    _rebuildStream.close();
    super.dispose();
  }

  @pragma('vm:prefer-inline')
  Future<List<Map<String, dynamic>>> _getMarketVisitHistory(
    String marketId,
  ) async {
    try {
      final response = await supabase
          .from('market_visits')
          .select()
          .eq('market_id', marketId)
          .order('visit_date', ascending: false)
          .limit(5);
      return response;
    } catch (e) {
      debugPrint('Error loading visit history: $e');
      return [];
    }
  }

  Future<void> _recordMarketVisit(
    String marketId,
    String status,
    String? notes,
  ) async {
    try {
      await supabase.from('market_visits').insert({
        'market_id': marketId,
        'visit_date': DateTime.now().toIso8601String(),
        'status': status,
        'notes': notes,
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Visit recorded successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to record visit: $e')));
    }
  }

  Future<void> _optimizeRoute(List<Market> markets) async {
    final state = ref.read(mapsProvider);
    if (state.currentLocation == null) return;

    final locations = [
      state.currentLocation!,
      ...markets.map((m) => m.location),
    ];

    try {
      final optimizedRoute = await _routeService.optimizeRoute(locations);
      setState(() {
        _routePoints = optimizedRoute;
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to optimize route: $e')));
    }
  }

  Color _getMarketColor(MarketStatus status) {
    switch (status) {
      case MarketStatus.toVisit:
        return Colors.amber;
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

  String _getMarketStatusText(MarketStatus status) {
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

  Widget _buildCurrentLocationMarker(LatLng location) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: Colors.blue.withAlpha(128),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.blue, width: 2),
      ),
    );
  }

  Widget _buildMarketMarker(Market market) {
    final color = _getMarketColor(market.status);
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withAlpha(204),
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2),
      ),
      child: const Center(
        child: Icon(Icons.store, color: Colors.white, size: 20),
      ),
    );
  }

  List<Marker> _buildMarkers(BuildContext context) {
    final state = ref.watch(mapsProvider);
    final markers = <Marker>[];

    // Add current location marker
    if (state.currentLocation != null) {
      markers.add(
        Marker(
          point: state.currentLocation!,
          width: 20,
          height: 20,
          child: _buildCurrentLocationMarker(state.currentLocation!),
        ),
      );
    }

    // Add market markers
    for (final market in state.markets) {
      markers.add(
        Marker(
          point: market.location,
          width: 40,
          height: 40,
          child: _buildMarketMarker(market),
        ),
      );
    }

    return markers;
  }

  Future<void> _navigateToNextMarket() async {
    final state = ref.read(mapsProvider);
    if (state.markets.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('No markets available')));
      }
      return;
    }

    // Find markets that need to be visited
    final unvisitedMarkets =
        state.markets.where((m) => m.status == MarketStatus.toVisit).toList();

    if (unvisitedMarkets.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No unvisited markets available')),
        );
      }
      return;
    }

    // Get current location
    final currentLocation = state.currentLocation;
    if (currentLocation == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Current location not available')),
        );
      }
      return;
    }

    // Find nearest unvisited market
    Market nearestMarket = unvisitedMarkets.first;
    double shortestDistance = const Distance().as(
      LengthUnit.Kilometer,
      currentLocation,
      nearestMarket.location,
    );

    for (final market in unvisitedMarkets.skip(1)) {
      final distance = const Distance().as(
        LengthUnit.Kilometer,
        currentLocation,
        market.location,
      );
      if (distance < shortestDistance) {
        shortestDistance = distance;
        nearestMarket = market;
      }
    }

    try {
      // Initialize route service if needed
      if (!_routeService.isInitialized) {
        await _routeService.initialize();
      }

      // Generate route to nearest market
      await ref
          .read(mapsProvider.notifier)
          .generateRoute(currentLocation, nearestMarket.location);

      // Update selected market
      ref.read(mapsProvider.notifier).selectMarket(nearestMarket);

      // Center map on the route
      final bounds = LatLngBounds.fromPoints([
        currentLocation,
        nearestMarket.location,
      ]);
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.all(50.0),
        ),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Navigating to ${nearestMarket.name} (${shortestDistance.toStringAsFixed(1)} km away)',
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Navigation error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate route: $e'),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  void _fitBounds(LatLng point1, LatLng point2) {
    final bounds = LatLngBounds.fromPoints([point1, point2]);
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.all(50.0),
      ),
    );
  }

  double _calculateDistance(LatLng point1, LatLng point2) {
    const Distance distance = Distance();
    return distance.as(LengthUnit.Kilometer, point1, point2);
  }

  List<Market> _getFilteredMarkets(List<Market> markets) {
    return markets.where((market) {
      // Apply search filter
      final matchesSearch = _searchQuery.isEmpty ||
          market.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (market.address?.toLowerCase() ?? '')
              .contains(_searchQuery.toLowerCase());

      // Apply status filter
      final matchesFilter =
          _selectedFilter == 'all' || market.status.value == _selectedFilter;

      return matchesSearch && matchesFilter;
    }).toList();
  }

  void _handleMapTap(TapPosition tapPosition, LatLng point) {
    // Clear selected market when tapping on the map
    ref.read(mapsProvider.notifier).selectMarket(null);
  }

  Widget _buildRouteLayer() {
    final state = ref.watch(mapsProvider);
    if (state.routePoints.isEmpty) return const SizedBox.shrink();

    return PolylineLayer(
      polylines: [
        Polyline(
          points: state.routePoints,
          color: Theme.of(context).primaryColor.withAlpha(204),
          strokeWidth: 5,
          borderColor: Colors.white,
          borderStrokeWidth: 2,
        ),
      ],
    );
  }

  Widget _buildHeatmapLayer() {
    final state = ref.watch(mapsProvider);
    if (state.markets.isEmpty) {
      return const SizedBox.shrink();
    }

    final points = state.markets.map((market) {
      double intensity = 0.0;
      switch (market.status) {
        case MarketStatus.toVisit:
          intensity = 0.3;
          break;
        case MarketStatus.saleMade:
          intensity = 0.7;
          break;
        case MarketStatus.closed:
          intensity = 0.5;
          break;
        case MarketStatus.noNeed:
          intensity = 0.2;
          break;
        case MarketStatus.visited:
          intensity = 0.4;
          break;
      }
      return WeightedLatLng(
        LatLng(market.location.latitude, market.location.longitude),
        intensity,
      );
    }).toList();

    return HeatMapLayer(
      heatMapDataSource: InMemoryHeatMapDataSource(data: points),
      heatMapOptions: HeatMapOptions(
        gradient: _gradients[_gradientIndex],
        minOpacity: _opacity,
        radius: _radius,
      ),
      reset: _rebuildStream.stream,
    );
  }

  Widget _buildMarketMarkers() {
    final state = ref.watch(mapsProvider);
    return MarkerClusterLayerWidget(
      options: MarkerClusterLayerOptions(
        maxClusterRadius: 120,
        size: const Size(40, 40),
        markers: state.markets
            .map(
              (market) => Marker(
                point: market.location,
                width: 40,
                height: 40,
                child: _buildMarketMarker(market),
              ),
            )
            .toList(),
        builder: (context, markers) {
          return Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: Colors.blue,
            ),
            child: Center(
              child: Text(
                markers.length.toString(),
                style: const TextStyle(color: Colors.white),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(mapsProvider);
    final filteredMarkets = _getFilteredMarkets(state.markets);

    // Trigger heatmap rebuild when markets change
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _rebuildStream.add(null);
    });

    if (state.isLoading) {
      return AppLayout(
        appBar: AppBar(title: const Text('Market Map')),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading map data...'),
            ],
          ),
        ),
      );
    }

    if (state.error != null) {
      return AppLayout(
        appBar: AppBar(title: const Text('Market Map')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Error: ${state.error}'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  ref.read(mapsProvider.notifier).refreshMap();
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return AppLayout(
      appBar: AppBar(
        title: const Text('Interactive Map'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Markets',
            onPressed: () {
              ref.read(mapsProvider.notifier).loadMarkets();
            },
          ),
          IconButton(
            icon: Icon(_showHeatmap ? Icons.layers_clear : Icons.layers),
            tooltip: _showHeatmap ? 'Hide Heatmap' : 'Show Heatmap',
            onPressed: () {
              setState(() {
                _showHeatmap = !_showHeatmap;
              });
            },
          ),
          if (_showHeatmap)
            Tooltip(
              message: _getGradientName(_gradientIndex),
              child: IconButton(
                icon: const Icon(Icons.palette),
                onPressed: () {
                  setState(() {
                    _gradientIndex = (_gradientIndex + 1) % _gradients.length;
                  });
                },
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter:
                  state.currentLocation ?? const LatLng(30.422, -9.599),
              initialZoom: 14,
              onTap: (_, __) {
                _popupController.hideAllPopups();
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.jaouda.boujdour.app',
              ),
              if (state.currentLocation != null)
                _buildCurrentLocationMarker(state.currentLocation!),
              _buildMarketMarkers(),
              _buildRouteLayer(),
              if (_showHeatmap) _buildHeatmapLayer(),
            ],
          ),
          if (_showHeatmap)
            Positioned(
              top: 16,
              left: 16,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(26),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Market Status',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    _buildLegendItem('Sale Made', Colors.green),
                    _buildLegendItem('Closed', Colors.red),
                    _buildLegendItem('To Visit', Colors.amber),
                    _buildLegendItem('No Need', Colors.grey),
                    const SizedBox(height: 16),
                    Text(
                      'Opacity',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    Slider(
                      value: _opacity,
                      min: 0.0,
                      max: 1.0,
                      divisions: 10,
                      label: _opacity.toStringAsFixed(1),
                      onChanged: (value) {
                        setState(() {
                          _opacity = value;
                        });
                      },
                    ),
                    Text(
                      'Radius',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    Slider(
                      value: _radius,
                      min: 10.0,
                      max: 50.0,
                      divisions: 8,
                      label: _radius.toStringAsFixed(0),
                      onChanged: (value) {
                        setState(() {
                          _radius = value;
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _opacity = 0.1;
                          _radius = 30.0;
                          _gradientIndex = 0;
                        });
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reset Settings'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 36),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (state.routePoints.isNotEmpty && _showRouteInfo)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: RouteInfoPanel(
                distance: state.routeDistance ?? 0.0,
                duration: state.routeDuration ?? Duration.zero,
                onClose: () {
                  setState(() {
                    _showRouteInfo = false;
                  });
                },
              ),
            ),
          Positioned(
            bottom: 16,
            right: 16,
            child: Column(
              children: [
                FloatingActionButton(
                  heroTag: 'location',
                  onPressed: () async {
                    await ref.read(mapsProvider.notifier).getCurrentLocation();
                    final location = ref.read(mapsProvider).currentLocation;
                    if (location != null) {
                      _mapController.move(location, 15.0);
                    }
                  },
                  child: const Icon(Icons.my_location),
                ),
                const SizedBox(height: 8),
                FloatingActionButton(
                  heroTag: 'route',
                  onPressed: () async {
                    await _navigateToNextMarket();
                    setState(() {
                      _showRouteInfo = true;
                    });
                  },
                  child: const Icon(Icons.directions),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text(label),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    String label,
    String value,
    IconData icon, [
    Color? color,
  ]) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color ?? Colors.blue),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  Color _getMarkerColor(MarketStatus status) {
    switch (status) {
      case MarketStatus.saleMade:
        return Colors.green;
      case MarketStatus.closed:
        return Colors.red;
      case MarketStatus.toVisit:
        return Colors.amber;
      case MarketStatus.noNeed:
        return Colors.grey;
      case MarketStatus.visited:
        return Colors.blue;
    }
  }

  String _getGradientName(int index) {
    switch (index) {
      case 0:
        return 'Default (Green to Red)';
      case 1:
        return 'Cool (Blue to Purple)';
      case 2:
        return 'Warm (Blue to Yellow)';
      case 3:
        return 'Traffic (Green to Red)';
      case 4:
        return 'Ocean (Blue to Teal)';
      case 5:
        return 'Sunset (Purple to Orange)';
      case 6:
        return 'Forest (Green to Brown)';
      case 7:
        return 'Rainbow';
      default:
        return 'Unknown Gradient';
    }
  }
}

class RouteInfoPanel extends StatelessWidget {
  final double distance;
  final Duration duration;
  final VoidCallback onClose;

  const RouteInfoPanel({
    super.key,
    required this.distance,
    required this.duration,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(26),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Route Information',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: onClose,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.directions_car, size: 20),
              const SizedBox(width: 8),
              Text(
                '${(distance / 1000).toStringAsFixed(1)} km',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.timer, size: 20),
              const SizedBox(width: 8),
              Text(
                '${duration.inMinutes} min',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
