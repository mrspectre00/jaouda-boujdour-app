import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:math' as math;
import '../models/market.dart';
import 'market_detail_screen.dart'; // Added for navigation
import '../services/supabase_client.dart'; // Added for status update
import 'package:intl/intl.dart'; // Added for date formatting
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:flutter_map_heatmap/flutter_map_heatmap.dart';

class MapScreen extends StatefulWidget {
  final List<Market> markets;
  final LatLng? currentLocation;

  const MapScreen({super.key, required this.markets, this.currentLocation});

  @override
  void dispose() {
    _locationSubscription?.cancel();
    super.dispose();
  }

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late MapController _mapController;
  LocationData? _currentLocationData;
  StreamSubscription<LocationData>? _locationSubscription;
  bool _isMapLoaded = false;
  final double _currentZoom = 13.0;
  Market? _selectedMarket;
  bool _isDrawingRoute = false;
  bool _isUpdatingStatus = false; // Added loading state for status update

  // Removed mock data for _currentLocation and _markets
  // Use widget.currentLocation and widget.markets instead

  List<LatLng> _routePoints = [];

  @override
  void dispose() {
    _locationSubscription?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    _startLocationTracking();
    super.initState();
    _mapController = MapController();

    // Add a small delay for web platforms to ensure map loads properly
    if (kIsWeb) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          setState(() {
            _isMapLoaded = true;
          });
        }
      });
    }
  }

  // Get status text
  String _getStatusText(String? statusCode) {
    switch (statusCode) {
      case 'to_visit':
        return 'Need to Visit';
      case 'visited_sale':
        return 'Sale Made';
      case 'visited_no_sale':
        return 'Closed/No Sale';
      case 'visited_not_needed': // Added new status
        return 'Not Needed';
      default:
        return 'Unknown';
    }
  }

  // Start real-time location tracking
  void _startLocationTracking() async {
    final location = Location();
    bool serviceEnabled = await location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await location.requestService();
      if (!serviceEnabled) {
        return;
      }
    }

    PermissionStatus permission = await location.hasPermission();
    if (permission == PermissionStatus.denied) {
      permission = await location.requestPermission();
      if (permission != PermissionStatus.granted) {
        return;
      }
    }

    _locationSubscription = location.onLocationChanged.listen((
      LocationData locationData,
    ) {
      if (mounted) {
        setState(() {
          _currentLocationData = locationData;
        });
      }
    });
  }

  // Get marker color based on market status
  Color _getMarkerColor(String? status) {
    // Made status nullable
    switch (status) {
      case 'to_visit':
        return Colors.amber;
      case 'visited_sale':
        return Colors.green;
      case 'visited_no_sale':
        return Colors.red;
      case 'visited_not_needed': // Added new status color
        return Colors.orange;
      default:
        return Colors.blue; // Default or unknown status
    }
  }

  // Find the closest unvisited market
  Market? _findClosestUnvisitedMarket() {
    Market? closest;
    double minDistance = double.infinity;
    final currentLoc = widget.currentLocation;
    if (currentLoc == null) return null; // Need current location

    const distance = Distance();

    for (var market in widget.markets) {
      // Use market.location which is LatLng
      if (market.status == 'to_visit') {
        // location is non-nullable in Market model
        final marketLoc = market.location; // Access the LatLng object
        final dist = distance.as(LengthUnit.Kilometer, currentLoc, marketLoc);
        if (dist < minDistance) {
          minDistance = dist;
          closest = market;
        }
      }
    }
    return closest;
  }

  // Generate a route to the closest unvisited market
  void _navigateToNextMarket() {
    print('[_navigateToNextMarket] FAB pressed.'); // DEBUG
    print(
      '[_navigateToNextMarket] Current location from widget: ${widget.currentLocation}',
    ); // ADDED DEBUG
    final closestMarket = _findClosestUnvisitedMarket();
    final currentLoc = widget.currentLocation;
    // print('[_navigateToNextMarket] Current Location: $currentLoc'); // DEBUG - Redundant with above print
    print(
      '[_navigateToNextMarket] Closest Market: ${closestMarket?.name}',
    ); // DEBUG

    if (closestMarket == null ||
        currentLoc == null ||
        closestMarket.latitude == null ||
        closestMarket.longitude == null) {
      print(
        '[_navigateToNextMarket] Condition failed: No market or location.',
      ); // DEBUG
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No unvisited markets available or location missing'),
        ),
      );
      return;
    }
    print(
      '[_navigateToNextMarket] Proceeding with route generation.',
    ); // ADDED DEBUG

    final marketLoc = LatLng(
      closestMarket.latitude!,
      closestMarket.longitude!,
    ); // Ensure location exists

    setState(() {
      _isDrawingRoute = true;
      // Generate a simple route with a few points (in real app, this would use actual routing)
      _routePoints = _generateRoute(currentLoc, marketLoc);
    });

    // Center the map on the midpoint between current location and destination
    final midLat = (currentLoc.latitude + marketLoc.latitude) / 2;
    final midLng = (currentLoc.longitude + marketLoc.longitude) / 2;

    // Calculate zoom level based on distance
    final latDiff = (currentLoc.latitude - marketLoc.latitude).abs();
    final lngDiff = (currentLoc.longitude - marketLoc.longitude).abs();
    final maxDiff = math.max(latDiff, lngDiff) * 2.5;
    final zoom = 14 - (math.log(maxDiff) / math.ln2);

    _mapController.move(LatLng(midLat, midLng), zoom.clamp(12.0, 16.0));
  }

  // Generate a basic route between two points (simplified for UI demo)
  List<LatLng> _generateRoute(LatLng start, LatLng end) {
    // In a real app, this would use a routing API
    // For demo, we'll create a slightly curved route
    const segments = 10;
    final points = <LatLng>[];
    points.add(start);

    // Add some intermediary points with slight random offset to simulate a route
    for (int i = 1; i < segments; i++) {
      final ratio = i / segments;
      final lat = start.latitude + (end.latitude - start.latitude) * ratio;
      final lng = start.longitude + (end.longitude - start.longitude) * ratio;

      // Add a slight random curve to the route
      const curveAmount = 0.001; // adjust for more/less curve
      final randomOffset = (math.Random().nextDouble() - 0.5) * curveAmount;

      points.add(LatLng(lat + randomOffset, lng + randomOffset));
    }

    points.add(end);
    return points;
  }

  // Function to update market status
  Future<void> _updateMarketStatus(Market market, String newStatus) async {
    print(
      '[_updateMarketStatus] Called with Market: ${market.name}, New Status: $newStatus',
    );

    // Added check for valid status transitions (optional but good practice)
    if (market.status != 'to_visit') {
      print(
        '[_updateMarketStatus] Market status is not to_visit, cannot update.',
      ); // DEBUG
      // Optionally show a message
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(content: Text('Market status is already ${_getStatusText(market.status)}.')),
      // );
      return;
    }

    setState(() {
      _isUpdatingStatus = true;
    });

    try {
      final userId = supabase.auth.currentUser!.id;
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

      // Check if an assignment exists for this market and vendor today
      final assignment =
          await supabase
              .from('daily_assignments')
              .select('id')
              .eq('vendor_id', userId)
              .eq('market_id', market.id)
              .eq('assignment_date', today)
              .maybeSingle();

      print('[_updateMarketStatus] Assignment found: $assignment'); // DEBUG

      if (assignment == null) {
        print('[_updateMarketStatus] No assignment found.'); // DEBUG
        throw Exception('No assignment found for this market today.');
      }

      // Update the status in the daily_assignments table
      await supabase
          .from('daily_assignments')
          .update({
            'status': newStatus,
            'visited_at': DateTime.now().toIso8601String(),
          })
          .eq('id', assignment['id']);

      // Update the local market state (optional, depends on how you refresh data)
      final marketIndex = widget.markets.indexWhere((m) => m.id == market.id);
      print(
        '[_updateMarketStatus] Market index in local list: $marketIndex',
      ); // DEBUG
      if (marketIndex != -1 && mounted) {
        setState(() {
          widget.markets[marketIndex] = widget.markets[marketIndex].copyWith(
            status: newStatus,
          );
          _selectedMarket =
              widget.markets[marketIndex]; // Update selected market too
          print('[_updateMarketStatus] Local market state updated.'); // DEBUG
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${market.name} status updated to ${_getStatusText(newStatus)}.',
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error updating market status: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating status: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingStatus = false;
        });
      }
      print('[_updateMarketStatus] Finished.'); // DEBUG
    }
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Add check for empty markets list
    if (widget.markets.isEmpty) {
      return const Scaffold(
        // Consider adding an AppBar if this screen can be shown independently
        // appBar: AppBar(title: Text("Map")),
        body: Center(child: Text('No markets assigned or found for today.')),
      );
    }

    final LatLng center =
        widget.currentLocation ??
        const LatLng(26.1258, -14.4842); // Default Boujdour

    return Scaffold(
      // Removed AppBar as it's likely handled by the parent screen (MarketsScreen)
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: center,
              initialZoom: _currentZoom,
              onTap: (_, __) {
                // Deselect market when tapping on the map background
                if (_selectedMarket != null) {
                  setState(() {
                    _selectedMarket = null;
                    _isDrawingRoute = false; // Clear route when deselecting
                    _routePoints = [];
                  });
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.jaouda.boujdour',
              ),
              // Current location marker
              if (widget.currentLocation != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      width: 40,
                      height: 40,
                      point: widget.currentLocation!,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.3),
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.my_location,
                            color: Colors.blue,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              // Market markers
              MarkerClusterLayerWidget(
                options: MarkerClusterLayerOptions(
                  maxClusterRadius: 45,
                  size: const Size(50, 50),
                  markers:
                      widget.markets
                          .where(
                            (market) =>
                                market.latitude != null &&
                                market.longitude != null,
                          )
                          .map((market) {
                            return Marker(
                              width: 80,
                              height: 80,
                              point: LatLng(
                                market.latitude!,
                                market.longitude!,
                              ),
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedMarket = market;
                                    _isDrawingRoute = false;
                                    _routePoints = [];
                                  });
                                  _mapController.move(
                                    LatLng(market.latitude!, market.longitude!),
                                    _mapController.camera.zoom,
                                  );
                                },
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.8),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: _getMarkerColor(market.status),
                                          width: 1,
                                        ),
                                      ),
                                      child: Text(
                                        market.name,
                                        style: const TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Icon(
                                      Icons.location_pin,
                                      color: _getMarkerColor(market.status),
                                      size: 35,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          })
                          .toList(),
                  builder: (context, markers) {
                    return Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.deepPurple.withOpacity(0.7),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        markers.length.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  },
                ),
              ),
              // Heatmap for visited markets
              HeatMapLayer(
                heatMapData:
                    widget.markets
                        .where((m) => m.status == 'visited_sale')
                        .map(
                          (m) => WeightedLatLng(
                            point: LatLng(m.latitude!, m.longitude!),
                            intensity: 1,
                          ),
                        )
                        .toList(),
                heatMapOptions: const HeatMapOptions(
                  radius: 30,
                  blur: 20,
                  minOpacity: 0.3,
                  maxOpacity: 0.8,
                  gradient: {
                    0.4: Colors.green,
                    0.65: Colors.yellow,
                    1.0: Colors.red,
                  },
                ),
              ),
              // Route polyline
              if (_isDrawingRoute && _routePoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _routePoints,
                      color: Colors.deepPurple,
                      strokeWidth: 4.0,
                    ),
                  ],
                ),
            ],
          ),
          // Selected Market Info Panel
          if (_selectedMarket != null)
            Positioned(
              bottom: 10,
              left: 10,
              right: 10,
              child: Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedMarket!.name,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Status: ${_getStatusText(_selectedMarket!.status)}',
                      ),
                      Text('Address: ${_selectedMarket!.address}'),
                      const SizedBox(height: 8),
                      if (_isUpdatingStatus)
                        const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else
                        Wrap(
                          // Use Wrap for better button layout on smaller screens
                          spacing: 4.0, // Horizontal space between buttons
                          runSpacing: 0.0, // Vertical space if wrapping occurs
                          alignment: WrapAlignment.spaceBetween,
                          children: [
                            // Details Button
                            TextButton.icon(
                              icon: const Icon(Icons.info_outline),
                              label: const Text('Details'),
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                visualDensity: VisualDensity.compact,
                              ),
                              onPressed: () {
                                print(
                                  '[Details Button] Pressed for market: ${_selectedMarket?.name}',
                                ); // DEBUG
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder:
                                        (context) => MarketDetailScreen(
                                          market: _selectedMarket!,
                                        ),
                                  ),
                                );
                              },
                            ),
                            // Log Visit Buttons (only if status is 'to_visit')
                            if (_selectedMarket!.status == 'to_visit') ...[
                              TextButton.icon(
                                icon: const Icon(
                                  Icons.check_circle,
                                  color: Colors.green,
                                  size: 20,
                                ),
                                label: const Text('Sale'),
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  visualDensity: VisualDensity.compact,
                                ),
                                onPressed: () {
                                  print(
                                    '[Sale Button] Pressed for market: ${_selectedMarket?.name}',
                                  ); // DEBUG
                                  _updateMarketStatus(
                                    _selectedMarket!,
                                    'visited_sale',
                                  );
                                },
                              ),
                              TextButton.icon(
                                icon: const Icon(
                                  Icons.cancel,
                                  color: Colors.red,
                                  size: 20,
                                ),
                                label: const Text('No Sale'),
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  visualDensity: VisualDensity.compact,
                                ),
                                onPressed: () {
                                  print(
                                    '[No Sale Button] Pressed for market: ${_selectedMarket?.name}',
                                  ); // DEBUG
                                  _updateMarketStatus(
                                    _selectedMarket!,
                                    'visited_no_sale',
                                  );
                                },
                              ),
                              // Added 'Not Needed' Button
                              TextButton.icon(
                                icon: const Icon(
                                  Icons.do_not_disturb_alt,
                                  color: Colors.orange,
                                  size: 20,
                                ),
                                label: const Text('Not Needed'),
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  visualDensity: VisualDensity.compact,
                                ),
                                onPressed: () {
                                  print(
                                    '[Not Needed Button] Pressed for market: ${_selectedMarket?.name}',
                                  ); // DEBUG
                                  _updateMarketStatus(
                                    _selectedMarket!,
                                    'visited_not_needed',
                                  );
                                },
                              ),
                            ],
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),
          // Floating Action Button for Navigation
          Positioned(
            bottom:
                _selectedMarket != null
                    ? 160
                    : 20, // Adjust position based on info panel
            right: 20,
            child: Column(
              // Use Column for multiple FABs
              mainAxisSize: MainAxisSize.min,
              children: [
                // Center on Me Button
                if (widget.currentLocation != null)
                  FloatingActionButton.small(
                    heroTag: 'center-map-btn', // Unique heroTag
                    onPressed: () {
                      _mapController.move(
                        widget.currentLocation!,
                        _mapController.camera.zoom,
                      );
                    },
                    tooltip: 'Center on My Location',
                    child: const Icon(Icons.my_location),
                  ),
                if (widget.currentLocation != null)
                  const SizedBox(height: 8), // Spacing between FABs
                // Navigate to Next Market Button
                Builder(
                  // Use Builder to get context for Theme
                  builder: (context) {
                    final bool hasLocation = widget.currentLocation != null;
                    // Calculate closest market once for efficiency
                    final Market? closestMarket = _findClosestUnvisitedMarket();
                    final bool canNavigate =
                        hasLocation && closestMarket != null;

                    String tooltip;
                    Widget fabIcon;
                    if (!hasLocation) {
                      tooltip = 'Waiting for location...';
                      // Show spinner icon if waiting for location
                      fabIcon = const SizedBox(
                        width: 24, // Standard FAB icon size
                        height: 24,
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                          strokeWidth: 2.0,
                        ),
                      );
                    } else if (closestMarket == null) {
                      tooltip = 'No unvisited markets nearby';
                      fabIcon = const Icon(
                        Icons.navigation_outlined,
                      ); // Indicate no target
                    } else {
                      tooltip =
                          'Navigate to Next Market (${closestMarket.name})';
                      fabIcon = const Icon(Icons.directions);
                    }

                    return FloatingActionButton(
                      heroTag: 'navigate-fab-btn', // Unique heroTag
                      onPressed: canNavigate ? _navigateToNextMarket : null,
                      tooltip: tooltip,
                      backgroundColor:
                          canNavigate
                              ? Theme.of(context)
                                  .colorScheme
                                  .secondary // Active color
                              : Colors.grey, // Disabled color
                      child: fabIcon,
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
