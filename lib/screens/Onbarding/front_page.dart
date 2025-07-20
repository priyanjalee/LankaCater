import 'package:flutter/material.dart';
import 'package:lankacater/constants/colors.dart';

class FrontPage extends StatelessWidget {
  const FrontPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text(
            "Welcome",
            style: TextStyle(
              fontSize: 40,
              color: kBlack,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Text(
            "Your event. Our flavors. Let’s serve it right!",
            style: TextStyle(
              fontSize: 15,
              color: Color.fromARGB(255, 165, 165, 191),
              fontWeight: FontWeight.bold,
            ),
          ),
          Image.asset(
            "assests/images/welcme.png",
            width: 500,
            fit: BoxFit.cover,
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}