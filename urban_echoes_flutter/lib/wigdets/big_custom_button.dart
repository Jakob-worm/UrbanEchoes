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
      child: SizedBox(
        width: width ?? screenWidth * 0.70,
        height: height ?? (imageUrl != null ? screenHeight * 0.40 : screenHeight * 0.20),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            foregroundColor: theme.colorScheme.onPrimary,
            backgroundColor: onPressed != null ? theme.colorScheme.primary : Colors.grey,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            padding: EdgeInsets.zero,
          ),
          onPressed: onPressed,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              image: imageUrl != null
                  ? DecorationImage(
                      image: AssetImage(imageUrl!),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: Container(
              alignment: Alignment.center,
              child: Text(
                text,
                style: style,
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
