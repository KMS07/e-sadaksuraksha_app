import 'dart:developer';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'map_widget.dart';

enum UserType { driver, pedestrian }

class AuthenticationScreen extends StatefulWidget {
  const AuthenticationScreen({super.key});

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
      if (firebaseAuth.currentUser == null) return;
      log("Current User....   ${firebaseAuth.currentUser}");
      await firebaseDatabase.ref("geo_location_users/${firebaseAuth.currentUser!.uid}").set({
        "user_id": firebaseAuth.currentUser!.uid,
        "user_type": userType.name,
        "user_email": firebaseAuth.currentUser!.email ?? "",
        "user_name": firebaseAuth.currentUser!.displayName ?? "",
        "Sign_in": "Yes"
      });
    } catch (e) {
      throw Exception(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          RadioListTile(
              value: UserType.driver,
              groupValue: userType,
              title: const Text("Driver"),
              onChanged: (v) {
                if (v == null) return;
                userType = v;
                setState(() {});
              }),
          RadioListTile(
              value: UserType.pedestrian,
              groupValue: userType,
              title: const Text("Pedestrian"),
              onChanged: (v) {
                if (v == null) return;
                userType = v;
                setState(() {});
              }),
          ElevatedButton(
            onPressed: () {
              signInUser().then((value) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("User Signed in Successfully")));
                // Navigator.of(context)
                //     .pushReplacement(MaterialPageRoute(builder: (c) => GoogleMapLocationScreen(
                //   userType: userType,
                // )));
              });
            },
            child: const Text("Signin In"),
          ),
        ],
      ),
    );
  }
}
