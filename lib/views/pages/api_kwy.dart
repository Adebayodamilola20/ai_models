import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;

Stream<String> sendMessageStream(String message, List<Map<String, String>> history) async* {
  // Your permanent Render URL
  final String baseUrl = "https://ai-models-94ei.onrender.com";
  final Uri url = Uri.parse("$baseUrl/chat");

  final request = http.Request("POST", url);
  request.headers["Content-Type"] = "application/json";
  
  // Note: We don't need the ngrok-skip header anymore since we're on Render!
  
  request.body = jsonEncode({
    "message": message,
    "history": history,
  });

  try {
    final response = await request.send().timeout(const Duration(seconds: 40));

    if (response.statusCode == 200) {
      final responseBody = await response.stream.bytesToString();
      try {
        final decoded = jsonDecode(responseBody);
        final String reply = decoded['response'] ?? "No response.";
        
        // Simulate streaming for the existing UI by yielding characters
        for (int i = 0; i < reply.length; i++) {
          yield reply[i];
          await Future.delayed(const Duration(milliseconds: 5));
        }
      } catch (e) {
        print("Parse Error: $e");
      }
    } else {
      print("Server returned ${response.statusCode}");
      yield "Error: Server returned ${response.statusCode}";
    }
  } catch (e) {
    print("CONNECTION ERROR: $e");
    yield "Connection failed. Please check if the Render server is still waking up.";
  }
}