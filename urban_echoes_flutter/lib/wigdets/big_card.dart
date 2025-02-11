import 'package:flutter/material.dart';

class BigCard extends StatelessWidget {
  final String text; // Declare the text parameter

  const BigCard({
    super.key,
    required this.text, // Use this.text to assign the value
  });

  @override
  Widget build(BuildContext context) {
    var theme = Theme.of(context);
    var style = theme.textTheme.displayMedium!.copyWith(
      color: theme.colorScheme.onPrimary,
    );

    return ElevatedButton(
      onPressed: () {
        print('Make observation clicked');
      },
      child: Card(
        color: theme.colorScheme.primary,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: AnimatedSize(
            duration: Duration(milliseconds: 200),
            child: MergeSemantics(
              child: Wrap(
                children: [
                  Text(
                    text, // Use the text variable here
                    style: style.copyWith(fontWeight: FontWeight.w200),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
