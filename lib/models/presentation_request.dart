class PresentationRequestDto {
  final String sessionId;
  final String requesterId;
  final String requesterName;
  final List<String> requestedAttributes;
  final String purpose;
  final DateTime expiresAt;

  PresentationRequestDto({
    required this.sessionId,
    required this.requesterId,
    required this.requesterName,
    required this.requestedAttributes,
    required this.purpose,
    required this.expiresAt,
  });

  factory PresentationRequestDto.fromJson(Map<String, dynamic> json) {
    return PresentationRequestDto(
      sessionId: json['sessionId'],
      requesterId: json['requesterId'],
      requesterName: json['requesterName'],
      requestedAttributes: List<String>.from(json['requestedAttributes']),
      purpose: json['purpose'],
      expiresAt: DateTime.parse(json['expiresAt']),
    );
  }
}