import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'dart:math';
import 'dart:developer' as developer;

/// Professional OTP Service using Gmail SMTP
/// Sends real emails via Gmail
class OtpService {
  // Singleton
  static final OtpService _instance = OtpService._internal();
  factory OtpService() => _instance;
  OtpService._internal();

  // Store OTP temporarily (email -> OTP mapping)
  final Map<String, String> _otpStorage = {};
  final Map<String, DateTime> _otpExpiry = {};
  
  // OTP validity duration
  static const _otpValidityMinutes = 10;
  
  // Gmail SMTP Configuration
  // IMPORTANT: Replace these with your actual Gmail credentials
  // For security, use an App Password, not your actual Gmail password
  // Generate App Password: https://myaccount.google.com/apppasswords
  static const String _gmailUsername = 'YOUR_EMAIL@gmail.com'; 
  static const String _gmailPassword = 'YOUR_APP_PASSWORD';
  static const String _senderName = 'StrayCare Connect';

  /// Send OTP to the specified email via Gmail SMTP
  /// Returns null if successful, error message otherwise
  Future<String?> sendOtp(String email) async {
    developer.log('🔵 OTP Service: Sending OTP to $email via Gmail SMTP', name: 'OtpService');
    
    if (email.isEmpty || !email.contains('@')) {
      developer.log('❌ OTP Service: Invalid email format', name: 'OtpService');
      return 'Invalid email address';
    }

    try {
      // Generate random 6-digit OTP
      final random = Random();
      final otp = (100000 + random.nextInt(900000)).toString();
      
      // Store OTP with expiry
      _otpStorage[email] = otp;
      _otpExpiry[email] = DateTime.now().add(const Duration(minutes: _otpValidityMinutes));
      
      developer.log('� Generated OTP: $otp for $email', name: 'OtpService');
      
      // Configure Gmail SMTP
      final smtpServer = gmail(_gmailUsername, _gmailPassword);
      
      // Create email message
      final message = Message()
        ..from = Address(_gmailUsername, _senderName)
        ..recipients.add(email)
        ..subject = 'Your StrayCare Connect Verification Code'
        ..html = '''
          <!DOCTYPE html>
          <html>
          <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
          </head>
          <body style="margin: 0; padding: 0; font-family: Arial, sans-serif; background-color: #f5f5f5;">
            <table width="100%" cellpadding="0" cellspacing="0" style="background-color: #f5f5f5; padding: 20px;">
              <tr>
                <td align="center">
                  <table width="600" cellpadding="0" cellspacing="0" style="background-color: white; border-radius: 10px; overflow: hidden; box-shadow: 0 2px 10px rgba(0,0,0,0.1);">
                    <!-- Header -->
                    <tr>
                      <td style="background: linear-gradient(135deg, #FF6B35 0%, #F7931E 100%); padding: 30px; text-align: center;">
                        <h1 style="color: white; margin: 0; font-size: 28px;">StrayCare Connect</h1>
                        <p style="color: white; margin: 10px 0 0 0; font-size: 14px;">Email Verification</p>
                      </td>
                    </tr>
                    
                    <!-- Content -->
                    <tr>
                      <td style="padding: 40px 30px;">
                        <h2 style="color: #333; margin: 0 0 20px 0; font-size: 24px;">Verify Your Email</h2>
                        <p style="color: #666; font-size: 16px; line-height: 1.6; margin: 0 0 30px 0;">
                          Thank you for signing up! Please use the verification code below to complete your registration:
                        </p>
                        
                        <!-- OTP Box -->
                        <div style="background-color: #f8f9fa; border: 2px dashed #FF6B35; border-radius: 8px; padding: 20px; text-align: center; margin: 30px 0;">
                          <p style="color: #666; font-size: 14px; margin: 0 0 10px 0;">Your Verification Code</p>
                          <h1 style="color: #FF6B35; font-size: 48px; letter-spacing: 8px; margin: 0; font-weight: bold;">$otp</h1>
                        </div>
                        
                        <p style="color: #666; font-size: 14px; line-height: 1.6; margin: 20px 0 0 0;">
                          <strong>Important:</strong> This code will expire in $_otpValidityMinutes minutes.
                        </p>
                        <p style="color: #999; font-size: 12px; line-height: 1.6; margin: 10px 0 0 0;">
                          If you didn't request this code, please ignore this email.
                        </p>
                      </td>
                    </tr>
                    
                    <!-- Footer -->
                    <tr>
                      <td style="background-color: #f8f9fa; padding: 20px 30px; text-align: center; border-top: 1px solid #e9ecef;">
                        <p style="color: #999; font-size: 12px; margin: 0;">
                          © 2024 StrayCare Connect. All rights reserved.
                        </p>
                        <p style="color: #999; font-size: 12px; margin: 10px 0 0 0;">
                          Helping strays find care, one connection at a time.
                        </p>
                      </td>
                    </tr>
                  </table>
                </td>
              </tr>
            </table>
          </body>
          </html>
        ''';
      
      // Send email
      developer.log('📤 Sending email via Gmail SMTP...', name: 'OtpService');
      final sendReport = await send(message, smtpServer);
      
      developer.log('✅ OTP Service: Email sent successfully! ${sendReport.toString()}', name: 'OtpService');
      
      return null; // Success
    } on MailerException catch (e) {
      developer.log('❌ OTP Service: Failed to send email: ${e.toString()}', name: 'OtpService');
      
      // Provide user-friendly error messages
      if (e.toString().contains('authentication')) {
        return 'Email service authentication failed. Please contact support.';
      } else if (e.toString().contains('network')) {
        return 'Network error. Please check your internet connection.';
      } else {
        return 'Failed to send verification email. Please try again.';
      }
    } catch (e) {
      developer.log('❌ OTP Service: Unexpected error: $e', name: 'OtpService');
      return 'An unexpected error occurred. Please try again.';
    }
  }

  /// Verify the OTP entered by user
  Future<bool> verifyOtp(String otp) async {
    developer.log('🔵 OTP Service: Verifying OTP: $otp', name: 'OtpService');
    
    try {
      // Find matching email for this OTP
      String? matchingEmail;
      for (var entry in _otpStorage.entries) {
        if (entry.value == otp) {
          matchingEmail = entry.key;
          break;
        }
      }
      
      if (matchingEmail == null) {
        developer.log('❌ OTP Service: No matching OTP found', name: 'OtpService');
        return false;
      }
      
      // Check if OTP has expired
      final expiry = _otpExpiry[matchingEmail];
      if (expiry == null || DateTime.now().isAfter(expiry)) {
        developer.log('❌ OTP Service: OTP has expired', name: 'OtpService');
        _otpStorage.remove(matchingEmail);
        _otpExpiry.remove(matchingEmail);
        return false;
      }
      
      // OTP is valid
      developer.log('✅ OTP Service: OTP verified successfully for $matchingEmail', name: 'OtpService');
      
      // Clean up used OTP
      _otpStorage.remove(matchingEmail);
      _otpExpiry.remove(matchingEmail);
      
      return true;
    } catch (e) {
      developer.log('❌ OTP Service: Error verifying OTP: $e', name: 'OtpService');
      return false;
    }
  }
}
