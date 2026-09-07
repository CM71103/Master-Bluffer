import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';


class LoginScreen extends StatefulWidget{
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState()=> _LoginScreenState();

}

class _LoginScreenState extends State<LoginScreen>{

  final FirebaseAuth _auth = FirebaseAuth.instance;

  final GoogleSignIn _googleAuth = GoogleSignIn(clientId:'883473585633-6keu98g7hsb9cm1qeqvl76puf12gl423.apps.googleusercontent.com');

  bool _loading = false;
  String? _err;

  Future<void> _signInWithGoogle() async{
    setState((){
      _loading=false;
      _err=null;
    });

    try{
      final GoogleSignInAccount? googleUser = await _googleAuth.signIn();

      if(googleUser==null){
        setState(()=>_loading=false);
        return;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken:googleAuth.accessToken,
        idToken: googleAuth.idToken,
      ) ;

      await _auth.signInWithCredential(credential);

      if(mounted){
        Navigator.pushNamed(context,'/home');
      }

    }
    catch(e){
      setState((){
          print("GOOGLE SIGN-IN ERROR: $e"); 
        _loading=false;
        _err = e.toString();
      });
    }

  }

  Future<void> _signInAnonymously() async{
    setState((){
      _loading=true;
      _err= null;
    });

    try{
      await _auth.signInAnonymously();
      if(mounted){
        Navigator.pushNamed(context,'/home');  
      }
    }
    catch(e){
      print("GOOGLE SIGN-IN ERROR: $e");  // ← ADD this
      setState((){
        _loading=false;
        _err = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context){
    return Scaffold(
      backgroundColor: Color(0xFF1A1A2E),
      body:SafeArea(
        child:SingleChildScrollView(
        child:Padding(
          padding:EdgeInsets.all(24.0),
          child:Column(
            mainAxisAlignment:MainAxisAlignment.center,
            children:[
              Icon(
                Icons.theater_comedy,
                size:100,
                color:Colors.white,
              ),
              SizedBox(height:24),
              Text(
                'Bluff Master',
                style:TextStyle(
                  fontSize:32,
                  fontWeight:FontWeight.bold,
                  color:Colors.white,
                ),
              ),
              SizedBox(height:8),
              Text(
                'The Ultimate Party Bluffing Game',
                style:TextStyle(
                  fontSize:20,
                  color:Colors.grey,
                ),
                textAlign:TextAlign.center,
              ),
              SizedBox(height: 48),
              if(_err!=null && _err!.isNotEmpty)
                Container(
                  padding:EdgeInsets.all(12),
                  margin:EdgeInsets.only(bottom: 16),
                  decoration:BoxDecoration(
                    color:Colors.red.shade900.withOpacity(0.3),
                    borderRadius:BorderRadius.circular(8),
                  ),
                  child:Text(_err!,style:TextStyle(color:Colors.white)),
                ),
              SizedBox(
                width:double.infinity,
                height: 50,
                child:ElevatedButton.icon(
                  onPressed: _loading ? null : _signInWithGoogle, 
                  icon:_loading ? SizedBox(
                    width:20,
                    height:20,
                    child:CircularProgressIndicator(strokeWidth: 2) 
                  ): Image.asset('assets/google-logo.jpg',height:24,width:24),                    label:Text('Continue with Google',style:TextStyle(fontSize:16)),
                  style:ElevatedButton.styleFrom(
                    backgroundColor:Colors.white,
                    foregroundColor:Colors.black,
                    shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(12)),
                  )
                ),
              ),
              SizedBox(height:16),
              SizedBox(
                width: double.infinity,
                height:50,
                child:OutlinedButton(
                  onPressed:_loading ? null : _signInAnonymously,
                  style:OutlinedButton.styleFrom(
                    side:BorderSide(color:Colors.white),
                    shape:RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child:Text('Play as Guest',style:TextStyle(fontSize:17)),
                )
              ),
              SizedBox(height:32),
              Text(
                 'Join rooms • Claim roles • Outsmart the Imposter',
                style: TextStyle(fontSize: 14, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ]
          )
        )
        )
      )
    );
  }
}