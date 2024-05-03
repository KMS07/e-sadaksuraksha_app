import 'dart:developer';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:geolocation_app/driver_screen.dart';
import 'package:geolocation_app/screens/auth_screen.dart';
import 'package:geolocation_app/screens/map_widget.dart';
import 'package:geolocation_app/viewContacts.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';
import 'package:contacts_service/contacts_service.dart' as contact;
import 'firebase_options.dart';


@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // If you're going to use other Firebase services in the background, such as Firestore,
  // make sure you call `initializeApp` before using other Firebase services.
  // await Firebase.initializeApp();

  print("Handling a background message: ${message.messageId}");
}
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  requestNotifyPermission();
  await FirebaseMessaging.instance.setAutoInitEnabled(true);
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    print('Got a message whilst in the foreground!');
    print('Message data: ${message.data}');

    if (message.notification != null) {
      print('Message also contained a notification: ${message.notification}');
    }
  });
  final fcmToken = await FirebaseMessaging.instance.getToken();
  print('fcm token: $fcmToken');
  runApp(
    MyApp(fcmToken: fcmToken)
  );
}
Future<void> requestNotifyPermission() async {
  FirebaseMessaging messaging = FirebaseMessaging.instance;

  NotificationSettings settings = await messaging.requestPermission(
    alert: true,
    announcement: true,
    badge: true,
    carPlay: false,
    criticalAlert: true,
    provisional: true,
    sound: true,
  );

  print('User granted permission: ${settings.authorizationStatus}');
}
enum UserType { driver, pedestrian }

class MyApp extends StatelessWidget {
  final String? fcmToken;
  const MyApp({super.key, required this.fcmToken});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        title: 'Sidebar Navigation',
        theme: ThemeData(
          primarySwatch: Colors.blue,
        ),
        home: AuthenticationScreen(fcmToken: fcmToken)
    );
  }
}
class AuthenticationScreen extends StatefulWidget {
  final String? fcmToken;
  const AuthenticationScreen({super.key, required this.fcmToken});


  @override
  State<AuthenticationScreen> createState() => _AuthenticationScreenState();

}

class _AuthenticationScreenState extends State<AuthenticationScreen> {
  UserType userType = UserType.driver;

  FirebaseDatabase firebaseDatabase = FirebaseDatabase.instance;
  FirebaseAuth firebaseAuth = FirebaseAuth.instance;

  Future signInUser() async {
    try {
      // Trigger the authentication flow
      await GoogleSignIn().signOut();
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();

      // Obtain the auth details from the request
      final GoogleSignInAuthentication? googleAuth = await googleUser?.authentication;

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth?.accessToken,
        idToken: googleAuth?.idToken,
      );

      // Once signed in, return the UserCredential
      await firebaseAuth.signInWithCredential(credential);

      FirebaseMessaging firebaseMessaging = FirebaseMessaging.instance;
      String? token = await firebaseMessaging.getToken();

      if (firebaseAuth.currentUser == null) return;
      log("Current User....   ${firebaseAuth.currentUser}");
      await firebaseDatabase.ref("geo_location_users/${firebaseAuth.currentUser!.uid}").set({
        "user_id": firebaseAuth.currentUser!.uid,
        "user_type": userType.name,
        "user_email": firebaseAuth.currentUser!.email ?? "",
        "user_name": firebaseAuth.currentUser!.displayName ?? "",
        "Sign_in": "Yes"
      });
      await firebaseDatabase.ref("users/${firebaseAuth.currentUser!.uid}").update({
        "user_id": firebaseAuth.currentUser!.uid,
        "fcmtoken": widget.fcmToken,
      });
    } catch (e) {
      throw Exception(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'e-sadaksuraksh', // Title of the app
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
              color: Colors.white
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.blueAccent, // Customize app bar color as needed
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Login',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 20), // Add spacing between title and radio buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                customRadioListTile(
                  title: "Driver",
                  value: UserType.driver,
                  icon: Image.asset(
                    'assets/driver_icon.jpg', // Placeholder for driver icon
                    width: 50,
                    height: 50,
                  ),
                ),
                SizedBox(width: 20),
                customRadioListTile(
                  title: "Pedestrian",
                  value: UserType.pedestrian,
                  icon: Icon(
                    Icons.directions_walk, // Placeholder for pedestrian icon
                    size: 50,
                    color: Colors.black,
                  ),
                ),
              ],
            ),

            SizedBox(height: 20), // Add spacing between radio buttons and button
            ElevatedButton(
              onPressed: () {
                signInUser().then((value) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("User Signed in Successfully"),
                    ),
                  );
                  if (userType == UserType.driver) {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (c) => Driver_screen(
                          userType: userType,
                        ),
                      ),
                    );
                  } else {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (c) => GoogleMapLocationScreen(
                          userType: userType,
                        ),
                      ),
                    );
                  }
                });
              },
              child: const Text("Sign In"),
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.black, // text color
                elevation: 5, // elevation
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10), // rounded corners
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  Widget customRadioListTile({
    required String title,
    required UserType value,
    required Widget icon,
  }) {
    return GestureDetector(
      onTap: () {
        setState(() {
          userType = value;
        });
      },
      child: Container(
        padding: EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: userType == value ? Colors.blue.withOpacity(0.2) : Colors.transparent,
          border: Border.all(
            color: userType == value ? Colors.blue : Colors.grey,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            icon,
            SizedBox(height: 10),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: userType == value ? Colors.blue : Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
