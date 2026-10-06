import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/socket_service.dart';
import '../services/firestore_service.dart';
import '../services/notification_service.dart';
import '../theme.dart';


class GameScreen extends StatefulWidget{
  const GameScreen({super.key});

  @override
  State<GameScreen> createState()=> _GameScreenState();
}

class _GameScreenState extends State<GameScreen>{
  
  final SocketService _socket = SocketService.instance;
  final TextEditingController _clueController = TextEditingController();

  String _phase = 'word-reveal';
  String? _myWord;
  bool?  _isImposter;
  int _timer=0;
  List<dynamic> _clues = [];
  List<dynamic> _players = [];
  bool _hasVoted = false;
  bool _hasClued = false;
  Map? _result;

  String get _playerName{
    final user = FirebaseAuth.instance.currentUser;
    return user?.isAnonymous==true?"Guest":(user?.displayName ?? user?.email??"Player").toString();
  }

  @override
  void initState(){
    super.initState();
    _socket.connect();
    _setupListeners();
    final saved = SocketService.instance.currentPlayers;
    if(saved!=null) _players=saved;
    final role = SocketService.instance.lastRole;
    if(role!=null){
      _myWord = role['word'];
      _isImposter = role['isImposter'];
    }
  }



  void _setupListeners(){
    _socket.onRoleAssigned((data){
      if(!mounted) return;
      setState((){
        _myWord = data['word'];
        _isImposter = data['isImposter'];
      });
    });

    _socket.onPhaseChange((data){
      if(!mounted) return;
      setState((){
        _phase = data['phase'];
        if(data['timer']!=null) _timer = data['timer'];
        if(data['phase']=='clue') _clueController.clear();
        if(data['phase']=='voting') _hasVoted = false;
      });
    });

    _socket.onClueSubmitted((data){
      if(!mounted) return;
      setState(()=>_clues=data);
      });

    _socket.onTimerTick((data){
      if(!mounted) return;
      setState(()=>_timer=data);
    });

    _socket.onVotesUpdated((data){
      if(!mounted) return;
      setState(()=>_hasVoted = data['hasVoted']==true);
    });

    _socket.onRoundResults((data){
      if(!mounted) return;
      setState((){
        _result = data;
        _phase = 'results';
      });
      _onResults(data);
    });

    _socket.onRoomReset((data){
      if(!mounted) return;
      setState((){
        _myWord = null;
        _isImposter = null;
        _clues=[];
        _result=null;
        _hasClued = false;
        _hasVoted = false;
        _players=data['players'] as List;
      });
      if(Navigator.canPop(context)) Navigator.pop(context);
    });

    _socket.onPlayersUpdated((data){
      if(!mounted) return;
      setState(()=>_players=data);
    });
  }

  bool _saved = false;

  // Saves the finished game to Firebase and shows a device notification.
  void _onResults(Map data){
    if(_saved) return;
    _saved = true;
    final teamWon = data['winner']=='team';
    final won = _isImposter==true ? !teamWon : teamWon;
    FirestoreService.instance.saveGameResult(
      roomCode: SocketService.instance.roomCode ?? '',
      wasImposter: _isImposter==true,
      won: won,
      imposterName: (data['imposterName'] ?? '').toString(),
      teamWord: (data['teamWord'] ?? '').toString(),
      imposterWord: (data['imposterWord'] ?? '').toString(),
    ).catchError((Object error) {
      debugPrint('Could not save game history to Firestore: $error');
    });
    NotificationService.instance.show(
      won ? 'You won!' : 'You lost',
      teamWon ? 'The team caught the imposter.' : 'The imposter got away.',
    );
  }

  void _submitClue(){
    final clue = _clueController.text.trim();
    if(clue.isEmpty || _hasClued) return;
    _hasClued = true;
    _socket.submitClue(clue,_playerName);
    _clueController.clear();
  }

  void _submitVote(String playerid){
    if(_hasVoted) return;
    _hasVoted = true;
    _socket.submitVote(playerid);
  }

  @override
  void dispose(){
    _clueController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context){
    return Scaffold(
      backgroundColor:kBg,
      appBar:AppBar(
        title:Text('Bluff Master'),
        automaticallyImplyLeading:false,
      ),
      body:ResponsiveBody(maxWidth:600,child:_buildPhase()),
    );
  }

  Widget _buildPhase(){
    switch (_phase){
      case 'word-reveal': return _buildWordReveal();
      case 'clue': return _buildCluePhase();
      case 'voting': return _buildVoting();
      case 'results': return _buildResults();
      default:
        return Center(child:CircularProgressIndicator.adaptive());
    }
  }

  Widget _buildWordReveal(){
    return Center(
      child:Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children:[
          Icon(
            _isImposter ==true ? Icons.theater_comedy : Icons.group,
            size:100,
            color:_isImposter==true ? Colors.red:Colors.green, 
          ),
          SizedBox(height:24),
          Text(
            _isImposter==true ? "You're Imposter" : "You're on the TEAM",
            style:TextStyle(fontSize:28,fontWeight:FontWeight.bold,color:Colors.white),
            textAlign:TextAlign.center, 
          ),
          SizedBox(height:16),
          Text(
            _isImposter==true
                ? 'Everyone else knows the real word.\nYou must bluff!'
                : 'Everyone has the same word.\nFind the imposter!',
            style:TextStyle(color:Colors.grey,fontSize:16),
            textAlign:TextAlign.center,
          ),
          SizedBox(height:32),
          Container(
            padding:EdgeInsets.all(32),
            decoration:BoxDecoration(
              color:Colors.grey.shade900,
              borderRadius:BorderRadius.circular(16),
              border:Border.all(
                color:_isImposter==true ? Colors.red:Colors.green,
                width:2,
              ),
            ),
            child:Column(
              children:[
                Text('YOUR SECRET WORD',style:TextStyle(color:Colors.grey,fontSize:14,letterSpacing:2)),
                SizedBox(height:8),
                Text(
                  _myWord ?? '???',
                  style:TextStyle(
                    fontSize:32,
                    fontWeight:FontWeight.bold,color:Colors.white,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height:24),
          Text('Waiting for clue phase...', style:TextStyle(color:Colors.grey))
        ],
      ),
    );
  }

  Widget _buildCluePhase(){
    return Column(
      children:[
        _buildTimerBar(),
        Expanded(
          child:ListView.builder(
            padding:EdgeInsets.all(16),
            itemCount:_clues.length,
            itemBuilder:(context,index){
              final clue = _clues[index];
              final isMe = clue['playerId'] == _socket.playerId;
              return Card(
                margin:EdgeInsets.only(bottom:8),
                color:isMe ? Colors.deepPurple:Colors.grey.shade900,
                child:ListTile(
                  leading:CircleAvatar(
                    backgroundColor:Colors.deepPurple,
                    child:Text(
                      (clue['playerName'] as String)[0].toUpperCase(),
                      style:TextStyle(
                        color:Colors.white
                      ),
                    ),
                  ),
                  title:Text(
                    '${clue["playerName"]} ${isMe? ' (You)':''}',
                    style:TextStyle(color:Colors.white),
                  ),
                  subtitle:Text(
                    clue['clue'],
                    style:TextStyle(color:Colors.amber,fontSize:16),
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding:EdgeInsets.all(16),
          child:Row(
            children:[
              Expanded(
                child:TextField(
                  controller:_clueController,
                  enabled:!_hasClued,
                  style:TextStyle(color:Colors.white),
                  decoration:InputDecoration(
                    hintText:_hasClued ? 'Clue sent!' : 'Type one word clue...',
                    hintStyle:TextStyle(color:Colors.grey),
                    filled:true,
                    fillColor:Colors.grey.shade800,
                    border:OutlineInputBorder(borderRadius:BorderRadius.circular(12),borderSide:BorderSide.none),
                  ),
                  onSubmitted:(_)=>_submitClue(),
                ),
              ),
              SizedBox(width:8),
              ElevatedButton(
                onPressed:_hasClued?null:_submitClue,
                child:Text("Send"),
              )
            ]
          )
        )
      ],
    );
  }

  Widget _buildVoting(){
    return Column(
      children:[
        _buildTimerBar(),
        Padding(
          padding:EdgeInsets.all(16),
          child:Container(
            padding:EdgeInsets.all(16),
            decoration:BoxDecoration(
              color:Colors.red.shade900,
              borderRadius: BorderRadius.circular(12),
              border:Border.all(color:Colors.red),
            ),
            child:Text(
              _hasVoted
              ? 'Vote Submitted! Waiting for others...'
              :'Who do you think is the Imposter?',
              textAlign:TextAlign.center,
              style:TextStyle(fontSize:18,fontWeight:FontWeight.bold,color:Colors.white),
            ),
          ),
        ),
        Expanded(
          child:ListView.builder(
            padding:EdgeInsets.all(16),
            itemCount:_players.length,
            itemBuilder:(context,index){
              final player = _players[index];
              final isMe = player['id'] ==_socket.playerId;
              return Card(
                margin:EdgeInsets.only(bottom:8),
                color:Colors.grey.shade800,
                child:ListTile(
                  leading:CircleAvatar(
                    backgroundColor:Colors.deepPurple,
                    child:Text(
                      (player['name'] as String)[0].toUpperCase(),
                      style:TextStyle(color:Colors.white),
                    ),
                  ),
                  title:Text(
                    '${player['name']}${isMe?' (You)':''}',
                    style:TextStyle(color:Colors.white),
                  ),
                  trailing:Icon(
                    Icons.person_search,color:Colors.red,
                  ),
                  onTap:(){
                    if (!_hasVoted) _submitVote(player['id']);
                  }
                ),
              );
            }
          )
        )
      ],
    );
  }


  Widget _buildResults(){
    final winner = _result?['winner'];
    final imposterName = _result?['imposterName'];
    final teamWon = winner=='team';
    return Center(
      child:Column(
        mainAxisAlignment:MainAxisAlignment.center,
        children:[
          Icon(
            teamWon ? Icons.emoji_events:Icons.sentiment_very_dissatisfied,
            size:100,
            color:teamWon ? Colors.green:Colors.red,
          ),
          SizedBox(height:24),
          Text(
            teamWon ? 'TEAM WINS!': 'IMPOSTER WINS!',
            style:TextStyle(fontSize:36,fontWeight:FontWeight.bold,color : teamWon ? Colors.green:Colors.red),
          ),
          SizedBox(height:16),
          Container(
            padding:EdgeInsets.all(24),
            decoration:BoxDecoration(
              color:Colors.grey.shade900,
              borderRadius:BorderRadius.circular(16),
            ),
            child:Column(
              children:[
                Text('The Imposter was:',style:TextStyle(color:Colors.grey)),
                SizedBox(height:8),
                Text(
                  imposterName ?? '???',
                  style:TextStyle(fontSize:28,fontWeight:FontWeight.bold,color:Colors.white),
                ),
                SizedBox(height:16),
                Row(
                  mainAxisAlignment:MainAxisAlignment.center,
                  children:[
                    Column(
                      children:[
                        Text('Team Word',style:TextStyle(color:Colors.grey,fontSize:12)),
                        Text(_result?['teamWord'] ?? '???',style:TextStyle(fontSize:20,fontWeight:FontWeight.bold,color:Colors.green)),
                      ],
                    ),
                    SizedBox(width:32),
                    Column(
                      children:[
                        Text('Imposter Word',style:TextStyle(color:Colors.grey,fontSize:12)),
                        Text(_result?['imposterWord'] ?? '???',style:TextStyle(fontSize:20,fontWeight:FontWeight.bold,color:Colors.red))
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height:32),
          Text('New round Starting soon...',style:TextStyle(color:Colors.grey)),
          SizedBox(height:16),
          Padding(
            padding:EdgeInsets.symmetric(horizontal:32),
            child:ElevatedButton.icon(
              icon:Icon(Icons.meeting_room),
              label:Text('Back to Lobby'),
              onPressed:()=>Navigator.pop(context),
            ),
          ),
        ]
      )
    );
  }

  Widget _buildTimerBar(){
    return Container(
      width:double.infinity,
      padding:EdgeInsets.symmetric(horizontal:16,vertical:12),
      color:Colors.deepPurple.shade900,
      child:Row(
        children:[
          Icon(Icons.timer,color:Colors.amber),
          SizedBox(width:8),
          Text(
            '${_timer.toString().padLeft(2,'0')}s',
            style:TextStyle(fontSize:20,fontWeight:FontWeight.bold,color:Colors.white),
          ),
        ],
      ),
    );
  }




}
