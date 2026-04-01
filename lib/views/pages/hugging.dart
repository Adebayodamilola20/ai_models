import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class HuggingFaceService {
  static final _token = dotenv.env['HUGGINGFACE_TOKEN'] ?? '';
  
  static const _baseUrl = 'https://ai-models-94ei.onrender.com';
  static const _captionUrl = '$_baseUrl/analyze_image';
  static const _generationUrl = '$_baseUrl/generate_image';

  static Future<String> analyzeImage(File image) async {
    try {
      final bytes = await image.readAsBytes();

      final response = await http.post(
        Uri.parse(_captionUrl),
        headers: {
          'Authorization': 'Bearer $_token',
        },
        body: bytes,
      ).timeout(const Duration(seconds: 120));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map && data.containsKey('generated_text')) {
          return data['generated_text'] ?? 'No description found.';
        }
        if (data is List && data.isNotEmpty) {
          return data[0]['generated_text'] ?? 'No description found.';
        }
      } 
      
      // Clean up error message if it's HTML
      if (response.body.contains('<!DOCTYPE html>') || response.body.contains('<html')) {
        if (response.statusCode == 503) {
          return "Model is loading. Please wait 20-30 seconds and try again.";
        }
        return "Hugging Face Error: Model is currently unavailable or the API path is incorrect (Status: ${response.statusCode})";
      }

      final errorData = jsonDecode(response.body);
      return "AI Error: ${errorData['error'] ?? 'Unknown error (Status: ${response.statusCode})'}";
    } catch (e) {
      return "Connection Error: $e";
    }
  }

  static Future<File?> generateImage(String prompt) async {
    try {
      final response = await http.post(
        Uri.parse(_generationUrl),
        headers: {
          'Authorization': 'Bearer $_token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({"inputs": prompt}),
      ).timeout(const Duration(seconds: 120));

      if (response.statusCode == 200) {
        // Create a temporary file to store the generated image
        final directory = Directory.systemTemp;
        final file = File('${directory.path}/gen_${DateTime.now().millisecondsSinceEpoch}.png');
        await file.writeAsBytes(response.bodyBytes);
        return file;
      }
      return null;
    } catch (e) {
      print("Generation Error: $e");
      return null;
    }
  }
}

