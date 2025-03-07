import 'dart:convert';
import 'dart:html' as html;
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class ApiService {
  // Only use localhost - no production API exists
  static const String baseUrl = 'http://127.0.0.1:5000';
  
  // API key for authentication when connecting to remote server
  static String? apiKey;
  
  // Helper to get headers with API key if available
  static Map<String, String> _getHeaders() {
    final headers = {'Content-Type': 'application/json'};
    if (apiKey != null && apiKey!.isNotEmpty) {
      headers['X-API-Key'] = apiKey!;
    }
    return headers;
  }
  
  // Method to verify API key with the server
  static Future<bool> verifyApiKey() async {
    if (apiKey == null || apiKey!.isEmpty) {
      return false;
    }
    
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/verify-key'),
        headers: _getHeaders(),
      );
      
      return response.statusCode == 200;
    } catch (e) {
      print('Error verifying API key: $e');
      return false;
    }
  }
  
  // Method to generate a meditation based on stress description
  static Future<Map<String, dynamic>> processText(String stressDescription) async {
    try {
      print('Sending request to backend: $baseUrl/api/generate-meditation');
      // Send request to the Python backend
      final response = await http.post(
        Uri.parse('$baseUrl/api/generate-meditation'),
        headers: _getHeaders(),
        body: jsonEncode({'worry': stressDescription}),
      );
      
      print('Response status code: ${response.statusCode}');
      print('Response body: ${response.body}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        // Check if this is an asynchronous job response
        if (data.containsKey('job_id')) {
          print('Received job ID: ${data['job_id']}');
          return {
            'job_id': data['job_id'],
            'status': data['status'] ?? 'pending',
            'message': data['message'] ?? 'Meditation generation started',
          };
        }
        
        // Check if this is a direct meditation response
        if (data.containsKey('meditation_script')) {
          return {
            'meditation': data['meditation_script'],
            'audioUrl': data['audio_url'],
            'status': 'success',
          };
        }
        
        // Unknown response format
        return {
          'meditation': 'Received unexpected response format from server',
          'status': 'error',
          'error': 'Invalid response format',
        };
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        // Authentication error
        return {
          'meditation': 'Authentication failed. Please check your API key configuration.',
          'status': 'error',
          'error': 'Authentication failed: ${response.statusCode}',
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
        headers: _getHeaders(),
      );
      
      print('Status response: ${response.statusCode}, ${response.body}');
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        // Authentication error
        return {
          'status': 'error',
          'progress': 0,
          'error': 'Authentication failed. Please check your API key configuration.',
        };
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