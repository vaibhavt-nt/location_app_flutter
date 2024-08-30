import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_background/flutter_background.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _currentLocation = 'Fetching location...';
  String _currentLocationName = 'Fetching location...';
  String _previousLocation = 'No previous location';
  String _previousLocationName = 'No previous location';
  bool _showTurnOnLocationButton =
      false; // New state variable to control button visibility
  bool permissionDenied =
      false; // New state variable to control button visibility
  bool permissionPermanentDenied =
      false; // New state variable to control button visibility
  final List<String> _locationHistory = [];

  //var for geofence and notification
  double geoFenceLatitude = 0.0;
  double geoFenceLongitude = 0.0;
  double geoFenceRadius = 0;

  TextEditingController latitudeController = TextEditingController();
  TextEditingController longitudeController = TextEditingController();
  TextEditingController radiusController = TextEditingController();

  /// Determine the current position of the device.
  ///
  /// When the location services are not enabled or permissions
  /// are denied, the `Future` will return an error.
  Future<void> _determinePosition() async {
    late LocationSettings locationSettings;

    if (defaultTargetPlatform == TargetPlatform.android) {
      // Initialize the background service
      const androidConfig = FlutterBackgroundAndroidConfig(
        notificationTitle: "Running in Background",
        notificationText:
            "Example app will continue to receive your location even when you aren't using it",
        notificationImportance: AndroidNotificationImportance.high,
        // notificationIcon:
        //     AndroidResource(name: 'app_icon', defType: 'drawable'),
      );

      bool hasPermissions = await FlutterBackground.hasPermissions;
      if (!hasPermissions) {
        // Attempt to initialize and request permissions
        bool initialized =
            await FlutterBackground.initialize(androidConfig: androidConfig);
        if (initialized) {
          bool backgroundEnabled =
              await FlutterBackground.enableBackgroundExecution();
          if (!backgroundEnabled) {
            throw Exception("Failed to enable background execution");
          }
        } else {
          throw Exception("FlutterBackground initialization failed");
        }
        hasPermissions =
            await FlutterBackground.hasPermissions; // Re-check permissions
      }

      locationSettings = AndroidSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 0,
          // forceLocationManager: true,
          // intervalDuration: const Duration(seconds: 10),
          //(Optional) Set foreground notification config to keep the app alive
          //when going to the background
          foregroundNotificationConfig: const ForegroundNotificationConfig(
            notificationText:
                "Example app will continue to receive your location even when you aren't using it",
            notificationTitle: "Running in Background",
            enableWakeLock: true,
          ));
    } else if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      locationSettings = AppleSettings(
        accuracy: LocationAccuracy.high,
        activityType: ActivityType.fitness,
        distanceFilter: 100,
        pauseLocationUpdatesAutomatically: true,
        // Only set to true if our app will be started up in the background.
        showBackgroundLocationIndicator: false,
      );
    } else if (kIsWeb) {
      locationSettings = WebSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 100,
        maximumAge: const Duration(minutes: 5),
      );
    } else {
      locationSettings = const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 100,
      );
    }

    bool serviceEnabled;
    LocationPermission permission;

    // Test if location services are enabled.
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() {
        _currentLocation = 'Location services are disabled.';
        _showTurnOnLocationButton =
            true; // Show the button when services are disabled
      });
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() {
          _currentLocation = 'Location permissions are denied';
          permissionDenied = true;
        });

        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      setState(() {
        _currentLocation =
            'Location permissions are permanently denied, we cannot request permissions. Open settings and enable location services.';
        permissionPermanentDenied = true;
        permissionDenied = false;
      });
      return;
    }

    // When we reach here, permissions are granted, and we can
    // start listening to location updates.
    setState(() {
      _showTurnOnLocationButton =
          false; // Show the button when services are disabled
      permissionDenied = false;
      permissionPermanentDenied = false;
    });

    Geolocator.getPositionStream(locationSettings: locationSettings)
        .listen((Position position) {
      setState(() {
        // Store the current location in the history before updating
        if (_currentLocation != 'Fetching location...' &&
            _currentLocation !=
                'Location permissions are permanently denied, we cannot request permissions. Open settings and enable location services.' &&
            _currentLocation != 'Location permissions are denied' &&
            _currentLocation != 'Location services are disabled.') {
          _locationHistory.add(_currentLocation);
          _previousLocation = _currentLocation;
        }
        _currentLocation =
            'Lat: ${position.latitude}, Lon: ${position.longitude}';
        //convert lat and lag to address
        getAddressFromLatLng(position.latitude, position.longitude);
        // Check if the position is within the geofence area
        _checkGeofence(position);
      });
    });
  }

  ///this is for geofencing an notification when user enter in specific area
// Define your geofence area
  bool myGeoFenceContains(double lat, double lon) {
    final distance = Geolocator.distanceBetween(
        geoFenceLatitude, geoFenceLongitude, lat, lon);
    return distance <= geoFenceRadius;
  }

// Method to check and notify
  void _checkGeofence(Position position) {
    if (myGeoFenceContains(position.latitude, position.longitude)) {
      _sendNotification();
    }
  }

// Method to send notification
  void _sendNotification() {
    // You can use a package like `flutter_local_notifications` to show notifications
    // Here's a simplified example:
    FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'geofence_channel_id',
      'Geofence Notifications',
      channelDescription: 'This channel is used for geofence notifications.',
      importance: Importance.max,
      priority: Priority.high,
    );

    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    flutterLocalNotificationsPlugin.show(
      0,
      'Geofence Alert',
      'You have entered the $geoFenceLatitude , $geoFenceLongitude!',
      platformChannelSpecifics,
      payload: 'item x',
    );
  }

  @override
  void initState() {
    super.initState();
    _determinePosition();
  }

//this is for getting address from long and lat
  Future<void> getAddressFromLatLng(double latitude, double longitude) async {
    try {
      List<Placemark> placemarks =
          await placemarkFromCoordinates(latitude, longitude);
      Placemark place = placemarks[0];
      setState(() {
        if (_currentLocationName != 'Fetching location...') {
          _previousLocationName = _currentLocationName;
        }
        _currentLocationName =
            '${place.street},${place.thoroughfare},${place.subLocality}, ${place.locality},${place.postalCode}, ${place.administrativeArea}, ${place.country}';
      });
      debugPrint(
          'Address: ${place.street}, ${place.locality}, ${place.administrativeArea}, ${place.country}');
    } catch (e) {
      setState(() {
        _currentLocationName = 'Failed to fetch address';
      });
      debugPrint('$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Location Service'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          primary: true,
          children: [
            const Text('Enter location for getting notification'),
            TextField(
              controller: latitudeController,
              onSubmitted: (value) {
                try {
                  setState(() {
                    // Convert the input value from String to double
                    double newLatitude = double.parse(value);
                    // Update the geoFenceLongitude variable with the new value
                    geoFenceLatitude = newLatitude;
                  });
                  latitudeController.clear();
                } catch (e) {
                  // Handle the error if the conversion fails
                  debugPrint('Error converting value to double: $e');
                }
              },
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(hintText: 'Enter Latitude'),
            ),
            TextField(
              controller: longitudeController,
              onSubmitted: (value) {
                try {
                  setState(() {
                    // Convert the input value from String to double
                    double newLongitude = double.parse(value);
                    // Update the geoFenceLongitude variable with the new value
                    geoFenceLongitude = newLongitude;
                  });

                  longitudeController.clear();
                } catch (e) {
                  // Handle the error if the conversion fails
                  debugPrint('Error converting value to double: $e');
                }
              },
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(hintText: 'Enter Longitude'),
            ),
            TextField(
              controller: radiusController,
              onSubmitted: (value) {
                try {
                  setState(() {
                    // Convert the input value from String to double
                    double newRadius = double.parse(value);
                    // Update the geoFenceLongitude variable with the new value
                    geoFenceRadius = newRadius;
                  });

                  radiusController.clear();
                } catch (e) {
                  // Handle the error if the conversion fails
                  debugPrint('Error converting value to double: $e');
                }
              },
              keyboardType: TextInputType.number,
              decoration:
                  const InputDecoration(hintText: 'Enter Radius in meter'),
            ),
            const Center(
                child: Text('You will be notified when you reach location')),
            Text('geoFenceLatitude : $geoFenceLatitude'),
            Text('geoFenceLongitude : $geoFenceLongitude'),
            Text('geoFenceRadius : $geoFenceRadius'),
            ElevatedButton(
                onPressed: () async {
                  await _determinePosition();
                  debugPrint('refreshed');
                },
                child: const Text('refresh')),
            if (_showTurnOnLocationButton == true)
              ElevatedButton(
                  onPressed: () async {
                    await Geolocator.openAppSettings();
                    await Geolocator.openLocationSettings();
                    await _determinePosition();
                    setState(() {
                      _showTurnOnLocationButton =
                          false; // Show the button when services are disabled
                    });
                  },
                  child: const Text('turn on location')),
            if (permissionDenied == true)
              ElevatedButton(
                  onPressed: () async {
                    LocationPermission permission =
                        await Geolocator.requestPermission();
                    setState(() {
                      permission;
                    });
                    await _determinePosition();
                  },
                  child: const Text('enable location')),
            if (permissionPermanentDenied == true)
              ElevatedButton(
                  onPressed: () async {
                    await Geolocator.openAppSettings();
                    await Geolocator.openLocationSettings();
                    await _determinePosition();
                  },
                  child: const Text('ask for location permission')),
            Text(
              'Current Location: $_currentLocation',
              style: const TextStyle(fontSize: 16),
            ),
            Text(
              'Current Location Name: $_currentLocationName',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 10),
            Text(
              'Previous Location: $_previousLocation',
              style: const TextStyle(fontSize: 16),
            ),
            Text(
              'Previous Location Name: $_previousLocationName',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 20),
            if (_locationHistory.isNotEmpty)
              ListView.builder(
                shrinkWrap: true,
                primary: false,
                itemCount: _locationHistory.length,
                reverse: true,
                itemBuilder: (context, index) {
                  return Text(_locationHistory[index]);
                },
              ),
          ],
        ),
      ),
    );
  }
}
