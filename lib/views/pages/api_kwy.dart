import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;

Stream<String> sendMessageStream(String message, List<Map<String, String>> history) async* {
final url = Uri.parse("https://unorbed-hypermystical-owen.ngrok-free.dev/chat_stream");

  final client = http.Client();
  final request = http.Request("POST", url);
  request.headers["Content-Type"] = "application/json";
  request.headers["ngrok-skip-browser-warning"] = "true";
  request.body = jsonEncode({
    "message": message,
    "history": history,
  });

  try {
    final response = await request.send().timeout(const Duration(seconds: 40));

    if (response.statusCode == 200) {
      await for (var line in response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())) {
        
        if (line.startsWith("data: ")) {
          String rawData = line.substring(6).trim();
          if (rawData == "[DONE]") return;

          try {
            final decoded = jsonDecode(rawData);
            String? token = decoded['token'];
            if (token != null) yield token;
          } catch (e) {
            
            print("Stream Parse Error: $e");
          }
        }
      }
    } else {
      print("Server returned ${response.statusCode}");
    }
  } catch (e) {
    
    print("CONNECTION ERROR: $e"); 
  }
}