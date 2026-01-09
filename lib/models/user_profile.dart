class UserProfile {
  final String? name;
  final String? coreValues;
  final String? communicationStyle;
  final String? lifePhase;
  final String? interests;
  final String? favorites;
  final String? speechPatterns;
  final String? birthday;
  final String? relationships;

  UserProfile({
    this.name,
    this.coreValues,
    this.communicationStyle,
    this.lifePhase,
    this.interests,
    this.favorites,
    this.speechPatterns,
    this.birthday,
    this.relationships,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      name: json['name'],
      coreValues: json['core_values'],
      communicationStyle: json['communication_style'],
      lifePhase: json['life_phase'],
      interests: json['interests'],
      favorites: json['favorites'],
      speechPatterns: json['speech_patterns'],
      birthday: json['birthday'],
      relationships: json['relationships'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'core_values': coreValues,
      'communication_style': communicationStyle,
      'life_phase': lifePhase,
      'interests': interests,
      'favorites': favorites,
      'speech_patterns': speechPatterns,
      'birthday': birthday,
      'relationships': relationships,
    };
  }
}
