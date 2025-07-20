import 'package:flutter/material.dart';
import 'package:lankacater/screens/onboard_screen.dart';

void main(){
  runApp(const MyApp());
}
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "LankaCater",
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: "Inter"
      ),
      home: OnboardingScreen(
        
      )
      );
      
  }
}