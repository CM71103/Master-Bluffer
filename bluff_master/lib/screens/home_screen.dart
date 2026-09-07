import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HomeScreen extends StatelessWidget{
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context){
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar:AppBar(
        title:Text('Bluff Master'),
        backgroundColor:Color(0xFF1A1A2E),
        foregroundColor: Colors.white,
        actions:[
          IconButton(
            icon:Icon(Icons.logout),
            onPressed:()async{
              await FirebaseAuth.instance.signOut();
              if(context.mounted){
                Navigator.pushNamedAndRemoveUntil(context,'/login',(route)=>false);
                // it navigates to a named route then pops routes until a predicate is satisfied , here as as the predicate is route=>false all routes before it get removed from stack hence it cannot be moved backward
              }
            }
          )
        ]
      ),
      body:Center(
        child:Column(
          mainAxisAlignment:MainAxisAlignment.center,
          children:[
            Icon(Icons.verified_user,size:80,color:Colors.green),
            SizedBox(height: 16),
            Text(
              user?.isAnonymous == true
              ? 'Welcome Guest'
              :'Welcome, ${user?.displayName ?? user?.email ?? 'Player'}',
              // here user.email is fallbalck for user.dispayname 
              style:TextStyle(fontSize:20),
              textAlign:TextAlign.center,
            ),
            SizedBox(height:32),
            ElevatedButton(
              onPressed:(){
                Navigator.pushNamed(context,'/lobby');
              },
              child:Text("Go To Lobby"),
            )
          ]
        )
      )
    );

  }

}
  


