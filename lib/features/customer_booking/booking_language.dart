import 'package:flutter/material.dart';

String _initialBookingLanguage() {
  final code = WidgetsBinding.instance.platformDispatcher.locale.languageCode;
  return code.toLowerCase() == 'it' ? 'it' : 'en';
}

final ValueNotifier<String> bookingLanguage = ValueNotifier<String>(
  _initialBookingLanguage(),
);

const bookingSupportedLocales = <Locale>[Locale('it', 'IT'), Locale('en')];

Locale get bookingLocale => bookingLanguage.value == 'it'
    ? const Locale('it', 'IT')
    : const Locale('en');

bool bookingIsItalian(BuildContext context) =>
    Localizations.localeOf(context).languageCode.toLowerCase() == 'it';

String bookingText(BuildContext context, String italian, String english) =>
    bookingIsItalian(context) ? italian : english;

void setBookingLanguage(String code) {
  final normalized = code.toLowerCase() == 'it' ? 'it' : 'en';
  if (bookingLanguage.value != normalized) bookingLanguage.value = normalized;
}

class BookingLanguageToggle extends StatelessWidget {
  const BookingLanguageToggle({super.key, this.compact = false});
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final current = Localizations.localeOf(context).languageCode;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFC8A45D)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Choice(
            label: 'IT',
            selected: current == 'it',
            compact: compact,
            onTap: () => setBookingLanguage('it'),
          ),
          _Choice(
            label: 'EN',
            selected: current != 'it',
            compact: compact,
            onTap: () => setBookingLanguage('en'),
          ),
        ],
      ),
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({
    required this.label,
    required this.selected,
    required this.compact,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(14),
    onTap: onTap,
    child: Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 5 : 6,
      ),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFFC8A45D) : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: selected ? const Color(0xFF171717) : Colors.white,
          fontSize: compact ? 11 : 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
  );
}
