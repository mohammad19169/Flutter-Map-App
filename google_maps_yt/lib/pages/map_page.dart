import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
//import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:location/location.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final Location _locationController = Location();
  final Completer<GoogleMapController> _mapController = Completer();
  LatLng? _currentP;
  Map<PolylineId, Polyline> polylines = {};
  StreamSubscription<LocationData>? _locationSubscription;

  @override
  void initState() {
    super.initState();
    _initializeLocation();
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initializeLocation() async {
    try {
      await _locationController.changeSettings(
        accuracy: LocationAccuracy.high,
        interval: 1000, 
        distanceFilter: 10, 
      );

      bool serviceEnabled = await _locationController.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await _locationController.requestService();
        if (!serviceEnabled) {
          throw Exception('Location services are disabled');
        }
      }

      PermissionStatus permissionGranted = await _locationController.hasPermission();
      if (permissionGranted == PermissionStatus.denied) {
        permissionGranted = await _locationController.requestPermission();
        if (permissionGranted != PermissionStatus.granted) {
          throw Exception('Location permissions are denied');
        }
      }

      final LocationData locationData = await _locationController.getLocation();
      _updateLocation(locationData);

      _locationSubscription = _locationController.onLocationChanged.listen(
        _updateLocation,
        onError: (error) {
          debugPrint('Location subscription error: $error');
        },
      );
    } catch (e) {
      debugPrint('Error initializing location: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error getting location: $e')),
        );
      }
    }
  }

  void _updateLocation(LocationData locationData) {
    if (locationData.latitude == null || locationData.longitude == null) return;

    if (mounted) {
      setState(() {
        _currentP = LatLng(locationData.latitude!, locationData.longitude!);
      });
      _cameraToPosition(_currentP!);
    }
  }

  Future<void> _cameraToPosition(LatLng pos) async {
    try {
      final GoogleMapController controller = await _mapController.future;
      CameraPosition newCameraPosition = CameraPosition(
        target: pos,
        zoom: 15, 
        tilt: 0, 
        bearing: 0, 
      );
      await controller.animateCamera(
        CameraUpdate.newCameraPosition(newCameraPosition),
      );
    } catch (e) {
      debugPrint('Error moving camera: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _currentP == null
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Getting your location...'),
                ],
              ),
            )
          : GoogleMap(
              myLocationEnabled: true, 
              myLocationButtonEnabled: true, 
              zoomControlsEnabled: true,
              onMapCreated: (GoogleMapController controller) {
                if (!_mapController.isCompleted) {
                  _mapController.complete(controller);
                }
              },
              initialCameraPosition: CameraPosition(
                target: _currentP!,
                zoom: 15,
              ),
              markers: {
                Marker(
                  markerId: const MarkerId("_currentLocation"),
                  icon: BitmapDescriptor.defaultMarker,
                  position: _currentP!,
                  infoWindow: const InfoWindow(title: "Current Location"),
                ),
              },
            ),
    );
  }
}