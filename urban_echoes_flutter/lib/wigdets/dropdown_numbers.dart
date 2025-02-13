import 'package:flutter/material.dart';

class DropdownNumbers extends StatefulWidget {
  const DropdownNumbers({super.key});

  @override
  _DropdownNumbersState createState() => _DropdownNumbersState();
}

class _DropdownNumbersState extends State<DropdownNumbers> {
  int? _selectedNumber;

  @override
  Widget build(BuildContext context) {
    return DropdownButton<int>(
      value: _selectedNumber,
      items: List.generate(10, (index) {
        return DropdownMenuItem<int>(
          value: index + 1,
          child: Text((index + 1).toString()),
        );
      }),
      onChanged: (value) {
        setState(() {
          _selectedNumber = value;
        });
      },
    );
  }
}
