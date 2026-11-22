import 'package:flutter/material.dart';

/// A swipe reveals an action; only the explicit button removes the notification.
class NotificationSlideCard extends StatefulWidget {
  const NotificationSlideCard({
    super.key,
    required this.child,
    required this.unread,
    required this.onTap,
    this.onDelete,
  });
  final Widget child;
  final bool unread;
  final VoidCallback onTap;
  final Future<void> Function()? onDelete;

  @override
  State<NotificationSlideCard> createState() => _NotificationSlideCardState();
}

class _NotificationSlideCardState extends State<NotificationSlideCard> {
  double _offset = 0;
  bool _busy = false;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        children: [
          if (_offset < 0)
            Positioned.fill(
              child: Align(
                alignment: Alignment.centerRight,
                child: SizedBox(
                  width: 104,
                  height: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.red.shade800,
                      shape: const RoundedRectangleBorder(),
                      padding: EdgeInsets.zero,
                    ),
                    onPressed: _busy
                        ? null
                        : () async {
                            setState(() => _busy = true);
                            try {
                              await widget.onDelete?.call();
                            } finally {
                              if (mounted) {
                                setState(() {
                                  _busy = false;
                                  _offset = 0;
                                });
                              }
                            }
                          },
                    child: Text(_busy ? '...' : 'ELIMINA'),
                  ),
                ),
              ),
            ),
          Transform.translate(
            offset: Offset(_offset, 0),
            child: GestureDetector(
              onHorizontalDragUpdate: widget.onDelete == null || _busy
                  ? null
                  : (details) {
                      setState(
                        () => _offset = (_offset + details.delta.dx).clamp(
                          -104.0,
                          0.0,
                        ),
                      );
                    },
              onHorizontalDragEnd: widget.onDelete == null || _busy
                  ? null
                  : (details) {
                      setState(() => _offset = _offset < -35 ? -104 : 0);
                    },
              child: Opacity(
                opacity: widget.unread ? 1 : 0.65,
                child: Card(
                  margin: EdgeInsets.zero,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: _busy
                        ? null
                        : () {
                            if (_offset != 0) {
                              setState(() => _offset = 0);
                              return;
                            }
                            widget.onTap();
                          },
                    child: widget.child,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
