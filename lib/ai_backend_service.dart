import 'dart:convert';
import 'package:http/http.dart' as http;

class AIBackendService {
  static const String baseUrl = 'https://prep-buddy-ai-backend.onrender.com';

  static Future<Map<String, dynamic>> analyzeAnswer({
    required String question,
    required String answer,
    required List<String> keywords,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/analyze-answer'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'question': question,
          'answer': answer,
          'keywords': keywords,
        }),
      );

      if (response.statusCode != 200) {
        return {
          'summary':
              'AI feedback abhi available nahi hai. Normal analysis use ki gayi hai.',
          'improvements': <String>[
            'Answer ko thoda aur structured banao.',
            'Relevant keywords naturally include karo.',
            'Short example ya reason add karo.',
          ],
          'missing_keywords': <String>[],
          'suggested_keywords': keywords,
          'better_answer': answer,
        };
      }

      return Map<String, dynamic>.from(jsonDecode(response.body));
    } catch (_) {
      return {
        'summary':
            'AI feedback abhi available nahi hai. Normal analysis use ki gayi hai.',
        'improvements': <String>[
          'Answer ko thoda aur structured banao.',
          'Relevant keywords naturally include karo.',
          'Short example ya reason add karo.',
        ],
        'missing_keywords': <String>[],
        'suggested_keywords': keywords,
        'better_answer': answer,
      };
    }
  }

  static Future<Map<String, dynamic>> suggestKeywords({
    required String question,
    required String type,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/suggest-keywords'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'question': question, 'type': type}),
      );

      if (response.statusCode != 200) {
        return {
          'suggested_keywords': <String>[],
          'reason': 'AI keyword suggestions abhi available nahi hain.',
        };
      }

      return Map<String, dynamic>.from(jsonDecode(response.body));
    } catch (_) {
      return {
        'suggested_keywords': <String>[],
        'reason': 'AI keyword suggestions abhi available nahi hain.',
      };
    }
  }
}
