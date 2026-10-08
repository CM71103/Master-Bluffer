const express  = require('express');
const http = require('http');
const {Server} = require('socket.io');
const cors = require('cors');
require('dotenv').config();
const mongo = require('./db');

const app = express();
app.use(cors());
// ---- REST API (MongoDB) used by the Flutter app ----
app.get('/health',(req,res)=>res.json({ok:true,mongo:mongo.isConnected()}));
const safe = (fn)=>async(req,res)=>{
  try{ res.json(await fn(req)); }
  catch(e){ console.log('api error',e.message); res.status(500).json({error:'server error'}); }
};
app.get('/api/leaderboard',safe(()=>mongo.leaderboard()));
app.get('/api/recent',safe(()=>mongo.recentGames()));
app.get('/api/history/:uid',safe((req)=>mongo.history(req.params.uid)));
app.delete('/api/history/:id/:uid',safe(async(req)=>({ok:await mongo.deleteGame(req.params.id,req.params.uid)})));

const server = http.createServer(app);
const io = new Server(server,{cors:{origin:"*"}});


const WORD_PAIRS = [
  ["Pizza","Oven"],["Dog","Cat"],["Sun","Moon"],
  ["Coffee","Tea"],["Beach","Pool"],["Car","Bike"],
  ["Book","Pen"],["Ice","Snow"],["Bird","Fish"],
  ["King","Queen"],["Gold","Silver"],["Fire","Smoke"],
];


const rooms = new Map();

// Round-flow timings (ms).
const WORD_REVEAL_MS = 5000;       // players study their secret word
const GAME_OVER_DELAY_MS = 15000;  // final scoreboard before returning to the lobby

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

// Starts the game: fresh words, a new imposter, then the word-reveal countdown.
// Called once when the host starts the game. The word and imposter stay the
// same for every round — only the clues accumulate.
async function startGame(room){
  if(room.players.length<2) return;
  const pair=await mongo.randomWordPair();
  room.teamWord=pair[0];
  room.imposterWord=pair[1];
  const idx=Math.floor(Math.random()*room.players.length);
  room.imposterId=room.players[idx].id;
  room.currentRound=1;
  room.votes={};
  room.clues=[];
  room.players.forEach(p=>{
    delete p.hasGivenClue;
    const isImp=p.id==room.imposterId;
    io.to(p.id).emit('role_assigned',{isImposter:isImp,word:isImp?room.imposterWord:room.teamWord});
  });
  io.to(room.id).emit('phase_change',{
    phase:'word-reveal',
    timer:Math.round(WORD_REVEAL_MS/1000),
    currentRound:room.currentRound,
    totalRounds:room.totalRounds,
  });
  setTimeout(()=>startCluePhase(room),WORD_REVEAL_MS);
}

// Starts a clue phase for the current round. Clues accumulate across rounds.
function startCluePhase(room){
  clearInterval(room.timerInterval);
  room.phase='clue';
  room.timer=60;
  room.players.forEach(p=>{delete p.hasGivenClue;});
  io.to(room.id).emit('phase_change',{phase:'clue',timer:room.timer,currentRound:room.currentRound,totalRounds:room.totalRounds});
  room.timerInterval = setInterval(()=>{
    room.timer--;
    io.to(room.id).emit('timer_tick',room.timer);
    if(room.timer<=0){
      clearInterval(room.timerInterval);
      afterCluePhase(room);
    }
  },1000);
}

// Called after a clue phase ends: advance to the next round, or start the
// final voting phase once every round has been played.
function afterCluePhase(room){
  if(room.currentRound >= room.totalRounds){
    startVotingPhase(room);
  } else {
    room.currentRound++;
    startCluePhase(room);
  }
}

// Starts the voting phase (called only after the final round's clue phase).
function startVotingPhase(room){
  clearInterval(room.timerInterval);
  room.phase='voting';
  room.votes={};
  room.timer=60;
  io.to(room.id).emit('phase_change',{phase:'voting',timer:room.timer,currentRound:room.currentRound,totalRounds:room.totalRounds});
  io.to(room.id).emit('players_updated',room.players);
  room.timerInterval = setInterval(()=>{
    room.timer--;
    io.to(room.id).emit('timer_tick',room.timer);
    if(room.timer<=0){
      clearInterval(room.timerInterval);
      endGame(room);
    }
  },1000);
}

// Ends the game after the final vote: show results, then reset to lobby.
function endGame(room){
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
  const imposterCaught = mostVoted==room.imposterId;
  const winner = imposterCaught?'team':'imposter';
  room.players.forEach(p=>{
    const wasImposter = p.id==room.imposterId;
    const won = wasImposter ? winner=='imposter' : winner=='team';
    if(won) room.scores[p.id] = (room.scores[p.id]||0) + 1;
  });

  const standings = room.players
    .map(p=>({name:p.name,score:room.scores[p.id]||0}))
    .sort((a,b)=>b.score-a.score);

  io.to(room.id).emit('round_results',{
    imposterId:room.imposterId,
    imposterName:room.players.find(p=>p.id==room.imposterId)?.name,
    mostVotedId:mostVoted,
    mostVotedName:room.players.find(p=>p.id==mostVoted)?.name,
    voteCounts,winner,
    teamWord:room.teamWord,
    imposterWord:room.imposterWord,
    currentRound:room.currentRound,
    totalRounds:room.totalRounds,
    isFinalRound:true,
    scores:standings,
  });
  mongo.saveGame({
    roomCode:room.code,
    winner,
    imposterName:room.players.find(p=>p.id==room.imposterId)?.name,
    teamWord:room.teamWord,
    imposterWord:room.imposterWord,
    round:room.totalRounds,
    totalRounds:room.totalRounds,
    players:room.players.map(p=>{
      const wasImposter = p.id==room.imposterId;
      return {uid:p.uid,name:p.name,wasImposter,won:wasImposter?winner=='imposter':winner=='team'};
    }),
  });

  io.to(room.id).emit('game_over',{scores:standings});
  setTimeout(()=>resetToLobby(room,true),GAME_OVER_DELAY_MS);
}

async function resetToLobby(room,gameFinished=false){
  clearInterval(room.timerInterval);
  room.phase='lobby';
  room.votes={};
  room.clues=[];
  room.imposterId=null;
  room.players.forEach(p=>{p.isReady=false;delete p.hasGivenClue;});
  // Only wipe the round counter and scores once the whole game is finished.
  if(gameFinished){
    room.currentRound=1;
    room.scores={};
  }
  const pair=await mongo.randomWordPair();
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
  socket.on('create_room',async({playerName,uid,rounds})=>{
    if(getRoomBySocket(socket.id)) return socket.emit('error',{message:'Leave your current room before creating another'});
    const code = genCode();
    const pair = await mongo.randomWordPair();
    const totalRounds = Math.max(1, Math.min(10, parseInt(rounds) || 1));
    const room = {
      id:code,
      code,hostId:socket.id,
      players:[{id:socket.id,uid:uid||null,name:playerName,isReady:false}],
      phase:'lobby',
      teamWord:pair[0],imposterWord:pair[1],
      imposterId:null,
      votes:{},
      clues:[],
      timer:0,
      timerInterval:null,
      totalRounds,
      currentRound:1,
      scores:{},
    };
    rooms.set(code,room);
    mongo.saveRoom(room);
    // as rooms is a Map it stores the code:room as a key value pair
    socket.join(code), 
    // After socket.join(code), that socket belongs to the Socket.IO room identified by that code.
    io.to(code).emit('room_created',room);
    // it broadcasts the 'room_created' event and its room data exclusively to all sockets(users) that have joined the room named code
    // here io.to(code) creates a virtual channel so when brodacasted it doesn't go out and interfer with other channels

    console.log('room created',code);
   });
  
   socket.on('join_room',({roomId,playerName,uid})=>{
    if(getRoomBySocket(socket.id)) return socket.emit('error',{message:'You are already in a room'});
    const room = rooms.get(String(roomId || '').toUpperCase());
    if(!room) return socket.emit('error',{message:'Room not found'});
    if(room.phase!='lobby') return socket.emit('error',{message:'Game Already started'});
    // UID is currently provided by the client and is NOT verified by Firebase Admin.
    // Use it only to prevent accidental duplicate seats, never as an authorization check.
    if(uid && room.players.some(p=>p.uid === uid)) {
      return socket.emit('error',{message:'This account is already in this room'});
    }
    if(room.players.length>=10) return socket.emit("error",{message:'Room already full'});
    room.players.push({id:socket.id,uid:uid||null,name:playerName,isReady:false});
    socket.join(room.code);
    socket.emit('room_joined',room);
    io.to(room.code).emit('players_updated',room.players);
   });

  socket.on('leave_room',()=>{
    for(const [code,room] of rooms){
      if(!room.players.some(p=>p.id==socket.id)) continue;
      room.players = room.players.filter(p=>p.id != socket.id);
      socket.leave(code);
      if(room.players.length===0){ clearInterval(room.timerInterval); rooms.delete(code); mongo.deleteRoom(code); }
      else{
        if(room.hostId==socket.id) room.hostId=room.players[0].id;
        io.to(code).emit('players_updated',room.players);
        io.to(code).emit('host_changed',{hostId:room.hostId});
      }
    }
  });

  socket.on('toggle_ready',()=>{
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
    if(room.phase!=='lobby') return socket.emit('error',{message:'A round is already in progress'});
    if(room.players.length<2) return socket.emit('error',{message:'Need at least 2 players'});
    if(room.currentRound > room.totalRounds) return socket.emit('error',{message:'All rounds completed'});

    startGame(room);
  });

  socket.on('submit_clue',({clue,playerName})=>{
    const room = getRoomBySocket(socket.id);
    if(!room || room.phase!=='clue') return;
    const player=room.players.find(p=>p.id===socket.id);
    if(!player||player.hasGivenClue) return;
    player.hasGivenClue=true;
    room.clues.push({playerId:socket.id,playerName,clue});
    io.to(room.id).emit('clue_submitted',room.clues);
    // Everyone has clued in: skip the rest of the timer and advance.
    if(room.players.length>0 && room.players.every(p=>p.hasGivenClue)){
      afterCluePhase(room);
    }
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
      endGame(room);
    }
  });


  socket.on('disconnect',()=>{
    console.log('disconnected',socket.id);
    for(const [code,room] of rooms){
      room.players = room.players.filter(p=>p.id != socket.id);
      if(room.players.length===0) { rooms.delete(code); mongo.deleteRoom(code); }
      else io.to(code).emit('players_updated',room.players);
    }
  });


})

const PORT = process.env.PORT || 3000;
mongo.connect().finally(()=>{
  server.listen(PORT,'0.0.0.0',()=> console.log('Server running on port '+PORT));
});
