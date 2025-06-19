import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutDeveloperPage extends StatefulWidget {
  @override
  _AboutDeveloperPageState createState() => _AboutDeveloperPageState();
}

class _AboutDeveloperPageState extends State<AboutDeveloperPage> {
  // URLs à modifier selon vos vrais profils
  final String githubUrl = 'https://github.com/Youchke';
  final String linkedinUrl = 'https://www.linkedin.com/in/younes-ouchake-4b2502282/';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'À propos du développeur',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.indigo[700],
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Photo de profil et nom
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 5,
                    blurRadius: 7,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: Colors.indigo[100],
                    backgroundImage: AssetImage('images/about_dev2.jpg'),
                  ),
                  SizedBox(height: 20),
                  Text(
                    'Ouchake Younes',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Développeur Mobile |AI and data Science Student',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
            
            SizedBox(height: 30),
            
            // Compétences
            _buildInfoCard(
              title: 'Compétences',
              icon: Icons.code,
              children: [
                Wrap(
                  children: [
                    _buildSkillChip('Flutter'),
                    _buildSkillChip('Dart|Python|Java|PHP|C/C++'),
                    _buildSkillChip('Firebase'),
                    _buildSkillChip('UML'),
                    _buildSkillChip('Git'),
                    _buildSkillChip('SQLite|oracle|postgres|MySQL'),
                    _buildSkillChip('AI generative'),
                    _buildSkillChip('Mathematique'),
                    _buildSkillChip('Web Scraping'),
                    _buildSkillChip('Hive'),
                  ],
                ),
              ],
            ),
            
            SizedBox(height: 30),
            
            // Liens professionnels
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildSocialButton(
                  icon: Icons.code,
                  label: 'GitHub',
                  color: Colors.grey[800]!,
                  url: githubUrl,
                ),
                _buildSocialButton(
                  icon: Icons.business,
                  label: 'LinkedIn',
                  color: Colors.blue[700]!,
                  url: linkedinUrl,
                ),
              ],
            ),
            
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
  
  Widget _buildInfoCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 3,
            blurRadius: 5,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.indigo[700], size: 24),
              SizedBox(width: 10),
              Text(
                title,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
          SizedBox(height: 15),
          ...children,
        ],
      ),
    );
  }
  
  Widget _buildSkillChip(String skill) {
    return Container(
      margin: EdgeInsets.only(right: 10, bottom: 10),
      child: Chip(
        label: Text(
          skill,
          style: TextStyle(
            color: Colors.indigo[700],
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: Colors.indigo[50],
        side: BorderSide(color: Colors.indigo[200]!),
      ),
    );
  }
  
  Widget _buildSocialButton({
    required IconData icon,
    required String label,
    required Color color,
    required String url,
  }) {
    return ElevatedButton.icon(
      onPressed: () => _launchUrl(url),
      icon: Icon(icon, color: Colors.white),
      label: Text(
        label,
        style: TextStyle(color: Colors.white),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(25),
        ),
      ),
    );
  }
  
  Future<void> _launchUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Impossible d\'ouvrir le lien'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}