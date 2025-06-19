// main.dart
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:typed_data';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:flutter/services.dart';

late List<CameraDescription> cameras;

// object_detection_screen.dart

class ObjectDetectionScreen extends StatefulWidget {
  @override
  _ObjectDetectionScreenState createState() => _ObjectDetectionScreenState();
}

class _ObjectDetectionScreenState extends State<ObjectDetectionScreen> {
  CameraController? _cameraController;
  ObjectDetector? _objectDetector;
  bool _isDetecting = false;
  List<Detection> _detections = [];
  Size? _imageSize;
  bool _isInitialized = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _initializeEverything();
  }

  Future<void> _initializeEverything() async {
    try {
      await _initializeDetector();
      await _initializeCamera();
    } catch (e) {
      setState(() {
        _errorMessage = 'Erreur d\'initialisation: $e';
      });
    }
  }

  Future<void> _initializeCamera() async {
    try {
      // Demander la permission de la caméra
      final status = await Permission.camera.request();
      if (status != PermissionStatus.granted) {
        setState(() {
          _errorMessage = 'Permission caméra refusée';
        });
        return;
      }

      if (cameras.isEmpty) {
        setState(() {
          _errorMessage = 'Aucune caméra disponible';
        });
        return;
      }

      // Initialiser le contrôleur de caméra
      _cameraController = CameraController(
        cameras[0],
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await _cameraController!.initialize();
      
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
        _startImageStream();
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Erreur caméra: $e';
      });
    }
  }

  Future<void> _initializeDetector() async {
    try {
      _objectDetector = ObjectDetector();
      await _objectDetector!.loadModel();
    } catch (e) {
      setState(() {
        _errorMessage = 'Erreur chargement modèle: $e';
      });
    }
  }

  void _startImageStream() {
    if (_cameraController != null && _cameraController!.value.isInitialized) {
      _cameraController!.startImageStream((CameraImage image) {
        if (!_isDetecting && _objectDetector != null) {
          _isDetecting = true;
          _detectObjects(image);
        }
      });
    }
  }

  Future<void> _detectObjects(CameraImage image) async {
    try {
      final detections = await _objectDetector!.detectObjects(image);
      
      if (mounted) {
        setState(() {
          _detections = detections;
          _imageSize = Size(
            image.width.toDouble(),
            image.height.toDouble(),
          );
        });
      }
    } catch (e) {
      print('Erreur de détection: $e');
    } finally {
      _isDetecting = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Afficher les erreurs
    if (_errorMessage.isNotEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text('Détection d\'objets')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error, size: 64, color: Colors.red),
              SizedBox(height: 16),
              Text(_errorMessage, textAlign: TextAlign.center),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _errorMessage = '';
                  });
                  _initializeEverything();
                },
                child: Text('Réessayer'),
              ),
            ],
          ),
        ),
      );
    }

    // Afficher le chargement
    if (!_isInitialized || _cameraController == null || !_cameraController!.value.isInitialized) {
      return Scaffold(
        appBar: AppBar(title: Text('Détection d\'objets')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Initialisation...'),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Détection d\'objets TensorFlow Lite'),
        backgroundColor: Colors.blue,
      ),
      body: Stack(
        children: [
          // Aperçu de la caméra
          Container(
            width: double.infinity,
            height: double.infinity,
            child: CameraPreview(_cameraController!),
          ),
          
          // Overlay des détections
          if (_imageSize != null)
            DetectionOverlay(
              detections: _detections,
              imageSize: _imageSize!,
              screenSize: MediaQuery.of(context).size,
            ),
          
          // Informations en bas
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              color: Colors.black54,
              padding: EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Objets détectés: ${_detections.length}',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  if (_detections.isNotEmpty)
                    ..._detections.take(3).map((detection) => Text(
                      '${detection.label}: ${(detection.confidence * 100).toStringAsFixed(1)}%',
                      style: TextStyle(color: Colors.white, fontSize: 14),
                    )),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _objectDetector?.dispose();
    super.dispose();
  }
}

class Detection {
  final String label;
  final double confidence;
  final Rect boundingBox;

  Detection({
    required this.label,
    required this.confidence,
    required this.boundingBox,
  });
}

class ObjectDetector {
  Interpreter? _interpreter;
  List<String> _labels = [];
  
  // Paramètres du modèle (ajustez selon votre modèle)
  static const int INPUT_SIZE = 300;
  static const double THRESHOLD = 0.5;

  Future<void> loadModel() async {
    try {
      // Charger le modèle TensorFlow Lite
      _interpreter = await Interpreter.fromAsset('assets/models/detect.tflite');
      
      // Charger les labels
      final labelsData = await rootBundle.loadString('assets/labels/labelmap.txt');
      _labels = labelsData.split('\n').where((label) => label.isNotEmpty).toList();
      
      print('Modèle chargé avec succès');
      print('Nombre de labels: ${_labels.length}');
      
      // Afficher les détails du modèle pour le débogage
      print('Input shape: ${_interpreter!.getInputTensor(0).shape}');
      print('Input type: ${_interpreter!.getInputTensor(0).type}');
      print('Output tensors: ${_interpreter!.getOutputTensors().length}');
      for (int i = 0; i < _interpreter!.getOutputTensors().length; i++) {
        print('Output $i shape: ${_interpreter!.getOutputTensor(i).shape}');
        print('Output $i type: ${_interpreter!.getOutputTensor(i).type}');
      }
    } catch (e) {
      print('Erreur lors du chargement du modèle: $e');
      throw e;
    }
  }

  Future<List<Detection>> detectObjects(CameraImage image) async {
    if (_interpreter == null) return [];

    try {
      // Préprocesser l'image - Retourner un Uint8List au lieu de double
      final inputImage = _preprocessImageAsUint8(image);
      
      // Vérifier le type d'entrée attendu par le modèle
      final inputTensor = _interpreter!.getInputTensor(0);
      final outputTensors = _interpreter!.getOutputTensors();
      
      // Préparer les tensors de sortie selon le type de modèle
      Map<int, Object> outputs = {};
      
      if (outputTensors.length == 4) {
        // Modèle de détection standard avec 4 sorties
        outputs = {
          0: List.filled(1 * 10 * 4, 0.0).reshape([1, 10, 4]), // boxes
          1: List.filled(1 * 10, 0.0).reshape([1, 10]),        // classes
          2: List.filled(1 * 10, 0.0).reshape([1, 10]),        // scores
          3: List.filled(1, 0.0).reshape([1]),                 // count
        };
      } else {
        // Adapter selon votre modèle spécifique
        for (int i = 0; i < outputTensors.length; i++) {
          final shape = outputTensors[i].shape;
          final totalSize = shape.reduce((a, b) => a * b);
          outputs[i] = List.filled(totalSize, 0.0).reshape(shape);
        }
      }

      // Exécuter l'inférence
      _interpreter!.runForMultipleInputs([inputImage], outputs);

      // Traiter les résultats selon le format de sortie
      if (outputs.length >= 3) {
        return _processDetections(
          (outputs[0] as List)[0], // boxes
          (outputs[1] as List)[0], // classes
          (outputs[2] as List)[0], // scores
          image.width,
          image.height,
        );
      }
      
      return [];
    } catch (e) {
      print('Erreur lors de la détection: $e');
      return [];
    }
  }

  // Nouvelle méthode pour préprocesser en Uint8
  Uint8List _preprocessImageAsUint8(CameraImage image) {
    try {
      // Créer une image RGB depuis CameraImage
      final rgbImage = _createRGBImageFromCamera(image);
      
      // Redimensionner l'image
      final resized = img.copyResize(rgbImage, width: INPUT_SIZE, height: INPUT_SIZE);
      
      // Convertir en Uint8List avec format [batch, height, width, channels]
      final imageBytes = Uint8List(1 * INPUT_SIZE * INPUT_SIZE * 3);
      int index = 0;
      
      for (int y = 0; y < INPUT_SIZE; y++) {
        for (int x = 0; x < INPUT_SIZE; x++) {
          final pixel = resized.getPixel(x, y);
          imageBytes[index++] = pixel.r.toInt(); // Rouge
          imageBytes[index++] = pixel.g.toInt(); // Vert
          imageBytes[index++] = pixel.b.toInt(); // Bleu
        }
      }
      
      // Reshape en 4D: [1, height, width, channels]
      return imageBytes;
    } catch (e) {
      print('Erreur préprocessing Uint8: $e');
      return Uint8List(1 * INPUT_SIZE * INPUT_SIZE * 3);
    }
  }

  // Méthode alternative pour les modèles qui attendent des float32
  List<List<List<List<double>>>> _preprocessImageAsFloat32(CameraImage image) {
    try {
      final rgbImage = _createRGBImageFromCamera(image);
      final resized = img.copyResize(rgbImage, width: INPUT_SIZE, height: INPUT_SIZE);
      
      // Normaliser les pixels (0-255 -> 0-1) avec format [batch, height, width, channels]
      final input = List.generate(1, (b) =>
        List.generate(INPUT_SIZE, (y) =>
          List.generate(INPUT_SIZE, (x) =>
            List.generate(3, (c) {
              final pixel = resized.getPixel(x, y);
              switch (c) {
                case 0: return pixel.r / 255.0;
                case 1: return pixel.g / 255.0;
                case 2: return pixel.b / 255.0;
                default: return 0.0;
              }
            })
          )
        )
      );

      return input;
    } catch (e) {
      print('Erreur préprocessing Float32: $e');
      return List.generate(1, (b) =>
        List.generate(INPUT_SIZE, (y) =>
          List.generate(INPUT_SIZE, (x) =>
            List.generate(3, (c) => 0.0)
          )
        )
      );
    }
  }

  img.Image _createRGBImageFromCamera(CameraImage image) {
    // Créer une image RGB depuis CameraImage
    final rgbImage = img.Image(width: image.width, height: image.height);
    
    if (image.format.group == ImageFormatGroup.yuv420) {
      // Conversion YUV420 vers RGB améliorée
      final yPlane = image.planes[0];
      final uPlane = image.planes[1];
      final vPlane = image.planes[2];
      
      for (int y = 0; y < image.height; y++) {
        for (int x = 0; x < image.width; x++) {
          final yIndex = y * yPlane.bytesPerRow + x;
          final uvPixelStride = uPlane.bytesPerPixel ?? 1;
          final uvRowStride = uPlane.bytesPerRow;
          final uvIndex = (y ~/ 2) * uvRowStride + (x ~/ 2) * uvPixelStride;
          
          if (yIndex < yPlane.bytes.length && 
              uvIndex < uPlane.bytes.length && 
              uvIndex < vPlane.bytes.length) {
            
            final yValue = yPlane.bytes[yIndex];
            final uValue = uPlane.bytes[uvIndex];
            final vValue = vPlane.bytes[uvIndex];
            
            // Conversion YUV vers RGB avec meilleure précision
            final r = (yValue + 1.402 * (vValue - 128)).round().clamp(0, 255);
            final g = (yValue - 0.344136 * (uValue - 128) - 0.714136 * (vValue - 128)).round().clamp(0, 255);
            final b = (yValue + 1.772 * (uValue - 128)).round().clamp(0, 255);
            
            rgbImage.setPixelRgb(x, y, r, g, b);
          }
        }
      }
    } else {
      // Pour d'autres formats, utiliser une conversion générique
      final bytes = image.planes[0].bytes;
      for (int i = 0; i < bytes.length - 2; i += 3) {
        final x = (i ~/ 3) % image.width;
        final y = (i ~/ 3) ~/ image.width;
        if (y < image.height) {
          rgbImage.setPixelRgb(x, y, bytes[i], bytes[i + 1], bytes[i + 2]);
        }
      }
    }
    
    return rgbImage;
  }

  List<Detection> _processDetections(
    dynamic boxes,
    dynamic classes,
    dynamic scores,
    int imageWidth,
    int imageHeight,
  ) {
    List<Detection> detections = [];

    try {
      // Convertir en listes si nécessaire
      List<List<double>> boxesList;
      List<double> classesList;
      List<double> scoresList;
      
      if (boxes is List<List<double>>) {
        boxesList = boxes;
      } else {
        boxesList = (boxes as List).map((e) => (e as List).cast<double>()).toList();
      }
      
      classesList = (classes as List).cast<double>();
      scoresList = (scores as List).cast<double>();

      for (int i = 0; i < scoresList.length; i++) {
        if (scoresList[i] > THRESHOLD) {
          final classIndex = classesList[i].round();
          if (classIndex >= 0 && classIndex < _labels.length) {
            final box = boxesList[i];
            
            // Convertir les coordonnées normalisées en pixels
            final rect = Rect.fromLTWH(
              box[1] * imageWidth,  // left
              box[0] * imageHeight, // top
              (box[3] - box[1]) * imageWidth,  // width
              (box[2] - box[0]) * imageHeight, // height
            );

            detections.add(Detection(
              label: _labels[classIndex],
              confidence: scoresList[i],
              boundingBox: rect,
            ));
          }
        }
      }
    } catch (e) {
      print('Erreur processing détections: $e');
    }

    return detections;
  }

  void dispose() {
    _interpreter?.close();
  }
}

class DetectionOverlay extends StatelessWidget {
  final List<Detection> detections;
  final Size imageSize;
  final Size screenSize;

  const DetectionOverlay({
    Key? key,
    required this.detections,
    required this.imageSize,
    required this.screenSize,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: DetectionPainter(
        detections: detections,
        imageSize: imageSize,
        screenSize: screenSize,
      ),
      size: screenSize,
    );
  }
}

class DetectionPainter extends CustomPainter {
  final List<Detection> detections;
  final Size imageSize;
  final Size screenSize;

  DetectionPainter({
    required this.detections,
    required this.imageSize,
    required this.screenSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final textPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    for (final detection in detections) {
      // Convertir les coordonnées du modèle vers l'écran
      final rect = _scaleRect(detection.boundingBox);
      
      // Dessiner le rectangle de détection
      canvas.drawRect(rect, paint);
      
      // Préparer le texte
      final text = '${detection.label} ${(detection.confidence * 100).toInt()}%';
      final textSpan = TextSpan(
        text: text,
        style: TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      );
      
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      );
      
      textPainter.layout();
      
      // Dessiner l'arrière-plan du texte
      final textRect = Rect.fromLTWH(
        rect.left,
        rect.top - 20,
        textPainter.width + 4,
        textPainter.height + 2,
      );
      
      canvas.drawRect(textRect, Paint()..color = Colors.red);
      
      // Dessiner le texte
      textPainter.paint(
        canvas,
        Offset(rect.left + 2, rect.top - 19),
      );
    }
  }

  Rect _scaleRect(Rect rect) {
    final scaleX = screenSize.width / imageSize.width;
    final scaleY = screenSize.height / imageSize.height;
    
    return Rect.fromLTWH(
      rect.left * scaleX,
      rect.top * scaleY,
      rect.width * scaleX,
      rect.height * scaleY,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}