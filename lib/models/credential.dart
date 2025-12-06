class IdentityCredential {
  final String id;
  final String credentialType;
  final String did;
  final CredentialSubject credentialSubject;

  IdentityCredential({
    required this.id,
    required this.credentialType,
    required this.did,
    required this.credentialSubject,
  });

  factory IdentityCredential.fromJson(Map<String, dynamic> json) {
    return IdentityCredential(
      id: json['id'],
      credentialType: json['credentialType'],
      did: json['subjectDID'],
      credentialSubject: CredentialSubject.fromJson(json['credentialSubject']),
    );
  }
}

class CredentialSubject {
  final String id;
  final String fullName;
  final String nic;
  final int age;
  final String dateOfBirth;
  final String? profilePhotoHash;
  final String citizenship;
  final String gender;
  final String nationality;
  final String bloodGroup;
  final AddressDto address;

  CredentialSubject({
    required this.id,
    required this.fullName,
    required this.nic,
    required this.age,
    required this.dateOfBirth,
    this.profilePhotoHash,
    required this.citizenship,
    required this.gender,
    required this.nationality,
    required this.bloodGroup,
    required this.address,
  });

  factory CredentialSubject.fromJson(Map<String, dynamic> json) {
    return CredentialSubject(
      id: json['id'],
      fullName: json['fullName'],
      nic: json['nic'],
      age: json['age'],
      dateOfBirth: json['dateOfBirth'],
      profilePhotoHash: json['profilePhoto'] ?? json['profilePhotoHash'],
      citizenship: json['citizenship'],
      gender: json['gender'],
      nationality: json['nationality'],
      bloodGroup: json['bloodGroup'],
      address: AddressDto.fromJson(json['address']),
    );
  }

  /// This map MUST match backend claim names & structures,
  /// because they hash String.valueOf(value) on that.
  Map<String, dynamic> toAttributesMap(List<String> requestedAttributes) {
    final Map<String, dynamic> attributes = {};

    void addIfRequested(String key, dynamic value) {
      if (value != null && requestedAttributes.contains(key)) {
        attributes[key] = value;
      }
    }

    // Top-level claims
    addIfRequested('id', id);
    addIfRequested('fullName', fullName);
    addIfRequested('nic', nic);
    addIfRequested('age', age);
    addIfRequested('dateOfBirth', dateOfBirth);
    addIfRequested('citizenship', citizenship);
    addIfRequested('gender', gender);
    addIfRequested('nationality', nationality);
    addIfRequested('bloodGroup', bloodGroup);
    addIfRequested('profilePhoto', profilePhotoHash);

    // Address as nested object (single "address" claim)
    if (requestedAttributes.contains('address')) {
      final addrMap = address.toAddressMap();
      if (addrMap.isNotEmpty) {
        attributes['address'] = addrMap;
      }
    }

    return attributes;
  }
}

class AddressDto {
  final String street;
  final String city;
  final String district;
  final String postalCode;
  final String province;
  final String? divisionalSecretariat;
  final String? gramaNiladhariDivision;

  AddressDto({
    required this.street,
    required this.city,
    required this.district,
    required this.postalCode,
    required this.province,
    this.divisionalSecretariat,
    this.gramaNiladhariDivision,
  });

  factory AddressDto.fromJson(Map<String, dynamic> json) {
    return AddressDto(
      street: json['street'] ?? '',
      city: json['city'] ?? '',
      district: json['district'] ?? '',
      postalCode: json['postalCode'] ?? '',
      province: json['province'] ?? '',
      divisionalSecretariat: json['divisionalSecretariat'],
      gramaNiladhariDivision: json['gramaNiladhariDivision'],
    );
  }

  /// Map in the SAME key order as backend convertAddressToMap
  Map<String, dynamic> toAddressMap() {
    final map = <String, dynamic>{};

    void addIfNotEmpty(String key, String? value) {
      if (value != null && value.isNotEmpty) {
        map[key] = value;
      }
    }

    addIfNotEmpty('street', street);
    addIfNotEmpty('city', city);
    addIfNotEmpty('district', district);
    addIfNotEmpty('postalCode', postalCode);
    addIfNotEmpty('divisionalSecretariat', divisionalSecretariat);
    addIfNotEmpty('gramaNiladhariDivision', gramaNiladhariDivision);
    addIfNotEmpty('province', province);

    return map;
  }

  @override
  String toString() {
    return '$street, $city, $district, $postalCode, $province';
  }
}
