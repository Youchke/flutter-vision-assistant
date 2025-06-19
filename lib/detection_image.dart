import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:typed_data';

class ImageGeneratorPage extends StatefulWidget {
  @override
  _ImageGeneratorPageState createState() => _ImageGeneratorPageState();
}

class _ImageGeneratorPageState extends State<ImageGeneratorPage> with TickerProviderStateMixin {
  final TextEditingController _descriptionController = TextEditingController();
  bool _isGenerating = false;
  Uint8List? _generatedImageBytes;
  String _currentPrompt = '';
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    
    _pulseController = AnimationController(
      duration: Duration(milliseconds: 1500),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  // Améliorer automatiquement le prompt pour de meilleurs résultats
  String _enhancePrompt(String userPrompt) {
    String enhancement = 'high quality, detailed, professional, 4K resolution, masterpiece, ultra realistic';
    return '$userPrompt, $enhancement';
  }

  // Générer l'image via l'API Pollinations.ai
  Future<void> _generateImageFromAPI() async {
    if (_descriptionController.text.trim().isEmpty) {
      _showSnackBar('Veuillez entrer une description', isError: true);
      return;
    }

    setState(() {
      _isGenerating = true;
      _generatedImageBytes = null;
    });

    _pulseController.repeat(reverse: true);

    try {
      String enhancedPrompt = _enhancePrompt(_descriptionController.text.trim());
      _currentPrompt = enhancedPrompt;

      String baseUrl = 'https://image.pollinations.ai/prompt';
      String encodedPrompt = Uri.encodeComponent(enhancedPrompt);
      
      String fullUrl = '$baseUrl/$encodedPrompt'
          '?model=flux'
          '&width=1024'
          '&height=1024'
          '&enhance=true'
          '&nologo=true'
          '&seed=${DateTime.now().millisecondsSinceEpoch}';

      final response = await http.get(
        Uri.parse(fullUrl),
        headers: {
          'User-Agent': 'Flutter-App',
        },
      ).timeout(Duration(seconds: 60));

      if (response.statusCode == 200) {
        setState(() {
          _generatedImageBytes = response.bodyBytes;
        });
        
        _animationController.forward();
        _showSnackBar('Image générée avec succès ! ✨');
        
        // Vibration légère pour le feedback
        HapticFeedback.lightImpact();
      } else {
        throw Exception('Erreur HTTP: ${response.statusCode}');
      }
    } catch (e) {
      _showSnackBar('Erreur lors de la génération: ${e.toString()}', isError: true);
      HapticFeedback.heavyImpact();
    } finally {
      setState(() {
        _isGenerating = false;
      });
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle,
              color: Colors.white,
              size: 20,
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: isError 
          ? Color(0xFFE53E3E) 
          : Color(0xFF38A169),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: EdgeInsets.all(16),
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _clearDescription() {
    _descriptionController.clear();
    setState(() {
      _generatedImageBytes = null;
      _currentPrompt = '';
    });
    _animationController.reset();
  }

  void _regenerateImage() {
    if (_descriptionController.text.trim().isNotEmpty) {
      _generateImageFromAPI();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.auto_awesome, color: Colors.white, size: 20),
            ),
            SizedBox(width: 12),
            Text(
              'Créateur d\'Images IA',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: Color(0xFF2D3748),
        elevation: 0,
        centerTitle: true,
        actions: [
          if (_descriptionController.text.isNotEmpty)
            Container(
              margin: EdgeInsets.only(right: 8),
              child: IconButton(
                icon: Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Color(0xFFF7FAFC),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.refresh, size: 20),
                ),
                onPressed: _clearDescription,
                tooltip: 'Nouveau',
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        physics: BouncingScrollPhysics(),
        child: Column(
          children: [
            // En-tête décoratif
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  SizedBox(height: 20),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        Container(
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Color(0xFF667EEA).withOpacity(0.1),
                                Color(0xFF764BA2).withOpacity(0.1),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.palette, 
                                   color: Color(0xFF667EEA), size: 24),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Transformez vos idées en œuvres d\'art',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF4A5568),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 20),
                ],
              ),
            ),

            Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                children: [
                  // Section de saisie améliorée
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 20,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(Icons.edit, color: Colors.white, size: 20),
                              ),
                              SizedBox(width: 16),
                              Text(
                                'Décrivez votre vision',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2D3748),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 20),
                          Container(
                            decoration: BoxDecoration(
                              color: Color(0xFFF7FAFC),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Color(0xFFE2E8F0),
                                width: 1.5,
                              ),
                            ),
                            child: TextField(
                              controller: _descriptionController,
                              maxLines: 6,
                              style: TextStyle(
                                fontSize: 16,
                                color: Color(0xFF2D3748),
                                height: 1.5,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Un paysage fantastique avec des montagnes violettes, un ciel étoilé, des cascades lumineuses et une lune géante...',
                                hintStyle: TextStyle(
                                  color: Color(0xFFA0AEC0),
                                  fontSize: 14,
                                ),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.all(20),
                              ),
                              onChanged: (value) {
                                setState(() {});
                              },
                            ),
                          ),
                          SizedBox(height: 16),
                          Container(
                            padding: EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Color(0xFFF0FFF4),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Color(0xFF9AE6B4).withOpacity(0.5),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.tips_and_updates, 
                                     color: Color(0xFF38A169), size: 20),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Plus c\'est détaillé, plus le résultat sera précis !',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF2F855A),
                                      fontWeight: FontWeight.w500,
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
                  
                  SizedBox(height: 24),
                  
                  // Bouton de génération premium
                  Container(
                    width: double.infinity,
                    height: 64,
                    child: AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _isGenerating ? _pulseAnimation.value : 1.0,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: _isGenerating 
                                  ? [Color(0xFFA0AEC0), Color(0xFF718096)]
                                  : [Color(0xFF667EEA), Color(0xFF764BA2)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: (_isGenerating ? Color(0xFF718096) : Color(0xFF667EEA))
                                    .withOpacity(0.4),
                                  blurRadius: 12,
                                  offset: Offset(0, 6),
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              onPressed: _isGenerating ? null : _generateImageFromAPI,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: _isGenerating
                                ? Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2.5,
                                        ),
                                      ),
                                      SizedBox(width: 16),
                                      Text(
                                        'Création en cours...',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.auto_awesome, 
                                           color: Colors.white, size: 24),
                                      SizedBox(width: 12),
                                      Text(
                                        'Créer l\'Image',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  
                  SizedBox(height: 32),
                  
                  // Section résultat améliorée
                  if (_generatedImageBytes != null)
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 30,
                              offset: Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [Color(0xFF48BB78), Color(0xFF38A169)],
                                          ),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Icon(Icons.image, color: Colors.white, size: 20),
                                      ),
                                      SizedBox(width: 12),
                                      Text(
                                        'Votre Création',
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF2D3748),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Container(
                                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Color(0xFF48BB78),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      '1024×1024',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 20),
                              
                              Hero(
                                tag: 'generated-image',
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.15),
                                          blurRadius: 20,
                                          offset: Offset(0, 8),
                                        ),
                                      ],
                                    ),
                                    child: Image.memory(
                                      _generatedImageBytes!,
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                      errorBuilder: (context, error, stackTrace) {
                                        return Container(
                                          height: 300,
                                          decoration: BoxDecoration(
                                            color: Color(0xFFF7FAFC),
                                            borderRadius: BorderRadius.circular(16),
                                          ),
                                          child: Center(
                                            child: Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Icon(Icons.error_outline,
                                                     color: Color(0xFFE53E3E), size: 48),
                                                SizedBox(height: 12),
                                                Text(
                                                  'Erreur de chargement',
                                                  style: TextStyle(
                                                    color: Color(0xFFE53E3E),
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ),
                              
                              SizedBox(height: 20),
                              
                              // Boutons d'action
                              Row(
                                children: [
                                  Expanded(
                                    child: Container(
                                      height: 48,
                                      child: ElevatedButton.icon(
                                        onPressed: _regenerateImage,
                                        icon: Icon(Icons.refresh, size: 20),
                                        label: Text('Regénérer'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Color(0xFFF7FAFC),
                                          foregroundColor: Color(0xFF4A5568),
                                          elevation: 0,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                            side: BorderSide(color: Color(0xFFE2E8F0)),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: Container(
                                      height: 48,
                                      child: ElevatedButton.icon(
                                        onPressed: () {
                                          HapticFeedback.lightImpact();
                                          _showSnackBar('Image copiée ! 📋');
                                        },
                                        icon: Icon(Icons.copy, size: 20),
                                        label: Text('Copier'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Color(0xFF667EEA),
                                          foregroundColor: Colors.white,
                                          elevation: 0,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
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

  @override
  void dispose() {
    _descriptionController.dispose();
    _animationController.dispose();
    _pulseController.dispose();
    super.dispose();
  }
}