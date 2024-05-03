import 'dart:developer';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:geolocation_app/addemergencycontacts.dart';
import 'viewContacts.dart';
import 'RouteOptimization.dart';
import 'screens/map_widget.dart';
import 'auth_screen.dart';
import 'uploadtraffic_incidentdb.dart';
import 'emergencyassistance.dart';
class Driver_screen extends StatelessWidget {
  Driver_screen({super.key,required this.userType});
  UserType userType;
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sidebar Navigation',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      // Define routes for each screen
      routes: {
        '/': (context) => MainScreen(),
        '/routeopt': (context) => RouteOpt(),
        '/driverawareness': (context) => GoogleMapLocationScreen(userType: userType),
        '/reportincident': (context) => ReportIncidentForm(userType: userType),
        '/ea': (context) => EmergencyAssistanceScreen(),
        '/addcontacts': (context) => const AddContactsScreen(),
        '/viewcontacts': (context) => const ViewContactsScreen()
      },
    );
  }
}
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}


class _MainScreenState extends State<MainScreen> {
  bool isDriverAwarenessEnabled = true;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'e-sadaksuraksha',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.blueAccent,
      ),
      drawer: AppDrawer(
        isDriverAwarenessEnabled: isDriverAwarenessEnabled,
        toggleDriverAwareness: (bool value) {
          setState(() {
            isDriverAwarenessEnabled = value;
          });
        },
      ), // Sidebar is visible on this screen
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.blueAccent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.directions_car,
                size: 100,
                color: Colors.blueAccent,
              ),
            ),
            SizedBox(height: 20),
            Text(
              'Welcome to e-sadaksuraksha',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Stay safe on the road with our traffic safety app. Get real-time updates on traffic conditions, receive alerts about accidents or road closures, and access useful resources for safe driving.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.black54,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class AppDrawer extends StatelessWidget {
  final bool isDriverAwarenessEnabled;
  final Function(bool) toggleDriverAwareness;

  const AppDrawer({
    required this.isDriverAwarenessEnabled,
    required this.toggleDriverAwareness,
  });
  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        children: <Widget>[
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: <Widget>[
                Container(
                  height: 120, // Set the desired height
                  child: const DrawerHeader(
                    decoration: BoxDecoration(
                      color: Colors.blue,
                    ),
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 4.0),
                      child: Text(
                        'e-sadaksuraksha',
                        style: TextStyle(
                          fontSize: 24,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.alt_route,color: Colors.blueAccent),
                  title: const Text(
                    'Get optimized Route ',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.black87,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                  onTap: () {
                    Navigator.pushNamed(context, '/routeopt');
                  },
                ),
                ListTile(
                  leading: Icon(
                    Icons.report,
                    color: Colors.blueAccent,
                  ),
                  title: Text(
                    'Driver Awareness',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.black87,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                  trailing: Switch(
                    value: isDriverAwarenessEnabled,
                    onChanged: toggleDriverAwareness,
                  ),
                  onTap: () {
                    if (isDriverAwarenessEnabled) {
                      Navigator.pushNamed(context, '/driverawareness');
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.traffic,color: Colors.blueAccent),
                  title: const Text(
                    'Report traffic incidents',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.black87,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                  onTap: () {
                    Navigator.pushNamed(context, '/reportincident');
                  },
                ),
                ListTile(
                  leading: Icon(
                    Icons.local_hospital,
                    color: Colors.blueAccent,
                  ),
                  title: const Text(
                    'Emergency Assistance',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.black87,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                  onTap: () {
                    Navigator.pushNamed(context, '/ea');
                  },
                ),
                ListTile(
                  leading: Icon(
                    Icons.local_hospital,
                    color: Colors.blueAccent,
                  ),
                  title: const Text(
                    'Add Emergency Contacts',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.black87,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                  onTap: () {
                    Navigator.pushNamed(context, '/addcontacts');
                  },
                ),
                ListTile(
                  leading: Icon(
                    Icons.local_hospital,
                    color: Colors.blueAccent,
                  ),
                  title: const Text(
                    'View Contacts',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.black87,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                  onTap: () {
                    Navigator.pushNamed(context, '/viewcontacts');
                  },
                )
              ],
            ),
          ),
          FloatingActionButton(
              child: const Icon(Icons.logout),
              onPressed: () async {
                FirebaseDatabase firebaseDatabase = FirebaseDatabase.instance;
                FirebaseAuth firebaseAuth = FirebaseAuth.instance;
                await firebaseDatabase.ref("geo_location_users/${firebaseAuth.currentUser!.uid}").update({
                  "Sign_in": "No",
                });
                final DatabaseReference usersRef = firebaseDatabase.ref('users');
                final String uid = firebaseAuth.currentUser!.uid;
                log(uid);
                String? fcmToken;
                usersRef.child(uid).child('fcmtoken').get().then((DataSnapshot snapshot) {
                  if (snapshot.exists) {
                    // "fcmtoken" exists for the current user
                    fcmToken = snapshot.value as String?;
                    print('FCM Token: $fcmToken');
                  } else {
                    // "fcmtoken" does not exist for the current user
                    print('FCM Token not found for UID: $uid');
                  }});
                await firebaseAuth.signOut();
                ScaffoldMessenger.of(context)
                    .showSnackBar(const SnackBar(content: Text("User Logged Out Successfully")));
                Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (c) => AuthenticationScreen(fcmToken: fcmToken)));
              }),
        ],
      ),
    );
  }
}

