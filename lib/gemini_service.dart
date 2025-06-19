// services/gemini_service.dart
import 'package:google_generative_ai/google_generative_ai.dart';

class GeminiService {
  static const String apiKey = 'AIzaSyAPwwmSM9yZC_S-of7KogioASYDGF8Hw7w'; 
  
  static Future<String> askGemini(String prompt) async {
    try {
      final model = GenerativeModel(
        model: 'gemini-1.5-flash',
        apiKey: apiKey,
      );
      
      final responses = model.generateContentStream([Content.text(prompt)]);
      String fullResponse = '';
      
      await for (final response in responses) {
        if (response.text != null) {
          fullResponse += response.text!;
        }
      }
      
      return fullResponse.isNotEmpty ? fullResponse : 'Désolé, je n\'ai pas pu générer une réponse.';
    } catch (e) {
      return 'Erreur: $e';
    }
  }
}