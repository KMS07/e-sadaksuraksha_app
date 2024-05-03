import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'addemergencycontacts.dart';
import 'package:contacts_service/contacts_service.dart' as contact;

class ViewContactsScreen extends StatefulWidget {
  const ViewContactsScreen({super.key});

  @override
  State<ViewContactsScreen> createState() => _ViewContactsScreenState();
}

class _ViewContactsScreenState extends State<ViewContactsScreen> {
  FirebaseDatabase firebaseDatabase = FirebaseDatabase.instance;
  FirebaseAuth firebaseAuth = FirebaseAuth.instance;
  List<Map<String, dynamic>> contacts = [];

  @override
  void initState() {
    super.initState();
    // Fetch contacts data from Firebase
    fetchContacts();
  }

  void fetchContacts() {
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

  @override
  Widget build(BuildContext context) {
    // Build your widget using selectedContacts
    return Scaffold(
      appBar: AppBar(
        title: Text('Selected Contacts'),
      ),
      body: ListView.builder(
        itemCount: contacts.length,
        itemBuilder: (context, index) {
          final contact1 = contacts[index];
          return Dismissible(
            key: UniqueKey(),
            direction: DismissDirection.endToStart,
            onDismissed: (direction) async {
              setState(() {
                contacts.removeAt(index);
              });
              await firebaseDatabase.ref("users/${firebaseAuth.currentUser!.uid}").update({
                "contacts": contacts
              });
            },
            child: ListTile(
              title: Text(contact1["displayName"] ?? ''),
              trailing: IconButton(
                icon: const Icon(Icons.delete),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text('Delete Contact?'),
                      content: Text('Are you sure you want to delete ${contact1["displayName"]}?'),
                      actions: [
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            setState(() {
                              contacts.removeAt(index);
                            });
                            firebaseDatabase.ref("users/${firebaseAuth.currentUser!.uid}").update({
                              "contacts": contacts
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('${contact1["displayName"]} removed'),
                              ),
                            );
                          },
                          child: Text('Delete'),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                          child: Text('Cancel'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}
