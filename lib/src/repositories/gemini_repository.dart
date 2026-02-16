import 'dart:convert';
import 'dart:io';

import 'package:google_generative_ai/google_generative_ai.dart';

class GeminiRepository {
  Future<String?> extractTextFromImage({
    required String apiKey,
    required List<int> imageBytes,
    String? prompt,
  }) async {
    try {
      final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$apiKey',
      );
      final base64Image = base64Encode(imageBytes);

      final requestBody = {
        'contents': [
          {
            'parts': [
              {
                'text': prompt ??
                    'Extract all visible text from this image. Output ONLY the text.'
              },
              {
                'inline_data': {'mime_type': 'image/jpeg', 'data': base64Image}
              }
            ]
          }
        ],
        'generationConfig': {'temperature': 0.4, 'maxOutputTokens': 1000}
      };

      final client = HttpClient();
      final request = await client.postUrl(url);
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(requestBody));

      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();
      final json = jsonDecode(responseBody) as Map<String, dynamic>;

      if (json.containsKey('candidates')) {
        final candidates = json['candidates'] as List;
        if (candidates.isNotEmpty) {
          final contentParts = candidates[0]['content']['parts'] as List;
          if (contentParts.isNotEmpty) {
            return contentParts[0]['text'].toString().trim();
          }
        }
      }
      return null;
    } catch (e) {
      print('❌ Gemini OCR Error: $e');
      return null;
    }
  }

  Future<List<double>> generateEmbedding({
    required String text,
    required String apiKey,
  }) async {
    final model = GenerativeModel(
      model: 'text-embedding-004', // Embedding Model
      apiKey: apiKey,
    );

    final content = Content.text(text);
    final result = await model.embedContent(content);

    return result.embedding.values;
  }
}
