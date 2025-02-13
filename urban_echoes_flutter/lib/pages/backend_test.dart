import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_state_maneger.dart';

class BackEndTest extends StatelessWidget {
  const BackEndTest({super.key});

  @override
  Widget build(BuildContext context) {
    var appState = context.watch<MyAppState>();

    return Center(
      child: FutureBuilder<void>(
        future: appState.fetchBackendMessage(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text("Backend Response:"),
                SizedBox(height: 10),
                CircularProgressIndicator(), // Show a loading indicator while fetching data
              ],
            );
          } else if (snapshot.hasError) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text("Backend Response:"),
                SizedBox(height: 10),
                Text(
                  "Failed to fetch data",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            );
          } else {
            return Column(
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
            );
          }
        },
      ),
    );
  }
}
