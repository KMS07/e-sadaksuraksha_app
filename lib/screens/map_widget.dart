import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:math' as math;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../driver_screen.dart';
import '../model/model_user_infos.dart';
import '../auth_screen.dart';
import 'widgets/alert_dialog.dart';
import 'widgets/accalert_dialog.dart';
import 'package:sensors/sensors.dart';
// import 'package:flutter_tts/flutter_tts.dart';

LatLng currentLocation = const LatLng(26.943040, 75.757060);

bool accAlert = false;
bool speedDialog = false;
bool accDialog = false;
bool speedAlert = false;
extension MakeItLl on Position {
  LatLng get toLatLong {
    return LatLng(latitude, longitude);
  }
}

class GoogleMapLocationScreen extends StatefulWidget {
  const GoogleMapLocationScreen({super.key, required this.userType});
  final UserType userType;

  @override
  State<GoogleMapLocationScreen> createState() =>
      _GoogleMapLocationScreenState();
}

class _GoogleMapLocationScreenState extends State<GoogleMapLocationScreen> {
  GoogleMapController? _mapController;
  LatLng? cameraLatLng;
  List<Marker> marker = <Marker>[];
  FirebaseDatabase firebaseDatabase = FirebaseDatabase.instance;

  StreamSubscription<Position>? locationStream;
  StreamSubscription<UserAccelerometerEvent>? accelerometerSubscription;
  double speed = 0;
  double accelerationMagnitude = 0.0;
  double threshold = 5.0;
  double previousXAcceleration = 0.0;
  double previousYAcceleration = 0.0;

  LatLng? userLatLong;

  FirebaseAuth firebaseAuth = FirebaseAuth.instance;

  int nearbyDrivers = 0;
  int nearbyDriversLocal = 0;

  int nearbyUsers = 0;
  int nearbyUsersLocal = 0;
  updateLocal() {
    log("Yes1");
    if (nearbyDrivers != nearbyDriversLocal || nearbyDriversLocal > 0) {
      log('Cond1');
      nearbyDriversLocal = nearbyDrivers;
      if (nearbyDriversLocal != 0) {
        log("Alert");
        alertUser();
      } else {
        FlutterRingtonePlayer().stop();
      }
    }
    if (nearbyUsers != nearbyUsersLocal || nearbyUsersLocal > 0) {
      log('Cond2');
      nearbyUsersLocal = nearbyUsers;
      if (nearbyUsersLocal != 0) {
        log("Alert");
        alertUser();
      } else {
        FlutterRingtonePlayer().stop();
      }
    }
  }

  manageUsers(List<ModelUserInfo> users) {
    nearbyUsers = 0;
    nearbyDrivers = 0;
    if (widget.userType == UserType.driver) {
      log("Driver");
      for (var element in users) {
        log(element.user_type.toString());
        log(UserType.pedestrian.name);
        log(element.sign_in.toString());
        if (element.user_type.toString() == UserType.pedestrian.name &&
            element.sign_in.toString() == "Yes") {
          log("Counted");
          nearbyUsers++;
          marker.add(
            Marker(
                markerId: MarkerId(element.userId!),
                position: LatLng(element.latitude!.toDouble(),
                    element.longitude!.toDouble())),
          );
        }
      }
    }
    if (widget.userType == UserType.pedestrian) {
      for (var element in users) {
        if (element.user_type.toString() == UserType.driver.name &&
            element.sign_in.toString() == "Yes") {
          nearbyDrivers++;
          marker.add(
            Marker(
                markerId: MarkerId(element.userId!),
                position: LatLng(element.latitude!.toDouble(),
                    element.longitude!.toDouble())),
          );
        }
      }
    }
    log("YEs");
    updateLocal();
  }

  getLocationInfo() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Test if location services are enabled.
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Location services are not enabled don't continue
      // accessing the position and request users of the
      // App to enable the location services.
      return Future.error('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        // Permissions are denied, next time you could try
        // requesting permissions again (this is also where
        // Android's shouldShowRequestPermissionRationale
        // returned true. According to Android guidelines
        // your App should show an explanatory UI now.
        return Future.error('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      // Permissions are denied forever, handle appropriately.
      return Future.error(
          'Location permissions are permanently denied, we cannot request permissions.');
    }

    // When we reach here, permissions are granted and we can
    // continue accessing the position of the device.
    getLocationChangeInfo();
    return await Geolocator.getCurrentPosition();
  }

  getLocationChangeInfo() {
    const locationOptions = LocationSettings(accuracy: LocationAccuracy.bestForNavigation);
    locationStream =
        Geolocator.getPositionStream(locationSettings: locationOptions)
            .listen(manageUserPosition);
  }

  manageUserPosition(Position event) async {
    speed = event.speed;
    log("speed: $speed");
    alertSpeed();
    if (userLatLong == null && _mapController != null) {
      userLatLong = event.toLatLong;
      _mapController!.animateCamera(CameraUpdate.newCameraPosition(
          CameraPosition(target: userLatLong!, zoom: 16)));
    }
    userLatLong = event.toLatLong;
    marker.add(
      Marker(
          markerId: const MarkerId("My_user"),
          position: userLatLong!,
          icon:
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan)),
    );
    await firebaseDatabase
        .ref("geo_location_users/${firebaseAuth.currentUser!.uid}")
        .update({
      "latitude": userLatLong!.latitude,
      "longitude": userLatLong!.longitude,
    });
    setState(() {});
  }
  double calculateMagnitude(List<double> acceleration) {
    double sum = 0;
    for (double value in acceleration) {
      sum += value * value;
    }
    return math.sqrt(sum);
  }
  void alertSuddenAcceleration() {
    if (accelerationMagnitude > threshold) {
      // Sudden change detected, trigger alert
      if (!accAlert) {
        accAlert = true;
        showAccAlert();
        FlutterRingtonePlayer().play(
          android: AndroidSounds.ringtone,
          ios: IosSounds.glass,
          looping: true,
          volume: 1,
          asAlarm: false,
        );
      }
    } else {
      // No sudden change, stop alert
      FlutterRingtonePlayer().stop();
      accAlert = false;
    }
  }
  void detectSharpTurn(double xAcceleration, double yAcceleration) {
    // Set a threshold value for sharp turn detection
    double threshold = 5.0;

    // Calculate the change in acceleration since the last reading
    double deltaX = xAcceleration - previousXAcceleration;
    double deltaY = yAcceleration - previousYAcceleration;

    // Calculate the magnitude of change in acceleration vector
    double deltaMagnitude = math.sqrt(deltaX * deltaX + deltaY * deltaY);

    // Update previous acceleration values for next iteration
    previousXAcceleration = xAcceleration;
    previousYAcceleration = yAcceleration;

    // Check if the change in acceleration exceeds the threshold
    if (deltaMagnitude > threshold) {
      // Sharp turn detected, take appropriate action
      print("Sharp turn detected!");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sharp turn detected!'),
        ),
      );
    }
  }
  // Function to initialize accelerometer
  void initializeAccelerometer() {
    accelerometerSubscription = userAccelerometerEvents.listen((UserAccelerometerEvent event) {
      setState(() {
        // Calculate magnitude of acceleration vector
        accelerationMagnitude = calculateMagnitude([event.x, event.y]);
        print("acceleration:${accelerationMagnitude}");
        // Call function to process accelerometer data
        alertSuddenAcceleration();
        detectSharpTurn(event.x, event.y);
      });
    });
  }

  alertSpeed() {
    if (speed > 0.5) {
      if (speedAlert == false) {
        speedAlert = true;
        showSpeedAlert();
        FlutterRingtonePlayer().play(
          android: AndroidSounds.ringtone,
          ios: IosSounds.glass,
          looping: true, // Android only - API >= 28
          volume: 1, // Android only - API >= 28
          asAlarm: false, // Android only - all APIs
        );
      }
    } else {
      FlutterRingtonePlayer().stop();
      speedAlert = false;
    }
  }

  alertUser() async {
    FlutterRingtonePlayer().play(
      android: AndroidSounds.ringtone,
      ios: IosSounds.glass,
      looping: false, // Android only - API >= 28
      volume: 1, // Android only - API >= 28
      asAlarm: false, // Android only - all APIs
    );
  }
  showAccAlert()async {
    if (accDialog) return;
    accDialog = true;
    showDialog(
        context: context,
        builder: (c) {
          return const AccAlertDialogWidget();
        });
  }
  showSpeedAlert() async {
    if (speedDialog) return;
    speedDialog = true;
    showDialog(
        context: context,
        builder: (c) {
          return const AlertDialogWidget();
        });
  }

  @override
  void initState() {
    super.initState();
    getLocationInfo();
    //initializeAccelerometer();
  }

  @override
  void dispose() {
    super.dispose();
    if (locationStream != null) locationStream!.cancel();
    if (_mapController != null) {
      _mapController!.dispose();
    }
    if (accelerometerSubscription != null) {
      accelerometerSubscription!.cancel();
      accelerometerSubscription = null; // Reset the subscription
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: widget.userType == UserType.driver? Text('Driver Awareness'):Text('Pedestrian Awareness'),
        ),

        body: StreamBuilder(
          stream: firebaseDatabase.ref("geo_location_users").onValue,
          builder:
              (BuildContext context, AsyncSnapshot<DatabaseEvent> snapshot) {
            if (snapshot.hasData && snapshot.data != null) {
              //log("Got Data....   ${snapshot.data!.snapshot.value}");
              Map serverInfo = snapshot.data!.snapshot.value as Map;
              serverInfo.removeWhere((key, value) {
                Map userData = value as Map;
                String signIn = userData['Sign_in'];
                //log('Server message of sign in: ${signIn}');
                return key == firebaseAuth.currentUser!.uid ||
                    signIn.toString() == 'No';
              });
              // log("Got Data....  with filter ${jsonEncode(serverInfo)}");
              //log("Got Data....  with filter ${serverInfo.entries.map((e) => jsonDecode(jsonEncode(e.value))).toList()}");
              List<ModelUserInfo> usersList = serverInfo.entries
                  .map((e) => ModelUserInfo.fromJson(e.value as Map))
                  .toList();
              log("usersList: ${usersList.toString()}");
              usersList.removeWhere((element) =>
                  element.userId == null && element.longitude == null ||
                  element.longitude == null);
              usersList.removeWhere((element) {
                if (userLatLong == null) return false;
                double distanceInMeters = Geolocator.distanceBetween(
                    userLatLong!.latitude,
                    userLatLong!.longitude,
                    element.latitude!.toDouble(),
                    element.longitude!.toDouble());
                log("Distance from the user: $distanceInMeters");
                return distanceInMeters > 8 ;
              });
              manageUsers(usersList);
            }
            return Scaffold(
              body: GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: currentLocation,
                  zoom: 14,
                ),
                markers: marker.toSet(),
                zoomControlsEnabled: true,
                myLocationButtonEnabled: true,
                compassEnabled: true,
                mapToolbarEnabled: true,
                myLocationEnabled: true,
                onCameraMove: (CameraPosition position) {},
                onMapCreated: (controller) {
                  _mapController = controller;
                  if (userLatLong != null) {
                    _mapController!.animateCamera(
                        CameraUpdate.newCameraPosition(
                            CameraPosition(target: userLatLong!, zoom: 16)));
                  }
                },
                onTap: (LatLng l) {
                  // cameraLatlng = l;
                  // marker.add(Marker(markerId: const MarkerId("location"), position: l));
                  // setState(() {});
                },
              ),
              floatingActionButtonLocation:
                  FloatingActionButtonLocation.startFloat,
              floatingActionButton: FloatingActionButton(
                  child: const Icon(Icons.logout),
                  onPressed: () async {
                    await firebaseDatabase
                        .ref(
                            "geo_location_users/${firebaseAuth.currentUser!.uid}")
                        .update({
                      "Sign_in": "No",
                    });
                    final String uid = firebaseAuth.currentUser!.uid;
                    await firebaseAuth.signOut();
                    final DatabaseReference usersRef =
                        firebaseDatabase.ref('users');
                    String? fcmToken;
                    usersRef
                        .child(uid)
                        .child('fcmtoken')
                        .get()
                        .then((DataSnapshot snapshot) {
                      if (snapshot.exists) {
                        // "fcmtoken" exists for the current user
                        fcmToken = snapshot.value as String?;
                        print('FCM Token: $fcmToken');
                      } else {
                        // "fcmtoken" does not exist for the current user
                        print('FCM Token not found for UID: $uid');
                      }
                    });
                    FlutterRingtonePlayer().stop();
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text("User Logged Out Successfully")));
                    Navigator.of(context).pushReplacement(MaterialPageRoute(
                        builder: (c) =>
                            AuthenticationScreen(fcmToken: fcmToken)));
                  }),
              bottomNavigationBar: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (widget.userType == UserType.driver)
                        Flexible(
                            child: Text(
                                "Near by Pedestrians....  $nearbyUsersLocal"))
                      else
                        Flexible(
                            child: Text(
                                "Near by Drivers....  $nearbyDriversLocal"))
                    ],
                  ),
                  Text("Your Speed ${(speed).toStringAsFixed(2)}KM/HR")
                ],
              ),
            );
          },
        ));
  }
}
