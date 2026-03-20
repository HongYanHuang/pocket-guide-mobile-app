class User {
  final String email;
  final String name;
  final String? picture;
  final String role;

  User({
    required this.email,
    required this.name,
    this.picture,
    required this.role,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      email: json['email'] as String,
      name: json['name'] as String,
      picture: json['picture'] as String?,
      role: json['role'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'name': name,
      'picture': picture,
      'role': role,
    };
  }
}
