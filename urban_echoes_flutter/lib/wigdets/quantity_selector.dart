import 'package:flutter/material.dart';
import 'package:urban_echoes/wigdets/dropdown_numbers.dart';

class QuantitySelector extends StatelessWidget {
  final String birdName;
  final int? selectedNumber;
  final Function(int?) onNumberChanged;

  const QuantitySelector({
    Key? key,
    required this.birdName,
    required this.selectedNumber,
    required this.onNumberChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            RichText(
              text: TextSpan(
                text: 'Vælg mængde af ',
                style:
                    DefaultTextStyle.of(context).style.copyWith(fontSize: 15),
                children: <TextSpan>[
                  TextSpan(
                    text: birdName,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                      fontSize: 15,
                    ),
                  ),
                  TextSpan(
                    text: ' set:',
                    style: TextStyle(fontSize: 15),
                  ),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: 16),
        DropdownNumbers(
          initialValue: selectedNumber,
          onChanged: onNumberChanged,
        ),
      ],
    );
  }
}
