class UserProfile {
  final String? name;
  final String? coreValues;
  final String? communicationStyle;
  final String? lifePhase;

  UserProfile({
    this.name,
    this.coreValues,
    this.communicationStyle,
    this.lifePhase,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      name: json['name'],
      coreValues: json['core_values'],
      communicationStyle: json['communication_style'],
      lifePhase: json['life_phase'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'core_values': coreValues,
      'communication_style': communicationStyle,
      'life_phase': lifePhase,
    };
  }
}
