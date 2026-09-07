import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/socket_service.dart';

class LobbyScreen extends StatefulWidget{

  const LobbyScreen({super.key});

  @override
  State<LobbyScreen> createState()=> _LobbyScreenState();

}

class _LobbyScreenState extends State<LobbyScreen>{

  final SocketService _socket = SocketService.instance;
  final TextEditingController _codeController = TextEditingController();

  String? _roomCode;
  List<dynamic> _players=[];
  bool _isHost = false;
  bool _joined = false;
  String? _error ;

  // Your display name from auth
  String get _playerName{
    final user = FirebaseAuth.instance.currentUser;
    return user?.isAnonymous == true ? 'Guest':(user?.displayName ?? user?.email ??'Player').toString();
  }

  @override
  void initState(){
    super.initState();
    _socket.connect();
    _setupListeners();
  }

  void _setupListeners(){
    _socket.onRoomCreated((data){
      setState((){
        _roomCode = data['code'] as String;
        _isHost=true;
        _joined = true;
        _players = (data['players'] as List).toList();
        _error=null;
      });
    });

    _socket.onPlayersUpdated((data){
      setState((){
        _players=data;
        _joined=true;
      });
    });

    _socket.onError((data){
      setState(()=> _error = (data['message'] as String?) ?? 'Something went wrong');
    });
  }

  void _createRoom(){
    setState(()=>_error=null);
    _socket.createRoom(_playerName);
  }

  void _joinRoom(){
    final code = _codeController.text.trim().toUpperCase();
    if(code.length !=6){
      setState(()=>_error = 'Room code must be 6 characters');
      return;
    }
    setState(()=>_error=null);
    _socket.joinRoom(code,_playerName);
  }

  void _toggleReady(){
    print('BUTTON TAPPED - calling socket.toggleReady()');
    _socket.toggleReady();
  }

  void _startGame() => _socket.startGame();

  @override
  void dispose(){
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context){
    return Scaffold(
      backgroundColor: Color(0xFF1A1A2E),
      appBar:AppBar(
        title:Text('Lobby'),
        backgroundColor: Color(0xFF1A1A2E),
        foregroundColor: Colors.white,
      ),
      body:Padding(
        padding:EdgeInsets.all(16),
        child:Column(
          children:[
            if(!_joined) ...[
              Card(
                color:Colors.grey.shade900,
                child:Padding(
                  padding:EdgeInsets.all(16),
                  child:Column(
                    children:[
                      Text('Playing as: $_playerName',style:TextStyle(color:Colors.grey)),
                      SizedBox(height:16),
                      Row(
                        children:[
                          Expanded(
                            child:TextField(
                              controller:_codeController,
                              style:TextStyle(color:Colors.white,letterSpacing:4),
                              decoration:InputDecoration(
                                labelText:'Room Code',
                                labelStyle:TextStyle(color:Colors.grey),
                                prefixIcon:Icon(Icons.key,color:Colors.grey),
                              ),
                            ),
                          ),
                          SizedBox(width:8),
                          ElevatedButton(
                            onPressed:_joinRoom,
                            child:Text('Join'),
                          )
                        ]
                      ),
                      SizedBox(height:12),
                      SizedBox(
                        width:double.infinity,
                        child:OutlinedButton(
                          onPressed:_createRoom,
                          style:OutlinedButton.styleFrom(
                            side:BorderSide(color:Colors.white54),
                          ),
                          child:Text('Create New Room'),
                        )
                      ),
                      if(_error !=null)
                        Padding(
                          padding:EdgeInsets.only(top:8),
                          child:Text(_error!,style:TextStyle(color:Colors.red)),
                        ),
                    ],
                  ),
                ),
              ),
            ],
            if(_roomCode !=null)
              Container(
                width:double.infinity,
                margin:EdgeInsets.only(top:16),
                padding:EdgeInsets.all(16),
                decoration:BoxDecoration(
                  color:Colors.deepPurple.shade900,
                  borderRadius:BorderRadius.circular(12),
                ),
                child:Column(
                  children:[
                    Text('Room Code',style:TextStyle(color:Colors.grey)),
                    Text(
                      _roomCode!,
                      style:TextStyle(
                        fontSize:32,
                        fontWeight:FontWeight.bold,
                        color:Colors.white,
                        letterSpacing:6,
                      )
                    ),
                    Text(
                      'Share this with friends',
                      style:TextStyle(color:Colors.grey,fontSize:12),
                    )
                  ]
                )
              ),
              SizedBox(height:16),
              if(_players.isNotEmpty)
                Expanded(
                  child:ListView.builder(
                    itemCount: _players.length,
                    itemBuilder:(context,index){
                      final player = _players[index];
                      final isMe = player['id']==_socket.playerId;
                      final isReady = player['isReady']==true;
                      return Card(
                        color:Colors.grey.shade900,
                        child:ListTile(
                          leading:CircleAvatar(
                            backgroundColor:isReady ? Colors.green:Colors.grey,
                            child:Text(
                              (player['name'] as String)[0].toUpperCase(),
                              style:TextStyle(color:Colors.white),
                            ),
                          ),
                          title:Text(
                            '${player['name']}${isMe ? ' (You)':''}',
                            style:TextStyle(color:Colors.white),
                          ),
                          subtitle:Text(
                            isReady ? 'Ready':'Not Ready',
                            style:TextStyle(
                              color:isReady ? Colors.green : Colors.grey,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
            if(_joined)
              Padding(
                padding:EdgeInsets.only(bottom:16,top:8),
                child:Column(
                  children:[
                    SizedBox(
                      width:double.infinity,
                      child:OutlinedButton.icon(
                        style:OutlinedButton.styleFrom(
                          side:BorderSide(color:Colors.white54),
                        ),
                        icon:Icon(
                          _players.any((p)=>p['id']==_socket.playerId && p['isReady']==true)?Icons.check_circle : Icons.circle_outlined,
                          color:Colors.white,
                        ),
                        label:Text(
                          _players.any((p)=>p['id']==_socket.playerId && p['isReady']==true)
                              ? 'Not Ready'
                              : 'I\'m Ready',
                          style:TextStyle(color:Colors.white),
                        ),
                        onPressed:_toggleReady,
                      ),
                    ),
                    if(_isHost)
                      Padding(
                        padding:EdgeInsets.only(top:8),
                        child:SizedBox(
                          width:double.infinity,
                          child:ElevatedButton(
                            style:ElevatedButton.styleFrom(
                              backgroundColor:Colors.deepPurple,
                              disabledBackgroundColor: Colors.grey.shade700,
                            ),
                            onPressed: _players.length>=2 ? _startGame : null, 
                            child: Text(
                              'Start Game',
                              style:TextStyle(fontSize:18),
                            )
                          )
                        )
                      )
                  ]
                )
              )
          ]
        )
      )
    );
  }



}