import 'package:flutter/material.dart';

class BigCustomButton extends StatelessWidget {
  final String text; // Declare the text parameter
  final VoidCallback onPressed; // Declare the onPressed parameter
  final String? imageUrl; // Declare the optional imageUrl parameter
  final double? width; // Declare the optional width parameter ()
  final double? height; // Declare the optional height parameter ()

  const BigCustomButton(
      {super.key,
      required this.text, // Use this.text to assign the value
      required this.onPressed, // Use this.onPressed to assign the value
      this.imageUrl, // Use this.imageUrl to assign the value
      this.width, // Use this.width to assign the value}
      this.height}); // Use this.height to assign the value

  @override
  Widget build(BuildContext context) {
    var theme = Theme.of(context);
    var style = theme.textTheme.displayMedium!.copyWith(
      color: theme.colorScheme.onPrimary,
    );
    var screenWidth = MediaQuery.of(context).size.width;
    var screenHeight = MediaQuery.of(context).size.height;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Container(
        width: width ??
            screenWidth -
                (screenWidth * 0.30), // Use the provided width or default value
        height: height ??
            (imageUrl != null
                ? screenHeight * 0.60
                : screenHeight *
                    0.20), // Use the provided height or default value
        decoration: BoxDecoration(
          color: theme.colorScheme.primary,
          borderRadius: BorderRadius.circular(8), // Optional: rounded corners
          image: imageUrl != null
              ? DecorationImage(
                  image:
                      AssetImage(imageUrl!), // Use AssetImage for local assets
                  fit: BoxFit.cover,
                )
              : null,
        ),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            foregroundColor: theme.colorScheme.onPrimary,
            backgroundColor:
                Colors.transparent, // Make the button background transparent
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
