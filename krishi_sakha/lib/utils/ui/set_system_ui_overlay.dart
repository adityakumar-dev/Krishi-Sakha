 import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

Future<void> setSystemUIOverlayStyle() async {
 SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
    ));  }
