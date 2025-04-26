import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/supabase_client.dart';

class DatabaseTestScreen extends ConsumerStatefulWidget {
  const DatabaseTestScreen({super.key});

  @override
  ConsumerState<DatabaseTestScreen> createState() => _DatabaseTestScreenState();
}

class _DatabaseTestScreenState extends ConsumerState<DatabaseTestScreen> {
  bool _isLoading = false;
  final Map<String, bool> _tableStatus = {};
  String? _error;
  bool _postgisEnabled = false;
  List<Map<String, dynamic>>? _regionsData;
  List<Map<String, dynamic>>? _marketsData;

  @override
  void initState() {
    super.initState();
    _checkDatabase();
  }

  Future<void> _checkDatabase() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Check if tables exist
      await _checkTables();

      // Check if PostGIS is enabled
      try {
        final result = await supabase.rpc('check_postgis_exists');
        setState(() {
          _postgisEnabled = result as bool;
        });
      } catch (e) {
        setState(() {
          _postgisEnabled = false;
        });
      }

      // Try to get some data
      if (_tableStatus['regions'] == true) {
        final regions = await supabase.from('regions').select().limit(5);
        setState(() {
          _regionsData = List<Map<String, dynamic>>.from(regions);
        });
      }

      if (_tableStatus['markets'] == true) {
        final markets = await supabase.rpc('get_all_markets_with_coords');
        setState(() {
          _marketsData = List<Map<String, dynamic>>.from(markets);
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _checkTables() async {
    final tables = [
      'regions',
      'vendors',
      'markets',
      'products',
      'promotions',
      'sales',
    ];

    for (final table in tables) {
      try {
        await supabase.from(table).select('id').limit(1);
        _tableStatus[table] = true;
      } catch (e) {
        _tableStatus[table] = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Database Test'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _checkDatabase,
          ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Error: $_error',
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _checkDatabase,
                      child: const Text('Try Again'),
                    ),
                  ],
                ),
              )
              : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Database Connection Status',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Icon(
                              Icons.check_circle,
                              color: Colors.green,
                              size: 32,
                            ),
                            SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                'Connected to Supabase successfully',
                                style: TextStyle(fontSize: 16),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        const Text(
                          'PostGIS Extension: ',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          _postgisEnabled ? 'Enabled' : 'Not Enabled',
                          style: TextStyle(
                            fontSize: 16,
                            color: _postgisEnabled ? Colors.green : Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Table Status',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ..._tableStatus.entries.map(
                      (entry) => _buildTableStatusRow(entry.key, entry.value),
                    ),
                    if (_regionsData != null && _regionsData!.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      const Text(
                        'Sample Regions Data',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...List.generate(
                        _regionsData!.length,
                        (index) => Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Name: ${_regionsData![index]['name']}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'Country: ${_regionsData![index]['country']}',
                                ),
                                Text('ID: ${_regionsData![index]['id']}'),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                    if (_marketsData != null && _marketsData!.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      const Text(
                        'Sample Markets Data',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...List.generate(
                        _marketsData!.length,
                        (index) => Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Name: ${_marketsData![index]['name']}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'Address: ${_marketsData![index]['address']}',
                                ),
                                Text(
                                  'Location: ${_marketsData![index]['gps_location_text']}',
                                ),
                                Text(
                                  'Status: ${_marketsData![index]['status']}',
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
    );
  }

  Widget _buildTableStatusRow(String tableName, bool exists) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            exists ? Icons.check_circle : Icons.error,
            color: exists ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 8),
          Text(tableName, style: const TextStyle(fontSize: 16)),
          const Spacer(),
          Text(
            exists ? 'Exists' : 'Missing',
            style: TextStyle(
              color: exists ? Colors.green : Colors.red,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
