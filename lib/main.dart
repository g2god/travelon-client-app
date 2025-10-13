import 'package:flutter/material.dart';
import 'package:locatewifi/WifiLocator.dart';
import 'package:locatewifi/WifiSurveyPage.dart';
import 'package:locatewifi/mypage.dart';

void main() {
  runApp(const MyApp());
}

// main function
class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      // home: WifiLocator(),
      home: MapPage(),
    );
  }
}
