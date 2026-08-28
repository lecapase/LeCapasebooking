import 'package:flutter/material.dart';

import 'booking_language.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final italian = bookingIsItalian(context);
    final title = italian ? 'Informativa Privacy' : 'Privacy Notice';

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 36),
              children: italian
                  ? _italianSections.map(_section).toList()
                  : _englishSections.map(_section).toList(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _section(({String title, String body}) section) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            section.title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 7),
          Text(
            section.body,
            style: const TextStyle(fontSize: 14, height: 1.55),
          ),
        ],
      ),
    );
  }

  static const _italianSections = <({String title, String body})>[
    (
      title: 'Titolare del trattamento',
      body:
          'CIVU SRL, Via Roma 27, 72014 Cisternino (BR), P. IVA e C.F. '
          '02782130740. Per richieste relative alla privacy: '
          'lecapase@outlook.com.',
    ),
    (
      title: 'Dati trattati',
      body:
          'Trattiamo nome, cognome, email, numero di telefono, data, orario, '
          'numero di persone, occasione, origine e stato della prenotazione.',
    ),
    (
      title: 'Note e informazioni sanitarie',
      body:
          'Le Note sono facoltative. Se contengono informazioni relative '
          'alla salute, il trattamento avviene esclusivamente con consenso '
          'esplicito e per gestire la singola prenotazione. È possibile '
          'rimuovere tali informazioni e prenotare senza prestare il consenso.',
    ),
    (
      title: 'Finalità e basi giuridiche',
      body:
          'I dati sono utilizzati per ricevere, gestire, confermare, '
          'modificare o annullare la prenotazione e per inviare comunicazioni '
          'operative tramite email e WhatsApp. Il trattamento è necessario '
          'all’esecuzione delle misure richieste dal cliente e alla gestione '
          'del servizio. I controlli di sicurezza e la prevenzione degli abusi '
          'si fondano sul legittimo interesse del titolare.',
    ),
    (
      title: 'Comunicazioni promozionali',
      body:
          'Email e WhatsApp promozionali sono inviati esclusivamente con '
          'consenso facoltativo, separato dalla prenotazione e revocabile in '
          'qualsiasi momento. Il rifiuto non impedisce di prenotare.',
    ),
    (
      title: 'Fornitori e destinatari',
      body:
          'I dati possono essere trattati da fornitori tecnici incaricati '
          'della gestione della piattaforma, dell’hosting, delle email e dei '
          'messaggi WhatsApp, tra cui servizi Google/Firebase, Google Workspace '
          'o Gmail, 360dialog e Meta, nei limiti necessari al servizio.',
    ),
    (
      title: 'Trasferimenti internazionali',
      body:
          'Qualora un fornitore tratti dati fuori dallo Spazio Economico '
          'Europeo, il trasferimento avviene sulla base degli strumenti '
          'previsti dalla normativa applicabile, incluse decisioni di '
          'adeguatezza o clausole contrattuali standard.',
    ),
    (
      title: 'Conservazione',
      body:
          'I dati delle prenotazioni e lo storico operativo sono conservati '
          'per 24 mesi. Le Note sono cancellate automaticamente al termine del '
          'servizio o in caso di annullamento o rifiuto. I dati e i consensi '
          'marketing sono conservati per 24 '
          'mesi dall’ultima interazione, salvo revoca anticipata. Gli eventi '
          'tecnici e di sicurezza sono conservati fino a 12 mesi, fatti salvi '
          'obblighi di legge o necessità di tutela dei diritti.',
    ),
    (
      title: 'Diritti',
      body:
          'L’interessato può chiedere accesso, rettifica, cancellazione, '
          'limitazione, opposizione e portabilità, nonché revocare il consenso '
          'marketing scrivendo a lecapase@outlook.com. È inoltre possibile '
          'proporre reclamo al Garante per la protezione dei dati personali.',
    ),
    (title: 'Versione', body: 'Informativa versione 1.0 – 28 agosto 2026.'),
  ];

  static const _englishSections = <({String title, String body})>[
    (
      title: 'Data controller',
      body:
          'CIVU SRL, Via Roma 27, 72014 Cisternino (BR), Italy, VAT and tax '
          'number 02782130740. Privacy requests: lecapase@outlook.com.',
    ),
    (
      title: 'Data processed',
      body:
          'We process first name, last name, email, phone number, booking '
          'date and time, number of guests, occasion, booking source and '
          'status.',
    ),
    (
      title: 'Notes and health information',
      body:
          'Notes are optional. If they contain health information, they are '
          'processed only with explicit consent and solely to manage the '
          'individual booking. You may remove that information and book '
          'without giving consent.',
    ),
    (
      title: 'Purposes and legal bases',
      body:
          'Data is used to receive, manage, confirm, change or cancel the '
          'booking and to send operational email and WhatsApp messages. '
          'Processing is necessary to take the steps requested by the guest '
          'and to provide the booking service. Security and abuse-prevention '
          'controls are based on the controller’s legitimate interests.',
    ),
    (
      title: 'Promotional communications',
      body:
          'Promotional email and WhatsApp messages are sent only with '
          'optional consent, which is separate from the booking and may be '
          'withdrawn at any time. Refusing consent does not prevent booking.',
    ),
    (
      title: 'Providers and recipients',
      body:
          'Data may be processed by technical providers supporting the '
          'platform, hosting, email and WhatsApp services, including '
          'Google/Firebase, Google Workspace or Gmail, 360dialog and Meta, '
          'only as necessary to provide the service.',
    ),
    (
      title: 'International transfers',
      body:
          'Where a provider processes data outside the European Economic '
          'Area, transfers rely on safeguards permitted by applicable law, '
          'including adequacy decisions or standard contractual clauses.',
    ),
    (
      title: 'Retention',
      body:
          'Booking data and operational history are retained for 24 months. '
          'Notes are automatically deleted after the service or if the booking '
          'is cancelled or rejected. Marketing data and consent are retained '
          'for 24 months from the '
          'latest interaction unless withdrawn earlier. Technical and '
          'security events are retained for up to 12 months, subject to legal '
          'obligations or the need to protect legal rights.',
    ),
    (
      title: 'Your rights',
      body:
          'You may request access, correction, deletion, restriction, '
          'objection and portability, and may withdraw marketing consent by '
          'emailing lecapase@outlook.com. You may also lodge a complaint with '
          'the Italian Data Protection Authority.',
    ),
    (title: 'Version', body: 'Privacy Notice version 1.0 – 28 August 2026.'),
  ];
}
