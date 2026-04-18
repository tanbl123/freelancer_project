class CertificationItem {
  final String name;
  final String? issuedBy;
  final int? yearReceived;

  const CertificationItem({
    required this.name,
    this.issuedBy,
    this.yearReceived,
  });

  factory CertificationItem.fromMap(Map<String, dynamic> m) => CertificationItem(
        name: m['name'] as String,
        issuedBy: m['issuedBy'] as String?,
        yearReceived: (m['yearReceived'] as num?)?.toInt(),
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        'issuedBy': issuedBy,
        'yearReceived': yearReceived,
      };
}
