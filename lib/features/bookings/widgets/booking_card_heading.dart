import 'package:flutter/material.dart';

class BookingCardHeading extends StatelessWidget {
  const BookingCardHeading({
    super.key,
    required this.name,
    required this.guests,
  });
  final String name;
  final int guests;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            name.isEmpty ? 'Cliente' : name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          '${guests}p',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}
