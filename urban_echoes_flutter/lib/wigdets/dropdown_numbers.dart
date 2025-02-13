import 'package:flutter/material.dart';

class DropdownNumbers extends StatefulWidget {
  final int initialValue;
  final ValueChanged<int> onChanged;

  const DropdownNumbers(
      {super.key, required this.initialValue, required this.onChanged});

  @override
  _DropdownNumbersState createState() => _DropdownNumbersState();
}

class _DropdownNumbersState extends State<DropdownNumbers> {
  late int _selectedNumber;

  @override
  void initState() {
    super.initState();
    _selectedNumber = widget.initialValue;
  }

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
          _selectedNumber = value!;
        });
        widget.onChanged(value!);
      },
    );
  }
}
