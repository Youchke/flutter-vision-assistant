import 'package:flutter/material.dart';
import 'drawer.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_tts/flutter_tts.dart';

class AssistantVirtuel extends StatefulWidget {
  const AssistantVirtuel({super.key});

  @override
  State<AssistantVirtuel> createState() => _AssistantVirtuelState();
}

class _AssistantVirtuelState extends State<AssistantVirtuel> with TickerProviderStateMixin {
  final SpeechToText _speechToText = SpeechToText();
  final TextEditingController _textController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();
  final ScrollController _scrollController = ScrollController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  bool _speechEnabled = false;
  String _lastWords = '';
  List<Map<String, dynamic>> messages = [];
  late AnimationController _buttonController;
  late AnimationController _pulseController;
  late AnimationController _micController;
  late AnimationController _backgroundController;
  bool _isLoading = false;
  File? _selectedImage;
  Uint8List? _webImage;
  String? _imageName;
  String? _currentUserId;
  
  // SÉCURITÉ: Remplacez par votre vraie clé API
  static const String _geminiApiKey = 'AIzaSyDndzJxr0blcgnlSgoe_fb-Vvw8cwpIJm4';
  static const String _geminiApiUrl = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash-latest:generateContent';
  final FlutterTts _flutterTts = FlutterTts();
  bool _isSpeaking = false;
  @override
  void initState() {
    super.initState();
    _initSpeech();
    _initTts();
    _buttonController = AnimationController(duration: const Duration(milliseconds: 200), vsync: this);
    _pulseController = AnimationController(duration: const Duration(milliseconds: 1500), vsync: this)..repeat();
    _micController = AnimationController(duration: const Duration(milliseconds: 800), vsync: this);
    _backgroundController = AnimationController(duration: const Duration(seconds: 20), vsync: this)..repeat();
    
    _initializeUser();
  }

  @override
  void dispose() {
    _buttonController.dispose();
    _pulseController.dispose();
    _micController.dispose();
    _backgroundController.dispose();
    _textController.dispose();
    _scrollController.dispose();
    _flutterTts.stop();
    super.dispose();
  }

  // Initialiser l'utilisateur et charger les messages
  Future<void> _initializeUser() async {
    try {
      if (_auth.currentUser == null) {
        await _auth.signInAnonymously();
      }
      
      _currentUserId = _auth.currentUser?.uid;
      
      if (_currentUserId != null) {
        await _loadMessagesFromFirestore();
      } else {
        _addWelcomeMessage();
      }
    } catch (e) {
      print('Erreur initialisation utilisateur: $e');
      _addWelcomeMessage();
      _showMessage('Impossible de se connecter au service de sauvegarde', Colors.red.shade400);
    }
  }

  void _addWelcomeMessage() {
    setState(() {
      messages.add({
        'text': '👋 Bonjour ! Je suis votre assistant virtuel alimenté par Gemini. Comment puis-je vous aider aujourd\'hui ?',
        'isUser': false,
        'timestamp': DateTime.now(),
      });
    });
  }

  // Charger les messages depuis Firestore
  Future<void> _loadMessagesFromFirestore() async {
    if (_currentUserId == null) return;

    try {
      final querySnapshot = await _firestore
          .collection('users')
          .doc(_currentUserId)
          .collection('messages')
          .orderBy('timestamp', descending: false)
          .get();

      if (querySnapshot.docs.isEmpty) {
        await _saveWelcomeMessage();
      } else {
        setState(() {
          messages = querySnapshot.docs.map((doc) {
            final data = doc.data();
            return {
              'text': data['text'] ?? '',
              'isUser': data['sender'] == 'user',
              'timestamp': (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
              'messageId': doc.id,
            };
          }).toList();
        });
      }
      
      _scrollToBottom();
    } catch (e) {
      print('Erreur chargement messages: $e');
      _addWelcomeMessage();
      _showMessage('Erreur lors du chargement des messages', Colors.red.shade400);
    }
  }

  // Sauvegarder le message d'accueil
  Future<void> _saveWelcomeMessage() async {
    if (_currentUserId == null) return;

    try {
      const welcomeText = '👋 Bonjour ! Je suis votre assistant virtuel alimenté par Gemini. Comment puis-je vous aider aujourd\'hui ?';
      
      final docRef = await _firestore
          .collection('users')
          .doc(_currentUserId)
          .collection('messages')
          .add({
        'text': welcomeText,
        'sender': 'bot',
        'timestamp': FieldValue.serverTimestamp(),
      });

      setState(() {
        messages.add({
          'text': welcomeText,
          'isUser': false,
          'timestamp': DateTime.now(),
          'messageId': docRef.id,
        });
      });
    } catch (e) {
      print('Erreur sauvegarde message d\'accueil: $e');
      _addWelcomeMessage();
    }
  }

  // Sauvegarder un message dans Firestore
  Future<String?> _saveMessageToFirestore({
    required String text,
    required String sender,
  }) async {
    if (_currentUserId == null) return null;

    try {
      final docRef = await _firestore
          .collection('users')
          .doc(_currentUserId)
          .collection('messages')
          .add({
        'text': text,
        'sender': sender,
        'timestamp': FieldValue.serverTimestamp(),
      });

      return docRef.id;
    } catch (e) {
      print('Erreur sauvegarde message: $e');
      _showMessage('Erreur lors de la sauvegarde', Colors.red.shade400);
      return null;
    }
  }

  // Supprimer tous les messages
  Future<void> _clearConversation() async {
    if (_currentUserId == null) return;

    try {
      final batch = _firestore.batch();
      final querySnapshot = await _firestore
          .collection('users')
          .doc(_currentUserId)
          .collection('messages')
          .get();

      for (final doc in querySnapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      
      setState(() {
        messages.clear();
      });

      await _saveWelcomeMessage();
      _showMessage('Conversation effacée', Colors.green.shade400);
    } catch (e) {
      print('Erreur suppression messages: $e');
      _showMessage('Erreur lors de la suppression', Colors.red.shade400);
    }
  }

  void _initSpeech() async {
    try {
      _speechEnabled = await _speechToText.initialize(
        onError: (error) {
          print('Erreur Speech-to-Text: ${error.errorMsg}');
          _showMessage('Erreur vocale: ${error.errorMsg}', Colors.red.shade400);
        },
        onStatus: (status) => print('Speech status: $status'),
      );
      setState(() {});
    } catch (e) {
      print('Erreur initialisation speech: $e');
      _showMessage('Impossible d\'initialiser la reconnaissance vocale', Colors.red.shade400);
    }
  }

  void _startListening() async {
    if (!_speechEnabled) {
      _showMessage('Reconnaissance vocale non disponible', Colors.red.shade400);
      return;
    }

    try {
      await _speechToText.listen(
        onResult: _onSpeechResult,
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
        partialResults: true,
        localeId: 'fr_FR',
        cancelOnError: true,
      );
      _micController.repeat();
      setState(() {});
    } catch (e) {
      print('Erreur démarrage écoute: $e');
      _showMessage('Erreur lors du démarrage de l\'écoute', Colors.red.shade400);
    }
  }

  void _stopListening() async {
    await _speechToText.stop();
    _micController.stop();
    setState(() {});
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    setState(() => _lastWords = result.recognizedWords);
    
    if (result.finalResult && result.recognizedWords.trim().isNotEmpty) {
      final recognizedText = result.recognizedWords.trim();
      
      _addUserMessage(recognizedText, image: _selectedImage, webImage: _webImage);
      _sendToGemini(recognizedText, image: _selectedImage, webImage: _webImage);
      
      setState(() {
        _selectedImage = null;
        _webImage = null;
        _imageName = null;
      });
      
      _scrollToBottom();
    }
  }

  // Ajouter un message utilisateur
  Future<void> _addUserMessage(String text, {File? image, Uint8List? webImage}) async {
    final messageId = await _saveMessageToFirestore(text: text, sender: 'user');
    
    setState(() {
      messages.add({
        'text': text,
        'isUser': true,
        'timestamp': DateTime.now(),
        'messageId': messageId,
        'image': image,
        'webImage': webImage,
      });
      _lastWords = '';
    });
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1800,
        maxHeight: 1800,
        imageQuality: 85,
      );
      if (image != null) {
        await _processPickedImage(image);
      }
    } catch (e) {
      print('Erreur sélection image: $e');
      _showMessage('Erreur lors de la sélection d\'image', Colors.red.shade400);
    }
  }

  Future<void> _takePhoto() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1800,
        maxHeight: 1800,
        imageQuality: 85,
      );
      if (image != null) {
        await _processPickedImage(image);
      }
    } catch (e) {
      print('Erreur prise photo: $e');
      _showMessage('Erreur lors de la prise de photo', Colors.red.shade400);
    }
  }

  Future<void> _processPickedImage(XFile image) async {
    if (kIsWeb) {
      final bytes = await image.readAsBytes();
      setState(() {
        _webImage = bytes;
        _imageName = image.name;
        _selectedImage = null;
      });
    } else {
      setState(() {
        _selectedImage = File(image.path);
        _webImage = null;
        _imageName = image.name;
      });
    }
  }

  void _showMessage(String message, Color color) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              color == Colors.green.shade400 ? Icons.check_circle : Icons.error,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message, 
                style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)
              ),
            ),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showImagePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 50,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Choisir une image',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(child: _buildImageOption(Icons.photo_library_rounded, 'Galerie', _pickImage)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildImageOption(Icons.camera_alt_rounded, 'Appareil photo', _takePhoto)),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  Widget _buildImageOption(IconData icon, String title, VoidCallback onTap) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).pop();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFF6C63FF).withOpacity(0.2),
              const Color(0xFF9C88FF).withOpacity(0.1),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFF6C63FF).withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF6C63FF).withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: const Color(0xFF6C63FF), size: 24),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _sendTextMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty && _selectedImage == null && _webImage == null) return;
    
    final messageText = text.isNotEmpty ? text : 'Image envoyée';
    await _addUserMessage(messageText, image: _selectedImage, webImage: _webImage);
    
    _sendToGemini(text, image: _selectedImage, webImage: _webImage);
    _textController.clear();
    setState(() {
      _selectedImage = null;
      _webImage = null;
      _imageName = null;
    });
    _scrollToBottom();
  }

  Future<String> _encodeImageToBase64(File? imageFile, Uint8List? webImage) async {
    if (kIsWeb && webImage != null) {
      return base64Encode(webImage);
    } else if (imageFile != null) {
      final bytes = await imageFile.readAsBytes();
      return base64Encode(bytes);
    }
    throw Exception('Aucune image à encoder');
  }

  Future<void> _sendToGemini(String userMessage, {File? image, Uint8List? webImage}) async {
    if (userMessage.trim().isEmpty && image == null && webImage == null) {
      _showMessage('Aucun contenu à envoyer', Colors.red.shade400);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final uri = Uri.parse(_geminiApiUrl).replace(queryParameters: {'key': _geminiApiKey});
      
      Map<String, dynamic> requestBody = {
        'contents': [{'parts': []}],
        'generationConfig': {
          'temperature': 0.7,
          'topK': 40,
          'topP': 0.95,
          'maxOutputTokens': 1024,
        }
      };

      if (userMessage.trim().isNotEmpty) {
        requestBody['contents'][0]['parts'].add({'text': userMessage.trim()});
      }

      if (image != null || webImage != null) {
        final base64Image = await _encodeImageToBase64(image, webImage);
        requestBody['contents'][0]['parts'].add({
          'inline_data': {
            'mime_type': 'image/jpeg',
            'data': base64Image,
          }
        });
      }

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode(requestBody),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['candidates']?.isNotEmpty == true) {
          final geminiResponse = data['candidates'][0]['content']['parts'][0]['text'];
          await _addBotMessage(geminiResponse);
          setState(() => _isLoading = false);
        } else {
          throw Exception('Aucune réponse de Gemini');
        }
      } else {
        final errorData = jsonDecode(response.body);
        final errorMessage = errorData['error']?['message'] ?? 'Erreur inconnue';
        await _addBotMessage('Erreur ${response.statusCode}: $errorMessage');
        setState(() => _isLoading = false);
      }
    } catch (e) {
      await _addBotMessage('Erreur de connexion: ${e.toString()}');
      setState(() => _isLoading = false);
    }
    
    _scrollToBottom();
  }
  void _initTts() async {
    try {
      await _flutterTts.setLanguage("fr-FR");
      await _flutterTts.setSpeechRate(0.6);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);
      
      _flutterTts.setStartHandler(() {
        setState(() => _isSpeaking = true);
      });
      
      _flutterTts.setCompletionHandler(() {
        setState(() => _isSpeaking = false);
      });
      
      _flutterTts.setErrorHandler((msg) {
        setState(() => _isSpeaking = false);
        print('Erreur TTS: $msg');
      });
    } catch (e) {
      print('Erreur initialisation TTS: $e');
    }
  }

  Future<void> _speak(String text) async {
    try {
      if (_isSpeaking) {
        await _flutterTts.stop();
      }
      await _flutterTts.speak(text);
    } catch (e) {
      print('Erreur lecture vocale: $e');
      _showMessage('Erreur lors de la lecture vocale', Colors.red.shade400);
    }
  }

  Future<void> _stopSpeaking() async {
    try {
      await _flutterTts.stop();
    } catch (e) {
      print('Erreur arrêt TTS: $e');
    }
  }

  // 6. Modifiez la méthode _addBotMessage pour lire automatiquement
  Future<void> _addBotMessage(String text) async {
    final messageId = await _saveMessageToFirestore(text: text, sender: 'bot');
    
    setState(() {
      messages.add({
        'text': text,
        'isUser': false,
        'timestamp': DateTime.now(),
        'messageId': messageId,
      });
    });
    
    // Lecture automatique de la réponse du bot
    _speak(text);
  }

  Widget _buildMessage(Map<String, dynamic> message, int index) {
    final isUser = message['isUser'];
    final image = message['image'] as File?;
    final webImage = message['webImage'] as Uint8List?;
    
    return Container(
      margin: EdgeInsets.only(
        bottom: 20,
        left: isUser ? 60 : 16,
        right: isUser ? 16 : 60,
      ),
      child: Align(
        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: isUser 
                ? const LinearGradient(
                    colors: [Color(0xFF6C63FF), Color(0xFF9C88FF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : LinearGradient(
                    colors: [
                      const Color(0xFF1A1A2E),
                      const Color(0xFF16213E).withOpacity(0.8),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(24),
              topRight: const Radius.circular(24),
              bottomLeft: Radius.circular(isUser ? 24 : 8),
              bottomRight: Radius.circular(isUser ? 8 : 24),
            ),
            boxShadow: [
              BoxShadow(
                color: (isUser ? const Color(0xFF6C63FF) : Colors.black).withOpacity(0.3),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (image != null || webImage != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: kIsWeb && webImage != null
                        ? Image.memory(
                            webImage, 
                            width: 220, 
                            height: 220, 
                            fit: BoxFit.cover
                          )
                        : image != null
                            ? Image.file(
                                image, 
                                width: 220, 
                                height: 220, 
                                fit: BoxFit.cover
                              )
                            : Container(),
                  ),
                ),
              if (message['text'].isNotEmpty)
                Text(
                  message['text'],
                  style: TextStyle(
                    color: isUser ? Colors.white : Colors.white.withOpacity(0.9),
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    height: 1.5,
                  ),
                ),
              
              // Bouton TTS pour les messages du bot
              if (!isUser && message['text'].isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      GestureDetector(
                        onTap: () {
                          if (_isSpeaking) {
                            _stopSpeaking();
                          } else {
                            _speak(message['text']);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: const Color(0xFF6C63FF).withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _isSpeaking ? Icons.stop_rounded : Icons.volume_up_rounded,
                                color: const Color(0xFF6C63FF),
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _isSpeaking ? 'Arrêter' : 'Écouter',
                                style: const TextStyle(
                                  color: Color(0xFF6C63FF),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
  Widget _buildLoadingIndicator() {
    return Container(
      margin: const EdgeInsets.only(bottom: 20, left: 16, right: 60),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF1A1A2E),
                const Color(0xFF16213E).withOpacity(0.8),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
              bottomLeft: Radius.circular(8),
              bottomRight: Radius.circular(24),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Color.lerp(
                        const Color(0xFF6C63FF).withOpacity(0.4),
                        const Color(0xFF6C63FF),
                        _pulseController.value,
                      ),
                      shape: BoxShape.circle,
                    ),
                  );
                },
              ),
              const SizedBox(width: 8),
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Color.lerp(
                        const Color(0xFF6C63FF).withOpacity(0.4),
                        const Color(0xFF6C63FF),
                        (_pulseController.value + 0.33) % 1.0,
                      ),
                      shape: BoxShape.circle,
                    ),
                  );
                },
              ),
              const SizedBox(width: 8),
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Color.lerp(
                        const Color(0xFF6C63FF).withOpacity(0.4),
                        const Color(0xFF6C63FF),
                        (_pulseController.value + 0.66) % 1.0,
                      ),
                      shape: BoxShape.circle,
                    ),
                  );
                },
              ),
              const SizedBox(width: 16),
              Text(
                'Gemini réfléchit...',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontWeight: FontWeight.w500,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImagePreview() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1A1A2E),
            const Color(0xFF16213E).withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF6C63FF).withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: kIsWeb && _webImage != null
                ? Image.memory(_webImage!, width: 60, height: 60, fit: BoxFit.cover)
                : _selectedImage != null
                    ? Image.file(_selectedImage!, width: 60, height: 60, fit: BoxFit.cover)
                    : Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: const Color(0xFF6C63FF).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.image_rounded, color: Color(0xFF6C63FF), size: 28),
                      ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Image sélectionnée',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _imageName ?? 'image.jpg',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: IconButton(
              icon: const Icon(Icons.close_rounded, color: Colors.red, size: 20),
              onPressed: () {
                setState(() {
                  _selectedImage = null;
                  _webImage = null;
                  _imageName = null;
                });
              },
            ),
          ),
        ],
      ),
    );
  }
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0B),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.black.withOpacity(0.9),
                const Color(0xFF1A1A2E).withOpacity(0.9),
              ],
            ),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(24),
              bottomRight: Radius.circular(24),
            ),
          ),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6C63FF), Color(0xFF9C88FF)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.psychology_outlined,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Assistant Virtuel',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  'En ligne',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6C63FF),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withOpacity(0.1),
              ),
            ),
            child: PopupMenuButton<String>(
              icon: const Icon(
                Icons.more_vert_rounded,
                color: Colors.white,
                size: 20,
              ),
              color: const Color(0xFF1E1E2E),
              elevation: 20,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: Colors.white.withOpacity(0.1),
                ),
              ),
              onSelected: (value) {
                if (value == 'clear') {
                  _showClearConversationDialog();
                }
              },
              itemBuilder: (BuildContext context) => [
                PopupMenuItem<String>(
                  value: 'clear',
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.auto_delete_rounded,
                          color: Color(0xFFFF6B6B),
                          size: 20,
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Effacer la conversation',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      drawer: const Menu(),
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topRight,
            radius: 1.5,
            colors: [
              Color(0xFF1A1A2E),
              Color(0xFF0A0A0B),
              Color(0xFF000000),
            ],
          ),
        ),
        child: Column(
          children: [
            const SizedBox(height: 120), // AppBar spacing
            
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.02),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(32),
                    topRight: Radius.circular(32),
                  ),
                ),
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                  itemCount: messages.length + (_isLoading ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == messages.length && _isLoading) {
                      return _buildLoadingIndicator();
                    }
                    return _buildMessage(messages[index], index);
                  },
                ),
              ),
            ),
            
            // Speech recognition indicator
            if (_speechToText.isListening && _lastWords.isNotEmpty)
              Container(
                margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF6C63FF).withOpacity(0.1),
                      const Color(0xFF9C88FF).withOpacity(0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFF6C63FF).withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF6C63FF), Color(0xFF9C88FF)],
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.mic_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Écoute en cours... $_lastWords',
                        style: const TextStyle(
                          color: Color(0xFF6C63FF),
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            
            // Image preview
            if (_selectedImage != null || _webImage != null) _buildImagePreview(),
            
            // Input area
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              decoration: BoxDecoration(
                color: const Color(0xFF0A0A0B),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(32),
                  topRight: Radius.circular(32),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Input row
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A2E),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.1),
                      ),
                    ),
                    child: Row(
                      children: [
                        // Image button
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFF6C63FF).withOpacity(0.8),
                                const Color(0xFF9C88FF).withOpacity(0.8),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: IconButton(
                            icon: const Icon(
                              Icons.image_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                            onPressed: _showImagePicker,
                          ),
                        ),
                        
                        const SizedBox(width: 8),
                        
                        // Text field
                        Expanded(
                          child: TextField(
                            controller: _textController,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                            decoration: const InputDecoration(
                              hintText: 'Écrivez votre message...',
                              hintStyle: TextStyle(
                                color: Color(0xFF6B6B7D),
                                fontSize: 16,
                                fontWeight: FontWeight.w400,
                              ),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                            maxLines: null,
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) => _sendTextMessage(),
                          ),
                        ),
                        
                        const SizedBox(width: 8),
                        
                        // Voice button
                        GestureDetector(
                          onTapDown: (_) => _buttonController.forward(),
                          onTapUp: (_) {
                            _buttonController.reverse();
                            Future.delayed(const Duration(milliseconds: 50), () {
                              if (_speechToText.isNotListening && !_isLoading) {
                                _startListening();
                              } else if (_speechToText.isListening) {
                                _stopListening();
                              }
                            });
                          },
                          onTapCancel: () => _buttonController.reverse(),
                          child: AnimatedBuilder(
                            animation: _buttonController,
                            builder: (context, child) {
                              return Transform.scale(
                                scale: 1.0 - (_buttonController.value * 0.1),
                                child: Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    gradient: _speechToText.isListening 
                                        ? const LinearGradient(
                                            colors: [Color(0xFFFF6B6B), Color(0xFFFF8E8E)]
                                          )
                                        : _isLoading 
                                            ? LinearGradient(
                                                colors: [
                                                  Colors.grey.withOpacity(0.6),
                                                  Colors.grey.withOpacity(0.8)
                                                ]
                                              )
                                            : const LinearGradient(
                                                colors: [Color(0xFF6C63FF), Color(0xFF9C88FF)]
                                              ),
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: (_speechToText.isListening 
                                                ? const Color(0xFFFF6B6B)
                                                : _isLoading 
                                                    ? Colors.grey
                                                    : const Color(0xFF6C63FF))
                                            .withOpacity(0.4 + (_buttonController.value * 0.3)),
                                        blurRadius: 16 + (_buttonController.value * 8),
                                        offset: Offset(0, 4 + (_buttonController.value * 2)),
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    _speechToText.isNotListening 
                                        ? (_isLoading ? Icons.hourglass_empty_rounded : Icons.mic_rounded)
                                        : Icons.stop_rounded,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        
                        const SizedBox(width: 8),
                        
                        // Send button
                        Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF6C63FF), Color(0xFF9C88FF)],
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: IconButton(
                            icon: const Icon(
                              Icons.send_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                            onPressed: _isLoading ? null : _sendTextMessage,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  void _showTtsSettings() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF1E1E2E),
                  Color(0xFF16162A),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withOpacity(0.1),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Paramètres vocaux',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 20,
                  ),
                ),
                const SizedBox(height: 24),
                
                // Vitesse de lecture
                const Text(
                  'Vitesse de lecture',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
                StatefulBuilder(
                  builder: (context, setState) {
                    double speechRate = 0.6;
                    return Slider(
                      value: speechRate,
                      min: 0.3,
                      max: 1.0,
                      divisions: 7,
                      activeColor: const Color(0xFF6C63FF),
                      onChanged: (value) {
                        setState(() => speechRate = value);
                        _flutterTts.setSpeechRate(value);
                      },
                    );
                  },
                ),
                
                const SizedBox(height: 16),
                
                // Bouton de test
                ElevatedButton(
                  onPressed: () => _speak('Ceci est un test de la synthèse vocale'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C63FF),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text('Test vocal'),
                ),
                
                const SizedBox(height: 16),
                
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text(
                    'Fermer',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  void _showClearConversationDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF1E1E2E),
                  Color(0xFF16162A),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withOpacity(0.1),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 30,
                  offset: const Offset(0, 15),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF6B6B), Color(0xFFFF8E8E)],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.auto_delete_rounded,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Title
                const Text(
                  'Effacer la conversation',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 20,
                    letterSpacing: -0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 12),
                
                // Content
                const Text(
                  'Êtes-vous sûr de vouloir effacer toute la conversation ? Cette action est irréversible.',
                  style: TextStyle(
                    color: Color(0xFFB0B3C1),
                    fontSize: 16,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 32),
                
                // Buttons
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.2),
                          ),
                        ),
                        child: TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text(
                            'Annuler',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(width: 16),
                    
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFF6B6B), Color(0xFFFF8E8E)],
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: TextButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            _clearConversation();
                          },
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text(
                            'Effacer',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),   
              ],
            ),
          ),
        );
      },
    );
  }}