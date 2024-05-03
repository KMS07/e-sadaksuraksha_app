import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:contacts_service/contacts_service.dart' as contact;
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
//import 'package:sms/sms.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:telephony/telephony.dart';
import 'package:permission_handler/permission_handler.dart';

class EmergencyAssistanceScreen extends StatefulWidget {
  @override
  _EmergencyAssistanceScreenState createState() =>
      _EmergencyAssistanceScreenState();
}

class _EmergencyAssistanceScreenState extends State<EmergencyAssistanceScreen> {
  List<Map<String, dynamic>> contacts = [];
  FirebaseDatabase firebaseDatabase = FirebaseDatabase.instance;
  FirebaseAuth firebaseAuth = FirebaseAuth.instance;
  @override
  void initState() {
    super.initState();
    fetchContactsFromDB();
  }

  void fetchContactsFromDB() {
    firebaseDatabase
        .ref("users/${firebaseAuth.currentUser!.uid}/contacts")
        .get()
        .then((DataSnapshot snapshot) {
      if (snapshot.value != null) {
        // Access the 'contacts' field directly from the snapshot value
        var contactsData = snapshot.value;
        if (contactsData is List<dynamic>) {
          // Convert the contactsList to List<Map<String, dynamic>>
          setState(() {
            contacts = contactsData.map<Map<String, dynamic>>((contact) {
              // Convert each contact to a map
              return {
                "displayName": contact['displayName'],
                "phoneNumber": contact['phoneNumber'],
              };
            }).toList();
          });
        } else {
          print("Data is not a list");
        }
      } else {
        print("Data is null");
      }
    }).catchError((error) {
      print("Error: $error");
    });
  }

  Future<void> _sendEmergencySMS() async {
    // Get user's live location
    Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
    bool snackBarShown = false;
    // Prepare SMS message
    String message =
        "Emergency! I need your help. My current location is: https://maps.google.com/?q=${position.latitude},${position.longitude}";

    // Send SMS to emergency contacts
    for (var c in contacts) {
      // Assuming the phone number is stored in the first phone field
      String? phoneNumber = c["phoneNumber"];
      if (phoneNumber != null) {
        // SmsSender sender = SmsSender();
        // SmsMessage smsMessage = SmsMessage(phoneNumber, message);
        // sender.sendSms(smsMessage);
        final telephony = Telephony.instance;

        // Define the recipient phone number and message content
        String recipient = phoneNumber; // Replace with actual phone number
        // Send the SMS
        await telephony.sendSms(
          to: recipient,
          message: message,
          statusListener: (SendStatus status) {
            if (!snackBarShown) {
              // Check if SnackBar has already been shown
              snackBarShown =
                  true; // Set the flag to true to prevent showing the SnackBar multiple times
              if (status == SendStatus.SENT) {
                // SMS sent successfully
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('SMS sent successfully.'),
                    backgroundColor: Colors.green,
                  ),
                );
              } else {
                // Error occurred while sending SMS
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Failed to send SMS.'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }
          },
        );
      }
    }
  }

  Future<void> _makeEmergencyCall() async {
    const String emergencyNumber = 'tel:112';
    // if (await canLaunch(emergencyNumber)) {
    //   await launch(emergencyNumber);
    // } else {
    //   throw 'Could not launch $emergencyNumber';
    // }
    if (await Permission.phone.request().isGranted) {
      if (await canLaunch(emergencyNumber)) {
        await launch(emergencyNumber);
      }
    } else {
      // Handle if permission is not granted
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Permission Denied'),
          content:
              Text('You need to grant phone call permission to make a call.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text('Emergency Assistance'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                  onPressed: () {
                    _sendEmergencySMS();
                  },
                  child: const Text(
                    'Click here to send SMS to emergency contacts',
                    style: TextStyle(
                      fontSize: 16.0,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20.0, vertical: 15.0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.0),
                    ),
                  )),
              SizedBox(
                  height:
                      20), // Add vertical spacing between the button and the row
              Row(
                mainAxisAlignment: MainAxisAlignment
                    .center, // Align items to the center horizontally
                children: [
                  const Text(
                    'SOS call',
                    style: TextStyle(
                      fontSize: 18.0,
                      fontWeight: FontWeight.bold,
                    ),
                  ), // Text to the left of the button
                  SizedBox(
                      width:
                          10), // Add horizontal spacing between the text and the button
                  FloatingActionButton(
                    onPressed: () {
                      _makeEmergencyCall();
                    },
                    child: Icon(Icons.warning),
                    backgroundColor: Colors.red,
                  ),
                ],
              ),
            ],
          ),
        ));
  }
}

class ContactListPage extends StatefulWidget {
  @override
  ContactListPageScreen createState() => ContactListPageScreen();
}

class ContactListPageScreen extends State<ContactListPage> {
  List<contact.Contact> emergencyContacts = [];
  Set<int> selectedIndices = Set();

  @override
  void initState() {
    super.initState();
    _getPermission();
  }

  Future<void> _getPermission() async {
    if (await Permission.contacts.request().isGranted) {
      // Permission is granted
      _fetchContacts();
    }
  }

  Future<void> _fetchContacts() async {
    List<contact.Contact> contacts =
        await contact.ContactsService.getContacts(withThumbnails: false);
    setState(() {
      emergencyContacts = contacts.toList();
    });
  }

  Future<void> _sendEmergencySMS() async {
    // Get user's live location
    Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);

    // Prepare SMS message
    String message =
        "Emergency! I need your help. My current location is: https://maps.google.com/?q=${position.latitude},${position.longitude}";

    // Send SMS to emergency contacts
    for (int index in selectedIndices) {
      contact.Contact contact1 = emergencyContacts[index];
      // Assuming the phone number is stored in the first phone field
      String? phoneNumber = contact1.phones?.first.value;
      if (phoneNumber != null) {
        // SmsSender sender = SmsSender();
        // SmsMessage smsMessage = SmsMessage(phoneNumber, message);
        // sender.sendSms(smsMessage);
        final telephony = Telephony.instance;

        // Define the recipient phone number and message content
        String recipient = phoneNumber; // Replace with actual phone number
        // Send the SMS
        await telephony.sendSms(to: recipient, message: message);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Retrieve emergency contacts here
    return Scaffold(
        appBar: AppBar(
          title: Text('Emergency Contacts'),
        ),
        body: Column(children: [
          Text('Emergency contacts list goes here'),
          Expanded(
            child: ListView.builder(
              itemCount: emergencyContacts.length,
              itemBuilder: (context, index) {
                contact.Contact contact1 = emergencyContacts[index];
                return ListTile(
                  title: Text(contact1.displayName ?? ''),
                  // Handle selecting/deselecting contacts
                  onTap: () {
                    setState(() {
                      // Toggle selection
                      if (selectedIndices.contains(index)) {
                        selectedIndices.remove(index);
                      } else {
                        selectedIndices.add(index);
                      }
                    });
                  },
                  // Show selected status visually
                  leading: selectedIndices.contains(index)
                      ? const Icon(Icons.check_circle, color: Colors.green)
                      : const Icon(Icons.circle),
                );
              },
            ),
          ),
          FloatingActionButton(
            onPressed: () {
              // Send emergency SMS
              _sendEmergencySMS();
            },
            child: const Icon(Icons.warning),
          ),
        ]));
  }
}
