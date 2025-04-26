import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

class AddMarketScreen extends StatefulWidget {
  const AddMarketScreen({super.key});

  @override
  State<AddMarketScreen> createState() => _AddMarketScreenState();
}

class _AddMarketScreenState extends State<AddMarketScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _latitudeController = TextEditingController();
  final _longitudeController = TextEditingController();
  final _notesController = TextEditingController();
  bool _isLoading = false;
  LatLng? _selectedLocation;

  @override
  void initState() {
    super.initState();
    // Set default location (Boujdour)
    _latitudeController.text = '26.1258';
    _longitudeController.text = '-14.4842';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  // Pick location on map
  void _pickLocation() async {
    // In a real app, this would open a map to pick location
    // For now, we'll just show a placeholder message
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Location picker placeholder - would open map screen'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  // Submit form
  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      // Get form values
      final name = _nameController.text;
      final address = _addressController.text;
      final latitude = double.tryParse(_latitudeController.text) ?? 0;
      final longitude = double.tryParse(_longitudeController.text) ?? 0;
      final notes = _notesController.text;

      // Create market data
      final marketData = {
        'id': 'market_${DateTime.now().millisecondsSinceEpoch}',
        'name': name,
        'address': address,
        'latitude': latitude,
        'longitude': longitude,
        'notes': notes,
        'status': 'to_visit',
        'distance': 0.0, // would be calculated in real app
      };

      // Simulate network delay
      await Future.delayed(const Duration(seconds: 1));

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        // Return to previous screen with the new market data
        Navigator.pop(context, marketData);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add New Market'), elevation: 0),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Name field
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Market Name *',
                  hintText: 'Enter market name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a market name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Address field
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(
                  labelText: 'Address *',
                  hintText: 'Enter market address',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter an address';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Coordinates section
              const Text(
                'Coordinates',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  // Latitude field
                  Expanded(
                    child: TextFormField(
                      controller: _latitudeController,
                      decoration: const InputDecoration(
                        labelText: 'Latitude *',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Required';
                        }
                        if (double.tryParse(value) == null) {
                          return 'Invalid number';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Longitude field
                  Expanded(
                    child: TextFormField(
                      controller: _longitudeController,
                      decoration: const InputDecoration(
                        labelText: 'Longitude *',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Required';
                        }
                        if (double.tryParse(value) == null) {
                          return 'Invalid number';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Pick location button
              OutlinedButton.icon(
                onPressed: _pickLocation,
                icon: const Icon(Icons.map),
                label: const Text('Pick Location on Map'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
              const SizedBox(height: 16),

              // Notes field
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Notes (Optional)',
                  hintText: 'Any additional information about this market',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 32),

              // Submit button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitForm,
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child:
                      _isLoading
                          ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                          : const Text(
                            'ADD MARKET',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
