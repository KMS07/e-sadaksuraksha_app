import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:contacts_service/contacts_service.dart' as contact;
import 'package:geolocation_app/viewContacts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

class AddContactsScreen extends StatefulWidget {
  const AddContactsScreen({super.key});

  @override
  State<AddContactsScreen> createState() => _AddContactsScreenState();
}

class _AddContactsScreenState extends State<AddContactsScreen> {
  List<contact.Contact> emergencyContacts = [];
  List<contact.Contact> selectedEmergencyContacts = [];
  Set<int> selectedIndices = Set();
  List<Map<String, dynamic>> contacts = [];
  FirebaseDatabase firebaseDatabase = FirebaseDatabase.instance;
  FirebaseAuth firebaseAuth = FirebaseAuth.instance;
  @override
  void initState() {
    super.initState();
    _getPermission();
    fetchContactsFromDB();
  }
  void fetchContactsFromDB() {
    firebaseDatabase.ref("users/${firebaseAuth.currentUser!.uid}/contacts").get().then((DataSnapshot snapshot) {
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
  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      duration: Duration(seconds: 2), // Adjust duration as needed
    ));
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
                        bool found = false;
                        for(var x in contacts) {
                          if (x['phoneNumber'] == contact1.phones?.first.value) {
                            _showErrorMessage("Contact already exists!");
                            found = true;
                          }
                        }
                        print(found);
                        if(!found){
                          selectedIndices.add(index);
                        }
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
          ElevatedButton(
            onPressed: () async {
              // Add the selected contacts to list
              for(int i = 0; i<selectedIndices.length;i++){
                contacts.add({
                  'displayName': emergencyContacts[selectedIndices.elementAt(i)].displayName,
                  'phoneNumber': emergencyContacts[selectedIndices.elementAt(i)].phones?.first.value
                });
              }
              await firebaseDatabase.ref("users/${firebaseAuth.currentUser!.uid}").update({
                "contacts":contacts
              });
            },
            child: const Text('Add Contacts'),
          )
        ]));
  }
}
