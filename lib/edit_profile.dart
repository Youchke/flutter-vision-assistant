import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:app_ai_traiter/LocalBindings.dart';

class EditProfile extends StatefulWidget {
  @override
  _EditProfileState createState() => _EditProfileState();
}

class _EditProfileState extends State<EditProfile> {
  final _formKey = GlobalKey<FormState>();
  final _nomController = TextEditingController();
  final _prenomController = TextEditingController();
  final _passwordController = TextEditingController();
  
  bool _isLoading = false;
  bool _obscurePassword = true;
  File? _selectedImage;
  String? _currentImageBase64;
  String? docRef;
  
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ImagePicker _picker = ImagePicker();

  // Constantes pour les clés de stockage
  static const String userRef = "userRef";

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  // Charger les données utilisateur
  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);
    
    try {
      User? user = _auth.currentUser;
      if (user != null) {
        print('Chargement des données pour: ${user.uid}');
        
        // Correction: utiliser userRef au lieu de useRef
        String? docRefId = await LocalStorage.sharedInstance.loadUserRef(userRef);
        
        if (docRefId != null && docRefId.isNotEmpty) {
          // Utiliser l'ID du document stocké
          DocumentSnapshot userDoc = await _firestore
              .collection('clients')
              .doc(docRefId)
              .get();
          
          if (userDoc.exists) {
            Map<String, dynamic> data = userDoc.data() as Map<String, dynamic>;
            print('Données trouvées: $data');
            
            setState(() {
              _nomController.text = data['nom'] ?? '';
              _prenomController.text = data['prenom'] ?? '';
              _currentImageBase64 = data['image'];
              docRef = docRefId;
            });
          } else {
            print('Document utilisateur non trouvé avec ID: $docRefId');
            // Fallback: essayer avec l'UID
            await _tryLoadWithUID(user.uid);
          }
        } else {
          // Fallback: essayer avec l'UID si pas de docRef sauvegardé
          await _tryLoadWithUID(user.uid);
        }
      }
    } catch (e) {
      print('Erreur lors du chargement: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur de chargement: $e')),
      );
    }
    
    setState(() => _isLoading = false);
  }

  // Méthode de fallback pour charger avec UID
  Future<void> _tryLoadWithUID(String uid) async {
    try {
      DocumentSnapshot userDoc = await _firestore
          .collection('clients')
          .doc(uid)
          .get();
      
      if (userDoc.exists) {
        Map<String, dynamic> data = userDoc.data() as Map<String, dynamic>;
        print('Données trouvées avec UID: $data');
        
        setState(() {
          _nomController.text = data['nom'] ?? '';
          _prenomController.text = data['prenom'] ?? '';
          _currentImageBase64 = data['image'];
          docRef = uid;
        });
      }
    } catch (e) {
      print('Erreur lors du chargement avec UID: $e');
    }
  }

  // Sélectionner une image
  Future<void> _pickImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 70,
      );
      
      if (pickedFile != null) {
        setState(() {
          _selectedImage = File(pickedFile.path);
        });
        print('Image sélectionnée: ${pickedFile.path}');
      }
    } catch (e) {
      print('Erreur sélection image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de la sélection de l\'image')),
      );
    }
  }

  // Sauvegarder le profil
  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    
    try {
      User? user = _auth.currentUser;
      if (user == null) {
        throw Exception('Utilisateur non connecté');
      }
      
      print('Sauvegarde pour: ${user.uid}');
      
      // Utiliser docRef si disponible, sinon utiliser l'UID
      String documentId = docRef ?? user.uid;
      
      // Préparer les données à sauvegarder
      Map<String, dynamic> updateData = {
        'nom': _nomController.text.trim(),
        'prenom': _prenomController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      
      // Gérer l'image avec une meilleure gestion d'erreurs
      if (_selectedImage != null) {
        print('Conversion de l\'image en base64...');
        try {
          final XFile imageFile = XFile(_selectedImage!.path);
          final Uint8List imageBytes = await imageFile.readAsBytes();
          
          // Vérifier la taille de l'image (limite Firestore ~1MB pour être sûr)
          if (imageBytes.length > 1000000) {
            throw Exception('Image trop volumineuse (max 1MB)');
          }
          
          String imageBase64 = base64Encode(imageBytes);
          updateData['image'] = imageBase64;
          print('Image convertie, taille: ${imageBase64.length} caractères');
        } catch (e) {
          print('Erreur conversion image: $e');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur lors du traitement de l\'image: $e'),
              backgroundColor: Colors.orange,
            ),
          );
          // Continue sans l'image en cas d'erreur
        }
      }
      
      // Ne pas inclure le password dans updateData s'il est vide
      if (_passwordController.text.isNotEmpty) {
        updateData['password'] = _passwordController.text.trim();
      }
      
      print('Données à sauvegarder: ${updateData.keys}');
      
      // Sauvegarder dans Firestore
      await _firestore.collection('clients').doc(documentId).set(
        updateData, 
        SetOptions(merge: true)
      );
      print('Données sauvegardées dans Firestore');
      
      // Mettre à jour le mot de passe Firebase Auth si modifié
      if (_passwordController.text.isNotEmpty) {
        print('Mise à jour du mot de passe Firebase Auth...');
        try {
          await user.updatePassword(_passwordController.text.trim());
          print('Mot de passe Firebase Auth mis à jour');
        } catch (e) {
          print('Erreur mise à jour mot de passe: $e');
          // Si l'utilisateur doit se reconnecter pour changer le mot de passe
          if (e.toString().contains('requires-recent-login')) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Veuillez vous reconnecter pour changer votre mot de passe'),
                backgroundColor: Colors.orange,
              ),
            );
          } else {
            throw e;
          }
        }
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Profil mis à jour avec succès !'),
          backgroundColor: Colors.green,
        ),
      );
      
      // Recharger les données pour s'assurer que tout est à jour
      await _loadUserData();
      
      Navigator.pop(context, true);
      
    } catch (e) {
      print('Erreur sauvegarde: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de la sauvegarde: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
    
    setState(() => _isLoading = false);
  }

  Widget _buildProfileImage() {
    ImageProvider? imageProvider;
    
    if (_selectedImage != null) {
      imageProvider = FileImage(_selectedImage!);
    } else if (_currentImageBase64 != null && _currentImageBase64!.isNotEmpty) {
      try {
        imageProvider = MemoryImage(base64Decode(_currentImageBase64!));
      } catch (e) {
        print('Erreur décodage image: $e');
        imageProvider = null;
      }
    }
    
    return Stack(
      children: [
        CircleAvatar(
          radius: 60,
          backgroundColor: Colors.grey[300],
          backgroundImage: imageProvider,
          child: imageProvider == null
              ? Icon(Icons.person, size: 60, color: Colors.grey[600])
              : null,
        ),
        Positioned(
          bottom: 0,
          right: 0,
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
              shape: BoxShape.circle,
            ),
            child: Padding(
              padding: EdgeInsets.all(8),
              child: Icon(
                Icons.camera_alt,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Modifier le profil'),
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveProfile,
            child: Text(
              'Sauvegarder',
              style: TextStyle(
                color: _isLoading ? Colors.grey : Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 20),
                  Text('Chargement...'),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Photo de profil
                    GestureDetector(
                      onTap: _pickImage,
                      child: _buildProfileImage(),
                    ),
                    
                    SizedBox(height: 15),
                    Text(
                      'Appuyez pour changer la photo',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                    
                    SizedBox(height: 30),
                    
                    // Champ Prénom
                    TextFormField(
                      controller: _prenomController,
                      decoration: InputDecoration(
                        labelText: 'Prénom',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Prénom requis';
                        }
                        return null;
                      },
                    ),
                    
                    SizedBox(height: 20),
                    
                    // Champ Nom
                    TextFormField(
                      controller: _nomController,
                      decoration: InputDecoration(
                        labelText: 'Nom',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        prefixIcon: Icon(Icons.person),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Nom requis';
                        }
                        return null;
                      },
                    ),
                    
                    SizedBox(height: 20),
                    
                    // Champ Mot de passe
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'Nouveau mot de passe',
                        hintText: 'Laissez vide pour ne pas changer',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        prefixIcon: Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(_obscurePassword 
                              ? Icons.visibility_off 
                              : Icons.visibility),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                      ),
                      validator: (value) {
                        if (value != null && value.isNotEmpty && value.length < 6) {
                          return 'Minimum 6 caractères';
                        }
                        return null;
                      },
                    ),
                    
                    SizedBox(height: 8),
                    Text(
                      'Laissez vide pour conserver le mot de passe actuel',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    
                    SizedBox(height: 40),
                    
                    // Bouton sauvegarder
                    ElevatedButton(
                      onPressed: _isLoading ? null : _saveProfile,
                      style: ElevatedButton.styleFrom(
                        minimumSize: Size(double.infinity, 55),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: _isLoading
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                ),
                                SizedBox(width: 10),
                                Text('Sauvegarde...'),
                              ],
                            )
                          : Text(
                              'Sauvegarder les modifications',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  @override
  void dispose() {
    _nomController.dispose();
    _prenomController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}