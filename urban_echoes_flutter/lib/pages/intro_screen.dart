import 'package:flutter/material.dart';
import 'package:introduction_screen/introduction_screen.dart';

class IntroScreen extends StatelessWidget {
  final VoidCallback onDone;

  IntroScreen({required this.onDone});

  @override
  Widget build(BuildContext context) {
    return IntroductionScreen(
      showSkipButton: true,
      skip: const Text("Skip"),
      showNextButton: false,
      back: const Icon(Icons.arrow_back),
      done: const Text("Done"),
      pages: [
        PageViewModel(
          title: "Welcome",
          body: "This is the first page of the introduction.",
          image: Center(child: Icon(Icons.info, size: 100)),
        ),
        PageViewModel(
          title: "Features",
          body: "This is the second page of the introduction.",
          image: Center(child: Icon(Icons.featured_play_list, size: 100)),
        ),
        PageViewModel(
          title: "Get Started",
          body: "This is the third page of the introduction.",
          image: Center(child: Icon(Icons.start, size: 100)),
        ),
      ],
      onDone: onDone,
    );
  }
}