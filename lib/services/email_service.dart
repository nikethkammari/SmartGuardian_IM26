import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class EmailService {



  static const String _serviceId = 'service_smuxq4m';
  static const String _publicKey = 'tmxqqbH_JgwNFONgt';


  static const String _sosTemplateId = 'df7mqq5';




  Future<bool> _sendViaEmailJS({
    required String toEmail,
    required String templateId,
    required Map<String, dynamic> templateParams,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('https://api.emailjs.com/api/v1.0/email/send'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'service_id': _serviceId,
          'template_id': templateId,
          'user_id': _publicKey,
          'template_params': {'email': toEmail, ...templateParams},
        }),
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        debugPrint('EmailJS Error ${response.statusCode}: ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('EmailJS Exception: $e');
      return false;
    }
  }


  Future<bool> sendWelcomeEmail(String userEmail, String userName) async {
    return _sendViaEmailJS(
      toEmail: userEmail,
      templateId:
          'template_welcome',
      templateParams: {'user_name': userName},
    );
  }


  Future<bool> sendSOSAlert({
    required List<String> emergencyEmails,
    required String userName,
    required String location,
  }) async {
    bool allSent = true;
    for (var email in emergencyEmails) {
      final success = await _sendViaEmailJS(
        toEmail: email,
        templateId: _sosTemplateId,
        templateParams: {
          'user_name': userName,
          'location_link': location,
          'timestamp': DateTime.now().toString(),
        },
      );
      if (!success) allSent = false;
    }
    return allSent;
  }


  Future<bool> sendSOSPremiumAlert({
    required String emergencyEmail,
    required String fullName,
    required String locationName,
    required String latitude,
    required String longitude,
    required String dateTime,
    required String link,
  }) async {
    return _sendViaEmailJS(
      toEmail: emergencyEmail,
      templateId: 'template_gzuk13l',
      templateParams: {
        'FULL_NAME': fullName,
        'LOCATION_NAME': locationName,
        'LINK': link,
        'LATITUDE': latitude,
        'LONGITUDE': longitude,
        'DATE_TIME': dateTime,
      },
    );
  }


  Future<bool> sendJourneyNotification({
    required String userEmail,
    required String userName,
    required String startLocation,
    required String destination,
    required bool isStarting,
  }) async {
    return _sendViaEmailJS(
      toEmail: userEmail,
      templateId: 'template_journey',
      templateParams: {
        'user_name': userName,
        'start_location': startLocation,
        'destination': destination,
        'status': isStarting ? 'Started' : 'Completed',
        'timestamp': DateTime.now().toString(),
      },
    );
  }


  Future<bool> sendCustomEmail({
    required String to,
    required String subject,
    required String htmlBody,
  }) async {


    return _sendViaEmailJS(
      toEmail: to,
      templateId: 'template_custom',
      templateParams: {'subject': subject, 'message': htmlBody},
    );
  }
}
