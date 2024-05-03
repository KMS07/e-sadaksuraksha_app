import 'package:flutter/material.dart';

import '../map_widget.dart';

class AccAlertDialogWidget extends StatefulWidget {
  const AccAlertDialogWidget({super.key});

  @override
  State<AccAlertDialogWidget> createState() => _AccAlertDialogWidgetState();
}

class _AccAlertDialogWidgetState extends State<AccAlertDialogWidget> {
  @override
  void initState() {
    super.initState();
    accDialog = true;
  }

  @override
  void dispose() {
    super.dispose();
    accDialog = false;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text("Your acceleration is greater then 5m/s2"),
      actions: [
        ElevatedButton(onPressed: (){Navigator.pop(context);accAlert=false;}, child: Text("Okay"))
      ],
    );
  }
}
