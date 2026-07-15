import 'package:flutter/material.dart';

import '../models/vendeur.dart';
import '../services/token_storage.dart';
import '../services/vendeur_service.dart';
import '../theme/app_colors.dart';
import '../widgets/wave_clipper.dart';
import 'main_shell.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _numTelephoneController = TextEditingController();
  final _motDePasseController = TextEditingController();
  final _vendeurService = VendeurService();
  bool _isSignUp = false;
  bool _rememberMe = false;
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _numTelephoneController.dispose();
    _motDePasseController.dispose();
    super.dispose();
  }

  Future<void> _onSubmit() async {
    final numTelephone = _numTelephoneController.text.trim();
    final motDePasse = _motDePasseController.text;

    if (numTelephone.isEmpty || motDePasse.isEmpty) {
      _showMessage(
        'Veuillez renseigner le numéro de téléphone et le mot de passe.',
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (_isSignUp) {
        await _vendeurService.inscription(
          VendeurCreate(numTelephone: numTelephone, motDePasse: motDePasse),
        );
      }

      final response = await _vendeurService.connexion(
        VendeurLogin(numTelephone: numTelephone, motDePasse: motDePasse),
      );

      await TokenStorage.saveSession(
        accessToken: response.accessToken,
        vendeurId: response.vendeurId,
        numTelephone: numTelephone,
        rememberMe: _rememberMe,
      );

      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(
          builder: (_) => MainShell(
            vendeurId: response.vendeurId,
            numTelephone: numTelephone,
          ),
        ),
        (_) => false,
      );
    } on VendeurException catch (e) {
      _showMessage(e.message);
    } catch (_) {
      _showMessage('Une erreur inattendue est survenue.');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _toggleMode() {
    setState(() => _isSignUp = !_isSignUp);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SingleChildScrollView(
        child: Column(
          children: [
            Stack(
              children: [
                ClipPath(
                  clipper: const WaveClipper(waveHeight: 90, inverted: true),
                  child: Container(
                    height: MediaQuery.of(context).size.height * 0.38,
                    color: AppColors.sageGreen,
                  ),
                ),
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.38,
                  child: CustomPaint(
                    painter: TopographicPatternPainter(
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
                    size: Size(
                      MediaQuery.of(context).size.width,
                      MediaQuery.of(context).size.height * 0.38,
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  Text(
                    _isSignUp ? 'Sign up' : 'Log in',
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF333333),
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    width: _isSignUp ? 120 : 100,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.oliveGreen,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 32),
                  _buildLabel('Numéro de téléphone'),
                  const SizedBox(height: 8),
                  _buildTextField(
                    controller: _numTelephoneController,
                    hint: '06 12 34 56 78',
                    icon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 20),
                  _buildLabel('Mot de passe'),
                  const SizedBox(height: 8),
                  _buildTextField(
                    controller: _motDePasseController,
                    hint: 'Entrez votre mot de passe',
                    icon: Icons.lock_outline,
                    obscureText: _obscurePassword,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: AppColors.textGrey,
                        size: 20,
                      ),
                      onPressed: () {
                        setState(() => _obscurePassword = !_obscurePassword);
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (!_isSignUp)
                    Row(
                      children: [
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: Checkbox(
                            value: _rememberMe,
                            activeColor: AppColors.oliveGreen,
                            side: BorderSide(
                              color: AppColors.textGrey.withValues(alpha: 0.5),
                            ),
                            onChanged: (value) {
                              setState(() => _rememberMe = value ?? false);
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Remember Me',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textGrey.withValues(alpha: 0.9),
                          ),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () {},
                          child: Text(
                            'Forgot Password?',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.textGrey.withValues(alpha: 0.7),
                            ),
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _onSubmit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.oliveGreen,
                        foregroundColor: AppColors.white,
                        disabledBackgroundColor: AppColors.oliveGreen
                            .withValues(alpha: 0.6),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: AppColors.white,
                              ),
                            )
                          : Text(
                              _isSignUp ? 'Create account' : 'Login',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Center(
                    child: TextButton(
                      onPressed: _isLoading ? null : _toggleMode,
                      child: RichText(
                        text: TextSpan(
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textGrey.withValues(alpha: 0.8),
                          ),
                          children: [
                            TextSpan(
                              text: _isSignUp
                                  ? 'Already have an account? '
                                  : 'Don\'t have an account? ',
                            ),
                            TextSpan(
                              text: _isSignUp ? 'Log in' : 'Sign up',
                              style: const TextStyle(
                                color: AppColors.oliveGreen,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: Color(0xFF222222),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    Widget? suffixIcon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.lightGrey.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.lightGrey, width: 1),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscureText,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            color: AppColors.textGrey.withValues(alpha: 0.5),
            fontSize: 14,
          ),
          prefixIcon: Icon(icon, color: AppColors.textGrey, size: 20),
          suffixIcon: suffixIcon,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }
}
