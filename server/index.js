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

const MIN_PLAYERS = 3;          // players needed to start a game
const CLUE_SECONDS = 60;
const VOTE_SECONDS = 60;
const EARLY_END_SECONDS = 5;    // when everyone has answered, only this much time is left
const RESULT_SECONDS = 8;       // how long round results stay on screen


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

// What clients may see about a room. The room object itself holds timers and
// the secret words, so it must never be sent as it is.
function publicRoom(room){
  return {
    id:room.id,
    code:room.code,
    hostId:room.hostId,
    players:room.players,
    phase:room.phase,
    totalRounds:room.totalRounds,
    currentRound:room.currentRound,
  };
}

function stopTimer(room){
  clearInterval(room.timerInterval);
  room.timerInterval = null;
}

const isLive = (room)=> rooms.get(room.id)===room;

// Starts a new round: new word pair, new imposter, roles sent privately.
async function beginRound(room){
  if(!isLive(room)) return;
  if(room.players.length < MIN_PLAYERS){
    // too many players left to continue - finish the game with current scores
    return finishGame(room);
  }
  const pair = await mongo.randomWordPair();
  if(!isLive(room)) return;
  room.teamWord = pair[0];
  room.imposterWord = pair[1];
  room.clues = [];
  room.votes = {};
  room.players.forEach(p=>{ delete p.hasGivenClue; });
  const idx = Math.floor(Math.random()*room.players.length);
  room.imposterId = room.players[idx].id;
  room.phase = 'word-reveal';
  room.players.forEach(p=>{
    const isImp = p.id==room.imposterId;
    io.to(p.id).emit('role_assigned',{isImposter:isImp,word:isImp?room.imposterWord:room.teamWord});
  });
  io.to(room.id).emit('phase_change',{
    phase:'word-reveal',timer:5,
    currentRound:room.currentRound,totalRounds:room.totalRounds,
  });
  setTimeout(()=>{ if(isLive(room) && room.phase==='word-reveal') startCluePhase(room); },5000);
}

function startCluePhase(room){
  stopTimer(room);
  room.phase='clue';
  room.clues=[];
  room.cluesEarlyEnd=false;
  room.timer=CLUE_SECONDS;
  io.to(room.id).emit('phase_change',{phase:'clue',timer:room.timer});
  room.timerInterval = setInterval(()=>{
    room.timer--;
    io.to(room.id).emit('timer_tick',room.timer);
    if(room.timer<=0) startVotingPhase(room);
  },1000);
}

// Everyone has given a clue -> cut the remaining clue time down to 5 seconds.
function checkCluesComplete(room){
  if(room.phase!=='clue' || room.cluesEarlyEnd) return;
  if(room.players.length>0 && room.players.every(p=>p.hasGivenClue)){
    room.cluesEarlyEnd=true;
    if(room.timer>EARLY_END_SECONDS){
      room.timer=EARLY_END_SECONDS;
      io.to(room.id).emit('timer_tick',room.timer);
    }
  }
}

function startVotingPhase(room){
  if(room.phase!=='clue') return;
  stopTimer(room);
  room.phase='voting';
  room.votes={};
  room.timer=VOTE_SECONDS;
  io.to(room.id).emit('phase_change',{phase:'voting',timer:room.timer});
  io.to(room.id).emit('players_updated',room.players);
  room.timerInterval = setInterval(()=>{
    room.timer--;
    io.to(room.id).emit('timer_tick',room.timer);
    if(room.timer<=0) endRound(room);
  },1000);
}

// Everyone voted -> show the result immediately.
function checkVotesComplete(room){
  if(room.phase!=='voting') return;
  const cast = room.players.filter(p=>room.votes[p.id]).length;
  if(room.players.length>0 && cast>=room.players.length) endRound(room);
}

function endRound(room){
  if(room.phase!=='voting') return;   // guards against a double call (last vote + timer)
  stopTimer(room);
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
  const finishedRound = room.currentRound;
  const isLastRound = finishedRound >= room.totalRounds;
  io.to(room.id).emit('round_results',{
    imposterId:room.imposterId,
    imposterName:room.players.find(p=>p.id==room.imposterId)?.name,
    mostVotedId:mostVoted,
    mostVotedName:room.players.find(p=>p.id==mostVoted)?.name,
    voteCounts,winner,
    teamWord:room.teamWord,
    imposterWord:room.imposterWord,
    round:finishedRound,
    totalRounds:room.totalRounds,
    isLastRound,
  });
  mongo.saveGame({
    roomCode:room.code,
    winner,
    imposterName:room.players.find(p=>p.id==room.imposterId)?.name,
    teamWord:room.teamWord,
    imposterWord:room.imposterWord,
    round:finishedRound,
    totalRounds:room.totalRounds,
    players:room.players.map(p=>{
      const wasImposter = p.id==room.imposterId;
      return {uid:p.uid,name:p.name,wasImposter,won:wasImposter?winner=='imposter':winner=='team'};
    }),
  });
  if(isLastRound){
    setTimeout(()=>{ if(isLive(room) && room.phase==='results') finishGame(room); },RESULT_SECONDS*1000);
  } else {
    room.currentRound++;
    // next round starts by itself - nobody has to return to the lobby
    setTimeout(()=>{ if(isLive(room) && room.phase==='results') beginRound(room); },RESULT_SECONDS*1000);
  }
}

function finishGame(room){
  stopTimer(room);
  room.phase='game-over';
  const finalScores = room.players.map(p=>({
    name:p.name,
    score:room.scores[p.id]||0,
  })).sort((a,b)=>b.score-a.score);
  io.to(room.id).emit('game_over',{scores:finalScores});
  setTimeout(()=>{ if(isLive(room)) resetToLobby(room); },15000);
}

function resetToLobby(room){
  stopTimer(room);
  room.phase='lobby';
  room.votes={};
  room.clues=[];
  room.imposterId=null;
  room.scores={};
  room.currentRound = 1;
  room.players.forEach(p=>{p.isReady=false;delete p.hasGivenClue;});
  io.to(room.id).emit('room_reset',publicRoom(room));
  io.to(room.id).emit('players_updated',room.players);
}

// Removes a player from whatever room they are in and keeps that room consistent.
function removePlayer(socket){
  for(const [code,room] of rooms){
    if(!room.players.some(p=>p.id==socket.id)) continue;
    room.players = room.players.filter(p=>p.id != socket.id);
    socket.leave(code);
    if(room.players.length===0){
      stopTimer(room); rooms.delete(code); mongo.deleteRoom(code);
      continue;
    }
    if(room.hostId==socket.id){
      room.hostId=room.players[0].id;
      io.to(code).emit('host_changed',{hostId:room.hostId});
    }
    io.to(code).emit('players_updated',room.players);
    // the leaver may have been the only one we were waiting for
    checkCluesComplete(room);
    checkVotesComplete(room);
  }
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
    io.to(code).emit('room_created',publicRoom(room));
    // it broadcasts the 'room_created' event and its room data exclusively to all sockets(users) that have joined the room named code
    // here io.to(code) creates a virtual channel so when brodacasted it doesn't go out and interfer with other channels

    console.log('room created',code,'rounds',totalRounds);
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
    socket.emit('room_joined',publicRoom(room));
    io.to(room.code).emit('players_updated',room.players);
   });

  socket.on('leave_room',()=>removePlayer(socket));

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
    if(room.phase!=='lobby') return;
    if(room.players.length<MIN_PLAYERS) return socket.emit('error',{message:`Need at least ${MIN_PLAYERS} players`});
    room.currentRound = 1;
    room.scores = {};
    beginRound(room);
  });

  socket.on('submit_clue',({clue,playerName})=>{
    const room = getRoomBySocket(socket.id);
    if(!room || room.phase!=='clue') return;
    const player=room.players.find(p=>p.id===socket.id);
    if(!player||player.hasGivenClue) return;
    player.hasGivenClue=true;
    room.clues.push({playerId:socket.id,playerName,clue});
    io.to(room.id).emit('clue_submitted',room.clues);
    checkCluesComplete(room);
  })

  socket.on('submit_vote',({votedPlayerId})=>{
    const room=getRoomBySocket(socket.id);
    if(!room||room.phase!=='voting') return;
    if(room.votes[socket.id]) return;
    room.votes[socket.id]=votedPlayerId;
    // Only the voter is told "you have voted". (It used to be sent to the whole
    // room, which locked every other player out after the first vote.)
    socket.emit('votes_updated',{
      votesCast:room.players.filter(p=>room.votes[p.id]).length,
      totalPlayers:room.players.length,
      hasVoted:true,
    });
    checkVotesComplete(room);
  });


  socket.on('disconnect',()=>{
    console.log('disconnected',socket.id);
    removePlayer(socket);
  });


})

const PORT = process.env.PORT || 3000;
mongo.connect().finally(()=>{
  server.listen(PORT,'0.0.0.0',()=> console.log('Server running on port '+PORT));
});
