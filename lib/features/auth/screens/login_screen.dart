import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stray_resuce_bih/core/theme/app_theme.dart';
import 'package:stray_resuce_bih/core/models/enums.dart';
import 'package:stray_resuce_bih/core/services/firebase_service.dart';
import 'package:stray_resuce_bih/core/services/database_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:stray_resuce_bih/features/dashboards/citizen_dashboard.dart';
import 'package:stray_resuce_bih/features/dashboards/volunteer_dashboard.dart';
import 'package:stray_resuce_bih/features/dashboards/ngo_dashboard.dart';
import 'package:stray_resuce_bih/features/dashboards/vet_dashboard.dart';
import 'package:stray_resuce_bih/features/auth/screens/forgot_password_screen.dart';
import 'package:stray_resuce_bih/core/utils/validators.dart';

/// Login Screen - Existing users sign in
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // 1. Sign in with Firebase Auth
      final firebaseService = FirebaseService();
      final userCredential = await firebaseService.signInWithEmailPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (userCredential == null) {
        _showErrorMessage('Invalid email or password');
        return;
      }

      // 2. Fetch user profile from Firestore
      final userProfile = await DatabaseService().getUserProfile(
        userCredential.user!.uid,
      );

      if (userProfile == null) {
        // Sign out the user since profile doesn't exist
        await firebaseService.signOut();
        _showErrorMessage('User not available. Please sign up first.');
        return;
      }

      if (!mounted) return;

      // 3. Navigate to role-specific dashboard
      _navigateToDashboard(userProfile.role);

    } catch (e) {
      if (!mounted) return;
      
      // Aggressively simplify error messages for the user
      String errorStr = e.toString().toLowerCase();
      String simpleMessage = 'Login failed';

      // Advanced check: Try to distinguish "User not found" vs "Wrong Password"
      // even if Firebase returns a generic "invalid-credential".
      if (errorStr.contains('user-not-found') || 
          errorStr.contains('user not found') ||
          errorStr.contains('email not found')) {
         simpleMessage = 'User not available';
      } else if (errorStr.contains('wrong-password')) {
         simpleMessage = 'Incorrect password';
      } else if (errorStr.contains('invalid-credential') || 
                 errorStr.contains('credential') ||
                 errorStr.contains('incorrect') ||
                 errorStr.contains('malformed') ||
                 errorStr.contains('invalid_login_credentials')) {
        
        // Generic error? Let's double check if user exists!
        try {
          final email = _emailController.text.trim();
          if (email.isNotEmpty) {
            // Note: fetchSignInMethodsForEmail might throw if EEP is strict,
            // but for many projects it works or throws specific error.
            final methods = await FirebaseAuth.instance.fetchSignInMethodsForEmail(email);
            if (methods.isEmpty) {
              simpleMessage = 'User not available';
            } else {
              simpleMessage = 'Incorrect password';
            }
          } else {
            simpleMessage = 'Incorrect password';
          }
        } catch (checkErr) {
          // If verifying fails, stick to Incorrect password or generic.
          // print('Check error: $checkErr');
          simpleMessage = 'Incorrect password';
        }
        
      } else if (errorStr.contains('invalid-email') || 
                 errorStr.contains('badly formatted')) {
        simpleMessage = 'Invalid email format';
      } else if (errorStr.contains('network') || 
                 errorStr.contains('connection') ||
                 errorStr.contains('offline')) {
        simpleMessage = 'Check internet connection';
      } else if (errorStr.contains('too-many-requests')) {
        simpleMessage = 'Too many attempts. Try later.';
      } else if (errorStr.contains('user-disabled')) {
        simpleMessage = 'Account disabled';
      }
      
      _showErrorMessage(simpleMessage);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showErrorMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _navigateToDashboard(UserRole role) {
    Widget dashboard;
    switch (role) {
      case UserRole.citizen:
        dashboard = const CitizenDashboard();
        break;
      case UserRole.volunteer:
        dashboard = const VolunteerDashboard();
        break;
      case UserRole.ngo:
        dashboard = const NGODashboard();
        break;
      case UserRole.vet:
        dashboard = const VetDashboard();
        break;
    }

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => dashboard),
      (route) => false,
    );
  }

  Future<void> _showForgotPasswordDialog() async {
    final emailCtrl = TextEditingController();
    
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          top: 20,
          left: 20,
          right: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Reset Password',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Enter your email address and we will send you a link to reset your password.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: 'Email',
                prefixIcon: const Icon(Icons.email),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () async {
                  final email = emailCtrl.text.trim();
                  // Validate email format using regex
                  final emailError = Validators.validateEmail(email);
                  if (emailError != null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(emailError)),
                    );
                    return;
                  }

                  // Close sheet immediately
                  Navigator.pop(context);
                  
                  // Show loading indicator
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Processing...')),
                  );
                  
                  try {
                    // 1. Check if user exists in database
                    final exists = await DatabaseService().checkUserExists(email);
                    
                    if (!exists) {
                      if (!mounted) return;
                      _showErrorMessage('Email not registered. Please sign up first.');
                      return;
                    }

                    // 2. Send password reset email
                    // Note: Firebase Auth handles the actual password update securely via the link
                    await FirebaseService().sendPasswordResetEmail(email);
                    
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Reset link sent to $email. Please check your SPAM folder.'),
                        backgroundColor: Colors.green,
                        duration: const Duration(seconds: 5),
                      ),
                    );
                  } catch (e) {
                    if (!mounted) return;
                    
                    String error = 'Failed to send link';
                    if (e.toString().contains('user-not-found')) {
                      error = 'Account setup incomplete. Please contact support or Sign Up again.';
                    } else if (e.toString().contains('network')) {
                      error = 'Network error. Check your connection.';
                    }
                    
                    _showErrorMessage('$error ($e)');
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryOrange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Send Reset Link'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sign In'),
        backgroundColor: AppTheme.primaryOrange,
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppTheme.primaryOrange.withOpacity(0.1),
              Colors.white,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryOrange.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.pets,
                        size: 64,
                        color: AppTheme.primaryOrange,
                      ),
                    ),
                    
                    const SizedBox(height: 32),
                    
                    const Text(
                      'Welcome Back!',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Poppins',
                      ),
                    ),
                    
                    const SizedBox(height: 8),
                    
                    const Text(
                      'Sign in to continue',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                    
                    const SizedBox(height: 40),
                    
                    // Email Field
                    TextFormField(
                      controller: _emailController,
                      decoration: InputDecoration(
                        labelText: 'Email',
                        prefixIcon: const Icon(Icons.email),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: Validators.validateEmail,
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Password Field
                    TextFormField(
                      controller: _passwordController,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility_off : Icons.visibility,
                          ),
                          onPressed: () {
                            setState(() => _obscurePassword = !_obscurePassword);
                          },
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      obscureText: _obscurePassword,
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Required';
                        if (v.length < 6) return 'Min 6 characters';
                        return null;
                      },
                    ),
                    
                    const SizedBox(height: 12),
                    
                    // Forgot Password
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const ForgotPasswordScreen()),
                          );
                        },
                        child: const Text('Forgot Password?'),
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Sign In Button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleLogin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryOrange,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text(
                                'Sign In',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Poppins',
                                ),
                              ),
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Sign Up Link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text("Don't have an account? "),
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                          child: const Text(
                            'Sign Up',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryOrange,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
