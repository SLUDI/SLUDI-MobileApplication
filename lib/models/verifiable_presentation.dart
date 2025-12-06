class VerifiablePresentationDto {
  final String holder;
  final String credentialId;
  final Map<String, dynamic> attributes;
  final ProofDto proof;

  VerifiablePresentationDto({
    required this.holder,
    required this.credentialId,
    required this.attributes,
    required this.proof,
  });

  Map<String, dynamic> toJson() {
    return {
      'holder': holder,
      'credentialId': credentialId,
      'attributes': attributes,
      'proof': proof.toJson(),
    };
  }
}

class ProofDto {
  final String type;
  final String created;
  final String verificationMethod;
  final String proofPurpose;
  final String proofValue;

  ProofDto({
    required this.type,
    required this.created,
    required this.verificationMethod,
    required this.proofPurpose,
    required this.proofValue,
  });

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'created': created,
      'verificationMethod': verificationMethod,
      'proofPurpose': proofPurpose,
      'proofValue': proofValue,
    };
  }
}