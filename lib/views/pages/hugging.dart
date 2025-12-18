import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class HuggingFaceService {
  static const _token = String.fromEnvironment('HUGGING_FACE_TOKEN', defaultValue: '');
  static const _url =
      'https://api-inference.huggingface.co/models/Salesforce/blip-image-captioning-large';

  static Future<String> analyzeImage(File image, String prompt) async {
    try {
      final bytes = await image.readAsBytes();
      final base64Image = base64Encode(bytes);

      final body = jsonEncode({
        "input": {
          "images": base64Image,
          "prompt": prompt.isEmpty
              ? "Describe this image"
              : "USER:<image>\n$prompt\nASSISTANT:",
        },
      });
      final response = await http
          .post(
            Uri.parse(_url),
            headers: {
              'Authorization': 'Bearer $_token',
              'Content-Type': 'application/json',
            },
            body: body,
          )
          .timeout(const Duration(seconds: 120));

      print('Status Code: ${response.statusCode}');

      if (response.body.trim().startsWith('<')) {
        return "Api Error: Received Html. The model might be overloaded or the request format is incorrect";
      }
      if (response.statusCode == 503) {
        return "Model is loadin. Please wait 20-30 seconds and try again";
      }
      if (response.statusCode == 401) {
        return " Invalid API token. Please check your huggingFace token";
      }

      final data = jsonDecode(response.body);

      if (data is Map && data.containsKey('error')) {
        return "Error: ${data['error']}";
      }
      if (data is List && data.isNotEmpty) {
        final text = data[0]['generated_text'];
        return text != null ? text.toString() : 'No description';
      }
      return "Unexpected response format";
    } on SocketException {
      return "No internet connection";
    } on FormatException {
      return "Invaild JSON response from API";
    } catch (e) {
      return "Error: $e";
    }
  }
}
