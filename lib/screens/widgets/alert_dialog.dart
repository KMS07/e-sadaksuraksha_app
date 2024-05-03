import 'package:flutter/material.dart';

import '../map_widget.dart';

class AlertDialogWidget extends StatefulWidget {
  const AlertDialogWidget({super.key});

  @override
  State<AlertDialogWidget> createState() => _AlertDialogWidgetState();
}

class _AlertDialogWidgetState extends State<AlertDialogWidget> {
  @override
  void initState() {
    super.initState();

    speedDialog = true;
  }

  @override
  void dispose() {
    super.dispose();
    speedDialog = false;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text("Your Speed is greater then 15 KM"),
      actions: [
        ElevatedButton(onPressed: (){Navigator.pop(context);speedAlert=false;}, child: Text("Okay"))
      ],
    );
  }
}
