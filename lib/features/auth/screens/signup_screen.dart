import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:stray_resuce_bih/core/theme/app_theme.dart';
import 'package:stray_resuce_bih/core/models/enums.dart';
import 'package:stray_resuce_bih/core/models/models.dart';
import 'package:stray_resuce_bih/core/services/firebase_service.dart';
import 'package:stray_resuce_bih/core/services/database_service.dart';
import 'package:stray_resuce_bih/core/services/otp_service.dart';
import 'package:stray_resuce_bih/features/dashboards/citizen_dashboard.dart';
import 'package:stray_resuce_bih/features/dashboards/volunteer_dashboard.dart';
import 'package:stray_resuce_bih/features/dashboards/ngo_dashboard.dart';
import 'package:stray_resuce_bih/features/dashboards/vet_dashboard.dart';
import 'package:stray_resuce_bih/core/utils/validators.dart';

/// Signup Screen with role-specific fields
class SignupScreen extends ConsumerStatefulWidget {
  final UserRole role;
  
  const SignupScreen({super.key, required this.role});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _cityController = TextEditingController(text: 'Erode');
  
  // Role-specific controllers
  final _organizationNameController = TextEditingController();
  final _registrationNumberController = TextEditingController();
  final _licenseNumberController = TextEditingController();
  final _clinicNameController = TextEditingController();
  final _areaOfOperationController = TextEditingController();
  
  String? _selectedTransport;
  bool _isFullTime = true;
  bool _acceptedTerms = false;
  bool _isLoading = false;
  
  // OTP State
  bool _isEmailVerified = false;
  bool _isSendingOtp = false;
  
  // Phone validation state
  String? _phoneError;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _cityController.dispose();
    _organizationNameController.dispose();
    _registrationNumberController.dispose();
    _licenseNumberController.dispose();
    _clinicNameController.dispose();
    _areaOfOperationController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showErrorMessage(String message) {
    _showSnackBar(message, isError: true);
  }
  
  void _validatePhone(String value) {
    setState(() {
      if (value.isEmpty) {
        _phoneError = null; // Don't show error for empty field
      } else if (value.length < 10) {
        _phoneError = 'Phone number must be 10 digits';
      } else if (value.length > 10) {
        _phoneError = 'Phone number cannot exceed 10 digits';
      } else if (!RegExp(r'^\d+$').hasMatch(value)) {
        _phoneError = 'Only numbers allowed';
      } else {
        _phoneError = null; // Valid
      }
    });
  }

  Future<void> _verifyEmail() async {
    final email = _emailController.text.trim();
    final emailError = Validators.validateEmail(email);
    if (emailError != null) {
      _showSnackBar(emailError, isError: true);
      return;
    }

    setState(() => _isSendingOtp = true);

    // Send OTP
    final error = await OtpService().sendOtp(email);

    if (mounted) {
      setState(() => _isSendingOtp = false);
      if (error == null) {
        _showOtpDialog();
        _showSnackBar('OTP sent to your Gmail! Check inbox and spam folder.');
      } else {
        _showSnackBar(error, isError: true);
      }
    }
  }

  Future<void> _showOtpDialog() async {
    final otpController = TextEditingController();
    
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Verify Email'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter the 6-digit code sent to your email.'),
            const SizedBox(height: 16),
            TextField(
              controller: otpController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, letterSpacing: 8),
              decoration: const InputDecoration(
                counterText: '',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final otp = otpController.text.trim();
              if (otp.length != 6) return;

              final verified = await OtpService().verifyOtp(otp);
              
              if (context.mounted) {
                if (verified) {
                  setState(() => _isEmailVerified = true);
                  Navigator.pop(context);
                  _showSnackBar('Email verified successfully!');
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Invalid OTP'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryOrange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Verify'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleSignup() async {
    if (!_formKey.currentState!.validate()) return;
    
    // 1. Check if verify button was clicked and passed
    if (!_isEmailVerified) {
      _showErrorMessage('Please verify your email address first');
      return;
    }
    
    // Terms check
    if (!_acceptedTerms) {
      _showErrorMessage('Please accept terms and conditions');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. Create Firebase Auth account
      final firebaseService = FirebaseService();
      User? user;
      bool isNewUser = true;

      try {
        final userCredential = await firebaseService.registerWithEmailPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
        user = userCredential?.user;
      } on Exception catch (e) {
        // 1b. Auto-login if account exists
        if (e.toString().contains('email-already-in-use')) {
           try {
             final loginCredential = await firebaseService.signInWithEmailPassword(
                email: _emailController.text.trim(),
                password: _passwordController.text,
             );
             user = loginCredential?.user;
             isNewUser = false;
           } catch (_) {
             _showErrorMessage('Account exists but password is incorrect.');
             return;
           }
        } else {
          rethrow;
        }
      }

      if (user == null) {
        _showErrorMessage('Authentication failed.');
        return;
      }
      
      // 2. Create/Update user profile in Firestore
      final userModel = UserModel(
        uid: user.uid,
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        email: _emailController.text.trim(),
        role: widget.role,
        city: _cityController.text.trim(),
        location: const GeoPoint(11.3410, 77.7172), 
        verified: true, // We already verified via OTP
        createdAt: DateTime.now(),
        // Role-specific fields
        organizationName: widget.role == UserRole.ngo 
            ? _organizationNameController.text.trim() 
            : null,
        registrationNumber: widget.role == UserRole.ngo || widget.role == UserRole.vet
            ? _registrationNumberController.text.trim()
            : null,
        licenseNumber: widget.role == UserRole.vet
            ? _licenseNumberController.text.trim()
            : null,
        clinicName: widget.role == UserRole.vet
            ? _clinicNameController.text.trim()
            : null,
        availability: widget.role == UserRole.volunteer || widget.role == UserRole.vet
            ? _isFullTime
            : null,
        transport: widget.role == UserRole.volunteer
            ? _selectedTransport
            : null,
        areaOfOperation: widget.role == UserRole.volunteer
            ? _areaOfOperationController.text.trim()
            : null,
      );

      await DatabaseService().createUserProfile(userModel);

      if (!mounted) return;

      // 3. Success -> Dashboard
      _navigateToDashboard(widget.role);

    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Signup failed: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Sign Up as ${widget.role.displayName}'),
        backgroundColor: AppTheme.primaryOrange,
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            // Role Badge
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryOrange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.primaryOrange, width: 2),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(widget.role.emoji, style: const TextStyle(fontSize: 24)),
                    const SizedBox(width: 8),
                    Text(
                      widget.role.displayName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryOrange,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Common Fields
            _buildTextField(
              controller: _nameController,
              label: 'Full Name',
              icon: Icons.person,
              validator: (v) => v!.isEmpty ? 'Required' : null,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s]')),
              ],
            ),
            
            const SizedBox(height: 16),
            
            _buildTextField(
              controller: _phoneController,
              label: 'Mobile Number',
              icon: Icons.phone,
              keyboardType: TextInputType.phone,
              validator: Validators.validatePhone,
              onChanged: _validatePhone,
              errorText: _phoneError,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(10),
              ],
            ),
            
            const SizedBox(height: 16),
            
            _buildTextField(
              controller: _emailController,
              label: 'Email',
              icon: Icons.email,
              keyboardType: TextInputType.emailAddress,
              validator: Validators.validateEmail,
              suffix: _isEmailVerified
                  ? const Icon(Icons.check_circle, color: Colors.green)
                  : TextButton(
                      onPressed: _isSendingOtp ? null : _verifyEmail,
                      child: _isSendingOtp
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text(
                              'Verify',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                    ),
            ),
            
            const SizedBox(height: 16),
            
            _buildTextField(
              controller: _passwordController,
              label: 'Password',
              icon: Icons.lock,
              obscureText: true,
              validator: (v) => v!.length < 6 ? 'Min 6 characters' : null,
            ),
            
            const SizedBox(height: 16),
            
            _buildTextField(
              controller: _cityController,
              label: 'City / Area',
              icon: Icons.location_city,
              validator: (v) => v!.isEmpty ? 'Required' : null,
            ),
            
            // Role-specific fields
            if (widget.role == UserRole.volunteer) ..._buildVolunteerFields(),
            if (widget.role == UserRole.ngo) ..._buildNGOFields(),
            if (widget.role == UserRole.vet) ..._buildVetFields(),
            
            const SizedBox(height: 24),
            
            // Terms & Conditions
            CheckboxListTile(
              value: _acceptedTerms,
              onChanged: (v) => setState(() => _acceptedTerms = v!),
              title: const Text('I accept the Terms & Conditions'),
              controlAffinity: ListTileControlAffinity.leading,
              activeColor: AppTheme.primaryOrange,
            ),
            
            const SizedBox(height: 24),
            
            // Sign Up Button
            SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleSignup,
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
                        'Create Account',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
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
    TextInputType? keyboardType,
    bool obscureText = false,
    String? Function(String?)? validator,
    Widget? suffix,
    void Function(String)? onChanged,
    String? errorText,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        suffixIcon: suffix,
        errorText: errorText,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      keyboardType: keyboardType,
      obscureText: obscureText,
      validator: validator,
      onChanged: onChanged,
      inputFormatters: inputFormatters,
    );
  }

  List<Widget> _buildVolunteerFields() {
    return [
      const SizedBox(height: 24),
      const Text(
        'Volunteer Details',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 16),
      
      _buildTextField(
        controller: _areaOfOperationController,
        label: 'Area of Operation',
        icon: Icons.map,
        validator: (v) => v!.isEmpty ? 'Required' : null,
      ),
      
      const SizedBox(height: 16),
      
      DropdownButtonFormField<String>(
        value: _selectedTransport,
        decoration: InputDecoration(
          labelText: 'Transport',
          prefixIcon: const Icon(Icons.directions_car),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        items: ['Bike', 'Car', 'None'].map((t) {
          return DropdownMenuItem(value: t.toLowerCase(), child: Text(t));
        }).toList(),
        onChanged: (v) => setState(() => _selectedTransport = v),
        validator: (v) => v == null ? 'Required' : null,
      ),
      
      const SizedBox(height: 16),
      
      SwitchListTile(
        title: const Text('Availability'),
        subtitle: Text(_isFullTime ? 'Full Time' : 'Part Time'),
        value: _isFullTime,
        onChanged: (v) => setState(() => _isFullTime = v),
        activeColor: AppTheme.primaryOrange,
      ),
    ];
  }

  List<Widget> _buildNGOFields() {
    return [
      const SizedBox(height: 24),
      const Text(
        'NGO Details',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 16),
      
      _buildTextField(
        controller: _organizationNameController,
        label: 'Organization Name',
        icon: Icons.business,
        validator: (v) => v!.isEmpty ? 'Required' : null,
      ),
      
      const SizedBox(height: 16),
      
      _buildTextField(
        controller: _registrationNumberController,
        label: 'Registration Number',
        icon: Icons.badge,
        keyboardType: TextInputType.number,
        validator: (v) => v!.isEmpty ? 'Required' : null,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      ),
    ];
  }

  List<Widget> _buildVetFields() {
    return [
      const SizedBox(height: 24),
      const Text(
        'Veterinary Details',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 16),
      
      _buildTextField(
        controller: _clinicNameController,
        label: 'Clinic Name',
        icon: Icons.local_hospital,
        validator: (v) => v!.isEmpty ? 'Required' : null,
      ),
      
      const SizedBox(height: 16),
      
      _buildTextField(
        controller: _licenseNumberController,
        label: 'License Number',
        icon: Icons.verified,
        keyboardType: TextInputType.number,
        validator: (v) => v!.isEmpty ? 'Required' : null,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      ),
      
      const SizedBox(height: 16),
      
      SwitchListTile(
        title: const Text('Emergency Availability'),
        subtitle: Text(_isFullTime ? 'Available 24/7' : 'Limited Hours'),
        value: _isFullTime,
        onChanged: (v) => setState(() => _isFullTime = v),
        activeColor: AppTheme.primaryOrange,
      ),
    ];
  }
}
