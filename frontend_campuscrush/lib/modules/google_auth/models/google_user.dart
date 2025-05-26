class GoogleUser {
  final String id;
  final String email;
  final String displayName;
  final String? photoUrl;

  GoogleUser({
    required this.id,
    required this.email,
    required this.displayName,
    this.photoUrl,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'display_name': displayName,
      'photo_url': photoUrl,
    };
  }

  factory GoogleUser.fromJson(Map<String, dynamic> json) {
    return GoogleUser(
      id: json['id'],
      email: json['email'],
      displayName: json['display_name'] ?? '',
      photoUrl: json['photo_url'],
    );
  }
}
