import 'package:flutter/material.dart';

class BigCustomButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final String? imageUrl;
  final double? width;
  final double? height;

  const BigCustomButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.imageUrl,
    this.width,
    this.height,
  });

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
        width: width ?? screenWidth - (screenWidth * 0.30),
        height: height ??
            (imageUrl != null ? screenHeight * 0.60 : screenHeight * 0.20),
        decoration: BoxDecoration(
          color: onPressed != null ? theme.colorScheme.primary : Colors.grey,
          borderRadius: BorderRadius.circular(8),
          image: imageUrl != null
              ? DecorationImage(
                  image: AssetImage(imageUrl!),
                  fit: BoxFit.cover,
                )
              : null,
        ),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            foregroundColor: theme.colorScheme.onPrimary,
            backgroundColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onPressed: onPressed,
          child: Center(
            child: Text(
              text,
              style: style,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
