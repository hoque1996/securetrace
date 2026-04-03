import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

class TrackingScreen extends ConsumerStatefulWidget {
  const TrackingScreen({super.key});

  @override
  ConsumerState<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends ConsumerState<TrackingScreen> {
  GoogleMapController? _mapController;
  final LatLng _initialPosition = const LatLng(20.5937, 78.9629); // India Center
  LatLng? _currentPosition;
  final Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    _fetchCurrentLocation();
  }

  Future<void> _fetchCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      
      if (mounted) {
        setState(() {
          _currentPosition = LatLng(position.latitude, position.longitude);
          _markers.add(
            Marker(
              markerId: const MarkerId('current_device'),
              position: _currentPosition!,
              infoWindow: const InfoWindow(title: 'My Device', snippet: 'Tracking Active'),
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan),
            ),
          );
        });

        _mapController?.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(target: _currentPosition!, zoom: 15.0),
          ),
        );
      }
    } catch (e) {
      debugPrint("Error fetching location: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('LIVE TRACKING'),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location, color: Color(0xFF00E5FF)),
            onPressed: _currentPosition == null ? null : () {
              _mapController?.animateCamera(
                CameraUpdate.newCameraPosition(
                  CameraPosition(target: _currentPosition!, zoom: 16.0),
                ),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            mapType: MapType.normal,
            initialCameraPosition: CameraPosition(target: _initialPosition, zoom: 4.0),
            markers: _markers,
            onMapCreated: (GoogleMapController controller) {
              _mapController = controller;
              // If location was fetched before map initialized
              if (_currentPosition != null) {
                controller.animateCamera(
                  CameraUpdate.newCameraPosition(
                    CameraPosition(target: _currentPosition!, zoom: 16.0),
                  ),
                );
              }
            },
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
          ),
          if (_currentPosition == null)
            Container(
              color: Colors.black.withValues(alpha: 0.5),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Acquiring high-accuracy GPS...'),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
