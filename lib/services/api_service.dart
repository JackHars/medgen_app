import 'dart:convert';
import 'dart:html' as html;
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class ApiService {
  // Only use localhost - no production API exists
  static const String baseUrl = 'http://127.0.0.1:5000';
  
  // Method to generate a meditation based on stress description
  static Future<Map<String, dynamic>> processText(String stressDescription) async {
    try {
      print('Sending request to backend: $baseUrl/api/generate-meditation');
      // Send request to the Python backend
      final response = await http.post(
        Uri.parse('$baseUrl/api/generate-meditation'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'worry': stressDescription}),
      );
      
      print('Response status code: ${response.statusCode}');
      print('Response body: ${response.body}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'meditation': data['meditation_script'],
          'audioUrl': data['audio_url'],
          'status': 'success',
        };
      } else {
        throw Exception('Failed to generate meditation: ${response.statusCode}, body: ${response.body}');
      }
    } catch (e) {
      print('API Error (detailed): $e');
      // Return error message
      return {
        'meditation': 'Unable to connect to meditation server. Please check your connection and try again.',
        'audioUrl': null,
        'status': 'error',
        'error': e.toString(),
      };
    }
  }
  
  // Method to get the status of a meditation generation job
  static Future<Map<String, dynamic>> getMeditationStatus(String jobId) async {
    try {
      print('Checking status for job: $jobId');
      final response = await http.get(
        Uri.parse('$baseUrl/api/meditation-status/$jobId'),
        headers: {'Content-Type': 'application/json'},
      );
      
      print('Status response: ${response.statusCode}, ${response.body}');
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to get meditation status: ${response.statusCode}');
      }
    } catch (e) {
      print('Status API Error: $e');
      // Return error status
      return {
        'status': 'error',
        'progress': 0,
        'error': 'Failed to connect to server: $e',
      };
    }
  }
  
  // Method to download meditation audio
  static void downloadMeditationAudio(String audioUrl, String fileName) {
    if (audioUrl != null && audioUrl.isNotEmpty) {
      // If it's a relative URL, prepend the base URL
      final String fullUrl = audioUrl.startsWith('http') 
          ? audioUrl 
          : '$baseUrl$audioUrl';
      
      print('Downloading audio from: $fullUrl');
      
      // Create an anchor element with download attribute
      final anchor = html.AnchorElement(href: fullUrl)
        ..setAttribute('download', fileName)
        ..style.display = 'none';
      
      // Add to the DOM and click it
      html.document.body?.children.add(anchor);
      anchor.click();
      
      // Clean up
      anchor.remove();
    }
  }
} 