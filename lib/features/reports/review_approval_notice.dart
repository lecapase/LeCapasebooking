import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'review_automation_screen.dart';

class ReviewApprovalNotice extends StatefulWidget {
  const ReviewApprovalNotice({super.key});
  @override
  State<ReviewApprovalNotice> createState() => _ReviewApprovalNoticeState();
}

class _ReviewApprovalNoticeState extends State<ReviewApprovalNotice> {
  late final _pending = FirebaseFirestore.instance
      .collection('review_batches')
      .where('state', isEqualTo: 'pending')
      .snapshots();
  @override
  Widget build(
    BuildContext context,
  ) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: _pending,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return const ListTile(
          leading: Icon(Icons.warning_amber),
          title: Text('Notifiche recensioni non disponibili.'),
        );
      }
      final count = snapshot.data?.docs.length ?? 0;
      if (count == 0) return const SizedBox.shrink();
      return Material(
        color: const Color(0xFF3A3020),
        child: ListTile(
          leading: const Icon(
            Icons.notifications_active,
            color: Color(0xFFC8A45D),
          ),
          title: const Text('Richieste recensione da autorizzare'),
          subtitle: Text(
            '$count ${count == 1 ? 'giornata pronta' : 'giornate pronte'}. Nessuna email parte senza approvazione.',
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const ReviewAutomationScreen(),
            ),
          ),
        ),
      );
    },
  );
}
