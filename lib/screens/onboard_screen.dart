import 'package:flutter/material.dart';
import 'package:lankacater/constants/colors.dart';
import 'package:lankacater/data/onboarding_data.dart';
import 'package:lankacater/screens/Onbarding/front_page.dart';
import 'package:lankacater/screens/Onbarding/shared_onboarding_screen.dart';
import 'package:lankacater/screens/user_data_screen.dart';
import 'package:lankacater/widgets/custom_button.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {

  //page controller
  final PageController _controller=PageController();
  bool showDetailsPage = false;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Expanded(child: Stack(
            children: [
              //Onboarding screens
          PageView(
            controller: _controller,
            onPageChanged: (index) {
              setState(() {
                showDetailsPage = index ==2;
              });
              
            },
            children: [
              const FrontPage(),
              SharedOnboardingScreen(
                title: OnboardingData.OnboardingDataList[0].title,
                imagePath: OnboardingData.OnboardingDataList[0].imagePath,
                description: OnboardingData.OnboardingDataList[0].description,
              ),
               SharedOnboardingScreen(
                title: OnboardingData.OnboardingDataList[1].title,
                imagePath: OnboardingData.OnboardingDataList[1].imagePath,
                description: OnboardingData.OnboardingDataList[1].description,
              ),
               
               
            ],
          ),
          //smooth page indicator
          Container(
            alignment: const Alignment(0, 0.60),
            child: SmoothPageIndicator(
              controller: _controller,
              count: 3,
              effect: const WormEffect(
                activeDotColor: kMaincolor,
                dotColor: kGrey
              ),
            ),
          ),
          //navigation button
          Positioned(
            bottom: 40,
            left: 30,
            right: 30,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: !showDetailsPage ?
               GestureDetector(
                onTap: () {
                 _controller.animateToPage(
                    _controller.page!.toInt() +1,
                     duration: const Duration(microseconds: 400), 
                     curve: Curves.easeInOut,
                     );
                },
                child: CustomButton(
                  buttonName: showDetailsPage ? "Get Started" : "Next",
                  buttonColor: kMaincolor,
                ),
              )
              : GestureDetector(
                onTap: () { //Navigate to the user data page
                  Navigator.push(context, MaterialPageRoute(builder: (context) =>
                   const UserDataScreen()
                  ));
                  
                },
                child: CustomButton(
                  buttonName: showDetailsPage ?"Get Started" : "Next",
                  buttonColor: kMaincolor,
                
                ),
              ),
            )
          )
              
            ],
          )
          )
        ],
      ),
    );
  }
}