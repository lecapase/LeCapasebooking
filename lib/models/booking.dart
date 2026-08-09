class Booking {
  final String nome;
  final String cognome;
  final String email;
  final String telefono;

  final int persone;

  final String data;
  final String orario;

  final String occasione;
  final String note;

  final String stato;

  Booking({
    required this.nome,
    required this.cognome,
    required this.email,
    required this.telefono,
    required this.persone,
    required this.data,
    required this.orario,
    required this.occasione,
    required this.note,
    required this.stato,
  });

  Map<String, dynamic> toJson() {
    return {
      'nome': nome,
      'cognome': cognome,
      'email': email,
      'telefono': telefono,
      'persone': persone,
      'data': data,
      'orario': orario,
      'occasione': occasione,
      'note': note,
      'stato': stato,
    };
  }

  factory Booking.fromJson(
    Map<String, dynamic> json,
  ) {
    return Booking(
      nome: json['nome'] ?? '',
      cognome: json['cognome'] ?? '',
      email: json['email'] ?? '',
      telefono: json['telefono'] ?? '',
      persone: json['persone'] ?? 1,
      data: json['data'] ?? '',
      orario: json['orario'] ?? '',
      occasione: json['occasione'] ?? 'Nessuna',
      note: json['note'] ?? '',
      stato: json['stato'] ?? 'Da confermare',
    );
  }
}