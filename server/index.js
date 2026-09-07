const express  = require('express');
const http = require('http');
const {Server} = require('socket.io');
const cors = require('cors');

const app = express();
app.use(cors());
const server = http.createServer(app);
const io = new Server(server,{cors:{origin:"*"}});


const WORD_PAIRS = [
  ["Pizza","Oven"],["Dog","Cat"],["Sun","Moon"],
  ["Coffee","Tea"],["Beach","Pool"],["Car","Bike"],
  ["Book","Pen"],["Ice","Snow"],["Bird","Fish"],
  ["King","Queen"],["Gold","Silver"],["Fire","Smoke"],
];


const rooms = new Map();

function genCode(){
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
  let c = ''; 
  for (let i=0;i<6;i++) 
    c+=chars[Math.floor(Math.random()*chars.length)];
  return rooms.has(c) ? genCode():c;
}

function getRoomBySocket(socketId){
  for(const room of rooms.values()){
    if(room.players.some(p=>p.id==socketId )) return room;
  }
  return null;
}

function startCluePhase(room){
  room.phase='clue';
  room.clues=[];
  room.timer=60;
  io.to(room.id).emit('phase_change',{phase:'voting',timer:room.timer});
  room.timerInterval = setInterval(()=>{
    room.timer--;
    io.to(room.id).emit('timer_tick',room.timer);
    if(room.timer<=0){
      clearInterval(room.timerInterval);
      startVotingPhase(room);
    }
  },1000);
}

function startVotingPhase(room){
  room.status='voting';
  room.votes={};
  room.timer=60;
  io.to(room.id).emit('phase_change',{phase:'voting',timer:room.timer});
  io.to(room.id).emit('players_updated',room.players);
  room.timerInterval = setInterval(()=>{
    room.timer--;
    if(room.timer<=0){
      clearInterval(room.timerInterval);
      endRound(room);
    }
  });
}

function endRound(room){
  clearInterval(room.timerInterval);
  room.phase='results';
  const voteCounts={};
  room.players.forEach(p=>voteCounts[p.id]=0);
  Object.values(room.votes).forEach(votedId=>{
    if(voteCounts[votedId]!=null) voteCounts[votedId]++;
  });
  let maxVotes=0,mostVoted=null,ties=[];
  for(const [pid,count] of Object.entries(voteCounts)){
    if(count>maxVotes) {maxVotes=count;mostVoted=pid;ties=[pid];}
    else if(count==maxVotes){ties.push(pid);}
  }
  if(ties.length>1) mostVoted= ties[Math.floor(Math.random()*ties.length)];
  imposterCaught = mostVoted==room.imposterId;
  winner = imposterCaught?'team':'imposter';
  io.to(room.id).emit('round_results',{
    imposterId:room.imposterId,
    imposterName:room.players.find(p=>p.id==imposterId)?.name,
    mostVotedId:mostVoted,
    mostVotedName:room.players.find(p=>p.id==mostVoted)?.name,
    voteCounts,winner,
    teamWord:room.teamWord,
    imposterWord:room.imposterWord,
  });
  setTimeout(()=>resetToLobby(room),10000);
}

function resetToLobby(room){
  room.phase='lobby';
  room.votes={};
  room.clues=[];
  room.imposter=null;
  room.players.forEach(p=>{p.isReady=false;delete p.hasGivenClue;});
  const pair=WORD_PAIRS[Math.floor(Math.random()*WORD_PAIRS.length)];
  room.teamWord=pair[0];
  room.imposterWord=pair[1];
  io.to(room.id).emit('room_reset',room);
  io.to(room.id).emit('players_updated',room.players);
}

// Think of this as: "every time a new phone opens the app, run this block for them". Everything inside is per-client — the socket variable is that one phone's private line, and socket.id is its unique ID. All the socket.on(...) handlers below register what that client can ask the server to do.
io.on('connection',(socket)=>{
  // fires up whenever a new client establishes a web socket conn with server . here 'connection' is a event name triggered when a handshake succeeds
  console.log('connected',socket.id);

    // here we listen to an event as it is server side, the event here is create_room and as soon as the event happens Socket.io calls the callback which creates a room ,which is a js object about game room
  socket.on('create_room',({playerName})=>{
    const code = genCode();
    const pair = WORD_PAIRS[Math.floor(Math.random()*WORD_PAIRS.length)];
    const room = {
      code,hostId:socket.id,
      players:[{id:socket.id,name:playerName,isReady:false}],
      phase:'lobby',
      teamWord:pair[0],imposterWord:pair[1],
      imposterId:null,
      votes:{},
      clues:{},
      timer:0,
      timerInterval:null,
    };
    rooms.set(code,room);
    // as rooms is a Map it stores the code:room as a key value pair
    socket.join(code), 
    // After socket.join(code), that socket belongs to the Socket.IO room identified by that code.
    io.to(code).emit('room_created',room);
    // it broadcasts the 'room_created' event and its room data exclusively to all sockets(users) that have joined the room named code
    // here io.to(code) creates a virtual channel so when brodacasted it doesn't go out and interfer with other channels

    console.log('room created',code);
   });
  
   socket.on('join_room',({roomId,playerName})=>{
    const room = rooms.get(roomId.toUpperCase());
    if(!room) return socket.emit('error',{message:'Room not found'});
    if(room.players.length>=10) return socket.emit("error",{message:'Room already full'});
    if(room.phase!='lobby') return socket.emit('error',{message:'Game Already started'});
    room.players.push({id:socket.id,name:playerName,isReady:false});
    socket.join(room.id);
    io.to(room.id).emit('players_updated',room.players);
   });

  socket.on('toogle_ready',()=>{
    const room = getRoomBySocket(socket.id);
    if(room && room.phase=='lobby'){
      const p = room.players.find(x=>x.id==socket.id);
      if(p) {
        p.isReady = !p.isReady ;
        io.to(room.id).emit('players_updated',room.players);
      }
    }
  });

  socket.on('start_game',()=>{
    const room = getRoomBySocket(socket.id);
    if(!room || room.hostId != socket.id) return;
    if(room.players.length<2) return socket.emit('error',{message:'Need at least 2 players'});

    const idx = Math.floor(Math.random()*room.players.length);
    room.imposterId = room.players[idx];
    room.players.forEach(p=>{
      const isImp=p.id==room.imposterId;
      io.to(p.id).emit('role_assigned',{isImposter:isImp,word:isImp?room.imposterWord : room.teamWord});
    });
    io.to(room.id).emit('phase_change',{phase:'word-reveal',timer:5});
    setTimeout(()=>startCluePhase(room),5000);
  });

  socket.on('submit_clue',({clue,playerName})=>{
    const room = getRoomBySocket(socket.id);
    if(!room || room.phase!=='clue') return;
    const player=room.players.find(p=>p.id===socket.id);
    if(!player||player.hasGivenClue) return;
    player.hasGivenClue=true;
    room.clues.push({playerId:socket.id,playerName,clue});
    io.to(room.id).emit('clue_submitted',room.clues);
  })

  socket.on('submit_vote',({votedPlayerId})=>{
    const room=getRoomBySocket(socket.id);
    if(!room||room.phase!=='voting') return;
    if(room.votes[socket.id]) return;
    room.votes[socket.id]=votedPlayerId;
    io.to(room.id).emit('votes_updated',{
      votesCast:Object.keys(room.votes).length,
      totalPlayers:room.players.length,
      hasVoted:true,
    });
    if(Object.keys(room.votes).length===room.players.length){
      endRound(room);
    }
  });


  socket.on('disconnect',()=>{
    console.log('disconnected',socket.id);
    for(const [code,room] of rooms){
      room.players = room.players.filter(p=>p.id != socket.id);
      if(room.players.length===0) rooms.delete(code);
      else io.to(code).emit('players_updated',room.players);
    }
  });


})

server.listen(3000,()=> console.log('Server running on http://localhost:3000'));