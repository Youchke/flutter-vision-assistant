import 'package:flutter/material.dart';
//import 'package:app_ai_traiter/main.dart';
import 'package:app_ai_traiter/login.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:app_ai_traiter/LocalBindings.dart';

class RegisterPage extends StatefulWidget {
  @override
  _RegisterPageState createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  static const String isLoggedIn = "isLoggedIn";
  static const String userRef = "userRef";
  
  // Ajout des controllers
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _fnameController = TextEditingController();
  final _lnameController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  String? _uid;
  bool _isLoading = false;

  bool validateAndSave() {
    final form = _formKey.currentState;
    if (form!.validate()) {
      return true;
    }
    return false;
  }

  // Validation email plus robuste
  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return "L'email ne peut pas être vide";
    }
    // Expression régulière simple pour valider l'email
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
      return "Veuillez entrer un email valide";
    }
    return null;
  }

  // Validation mot de passe
  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return "Le mot de passe ne peut pas être vide";
    }
    if (value.length < 6) {
      return "Le mot de passe doit contenir au moins 6 caractères";
    }
    return null;
  }

  // Correction: amélioration de la fonction _add avec meilleure gestion d'erreurs
  Future<DocumentReference> _add() async {
    try {
      Map<String, dynamic> data = <String, dynamic>{
        "image": "",
        "nom": _lnameController.text.trim(),
        "prenom": _fnameController.text.trim(),
        "email": _emailController.text.trim().toLowerCase(),
        "uid": _uid,
        "status": true,
        "createdAt": FieldValue.serverTimestamp(), // Correction: utilisation de FieldValue pour timestamp côté serveur
        "updatedAt": FieldValue.serverTimestamp(),
      };
      
      // Créer une nouvelle référence pour chaque utilisateur
      DocumentReference docRef = FirebaseFirestore.instance.collection("clients").doc();
      await docRef.set(data);
      
      // Sauvegarder la référence du document immédiatement
      await LocalStorage.sharedInstance.setUserRef(key: userRef, value: docRef.id);
      
      print("Data added with ID: ${docRef.id}");
      return docRef; // Retourner la référence pour usage ultérieur si nécessaire
    } catch (e) {
      print("Error adding data: $e");
      Fluttertoast.showToast(msg: "Erreur lors de l'enregistrement des données: $e");
      rethrow; // Relancer l'erreur pour la gérer dans validateAndSubmit
    }
  }

  void validateAndSubmit() async {
    if (_isLoading) return; // Éviter les soumissions multiples
    
    FocusScope.of(context).requestFocus(FocusNode());
    
    // Vérification des mots de passe
    if (_passwordController.text != _confirmPasswordController.text) {
      Fluttertoast.showToast(msg: "Les mots de passe ne correspondent pas");
      return;
    }
    
    if (validateAndSave()) {
      setState(() {
        _isLoading = true;
      });
      
      try {
        // Créer l'utilisateur Firebase Auth
        UserCredential userCredential = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(
                email: _emailController.text.trim().toLowerCase(),
                password: _passwordController.text);
        
        print("User created: ${userCredential.user!.uid}");
        _uid = userCredential.user!.uid;
        
        // Définir le statut d'authentification
        try {
          await LocalStorage.sharedInstance
              .setAuthStatus(key: isLoggedIn, value: "true");
        } catch (e) {
          print("An error occurred while trying to set auth status: $e");
        }
        
        // Correction: attendre que _add() se termine avant de continuer
        await _add();
        
        // Envoyer l'email de vérification
        try {
          await userCredential.user!.sendEmailVerification();
          Fluttertoast.showToast(msg: "Email de vérification envoyé");
        } catch (e) {
          print("Error sending verification email: $e");
          // Ne pas bloquer l'inscription si l'email de vérification échoue
          Fluttertoast.showToast(msg: "Compte créé mais erreur d'envoi d'email de vérification");
        }
        
        Fluttertoast.showToast(msg: "Compte créé avec succès");
        
        // Vérifier si le widget est encore monté avant de naviguer
        if (mounted) {
          Navigator.pushReplacement(
              context, MaterialPageRoute(builder: (context) => Login()));
        }
        
      } catch (e) {
        print("Error during registration: $e");
        String errorMessage = "Une erreur s'est produite";
        
        // Messages d'erreur plus spécifiques
        if (e is FirebaseAuthException) {
          switch (e.code) {
            case 'weak-password':
              errorMessage = "Le mot de passe est trop faible";
              break;
            case 'email-already-in-use':
              errorMessage = "Un compte existe déjà avec cet email";
              break;
            case 'invalid-email':
              errorMessage = "L'adresse email n'est pas valide";
              break;
            case 'operation-not-allowed':
              errorMessage = "L'inscription par email n'est pas activée";
              break;
            case 'network-request-failed':
              errorMessage = "Erreur de connexion réseau";
              break;
            default:
              errorMessage = e.message ?? "Erreur d'authentification inconnue";
          }
        } else if (e is FirebaseException) {
          errorMessage = "Erreur Firestore: ${e.message}";
        }
        
        Fluttertoast.showToast(
          msg: errorMessage,
          toastLength: Toast.LENGTH_LONG,
        );
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  void dispose() {
    // Nettoyage des controllers
    _emailController.dispose();
    _passwordController.dispose();
    _fnameController.dispose();
    _lnameController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        // Arrière-plan dégradé amélioré
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF667eea),
              Color(0xFF764ba2),
              Color(0xFFf093fb),
              Color(0xFFf5576c),
            ],
            stops: [0.0, 0.3, 0.7, 1.0],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 30.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      // Ajout de l'image/logo en haut
                      Container(
                        margin: const EdgeInsets.only(bottom: 30),
                        child: Column(
                          children: [
                            // Vous pouvez remplacer cette icône par votre logo
                            Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.9),
                                borderRadius: BorderRadius.circular(50),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 20,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.person_add_alt_1,
                                size: 50,
                                color: Color(0xFF764ba2),
                              ),
                            ),
                            const SizedBox(height: 15),
                            const Text(
                              'Créer un compte',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                shadows: [
                                  Shadow(
                                    offset: Offset(0, 2),
                                    blurRadius: 4,
                                    color: Colors.black26,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(25),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.95),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            const Text(
                              'Inscription',
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF764ba2),
                              ),
                            ),
                            const SizedBox(height: 25),
                            TextFormField(
                              controller: _lnameController,
                              decoration: InputDecoration(
                                labelText: 'Saisir votre nom',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                prefixIcon: const Icon(Icons.person, color: Color(0xFF764ba2)),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15),
                                  borderSide: const BorderSide(color: Color(0xFF764ba2), width: 2),
                                ),
                              ),
                              validator: (value) => value == null || value.trim().isEmpty
                                  ? "Le nom ne peut pas être vide"
                                  : null,
                            ),
                            const SizedBox(height: 20),
                            TextFormField(
                              controller: _fnameController,
                              decoration: InputDecoration(
                                labelText: 'Saisir votre prénom',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                prefixIcon: const Icon(Icons.person_outline, color: Color(0xFF764ba2)),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15),
                                  borderSide: const BorderSide(color: Color(0xFF764ba2), width: 2),
                                ),
                              ),
                              validator: (value) => value == null || value.trim().isEmpty
                                  ? "Le prénom ne peut pas être vide"
                                  : null,
                            ),
                            const SizedBox(height: 20),
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              decoration: InputDecoration(
                                labelText: 'Saisir votre email',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                prefixIcon: const Icon(Icons.email, color: Color(0xFF764ba2)),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15),
                                  borderSide: const BorderSide(color: Color(0xFF764ba2), width: 2),
                                ),
                              ),
                              validator: _validateEmail,
                            ),
                            const SizedBox(height: 20),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: true,
                              decoration: InputDecoration(
                                labelText: 'Saisir votre mot de passe',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                prefixIcon: const Icon(Icons.lock, color: Color(0xFF764ba2)),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15),
                                  borderSide: const BorderSide(color: Color(0xFF764ba2), width: 2),
                                ),
                              ),
                              validator: _validatePassword,
                            ),
                            const SizedBox(height: 20),
                            TextFormField(
                              controller: _confirmPasswordController,
                              obscureText: true,
                              decoration: InputDecoration(
                                labelText: 'Confirmer votre mot de passe',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF764ba2)),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15),
                                  borderSide: const BorderSide(color: Color(0xFF764ba2), width: 2),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return "La confirmation du mot de passe ne peut pas être vide";
                                }
                                if (value != _passwordController.text) {
                                  return "Les mots de passe ne correspondent pas";
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 30),
                            SizedBox(
                              width: double.infinity,
                              height: 55,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : validateAndSubmit,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF764ba2),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                  elevation: 5,
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        width: 25,
                                        height: 25,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 3,
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                        ),
                                      )
                                    : const Text(
                                        'S\'inscrire',
                                        style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text(
                                  "Déjà un compte ? ",
                                  style: TextStyle(color: Colors.grey),
                                ),
                                TextButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (context) => Login()),
                                    );
                                  },
                                  child: const Text(
                                    "Se connecter",
                                    style: TextStyle(
                                      color: Color(0xFF764ba2),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        )),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}