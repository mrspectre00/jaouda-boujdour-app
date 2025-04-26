import 'package:flutter/material.dart';
import 'package:latlong2/latlong2.dart';
import 'package:intl/intl.dart'; // Add this import for date formatting
import '../models/market.dart';
import '../services/supabase_client.dart';
import '../services/location_service.dart';
import 'market_detail_screen.dart';
import 'add_market_screen.dart';
import 'map_screen.dart';

class MarketsScreen extends StatefulWidget {
  const MarketsScreen({super.key});

  @override
  State<MarketsScreen> createState() => _MarketsScreenState();
}

class _MarketsScreenState extends State<MarketsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final String _filterStatus = 'All';
  final String _filterDistance = 'All';
  List<Map<String, dynamic>> _markets = [];
  List<Map<String, dynamic>> _filteredMarkets = [];
  bool _isLoading = true;
  bool _isMapView = false;
  LatLng? _currentLocation;

  @override
  void initState() {
    super.initState();
    _loadInitialData(); // Call the combined function
    _searchController.addListener(_filterMarkets);
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterMarkets);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Fetch location and markets concurrently
      // Use the robust LocationService to get the current location
      final locationFuture = LocationService.getCurrentLocation(context);

      final marketsFuture = _fetchMarkets(); // Extracted market fetching logic

      // Wait for both to complete
      final results = await Future.wait([locationFuture, marketsFuture]);

      final position = results[0] as Position?;
      final marketsData = results[1] as List<Map<String, dynamic>>;
      debugPrint('[MarketsScreen _loadInitialData] Location fetch result: ${position?.toJson()}'); // ADDED DEBUG

      if (mounted) {
        setState(() {
          if (position != null) {
            _currentLocation = LatLng(position.latitude, position.longitude);
            debugPrint('[MarketsScreen _loadInitialData] _currentLocation set to: $_currentLocation'); // ADDED DEBUG
          } else {
            debugPrint('[MarketsScreen _loadInitialData] Position was null, _currentLocation remains null or unchanged.'); // ADDED DEBUG
          }
          _markets = marketsData;
          _filteredMarkets = _markets; // Apply initial filter state if needed
          _filterMarkets(); // Apply search/filter text if any exists
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading initial data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading market data: ${e.toString()}')),
        );
        setState(() {
          _isLoading = false; // Still stop loading on error
          _markets = []; // Clear markets on error
          _filteredMarkets = [];
        });
      }
    }
  }

  // Extracted market fetching logic from original _loadMarkets
  Future<List<Map<String, dynamic>>> _fetchMarkets() async {
    final userId = supabase.auth.currentUser!.id;
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    // Fetch assigned market IDs for today
    final assignmentData = await supabase
        .from('daily_assignments')
        .select('market_id')
        .eq('vendor_id', userId)
        .eq('assignment_date', today);

    final assignedMarketIds = assignmentData.map((row) => row['market_id'] as String).toList();

    if (assignedMarketIds.isEmpty) {
      return []; // Return empty list if no assignments
    }

    // Fetch market details for ALL markets using RPC to get coordinates
    final allMarketsData = await supabase
        .rpc('get_all_markets_with_coords') // Use RPC function (fetches all)
        .select('*, location') // Ensure location is selected if needed by Market.fromJson
        .in_('id', assignedMarketIds) // Filter by assigned IDs in the RPC call if possible, otherwise filter client-side
        .order('name');

    // Client-side filtering (if RPC doesn't filter)
    // final assignedMarketsData = allMarketsData
    //     .where((marketJson) => assignedMarketIds.contains(marketJson['id'] as String))
    //     .toList();

    // Assuming RPC returns the filtered list directly based on assignedMarketIds
    final markets = allMarketsData.map((json) => Market.fromJson(json)).toList();
    return markets.map((market) => market.toJson()).toList();
  }

  void _filterMarkets() {
    final searchText = _searchController.text.toLowerCase();

    final filtered =
        _markets.where((market) {
          final nameMatches = market['name'].toLowerCase().contains(searchText);
          final addressMatches = market['address'].toLowerCase().contains(
            searchText,
          );

          bool statusMatches = true;
          if (_filterStatus != 'All') {
            statusMatches = market['status'] == _getStatusCode(_filterStatus);
          }

          bool distanceMatches = true;
          if (_filterDistance != 'All') {
            final distance = market['distance'] as double;
            switch (_filterDistance) {
              case 'Less than 1km':
                distanceMatches = distance < 1.0;
                break;
              case '1-3km':
                distanceMatches = distance >= 1.0 && distance <= 3.0;
                break;
              case 'Over 3km':
                distanceMatches = distance > 3.0;
                break;
            }
          }

          return (nameMatches || addressMatches) &&
              statusMatches &&
              distanceMatches;
        }).toList();

    setState(() {
      _filteredMarkets = filtered;
    });
  }

  String _getStatusCode(String displayStatus) {
    switch (displayStatus) {
      case 'Need to Visit':
        return 'to_visit';
      case 'Sale Made':
        return 'visited_sale';
      case 'Closed/No Sale':
        return 'visited_no_sale';
      default:
        return '';
    }
  }

  String _getStatusText(String statusCode) {
    switch (statusCode) {
      case 'to_visit':
        return 'Need to Visit';
      case 'visited_sale':
        return 'Sale Made';
      case 'visited_no_sale':
        return 'Closed/No Sale';
      default:
        return 'Unknown';
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'to_visit':
        return Icons.schedule;
      case 'visited_sale':
        return Icons.check_circle;
      case 'visited_no_sale':
        return Icons.cancel;
      default:
        return Icons.help;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'to_visit':
        return Colors.amber;
      case 'visited_sale':
        return Colors.green;
      case 'visited_no_sale':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_filteredMarkets.length} Markets',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                ToggleButtons(
                  isSelected: [!_isMapView, _isMapView],
                  onPressed: (index) {
                    setState(() {
                      _isMapView = index == 1;
                    });
                  },
                  children: const [
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16.0),
                      child: Icon(Icons.list),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16.0),
                      child: Icon(Icons.map),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child:
                _isMapView
                    ? MapScreen(
                      markets:
                          _filteredMarkets
                              .map((e) => Market.fromJson(e))
                              .toList(),
                      currentLocation: _currentLocation,
                    )
                    : _buildListView(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddMarketScreen()),
          ).then((_) => _loadInitialData()); // Refresh data after adding
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Market'),
      ),
    );
  }

  Widget _buildListView() {
    if (_filteredMarkets.isEmpty) {
      return const Center(child: Text('No markets found'));
    }

    return ListView.builder(
      itemCount: _filteredMarkets.length,
      itemBuilder: (context, index) {
        final market = _filteredMarkets[index];
        return ListTile(
          title: Text(market['name']),
          subtitle: Text(market['address'] ?? 'No address'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder:
                    (context) =>
                        MarketDetailScreen(market: Market.fromJson(market)),
              ),
            ).then((_) => _loadInitialData()); // Refresh data after viewing details
          },
        );
      },
    );
  }
}
