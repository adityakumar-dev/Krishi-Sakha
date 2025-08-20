import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:krishi_sakha/providers/server_chat_handler_provider.dart';
import 'package:krishi_sakha/providers/void_provider.dart';
import 'package:provider/provider.dart';
import 'package:krishi_sakha/models/llm_model.dart';
import 'package:krishi_sakha/providers/model_provider.dart';
import 'package:krishi_sakha/providers/llama_provider.dart';
import 'package:krishi_sakha/screens/models/model_list_screen.dart';
import 'package:krishi_sakha/utils/routes/routes.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  await dotenv.load(fileName: ".env");
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();

  Hive.registerAdapter(LlmModelAdapter());
  await Supabase.initialize(url: "SUPABASE_URL", anonKey: "SUPBASE_ANON_KEY");

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
        ChangeNotifierProvider(create: (_) => ServerChatHandlerProvider()),
        ChangeNotifierProvider(create: (_) => VoiceProvider())
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
