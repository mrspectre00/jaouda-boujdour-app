import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';

import '../../../models/market.dart';
import '../../../services/location_service.dart';
import '../providers/markets_provider.dart';
import '../../../config/theme.dart';
import '../../../widgets/app_layout.dart';

class AddMarketScreen extends ConsumerStatefulWidget {
  const AddMarketScreen({super.key});

  @override
  ConsumerState<AddMarketScreen> createState() => _AddMarketScreenState();
}

class _AddMarketScreenState extends ConsumerState<AddMarketScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _notesController = TextEditingController();
  final _latController = TextEditingController();
  final _lngController = TextEditingController();
  final MapController _mapController = MapController();

  final _locationService = LocationService();
  bool _isLoading = false;
  String? _error;
  LatLng? _selectedLocation;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _notesController.dispose();
    _latController.dispose();
    _lngController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  void _updateLocationFields(LatLng location) {
    _latController.text = location.latitude.toStringAsFixed(6);
    _lngController.text = location.longitude.toStringAsFixed(6);
  }

  void _updateSelectedLocationFromFields() {
    final lat = double.tryParse(_latController.text);
    final lng = double.tryParse(_lngController.text);
    if (lat != null && lng != null) {
      setState(() {
        _selectedLocation = LatLng(lat, lng);
      });
      _mapController.move(_selectedLocation!, 15.0);
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final position = await _locationService.getCurrentPosition();
      final currentLatLng = LatLng(position.latitude, position.longitude);
      setState(() {
        _selectedLocation = currentLatLng;
        _isLoading = false;
        _updateLocationFields(currentLatLng);
      });
      _mapController.move(currentLatLng, 15.0);
    } catch (e) {
      setState(() {
        _error = "Failed to get current location: ${e.toString()}";
        _isLoading = false;
      });
    }
  }

  Future<void> _saveMarket() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fix the errors in the form')),
      );
      return;
    }
    if (_selectedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a location on the map')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final market = Market(
        id: '',
        name: _nameController.text.trim(),
        address: _addressController.text.trim(),
        latitude: _selectedLocation!.latitude,
        longitude: _selectedLocation!.longitude,
        notes: _notesController.text.trim(),
      );

      await ref.read(marketsProvider.notifier).addMarket(market);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Market added successfully! Pending review by admin.',
            ),
            backgroundColor: Colors.green,
          ),
        );
        context.pop();
      }
    } catch (e) {
      setState(() {
        _error = "Failed to add market: ${e.toString()}";
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final marketsState = ref.watch(marketsProvider);

    return AppLayout(
      title: 'Add New Market',
      body: _isLoading && _selectedLocation == null
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _selectedLocation == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _error!,
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _getCurrentLocation,
                        child: const Text('Retry Getting Location'),
                      ),
                    ],
                  ),
                )
              : Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextFormField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: 'Market Name',
                            prefixIcon: Icon(Icons.store),
                          ),
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                                  ? 'Please enter a market name'
                                  : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _addressController,
                          decoration: const InputDecoration(
                            labelText: 'Address',
                            prefixIcon: Icon(Icons.location_on),
                          ),
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                                  ? 'Please enter an address'
                                  : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _notesController,
                          decoration: const InputDecoration(
                            labelText: 'Notes (Optional)',
                            prefixIcon: Icon(Icons.note),
                          ),
                          maxLines: 3,
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Location',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _latController,
                                decoration: const InputDecoration(
                                  labelText: 'Latitude',
                                ),
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                                validator: (v) =>
                                    double.tryParse(v ?? '') == null
                                        ? 'Invalid'
                                        : null,
                                onChanged: (_) =>
                                    _updateSelectedLocationFromFields(),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextFormField(
                                controller: _lngController,
                                decoration: const InputDecoration(
                                  labelText: 'Longitude',
                                ),
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                                validator: (v) =>
                                    double.tryParse(v ?? '') == null
                                        ? 'Invalid'
                                        : null,
                                onChanged: (_) =>
                                    _updateSelectedLocationFromFields(),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 300,
                          child: FlutterMap(
                            mapController: _mapController,
                            options: MapOptions(
                              initialCenter: _selectedLocation ??
                                  const LatLng(27.1537, -13.2033),
                              initialZoom:
                                  _selectedLocation != null ? 15.0 : 6.0,
                              onTap: (tapPosition, point) {
                                setState(() {
                                  _selectedLocation = point;
                                  _updateLocationFields(point);
                                });
                                _mapController.move(
                                  point,
                                  _mapController.camera.zoom,
                                );
                                debugPrint('Map tapped at: $point');
                              },
                            ),
                            children: [
                              TileLayer(
                                urlTemplate:
                                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                              ),
                              if (_selectedLocation != null)
                                MarkerLayer(
                                  markers: [
                                    Marker(
                                      point: _selectedLocation!,
                                      width: 80,
                                      height: 80,
                                      child: Icon(
                                        Icons.location_pin,
                                        size: 40,
                                        color: Theme.of(context).primaryColor,
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Center(
                          child: ElevatedButton.icon(
                            onPressed: _getCurrentLocation,
                            icon: const Icon(Icons.my_location),
                            label: const Text('Use Current Location'),
                          ),
                        ),
                        const SizedBox(height: 32),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _saveMarket,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              backgroundColor: AppTheme.primaryColor,
                              foregroundColor: Colors.white,
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('Add Market'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }
}
