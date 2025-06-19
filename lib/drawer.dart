import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

class Menu extends StatefulWidget {
  const Menu({super.key});

  @override
  _MenuState createState() => _MenuState();
}

class _MenuState extends State<Menu> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FlutterSecureStorage _storage = FlutterSecureStorage();
  
  User? currentUser;
  Map<String, dynamic>? userData;
  String? profileImageBase64;
  bool isLoading = true;
  StreamSubscription<DocumentSnapshot>? _userDataSubscription;

  @override
  void initState() {
    super.initState();
    _initializeUserData();
  }

  @override
  void dispose() {
    _userDataSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initializeUserData() async {
    setState(() {
      isLoading = true;
    });

    try {
      currentUser = _auth.currentUser;
      if (currentUser != null) {
        await _loadUserData();
      }
    } catch (e) {
      print('Erreur lors de l\'initialisation des données utilisateur: $e');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _loadUserData() async {
    if (currentUser == null) return;

    try {
      // Récupérer l'ID du document utilisateur depuis le stockage local
      String? userDocId = await _storage.read(key: "userRef");
      
      if (userDocId != null) {
        // Écouter les changements en temps réel des données utilisateur
        _userDataSubscription = _firestore
            .collection('clients')
            .doc(userDocId)
            .snapshots()
            .listen((DocumentSnapshot doc) {
          if (doc.exists && mounted) {
            setState(() {
              userData = doc.data() as Map<String, dynamic>?;
              // Utiliser uniquement la clé 'image' pour cohérence avec EditProfile
              profileImageBase64 = userData?['image'];
            });
          }
        });
      } else {
        // Si pas d'ID stocké, chercher par UID
        QuerySnapshot querySnapshot = await _firestore
            .collection('clients')
            .where('uid', isEqualTo: currentUser!.uid)
            .limit(1)
            .get();

        if (querySnapshot.docs.isNotEmpty) {
          DocumentSnapshot doc = querySnapshot.docs.first;
          await _storage.write(key: "userRef", value: doc.id);
          
          // Écouter les changements
          _userDataSubscription = _firestore
              .collection('clients')
              .doc(doc.id)
              .snapshots()
              .listen((DocumentSnapshot doc) {
            if (doc.exists && mounted) {
              setState(() {
                userData = doc.data() as Map<String, dynamic>?;
                // Utiliser uniquement la clé 'image'
                profileImageBase64 = userData?['image'];
              });
            }
          });
        } else {
          // Fallback: essayer avec l'UID comme ID de document
          _userDataSubscription = _firestore
              .collection('clients')
              .doc(currentUser!.uid)
              .snapshots()
              .listen((DocumentSnapshot doc) {
            if (doc.exists && mounted) {
              setState(() {
                userData = doc.data() as Map<String, dynamic>?;
                profileImageBase64 = userData?['image'];
              });
              // Sauvegarder l'ID pour les prochaines fois
              _storage.write(key: "userRef", value: currentUser!.uid);
            }
          });
        }
      }
    } catch (e) {
      print('Erreur lors du chargement des données utilisateur: $e');
    }
  }

  String _getDisplayName() {
    if (userData != null) {
      String prenom = userData!['prenom'] ?? '';
      String nom = userData!['nom'] ?? '';
      if (prenom.isNotEmpty && nom.isNotEmpty) {
        return '$prenom $nom';
      }
    }
    return currentUser?.displayName ?? currentUser?.email?.split('@')[0] ?? 'Utilisateur';
  }

  String _getDisplayEmail() {
    return userData?['email'] ?? currentUser?.email ?? '';
  }

  Widget _buildProfileImage() {
    // Vérifier s'il y a une image en base64
    if (profileImageBase64 != null && profileImageBase64!.isNotEmpty) {
      try {
        // Décoder l'image base64
        Uint8List imageBytes = base64Decode(profileImageBase64!);
        return CircleAvatar(
          backgroundImage: MemoryImage(imageBytes),
          radius: 35,
          onBackgroundImageError: (exception, stackTrace) {
            print('Erreur décodage image base64: $exception');
          },
        );
      } catch (e) {
        print('Erreur lors du décodage de l\'image base64: $e');
        // En cas d'erreur, utiliser l'image par défaut
        return _buildDefaultAvatar();
      }
    } else {
      // Image par défaut si pas d'image
      return _buildDefaultAvatar();
    }
  }

  Widget _buildDefaultAvatar() {
    return CircleAvatar(
      backgroundImage: AssetImage('images/about_dev2.jpg'),
      radius: 35,
      onBackgroundImageError: (exception, stackTrace) {
        // Si l'image par défaut échoue aussi, utiliser une icône
        print('Erreur chargement image par défaut: $exception');
      },
      child: profileImageBase64 == null ? 
        Icon(Icons.person, size: 35, color: Colors.white70) : null,
    );
  }

  Widget _buildUserHeader() {
    if (isLoading) {
      return DrawerHeader(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue, Colors.green],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    return DrawerHeader(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue, Colors.green],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image de profil à gauche en haut
          Padding(
            padding: EdgeInsets.only(top: 10, right: 15),
            child: _buildProfileImage(),
          ),
          // Informations utilisateur à droite de l'image
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: 15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  // Nom et prénom
                  Text(
                    _getDisplayName(),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 5),
                  // Email
                  Text(
                    _getDisplayEmail(),
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          _buildUserHeader(),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                ListTile(
                  leading: Icon(Icons.smart_toy, color: Colors.blue),
                  title: Text('Assistant virtuel'),
                  onTap: () {
                    Navigator.pop(context);
                    // Navigation vers l'assistant virtuel
                    Navigator.pushNamed(context, '/assistant');
                  },
                ),
                ListTile(
                  leading: Icon(Icons.category, color: Colors.orange),
                  title: Text('Detection des objets'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/object-processing');
                  },
                ),
                ListTile(
                  leading: Icon(Icons.image_search, color: Colors.purple),
                  title: Text('Generation d\'images'),
                  onTap: () {
                    Navigator.pop(context);
                    // Navigation vers analyse d'images
                    Navigator.pushNamed(context, '/image-generation');
                  },
                ),
                Divider(),
                ExpansionTile(
                  leading: Icon(Icons.account_circle, color: Colors.teal),
                  title: Text('Compte'),
                  children: [
                    ListTile(
                      leading: Icon(Icons.edit, color: Colors.amber),
                      title: Text('Edit profile'),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.pushNamed(context, '/editprofile');
                      },
                    ),
                    ListTile(
                      leading: Icon(Icons.settings, color: Colors.grey),
                      title: Text('Paramètres'),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.pushNamed(context, '/settings');
                      },
                    ),
                  ],
                ),
                Divider(),
                ListTile( 
                  leading: Icon(Icons.contacts, color: Colors.green),
                  title: Text('Contact us'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/contact');
                  },
                ),
                ListTile(
                  leading: Icon(Icons.info, color: Colors.blue),
                  title: Text('About developeur'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/about_developpeur');
                  },
                ),
                ListTile(
                  leading: Icon(Icons.logout, color: Colors.red),
                  title: Text('Déconnexion'),
                  onTap: () {
                    Navigator.pop(context); // Fermer le drawer
                    
                    // Dialog de confirmation simple
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text('Déconnexion'),
                        content: Text('Voulez-vous vous déconnecter ?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text('Annuler'),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.pop(context); // Fermer le dialog
                              
                              // Déconnexion simple
                              Navigator.pushNamedAndRemoveUntil(
                                context,
                                '/login',
                                (route) => false,
                              );
                            },
                            child: Text(
                              'Déconnexion',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
