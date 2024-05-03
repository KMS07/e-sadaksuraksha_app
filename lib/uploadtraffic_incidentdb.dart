import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocation_app/NotificationServices.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'auth_screen.dart';
extension MakeItLl on Position {
  LatLng get toLatLong {
    return LatLng(latitude, longitude);
  }
}
class ReportIncidentForm extends StatefulWidget {
  @override
  const ReportIncidentForm({super.key, required this.userType});
  final UserType userType;
  _ReportIncidentFormState createState() => _ReportIncidentFormState();
}

class _ReportIncidentFormState extends State<ReportIncidentForm> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _typeController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _additionalInfoController = TextEditingController();
  StreamSubscription<Position>? locationStream;
  String _currentAddress = '';
  LatLng? userLatLong;

  NotificationServices notificationServices = NotificationServices();

  @override
  void initState() {
    super.initState();
    notificationServices.requestNotificationPermission();
    notificationServices.firebaseInit(context);
    notificationServices.setupInteractMessage(context);
    notificationServices.getDeviceToken().then((value) {
      if(kDebugMode){
        print('device token');
        print(value);
      }
    });
    getLocationInfo();
    // Start a timer to fetch the location continuously
    log('fetching');
    Timer.periodic(const Duration(seconds: 60), (Timer timer) {
      getLocationInfo();
    });
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
      return Future.error('Location permissions are permanently denied, we cannot request permissions.');
    }

    // When we reach here, permissions are granted and we can
    // continue accessing the position of the device.
    getLocationChangeInfo();
    return await Geolocator.getCurrentPosition();
  }

  getLocationChangeInfo() async{
    const locationOptions = LocationSettings(
        accuracy: LocationAccuracy.best
    );
    final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    log("hello");
    final address = await getAddressFromCoordinates(position.latitude,position.longitude);
    setState(() {
      _currentAddress = address;
      _locationController.text = _currentAddress;
    });
  }

  Future<String> getAddressFromCoordinates(double latitude, double longitude) async {
    const apiKey = 'AIzaSyAmD2yMXYYHJJnuaYii2ek8npmz2HS-lB0'; // Replace with your Google Maps API key
    final apiUrl = 'https://maps.googleapis.com/maps/api/geocode/json?latlng=$latitude,$longitude&key=$apiKey';

    final response = await http.get(Uri.parse(apiUrl));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final results = data['results'] as List<dynamic>;
      if (results.isNotEmpty) {
        return results[0]['formatted_address'];
      }
    }
    return 'Address not found';
  }
  List<String> _typeOptions = ['Traffic Jam','Traffic Accident'];
  String? _selectedType;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Report Incident'),
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<String>(
                value: _selectedType,
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedType = newValue;
                  });
                },
                items: _typeOptions.map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                decoration: InputDecoration(
                  labelText: 'Type',
                  border: OutlineInputBorder(), // Add border
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select incident type';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _locationController,
                decoration: InputDecoration(labelText: 'Location'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter location';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16.0),
              ElevatedButton(
                onPressed: getLocationChangeInfo,
                child: Text('Fetch Current Location'),
              ),
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(labelText: 'Description'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter description';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _additionalInfoController,
                decoration: InputDecoration(labelText: 'Additional Information'),
              ),
              SizedBox(height: 16.0),
              ElevatedButton(
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    // Get the values from the text fields
                    String? type =  _selectedType;
                    String location = _locationController.text;
                    String description = _descriptionController.text;
                    String additionalInfo = _additionalInfoController.text;

                    // Call the saveIncidentReport function with the values
                    saveIncidentReport(type, location, description, additionalInfo);
                  }
                },
                child: Text('Submit'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> saveIncidentReport(String? type, String location, String description, String additionalInfo) async{
    try {
      // Get a reference to the Firebase Realtime Database
      final reference = FirebaseDatabase.instance.ref();
      FirebaseAuth firebaseAuth = FirebaseAuth.instance;
      final FirebaseMessaging firebaseMessaging = FirebaseMessaging.instance;
      // Generate a unique key for the incident report
      final incidentKey = reference.child('incidents').push().key;
      if (incidentKey == null) {
        throw Exception('Error generating incident key.');
      }

      String currentUserUid = firebaseAuth.currentUser!.uid;
      // Create a map containing the incident details
      final Map<String, dynamic> incidentData = {
        'type': type,
        'location': location,
        'description': description,
        'additionalInfo': additionalInfo,
        // Add more fields as needed
      };

      // Save the incident report under the 'incidents' node with the generated key
      reference.child('incidents').child(incidentKey).set(incidentData);
      DatabaseEvent event = await reference.child('users').once();
      Map<dynamic, dynamic> usersData = event.snapshot.value as Map<dynamic, dynamic>;
      // List<String> tokens = [];
      // usersData.forEach((key, value) {
      //   // if (key != currentUserUid) {
      //     tokens.add(value['fcmtoken']);
      //   // }
      // });
      // log(tokens[0]);
      // // Prepare notification payload
      // var payload = <String, dynamic>{
      //   'notification': <String, dynamic>{
      //     'title': 'New Incident Report',
      //     'body': 'A new incident report has been submitted.',
      //   },
      //   'data': <String, dynamic>{
      //     // Additional data if needed
      //   },
      //   'tokens': tokens, // Send notification to all users except the current user
      // };
      //
      // // Send notification
      // await firebaseMessaging.send(payload);

      usersData.forEach((key, value) async{
        //if (key != currentUserUid) {
          var data = {
            'to' : value['fcmtoken'].toString(),
            'priority': 'high',
            'notification': {
              'title' : 'Incident',
              'body' : 'A $type occured at $location'
            },
          };
          await http.post(Uri.parse('https://fcm.googleapis.com/fcm/send'),
            body: jsonEncode(data),
            headers: {
            'Content-Type': 'application/json; charset=UTF-8',
            'Authorization': 'key=AAAAYW7aSaA:APA91bG9a1PzO2PSjuCXg7aUr5hy1OIPLeFFiMeJYqD1sShLeEd8j16WWNbJtnvSOY3rihqKEF0m9TC2vrqYr_IDx08wWxtPZfJwARQfdRAY55Nrz3AP7035MauVBO8yOuCXiyfGe4nP'
            }
          );
        //}
      });

      print('Incident report saved successfully!');
    } catch (e) {
      // Handle any errors that occur during the save process
      print('Error saving incident report: $e');
    }
  }
}
