import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

const String mistralApiKey = "OF6ucqQqXssXMj48pc6GlrV4DKusH9XW";


Stream<String> streamMessageToMistral(String userMessage) async* { 
  final url = Uri.parse("https://api.mistral.ai/v1/chat/completions");

  final request = http.Request("POST", url);
  request.headers.addAll({
    "Content-Type": "application/json",
    "Accept": "text/event-stream", 
    "Authorization": "Bearer $mistralApiKey",
  });

  request.body = jsonEncode({
    "model": "mistral-small-latest",
    "stream": true,
    "messages": [
      {"role": "user", "content": userMessage}
    ]
  });

  final response = await request.send();

  if (response.statusCode != 200) {
    final errorBody = await response.stream.bytesToString();
    print("MISTRAL API ERROR CODE: ${response.statusCode}");
    print("MISTRAL API ERROR BODY: $errorBody");
    throw Exception("Failed to start streaming response from Mistral.");
  }
  
  
  await for (var line in response.stream.transform(utf8.decoder).transform(const LineSplitter())) {
    
   
    if (line.startsWith("data: ")) {
      final jsonPart = line.substring(6).trim();

      
      if (jsonPart == "[DONE]") return;

      try {
        final data = jsonDecode(jsonPart);
        final token = data["choices"][0]["delta"]["content"];

        if (token != null) yield token;
      } catch (e) {
       
        print("JSON Parsing Error: $e");
        print("Faulty JSON part: $jsonPart");
        
        yield ' [Error] '; 
      }
    
    }
  }
}