import 'package:flutter/material.dart';

class BigCard extends StatelessWidget {
  final String text; // Declare the text parameter
  final VoidCallback onPressed; // Declare the onPressed parameter

  const BigCard({
    super.key,
    required this.text, // Use this.text to assign the value
    required this.onPressed, // Use this.onPressed to assign the value
  });

  @override
  Widget build(BuildContext context) {
    var theme = Theme.of(context);
    var style = theme.textTheme.displayMedium!.copyWith(
      color: theme.colorScheme.onPrimary,
    );
    var screenWidth = MediaQuery.of(context).size.width;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Container(
        width: screenWidth -
            (screenWidth *
                0.30), // Set the width to take up the entire screen width
        height: 200, // Set the height to make it square
        decoration: BoxDecoration(
          color: theme.colorScheme.primary,
          borderRadius: BorderRadius.circular(8), // Optional: rounded corners
        ),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            foregroundColor: theme.colorScheme.onPrimary,
            backgroundColor: theme.colorScheme
                .primary, // Use the theme's onPrimary color for text and icons
            shape: RoundedRectangleBorder(
              borderRadius:
                  BorderRadius.circular(8), // Optional: rounded corners
            ),
          ),
          onPressed: onPressed, // Use the onPressed parameter
          child: Center(
            child: Text(
              text,
              style: style,
              textAlign: TextAlign.center, // Center the text
            ),
          ),
        ),
      ),
    );
  }
}
