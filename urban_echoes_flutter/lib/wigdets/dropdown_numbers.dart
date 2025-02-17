import 'package:flutter/material.dart';

class DropdownNumbers extends StatefulWidget {
  final int? initialValue;
  final ValueChanged<int> onChanged;

  const DropdownNumbers({
    super.key,
    required this.initialValue,
    required this.onChanged,
  });

  @override
  _DropdownNumbersState createState() => _DropdownNumbersState();
}

class _DropdownNumbersState extends State<DropdownNumbers> {
  int? _selectedNumber;

  @override
  void initState() {
    super.initState();
    _selectedNumber = widget.initialValue;
  }

  @override
  Widget build(BuildContext context) {
    return DropdownButton<int?>(
      value: _selectedNumber,
      hint: Text('Select amount'),
      items: [
        DropdownMenuItem<int?>(
          value: null,
          child: Text('Select amount'),
        ),
        ...List.generate(10, (index) {
          return DropdownMenuItem<int?>(
            value: index + 1,
            child: Text((index + 1).toString()),
          );
        }),
      ],
      onChanged: (value) {
        setState(() {
          _selectedNumber = value;
        });
        if (value != null) {
          widget.onChanged(value);
        }
      },
    );
  }
}
