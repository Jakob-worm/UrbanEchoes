import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:urban_echoes/main.dart';

class BackEndTest extends StatelessWidget {
  const BackEndTest({super.key});

  @override
  Widget build(BuildContext context) {
    var appState = context.watch<MyAppState>();

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text("Backend Response:"),
          SizedBox(height: 10),
          Text(
            appState.backendMessage,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
