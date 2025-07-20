import 'package:flutter/material.dart';
import 'package:lankacater/constants/colors.dart';
import 'package:lankacater/constants/constant.dart';

class SharedOnboardingScreen extends StatelessWidget {
  final String title;
  final String imagePath;
  final String description;
  const SharedOnboardingScreen({
    super.key, 
    required this.title,
    required this.imagePath, 
    required this.description
    });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(kDefaultpadding.toDouble()),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Image.asset(
            imagePath,
            width: 300,
            fit:BoxFit.cover,
          ),
          const SizedBox(height: 20),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 20,),
          Text(
            description,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              color: kGrey,
              fontWeight: FontWeight.w600,
            ),
          )
        ],
      ),
    );
  }
}