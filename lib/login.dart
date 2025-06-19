import 'package:flutter/material.dart';
import 'package:app_ai_traiter/register.dart';
import 'package:app_ai_traiter/home.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:app_ai_traiter/LocalBindings.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class Login extends StatefulWidget {
 
  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> with TickerProviderStateMixin {
  static const String isLoggedIn = "isLoggedIn";
  static const String userRef = "userRef";
  bool passwordVisible = true;
  final _formKey = GlobalKey<FormState>();
  
  // Ajout des controllers
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack));
    
    _animationController.forward();
  }

  Future signInWithGoogle() async {
    try {
      // Configuration explicite de GoogleSignIn
      final GoogleSignIn googleSignIn = GoogleSignIn(
        scopes: ['email', 'profile'],
      );

      // Se déconnecter d'abord pour éviter les conflits
      await googleSignIn.signOut();
      
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        Fluttertoast.showToast(
          msg: "Connexion Google annulée",
          backgroundColor: Colors.orange,
        );
        return;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // Vérifier que les tokens sont disponibles
      if (googleAuth.accessToken == null || googleAuth.idToken == null) {
        throw Exception('Échec de récupération des tokens Google');
      }

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      UserCredential userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      
      // Vérifier si l'utilisateur existe déjà dans Firestore
      final userDoc = await FirebaseFirestore.instance
          .collection('clients')
          .where('uid', isEqualTo: userCredential.user!.uid)
          .get();

      if (userDoc.docs.isEmpty) {
        // Créer un nouveau document utilisateur
        await FirebaseFirestore.instance.collection('clients').add({
          'uid': userCredential.user!.uid,
          'email': userCredential.user!.email,
          'name': userCredential.user!.displayName ?? 'Utilisateur Google',
          'photoUrl': userCredential.user!.photoURL,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      // Sauvegarder l'état de connexion
      LocalStorage.sharedInstance.setAuthStatus(key: isLoggedIn, value: "true");
      
      // Récupérer la référence utilisateur
      final updatedUserDoc = await FirebaseFirestore.instance
          .collection('clients')
          .where('uid', isEqualTo: userCredential.user!.uid)
          .get();
      
      if (updatedUserDoc.docs.isNotEmpty) {
        LocalStorage.sharedInstance.setUserRef(
            key: userRef, value: updatedUserDoc.docs[0].id.toString());
      }

      Fluttertoast.showToast(
        msg: 'Connexion Google réussie !',
        backgroundColor: Colors.green,
      );

      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (context) => HomePage()));

    } catch (e) {
      print("Erreur Google Sign-In: $e");
      
      String errorMessage;
      if (e.toString().contains('network_error')) {
        errorMessage = "Erreur de réseau. Vérifiez votre connexion internet.";
      } else if (e.toString().contains('sign_in_canceled')) {
        errorMessage = "Connexion Google annulée";
      } else if (e.toString().contains('sign_in_failed')) {
        errorMessage = "Échec de la connexion Google. Réessayez.";
      } else {
        errorMessage = "Configuration Google Sign-In requise. Contactez le support.";
      }
      
      Fluttertoast.showToast(
        msg: errorMessage,
        backgroundColor: Colors.red,
        toastLength: Toast.LENGTH_LONG,
      );
    }
  }

  // Fonction pour mot de passe oublié
  Future<void> resetPassword() async {
    if (_emailController.text.isEmpty) {
      Fluttertoast.showToast(
        msg: "Veuillez saisir votre email d'abord",
        backgroundColor: Colors.orange,
      );
      return;
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: _emailController.text.trim(),
      );
      Fluttertoast.showToast(
        msg: "Email de réinitialisation envoyé ! Vérifiez votre boîte mail.",
        backgroundColor: Colors.green,
        toastLength: Toast.LENGTH_LONG,
      );
    } catch (e) {
      Fluttertoast.showToast(
        msg: "Erreur: ${e.toString()}",
        backgroundColor: Colors.red,
      );
    }
  }

  bool validateAndSave() {
    final form = _formKey.currentState;
    if (form!.validate()) {
      return true;
    }
    return false;
  }

  void validateAndSubmit() async {
    FocusScope.of(context).requestFocus(FocusNode());
    if (validateAndSave()) {
      try {
        // Show loading indicator
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8d48c7)),
              ),
            );
          },
        );

        // Utilisation des controllers au lieu de _email et _password
        UserCredential user = await FirebaseAuth.instance
            .signInWithEmailAndPassword(
                email: _emailController.text.trim(), 
                password: _passwordController.text.trim());
        
        // Dismiss loading dialog
        Navigator.of(context).pop();
        
        Fluttertoast.showToast(
          msg: 'Connexion réussie !',
          backgroundColor: Colors.green,
        );

        LocalStorage.sharedInstance.setAuthStatus(key: isLoggedIn, value: "true");

        FirebaseFirestore.instance
            .collection('clients')
            .where('uid', isEqualTo: user.user!.uid)
            .snapshots()
            .listen((data) {
          if (data.docs.isNotEmpty) {
            print('Doc found: ${data.docs[0].id}');
            LocalStorage.sharedInstance.setUserRef(
                key: userRef, value: data.docs[0].id.toString());
          }
        });
        
        if(FirebaseAuth.instance.currentUser!.emailVerified){
          Navigator.pushReplacement(
              context, MaterialPageRoute(builder: (context) => HomePage()));
        } else {
          Fluttertoast.showToast(
            msg: "Veuillez vérifier le lien dans votre email puis vous connecter",
            backgroundColor: Colors.orange,
            toastLength: Toast.LENGTH_LONG,
          );
        }
      } catch (e) {
        // Dismiss loading dialog if it's showing
        if (Navigator.canPop(context)) {
          Navigator.of(context).pop();
        }
        
        print("error: $e");
        String errorMessage = "Erreur de connexion";
        
        if (e.toString().contains('user-not-found')) {
          errorMessage = "Aucun utilisateur trouvé avec cet email";
        } else if (e.toString().contains('wrong-password')) {
          errorMessage = "Mot de passe incorrect";
        } else if (e.toString().contains('invalid-email')) {
          errorMessage = "Format d'email invalide";
        } else if (e.toString().contains('user-disabled')) {
          errorMessage = "Ce compte a été désactivé";
        }
        
        Fluttertoast.showToast(
          msg: errorMessage,
          backgroundColor: Colors.red,
          toastLength: Toast.LENGTH_LONG,
        );
      }
    }
  }

  @override
  void dispose() {
    // Nettoyage des controllers
    _emailController.dispose();
    _passwordController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF667eea),
              Color(0xFF764ba2),
              Color(0xFF8d48c7),
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0), // Réduit le padding horizontal
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          // Logo/Icon section
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.person_outline,
                              size: 60,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 30),
                          
                          // Main login container
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20), // Réduit le padding interne
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(25),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 20,
                                  spreadRadius: 5,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                const Text(
                                  'Bienvenue',
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF333333),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Connectez-vous à votre compte',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(height: 30),
                                
                                // Email field
                                TextFormField(
                                  controller: _emailController,
                                  keyboardType: TextInputType.emailAddress,
                                  decoration: InputDecoration(
                                    labelText: 'Email',
                                    prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFF8d48c7)),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(15),
                                      borderSide: BorderSide.none,
                                    ),
                                    filled: true,
                                    fillColor: const Color(0xFFF5F5F5),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(15),
                                      borderSide: const BorderSide(color: Color(0xFF8d48c7), width: 2),
                                    ),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return "L'email ne peut pas être vide";
                                    }
                                    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                                      return "Format d'email invalide";
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 20),
                                
                                // Password field
                                TextFormField(
                                  controller: _passwordController,
                                  obscureText: passwordVisible,
                                  decoration: InputDecoration(
                                    labelText: 'Mot de passe',
                                    prefixIcon: const Icon(Icons.lock_outlined, color: Color(0xFF8d48c7)),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        passwordVisible ? Icons.visibility_off : Icons.visibility,
                                        color: Color(0xFF8d48c7),
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          passwordVisible = !passwordVisible;
                                        });
                                      },
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(15),
                                      borderSide: BorderSide.none,
                                    ),
                                    filled: true,
                                    fillColor: const Color(0xFFF5F5F5),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(15),
                                      borderSide: const BorderSide(color: Color(0xFF8d48c7), width: 2),
                                    ),
                                  ),
                                  validator: (value) => value!.isEmpty
                                      ? "Le mot de passe ne peut pas être vide"
                                      : null,
                                ),
                                const SizedBox(height: 25),
                                
                                // Login button
                                SizedBox(
                                  width: double.infinity,
                                  height: 55,
                                  child: ElevatedButton(
                                    onPressed: validateAndSubmit,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF8d48c7),
                                      elevation: 5,
                                      shadowColor: const Color(0xFF8d48c7).withOpacity(0.4),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(15),
                                      ),
                                    ),
                                    child: const Text(
                                      'Se connecter',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                
                                // Google Sign In button
                                SizedBox(
                                  width: double.infinity,
                                  height: 55,
                                  child: OutlinedButton.icon(
                                    onPressed: signInWithGoogle,
                                    icon: Image.asset(
                                      'images/google_logo.png', // Assurez-vous d'avoir cette image
                                      height: 24,
                                      width: 24,
                                      errorBuilder: (context, error, stackTrace) {
                                        return const Icon(Icons.login, color: Color(0xFF8d48c7));
                                      },
                                    ),
                                    label: const Text(
                                      'Continuer avec Google',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                        color: Color(0xFF333333),
                                      ),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(color: Color(0xFFE0E0E0)),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(15),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 15), // Réduit l'espacement
                                
                                // Forgot password and register links - CORRECTION ICI
                                Column( // Changé de Row à Column pour éviter l'overflow
                                  children: [
                                    // Bouton mot de passe oublié
                                    SizedBox(
                                      width: double.infinity,
                                      child: TextButton(
                                        onPressed: resetPassword,
                                        child: const Text(
                                          'Mot de passe oublié ?',
                                          style: TextStyle(
                                            color: Color(0xFF8d48c7),
                                            fontWeight: FontWeight.w500,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                    ),
                                    // Espacement réduit
                                    const SizedBox(height: 5),
                                    // Bouton créer un compte
                                    SizedBox(
                                      width: double.infinity,
                                      child: TextButton(
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                                builder: (context) => RegisterPage()),
                                          );
                                        },
                                        child: const Text(
                                          "Créer un compte",
                                          style: TextStyle(
                                            color: Color(0xFF8d48c7),
                                            fontWeight: FontWeight.w500,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20), // Réduit l'espacement final
                        ],
                      ),
                    ),
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