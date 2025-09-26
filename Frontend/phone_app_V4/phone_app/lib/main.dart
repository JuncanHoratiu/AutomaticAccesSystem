import 'package:flutter/material.dart';
import 'login_page.dart'; // Importăm pagina de login

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: LoginPage(), // Pornim cu pagina de login
    );
  }
}
