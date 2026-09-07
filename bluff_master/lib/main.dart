import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/lobby_screen.dart';
import 'firebase_options.dart';
void main() async{
  WidgetsFlutterBinding.ensureInitialized();
  try{
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print("Firebase OK");
  }
  catch(e){
    print('Firebase FAILED $e');
  }
  // it wires up Flutter's entire platform connection — the ability to talk to native iOS/Android code, handle touches, render widgets, and cache images. All processes that have to be done prior to running of app for better working 
  runApp(const BluffMasterApp());
}

class BluffMasterApp extends StatelessWidget{
  const BluffMasterApp({super.key});

  @override
  Widget build(BuildContext context){
    return MaterialApp(
      title:'Bluff Master',
      theme:ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor:Colors.deepPurple),
        useMaterial3:true,
      ),
      home:const AuthGate(),
      routes:{
        '/login':(context)=> LoginScreen(),
        '/home':(context)=> HomeScreen(),
        '/lobby':(context)=>LobbyScreen(),
      },
    );
  }
}

class AuthGate extends StatelessWidget{

  const AuthGate({super.key});

  @override
  Widget build(BuildContext context){
    final user = FirebaseAuth.instance.currentUser;
    // returns currently signed in firebase auth

    if(user != null){
      return const HomeScreen();
    }
    else{
      return const LoginScreen();
    }
  }
}

