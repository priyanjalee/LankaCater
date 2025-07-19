import 'package:flutter/material.dart';

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
      home: Scaffold(
        body: Center(
          child: Text(
            "LankaCater",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w300
            ),
          )
        ),
      )
      ,
    );
  }
}