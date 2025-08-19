import 'package:flutter/material.dart';
import 'package:krishi_sakha/utils/theme/colors.dart';

class ChatServerScreen extends StatefulWidget {
  const ChatServerScreen({super.key});

  @override
  State<ChatServerScreen> createState() => _ChatServerScreenState();
}

class _ChatServerScreenState extends State<ChatServerScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryBlack,
      appBar: AppBar(
        leading: IconButton(onPressed: (){}, icon: Icon(Icons.arrow_back_ios)),
        backgroundColor: AppColors.primaryBlack,
        foregroundColor: AppColors.primaryWhite,
        title: const Text(
          'Local Assistants',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        elevation: 0,
      ),
      body: Center(
        child: ElevatedButton(onPressed: (){
          
        }, child: Text('Test Apis')),
      ),
    );
  }
}