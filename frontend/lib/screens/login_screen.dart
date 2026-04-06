import 'package:flutter/material.dart';
import 'package:klass_app/l10n/generated/app_localizations.dart';
import '../config/app_colors.dart';
import '../services/auth_service.dart';
import '../main.dart'; // To access MainShell
import 'forgot_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _authService = AuthService();
  bool _isLogin = true;
  bool _isLoading = false;
  String _errorMessage = '';
  String _selectedRole = 'teacher'; // Default role for registration

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() async {
    final localizations = AppLocalizations.of(context)!;

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      bool success = false;
      if (_isLogin) {
        success = await _authService.login(
          _emailController.text.trim(),
          _passwordController.text,
        );
      } else {
        success = await _authService.register(
          _nameController.text.trim(),
          _emailController.text.trim(),
          _passwordController.text,
          role: _selectedRole,
        );
      }

      if (success) {
        // Fetch user profile right after login/register
        final userProfile = await _authService.getMe();
        final role = AuthService.getRoleFromUserData(userProfile);
        final isFreelancer = AuthService.resolveAppRole(role) == 'freelancer';
        
        if (!mounted) return;
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isFreelancer 
                ? localizations.loginSuccessFreelancer
                : localizations.loginSuccess,
              style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600),
            ),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );

        await KlassApp.mainShellKey.currentState?.reloadRole();

        if (!mounted) return;

        Navigator.of(context, rootNavigator: true).popUntil((route) => route.isFirst);
      } else {
        setState(() {
          _errorMessage = localizations.loginGenericError;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Logo placeholder
              const Icon(
                Icons.school_rounded,
                size: 80,
                color: AppColors.primary,
              ),
              const SizedBox(height: 24),
              Text(
                _isLogin
                    ? localizations.loginTitleSignIn
                    : localizations.loginTitleSignUp,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Mona Sans',
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _isLogin
                    ? localizations.loginSubtitleSignIn
                    : localizations.loginSubtitleSignUp,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 32),

              if (_errorMessage.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.red.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    _errorMessage,
                    style: const TextStyle(color: AppColors.red, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // ─── Role Selector (Register Mode Only) ────────────────
              if (!_isLogin) ...[
                Text(
                  localizations.loginRegisterAs,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildRoleOption(
                        role: 'teacher',
                        label: _roleLabel(localizations, 'teacher'),
                        icon: Icons.school_rounded,
                        description: localizations.loginTeacherDescription,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildRoleOption(
                        role: 'freelancer',
                        label: _roleLabel(localizations, 'freelancer'),
                        icon: Icons.work_rounded,
                        description: localizations.loginFreelancerDescription,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],

              if (!_isLogin) ...[
                _buildTextField(
                  controller: _nameController,
                  label: localizations.commonFullName,
                  icon: Icons.person_outline,
                ),
                const SizedBox(height: 16),
              ],

              _buildTextField(
                controller: _emailController,
                label: localizations.commonEmailAddress,
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),

              _buildTextField(
                controller: _passwordController,
                label: localizations.commonPassword,
                icon: Icons.lock_outline,
                obscureText: true,
              ),

              if (_isLogin)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()),
                      );
                    },
                    child: Text(
                      localizations.loginForgotPassword,
                      style: TextStyle(
                        color: AppColors.primary,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                )
              else
                const SizedBox(height: 24),

              if (_isLogin) const SizedBox(height: 8),

              ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: _isLoading 
                    ? const SizedBox(
                        width: 20, 
                        height: 20, 
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                      )
                    : Text(
                        _isLogin
                            ? localizations.loginSubmitSignIn
                            : localizations.loginSubmitSignUp(
                                _roleLabel(localizations, _selectedRole),
                              ),
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
              const SizedBox(height: 16),

              TextButton(
                onPressed: () {
                  setState(() {
                    _isLogin = !_isLogin;
                    _errorMessage = '';
                  });
                },
                child: Text(
                  _isLogin
                      ? localizations.loginToggleToSignUp
                      : localizations.loginToggleToSignIn,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    color: AppColors.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _roleLabel(AppLocalizations localizations, String role) {
    switch (role) {
      case 'teacher':
        return localizations.commonTeacher;
      case 'freelancer':
        return localizations.commonFreelancer;
      default:
        return role;
    }
  }

  Widget _buildRoleOption({
    required String role,
    required String label,
    required IconData icon,
    required String description,
  }) {
    final isSelected = _selectedRole == role;
    return GestureDetector(
      onTap: () => setState(() => _selectedRole = role),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.08)
              : AppColors.background,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Column(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary.withValues(alpha: 0.15)
                    : AppColors.surfaceLight,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: isSelected ? AppColors.primary : AppColors.textMuted,
                size: 24,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: isSelected ? AppColors.primary : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: isSelected
                    ? AppColors.primary.withValues(alpha: 0.7)
                    : AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.textMuted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        filled: true,
        fillColor: AppColors.background,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      style: const TextStyle(
        fontFamily: 'Inter',
        color: AppColors.textPrimary,
      ),
    );
  }
}
