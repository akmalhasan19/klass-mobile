class AuthState {
  final Map<String, dynamic>? user;
  final String role;
  final bool isGuest;

  const AuthState({
    this.user,
    this.role = 'teacher',
    this.isGuest = true,
  });

  AuthState copyWith({
    Map<String, dynamic>? user,
    String? role,
    bool? isGuest,
  }) {
    return AuthState(
      user: user ?? this.user,
      role: role ?? this.role,
      isGuest: isGuest ?? this.isGuest,
    );
  }
}
