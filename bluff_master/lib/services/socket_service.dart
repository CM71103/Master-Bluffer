import 'package:socket_io_client/socket_io_client.dart' as IO;

class SocketService{
  // Singleton - one socket connection for the whole app
  SocketService._internal();
  // to restrict the use of socket to one instance 
  static final SocketService instance =  SocketService._internal();
  static const String serverUrl = 'http://localhost:3000';

  IO.Socket? _socket;

  bool get isConnected => _socket?.connected ?? false;
  String? get playerId => _socket?.id;
   // we use getter when we want to access method like a variable 
   // becuase upon keeping getter we are askign dart to recalculate the value when accessing 

  void connect(){
    if(isConnected) return;

    _socket = IO.io(serverUrl,<String,dynamic>{
      'transports':['polling','websocket'],
    });
    // this creates the socket instance with backend url as serverUrl, here transports tell how to connect to server
    // i)polling: Client sends http req again and again every few secs for new data ,slow more usage 
    // ii) websocket - one single permanent connection stays open . server can push data instantly

    _socket!.onConnect((_)=>print('Socket connected: ${_socket!.id}'));
    _socket!.onDisconnect((_)=>print('Socket disconnected'));
    _socket!.on('connect_error',(data)=>print('Connect error: $data'));
  }

  void disconnect()=>_socket?.disconnect();
  
  //client->server Actions
  
  void createRoom(String playerName){
    _socket?.emit('create_room',{'playerName':playerName});
  }
  // here string used is create_room so on server(node.js) also must listen with same string
  
  void joinRoom(String roomCode,String playerName){
    _socket?.emit('join_room',{'roomId':roomCode,"playerName":playerName});
  }

  void toggleReady(){
    print('EMIT toggle_ready');
    _socket?.emit('toggle_ready');
  }

  void startGame()=>_socket?.emit('start_game');

//---------------------------------------------------------------

  //Event listeners

// it is on the receiving side - it listens for a server event and forwards the data to your UI thr callback 
// here Function(Map) cb - it is a callback function which we pass and accepts a Map . Here .on() registers a listener on the Socket
// (data)=>cb(data as Map) - when event arrives socket gives you data 
  void onRoomCreated(Function(Map) cb){
    _socket?.on('room_created',(data)=>cb(data as Map));
  }

  void onPlayersUpdated(Function(List) cb){
    _socket?.on('players_updated',(data){
      print('RECEIVED players_updated: $data');
      cb(data as List);
    });
  }

  void onPhaseChange(Function(Map) cb){
    _socket?.on('phase_change',(data)=>cb(data as Map));
  }

  void onPlayerJoined(Function(Map) cb){
    _socket?.on('player_joined',(data)=>cb(data as Map));
  }

  void onError(Function(Map) cb){
    _socket?.on('error',(data)=>cb(data as Map));
  }

  void onRoleAssigned(Function(Map) cb){
    _socket?.on('role_assigned',(data)=>cb(data as Map));
  }


  void submitClue(String clue,String playerName){
    _socket?.emit('submit_clue',{'clue':clue,'playerName':playerName});
  }

  void submitVote(String votedPlayerId){
    _socket?.emit('submit_vote',{'votedPlayerId':votedPlayerId});
  }


}