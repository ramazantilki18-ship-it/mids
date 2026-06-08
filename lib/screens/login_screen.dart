import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/auth_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/metro_brand_header.dart';
import 'package:package_info_plus/package_info_plus.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameFocus = FocusNode();
  final _passwordFocus = FocusNode();
  bool _rememberMe = false;
  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _isResettingPassword = false;
  String _version = '';

  late AnimationController _fadeController;
  late AnimationController _pulseController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _loadSavedLogin();
    _loadVersionInfo();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutCubic,
    );

    _slideAnimation = Tween<double>(begin: 50, end: 0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOutCubic),
    );

    _pulseAnimation = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _fadeController.forward();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _usernameFocus.dispose();
    _passwordFocus.dispose();
    _fadeController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadVersionInfo() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      setState(() {
        _version = 'v${packageInfo.version} (${packageInfo.buildNumber})';
      });
    } catch (_) {}
  }

  Future<void> _loadSavedLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final remember = prefs.getBool('remember_me') ?? false;
    final savedUsername = prefs.getString('saved_username');
    final savedPassword = prefs.getString('saved_password');

    if (remember && savedUsername != null) {
      setState(() {
        _rememberMe = true;
        _usernameController.text = savedUsername;
        if (savedPassword != null) {
          _passwordController.text = savedPassword;
        }
      });
    }
  }

  Future<void> _handleLogin() async {
    final username = _usernameController.text;
    final password = _passwordController.text;

    if (username.isEmpty || password.isEmpty) {
      _showError('Lütfen bilgilerinizi kontrol edin.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final success = await context
          .read<AuthProvider>()
          .login(username, password, rememberMe: _rememberMe);
      if (success && mounted) {
        context.go('/');
      } else if (mounted) {
        _showError('Giriş başarısız! Lütfen bilgilerinizi kontrol edin.');
      }
    } catch (e) {
      if (mounted) {
        String errorMsg = e.toString().replaceAll('Exception: ', '');
        if (errorMsg.contains('12345')) {
          errorMsg = 'Giriş başarısız! Lütfen bilgilerinizi kontrol edin.';
        }
        _showError(errorMsg.isNotEmpty ? errorMsg : 'Giriş başarısız!');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleForgotPassword() async {
    if (_isResettingPassword) return;

    final account = await _showForgotPasswordDialog();
    if (account == null || account.trim().isEmpty || !mounted) return;

    setState(() => _isResettingPassword = true);
    try {
      await context.read<AuthProvider>().sendPasswordResetEmail(account);
      if (mounted) {
        _showSuccess(
          'Şifre yenileme bağlantısı e-posta adresinize gönderildi. '
          'Gelen kutunuzu ve spam klasörünü kontrol edin.',
        );
      }
    } catch (error) {
      if (mounted) {
        final message = error.toString().replaceFirst('Exception: ', '');
        _showError(message);
      }
    } finally {
      if (mounted) setState(() => _isResettingPassword = false);
    }
  }

  Future<String?> _showForgotPasswordDialog() async {
    final accountController = TextEditingController(
      text: _usernameController.text.trim(),
    );
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        void submit() {
          if (formKey.currentState?.validate() ?? false) {
            Navigator.of(dialogContext).pop(accountController.text.trim());
          }
        }

        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.lock_reset_rounded),
              SizedBox(width: 10),
              Expanded(child: Text('Şifremi Unuttum')),
            ],
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Kurumsal e-posta adresinizi veya kullanıcı adınızı girin. '
                  'Şifre yenileme bağlantısını e-posta adresinize göndereceğiz.',
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: accountController,
                  autofocus: true,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.done,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    labelText: 'E-posta veya kullanıcı adı',
                    prefixIcon: Icon(Icons.email_outlined),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Lütfen e-posta veya kullanıcı adınızı girin.';
                    }
                    return null;
                  },
                  onFieldSubmitted: (_) => submit(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('VAZGEÇ'),
            ),
            FilledButton.icon(
              onPressed: submit,
              icon: const Icon(Icons.send_rounded, size: 18),
              label: const Text('GÖNDER'),
            ),
          ],
        );
      },
    );

    accountController.dispose();
    return result;
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline_rounded,
                color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
                child: Text(msg,
                    style: const TextStyle(fontWeight: FontWeight.w600))),
          ],
        ),
        backgroundColor: const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showSuccess(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.mark_email_read_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                msg,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF16A34A),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        duration: const Duration(seconds: 5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/splash_bg.png',
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.0, 0.3, 0.6, 1.0],
                  colors: [
                    const Color(0xFF0A1628).withValues(alpha: 0.3),
                    const Color(0xFF0A1628).withValues(alpha: 0.5),
                    const Color(0xFF002B5B).withValues(alpha: 0.75),
                    const Color(0xFF001B3D).withValues(alpha: 0.95),
                  ],
                ),
              ),
            ),
          ),

          // LOGIN FORMU
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: AnimatedBuilder(
                  animation: _fadeController,
                  builder: (context, child) {
                    return Opacity(
                      opacity: _fadeAnimation.value,
                      child: Transform.translate(
                        offset: Offset(0, _slideAnimation.value),
                        child: child,
                      ),
                    );
                  },
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // LOGO
                        _buildLogoSection(),
                        const SizedBox(height: 32),
                        // FORM KARTI
                        _buildFormCard(),
                        const SizedBox(height: 24),
                        // ALT BİLGİ
                        _buildFooter(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoSection() {
    return const MetroBrandHeader(
      logoWidth: 125,
      titleWidth: 125,
      titleFontSize: 9.5,
      titleLetterSpacing: 1.7,
      titleExtraWidth: 0,
      titleColor: Color(0xFF003B8F),
    );
  }

  Widget _buildLegacyLogoSection() {
    return Column(
      children: [
        Container(
          width: 220,
          height: 150,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            color: Colors.white.withValues(alpha: 0.1),
            border: Border.all(
                color: Colors.white.withValues(alpha: 0.15), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.05),
                blurRadius: 30,
                spreadRadius: 2,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Image.asset(
                'assets/images/brand_vertical.png',
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) =>
                    const SizedBox.shrink(),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Başlık
        Text(
          'METRO İSTANBUL',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.07),
            fontSize: 24,
            fontWeight: FontWeight.w900,
            letterSpacing: 3,
          ),
        ),
        const SizedBox(height: 8),

        // Alt başlık
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: Colors.white.withValues(alpha: 0.08),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: const Text(
            'DENETİM SİSTEMİ',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 2.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFormCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: const Color(0xFF061A35).withValues(alpha: 0.62),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.16),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 40,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hoşgeldiniz başlığı
              Center(
                child: Column(
                  children: [
                    const Text(
                      'Hoş Geldiniz',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Devam etmek için giriş yapın',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.58),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // E-Posta
              _buildInputField(
                label: 'KURUMSAL E-POSTA',
                controller: _usernameController,
                focusNode: _usernameFocus,
                icon: Icons.email_outlined,
                nextFocus: _passwordFocus,
              ),
              const SizedBox(height: 18),

              // Şifre
              _buildInputField(
                label: 'ŞİFRE',
                controller: _passwordController,
                focusNode: _passwordFocus,
                icon: Icons.lock_outline_rounded,
                isPassword: true,
                onSubmit: (_) => _handleLogin(),
              ),
              const SizedBox(height: 16),

              // Oturum seçenekleri
              _buildLoginOptions(),
              const SizedBox(height: 24),

              // Giriş butonu
              _buildLoginButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    required FocusNode focusNode,
    required IconData icon,
    bool isPassword = false,
    FocusNode? nextFocus,
    ValueChanged<String>? onSubmit,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.white.withValues(alpha: 0.68),
              letterSpacing: 1.5,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            obscureText: isPassword ? _obscurePassword : false,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
            textInputAction:
                nextFocus != null ? TextInputAction.next : TextInputAction.done,
            onSubmitted: onSubmit ??
                (nextFocus != null
                    ? (_) => FocusScope.of(context).requestFocus(nextFocus)
                    : null),
            decoration: InputDecoration(
              prefixIcon: Container(
                margin: const EdgeInsets.only(left: 12, right: 8),
                child: Icon(icon,
                    color: Colors.white.withValues(alpha: 0.58), size: 20),
              ),
              prefixIconConstraints: const BoxConstraints(minWidth: 44),
              suffixIcon: isPassword
                  ? IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: Colors.white.withValues(alpha: 0.45),
                        size: 18,
                      ),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    )
                  : null,
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.09),
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                    BorderSide(color: Colors.white.withValues(alpha: 0.10)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                    BorderSide(color: Colors.white.withValues(alpha: 0.10)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                    color: Colors.white.withValues(alpha: 0.36), width: 1.5),
              ),
            ),
            cursorColor: Colors.white.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }

  Widget _buildRememberMe() {
    return GestureDetector(
      onTap: () => setState(() => _rememberMe = !_rememberMe),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              color: _rememberMe ? AppColors.primary : Colors.transparent,
              border: Border.all(
                color: _rememberMe
                    ? AppColors.primary
                    : Colors.white.withValues(alpha: 0.35),
                width: 1.5,
              ),
            ),
            child: _rememberMe
                ? const Icon(Icons.check_rounded, color: Colors.white, size: 14)
                : null,
          ),
          const SizedBox(width: 10),
          Text(
            'Beni Hatırla',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.68),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginOptions() {
    return Row(
      children: [
        Expanded(child: _buildRememberMe()),
        TextButton(
          onPressed:
              _isLoading || _isResettingPassword ? null : _handleForgotPassword,
          style: TextButton.styleFrom(
            foregroundColor: Colors.white.withValues(alpha: 0.82),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: _isResettingPassword
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text(
                  'Şifremi Unuttum',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildLoginButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1E4A8A), Color(0xFF002B5B)],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF002B5B).withValues(alpha: 0.4),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: _isLoading ? null : _handleLogin,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            elevation: 0,
            shadowColor: Colors.transparent,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
              : const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.login_rounded, size: 18),
                    SizedBox(width: 10),
                    Text(
                      'GİRİŞ YAP',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Center(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 30,
                height: 1,
                color: Colors.white.withValues(alpha: 0.1),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Icon(
                  Icons.security_rounded,
                  size: 14,
                  color: Colors.white.withValues(alpha: 0.2),
                ),
              ),
              Container(
                width: 30,
                height: 1,
                color: Colors.white.withValues(alpha: 0.1),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Güvenli kurumsal erişim',
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withValues(alpha: 0.25),
              fontWeight: FontWeight.w500,
              letterSpacing: 0.5,
            ),
          ),
          if (_version.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              _version,
              style: TextStyle(
                fontSize: 11,
                color: Colors.white.withValues(alpha: 0.35),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
