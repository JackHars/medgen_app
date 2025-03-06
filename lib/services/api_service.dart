import 'dart:convert';
import 'dart:html' as html;
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class ApiService {
  // Update with the backend URL
  static const String baseUrl = kDebugMode 
      ? 'http://localhost:5000' // Local development
      : 'https://api.oneiro.ai'; // Production
  
  // Method to generate a meditation based on stress description
  static Future<Map<String, dynamic>> processText(String stressDescription) async {
    try {
      // Send request to the Python backend
      final response = await http.post(
        Uri.parse('$baseUrl/api/generate-meditation'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'worry': stressDescription}),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'meditation': data['meditation_script'],
          'audioUrl': data['audio_url'],
          'status': 'success',
        };
      } else {
        throw Exception('Failed to generate meditation: ${response.statusCode}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('API Error: $e');
        // For development: Simulating a meditation response
        await Future.delayed(const Duration(seconds: 2));
        
        return {
          'meditation': _generateSampleMeditation(stressDescription),
          'audioUrl': null, // No audio in debug mode
          'status': 'success',
        };
      } else {
        // In production, return the error
        return {
          'meditation': 'Sorry, we had trouble generating your meditation. Please try again.',
          'audioUrl': null,
          'status': 'error',
          'error': e.toString(),
        };
      }
    }
  }
  
  // Method to get the status of a meditation generation job
  static Future<Map<String, dynamic>> getMeditationStatus(String jobId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/meditation-status/$jobId'),
        headers: {'Content-Type': 'application/json'},
      );
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to get meditation status: ${response.statusCode}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Status API Error: $e');
        // Simulate a completed job for development
        return {
          'status': 'completed',
          'progress': 100,
          'meditation_script': _generateSampleMeditation('sample'),
          'audio_url': null,
        };
      } else {
        rethrow;
      }
    }
  }
  
  // Method to download meditation audio
  static void downloadMeditationAudio(String audioUrl, String fileName) {
    if (audioUrl != null && audioUrl.isNotEmpty) {
      // Create an anchor element with download attribute
      final anchor = html.AnchorElement(href: audioUrl)
        ..setAttribute('download', fileName)
        ..style.display = 'none';
      
      // Add to the DOM and click it
      html.document.body?.children.add(anchor);
      anchor.click();
      
      // Clean up
      anchor.remove();
    }
  }
  
  // Helper method to generate a sample meditation for development
  static String _generateSampleMeditation(String stressDescription) {
    // Simplified logic to create a somewhat relevant meditation
    final String lowercaseDesc = stressDescription.toLowerCase();
    
    if (lowercaseDesc.contains('work') || lowercaseDesc.contains('deadline') || lowercaseDesc.contains('overwhelm')) {
      return '''Find a comfortable position and gently close your eyes. Take a deep breath in through your nose for 4 counts... and exhale through your mouth for 6 counts.

As you continue breathing deeply, notice the weight of work expectations and deadlines gradually lifting from your shoulders with each exhale. Your workplace challenges are temporary, but your inner peace is always accessible.

Imagine yourself completing your tasks with ease and clarity, one step at a time. There is no rush, only steady progress.

Now, bring your awareness to any tension you might be holding in your body. With each breath, consciously release that tension, starting from your forehead, moving down to your shoulders, your chest, and all the way to your toes.

Remember that you are more than your work. You are a being of limitless potential, simply experiencing a temporary challenge that will soon pass.

In this moment, you are exactly where you need to be. All is well.

When you're ready, gently wiggle your fingers and toes, and slowly open your eyes, carrying this sense of calm with you throughout your day.''';
    } else if (lowercaseDesc.contains('sleep') || lowercaseDesc.contains('insomnia') || lowercaseDesc.contains('rest')) {
      return '''Make yourself comfortable, whether you're lying in bed or sitting in a relaxing position. Close your eyes gently and begin to notice your breath, flowing in and out naturally.

With each inhale, feel a wave of relaxation entering your body. With each exhale, feel tension and wakefulness draining away.

Imagine a soft, warm light slowly traveling through your body, starting at your toes. As this healing light touches each part of you, that area becomes completely relaxed and heavy.

The light moves slowly up your feet... your ankles... your calves... your knees... making each part heavy and relaxed. Continue this journey through your entire body, all the way to the crown of your head.

Now picture yourself in a peaceful place – perhaps a quiet beach at sunset, or a meadow filled with soft grass. The air is perfectly comfortable, and you feel safe and protected.

With each breath, you sink deeper into relaxation. Your mind becomes quieter, your thoughts slower and more distant.

Remember that sleep is a natural process. You don't need to force it – simply create the conditions and allow it to come in its own time. Release any worries about sleeping and rest in the simple peace of this moment.

Continue breathing slowly and deeply, allowing your consciousness to drift like leaves on a gentle stream, carrying you toward restful sleep.''';
    } else {
      return '''Close your eyes and take a long, deep breath in through your nose. Hold it for a moment, then exhale completely through your mouth. Continue breathing deeply, allowing each breath to be fuller and more relaxing than the last.

As you breathe, become aware of any tension you're holding in your body. With each exhale, intentionally release that tension, letting it melt away.

Now, bring your attention to the present moment. Not the past with its memories, not the future with its expectations – just this moment, right here, right now.

Acknowledge any thoughts that arise without judgment. See them as clouds passing in the sky of your mind. You don't need to chase them or push them away – simply observe them as they come and go.

Return your focus to your breath, that constant companion that has been with you since your first moment and will be with you until your last.

With each inhale, imagine drawing in peace, clarity, and strength. With each exhale, release worry, stress, and anything that doesn't serve you.

Remember that you are not your thoughts or emotions – you are the awareness that observes them. In this space of awareness, there is always peace.

Take a few more deep breaths, and when you're ready, gently wiggle your fingers and toes, and slowly open your eyes, carrying this sense of calm awareness with you.''';
    }
  }
} 