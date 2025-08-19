import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:krishi_sakha/utils/routes/routes.dart';
import 'package:krishi_sakha/utils/theme/colors.dart';
import 'package:lottie/lottie.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});
  @override
  Widget build(BuildContext context) {

  final user = Supabase.instance.client.auth.currentUser;
  Future.delayed(Duration(seconds: 3), () {
  
    if(user != null){
      context.go(AppRoutes.home);
    }else{
      context.go(AppRoutes.onboarding);
    }    
  });


    return  Scaffold(
      backgroundColor: AppColors.primaryBlack,
      body: Center(
        child: Lottie.asset(
          repeat: false,
          'assets/lottie/IntroFirst.json', height: 300, width: 300),
      ),
    );
  }
}