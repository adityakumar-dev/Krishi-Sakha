import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:krishi_sakha/models/llm_model.dart';
import 'package:krishi_sakha/providers/model_provider.dart';
import 'package:krishi_sakha/providers/llama_provider.dart';
import 'package:krishi_sakha/screens/models/model_list_screen.dart';
import 'package:krishi_sakha/utils/routes/routes.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();

  Hive.registerAdapter(LlmModelAdapter());

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ModelProvider()),
        ChangeNotifierProvider(create: (_) => LlamaProvider()),
      ],
      child: MaterialApp.router(
        title: 'Simple AI Chat',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          visualDensity: VisualDensity.adaptivePlatformDensity,
          useMaterial3: true,
        ),
        routerConfig: appRouter,
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
