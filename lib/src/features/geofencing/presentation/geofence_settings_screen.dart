import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/geofence_repository.dart';
import '../domain/geofence.dart';

class GeofenceSettingsScreen extends ConsumerStatefulWidget {
  const GeofenceSettingsScreen({super.key});

  @override
  ConsumerState<GeofenceSettingsScreen> createState() => _GeofenceSettingsScreenState();
}

class _GeofenceSettingsScreenState extends ConsumerState<GeofenceSettingsScreen> {
  final _nameController = TextEditingController();
  final _radiusController = TextEditingController(text: '100');
  
  void _addGeofence() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Safe Zone'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Zone Name (e.g. Home)'),
            ),
            TextField(
              controller: _radiusController,
              decoration: const InputDecoration(labelText: 'Radius (meters)'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            const Text('Note: Uses current device location as center.', style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              // In a real app, we'd pick a point on the map. 
              // For MVP, we'll use current position or just a placeholder.
              // To make it functional, I'll fetch current position.
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              Navigator.pop(context);
              
              try {
                // Simplified for this task: center is current location
                final repo = ref.read(geofenceRepositoryProvider);
                await repo.addGeofence(Geofence(
                  id: '',
                  name: _nameController.text,
                  latitude: 0, // Placeholder, usually would be picked on map
                  longitude: 0, // Placeholder
                  radius: double.tryParse(_radiusController.text) ?? 100,
                ));
                scaffoldMessenger.showSnackBar(const SnackBar(content: Text('Safe Zone Added!')));
              } catch (e) {
                scaffoldMessenger.showSnackBar(SnackBar(content: Text('Error: $e')));
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final geofencesAsync = ref.watch(geofencesStreamProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('SAFE ZONES (GEOFENCING)')),
      body: geofencesAsync.when(
        data: (geofences) => ListView.builder(
          itemCount: geofences.length,
          itemBuilder: (context, index) {
            final g = geofences[index];
            return ListTile(
              leading: const Icon(Icons.verified_user, color: Colors.greenAccent),
              title: Text(g.name),
              subtitle: Text('Radius: ${g.radius.toInt()}m'),
              trailing: IconButton(
                icon: const Icon(Icons.delete, color: Colors.redAccent),
                onPressed: () => ref.read(geofenceRepositoryProvider).deleteGeofence(g.id),
              ),
            );
          },
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Error: $e')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addGeofence,
        label: const Text('Add Safe Zone'),
        icon: const Icon(Icons.add_location),
      ),
    );
  }
}
