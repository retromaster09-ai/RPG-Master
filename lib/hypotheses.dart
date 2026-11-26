enum HypothesisStatus {
  open('Ativa'),
  confirmed('Confirmada'),
  refuted('Refutada');

  const HypothesisStatus(this.label);
  final String label;

  String conclusionLabel({required bool hypothesis}) {
    if (hypothesis) return label;
    return switch (this) {
      HypothesisStatus.open => 'Ativa',
      HypothesisStatus.confirmed => 'Resolvida',
      HypothesisStatus.refuted => 'Descartada',
    };
  }
}

class HypothesisResolution {
  const HypothesisResolution({
    this.status = HypothesisStatus.open,
    this.reason = '',
  });

  factory HypothesisResolution.fromJson(Map<String, dynamic> json) =>
      HypothesisResolution(
        status: switch (json['resolution']) {
          'confirmed' => HypothesisStatus.confirmed,
          'refuted' => HypothesisStatus.refuted,
          _ => HypothesisStatus.open,
        },
        reason: json['resolutionReason'] is String
            ? json['resolutionReason'] as String
            : '',
      );

  final HypothesisStatus status;
  final String reason;

  bool get closed => status != HypothesisStatus.open;

  bool sameAs(HypothesisResolution other) =>
      status == other.status && reason == other.reason;

  Map<String, Object> toJson() => {
    'resolution': status.name,
    'resolutionReason': reason,
  };
}
