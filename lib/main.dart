import 'package:flutter/material.dart';
import 'package:new_project/face_detection_screen.dart';
import 'login_screen.dart';
import 'id_verification_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget { 
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Digital World',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const WelcomeScreen(),
    );
  }
}

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration( 
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFFFFFF),  // Deep purple
              Color(0xFFD6E6F2),   // Blue
            ],
            stops: [0.1, 0.9],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Welcome text
              const Column(
                children: [
                  Text(
                    'Welcome to',
                    style: TextStyle(
                      fontSize: 50,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  Text(
                    'Digital World',
                    style: TextStyle(
                      fontSize: 50,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'With',
                    style: TextStyle(
                      fontSize: 50,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),

              RichText(
                text: TextSpan(
                  style: TextStyle(
                    fontSize: 60,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF13A4B4),  // Changed from black to white
                    letterSpacing: 20.0,
                    
                    
                  ),
                  children: [
                    TextSpan(text: 'SL'),
                    TextSpan(
                      text: 'U',
                      style: TextStyle(color: Colors.yellow),
                    ),
                    TextSpan(text: 'ID'),
                  ],
                ),
              ),
              
              const SizedBox(height: 60),
              
              // Buttons
              SizedBox(
                width: 300, // Increased width to accommodate both buttons side by side
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween, // Space between buttons
                  children: [
                    // Register Button
                    SizedBox(
                      width: 140, // Fixed width for each button
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const IDVerificationScreen(
                              //idNumber: '199832697842',
                            )),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF13A4B4),
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 3,
                        ),
                        child: const Text(
                          'Register',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                    
                    // Login Button
                    SizedBox(
                    
                      width: 140, // Fixed width for each button
                      height: 50,
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const LoginScreen()),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.black,
                          backgroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white),
                          minimumSize: const Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Login',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
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
      ),
    );
  }
}