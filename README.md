<div align="center">

# 🎭 Bluff Master

### Same room. Different words. One convincing liar.

A real-time multiplayer social deduction game built with Flutter and Socket.IO. Create a room, trade clues, read the room, and vote for the player whose word doesn't quite fit.

[![Flutter](https://img.shields.io/badge/Flutter-Dart-02569B?logo=flutter&logoColor=white)](https://flutter.dev/)
[![Node.js](https://img.shields.io/badge/Backend-Node.js-339933?logo=nodedotjs&logoColor=white)](https://nodejs.org/)
[![Socket.IO](https://img.shields.io/badge/Realtime-Socket.IO-010101?logo=socketdotio&logoColor=white)](https://socket.io/)
[![Firebase](https://img.shields.io/badge/Auth%20%26%20profiles-Firebase-FFCA28?logo=firebase&logoColor=black)](https://firebase.google.com/)
[![MongoDB](https://img.shields.io/badge/Game%20history-MongoDB-47A248?logo=mongodb&logoColor=white)](https://www.mongodb.com/)

[How it works](#-how-it-works) · [Features](#-features) · [Run locally](#-run-locally) · [Architecture](#-architecture)

</div>

---

## 🎲 How it works

1. **Create or join a room.** A host shares a six-letter room code. Two to ten players can join. The host chooses a category and 1 to 10 clue rounds.
2. **Read your secret word.** Most players get one word. One randomly chosen imposter gets a *related but different* word. Only that player sees their role.
3. **Give clues.** Each player submits one clue per round. Clues accumulate as the rounds progress. Make yours useful without giving away too much.
4. **Vote.** After the final clue round, everyone votes for the suspected imposter. Catch the imposter and the team wins. Otherwise, the imposter wins.
5. **See the reveal.** Results show the vote, both words, and the room standings before returning players to the lobby.

> **Example:** The team sees **Cake**. The imposter sees **Pastry**. Both words sound plausible until the clues start to diverge.

## ✨ Features

| | |
| --- | --- |
| 🎭 **Private roles** | Secret words and imposter identity are sent to each player individually, not included in lobby snapshots. |
| ⚡ **Live rooms** | Socket.IO synchronizes lobby state, clues, timers, votes, and results. |
| 🗂️ **Word categories** | Curated pairs for foods, football, animals, and places. Playable without MongoDB. |
| 🔐 **Multiple sign-in options** | Firebase Authentication supports email/password, Google, and guest sign-in when providers are enabled. |
| 📊 **Profiles and history** | Firestore stores user stats and saved results. MongoDB backs server-side history, recent games, and leaderboard endpoints when configured. |
| 🔔 **Local notifications** | Mobile device notifications for room and game events. Not supported on web. |

## 🚀 Run locally

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) with Dart **3.7.2 or newer** and a configured target device or emulator.
- [Node.js](https://nodejs.org/) **18 or newer** with npm.
- A [Firebase project](https://console.firebase.google.com/) configured for the platforms you plan to run. Enable the sign-in providers you want to use and configure Firestore access for your development environment. See [Firebase setup guide](bluff_master/FIREBASE_SETUP.md) for platform-specific steps. Regenerate `firebase_options.dart` with FlutterFire for your own project.
- **Optional:** MongoDB for persistent server-side game history, leaderboard, and recent games. Multiplayer and built-in word pairs work without it.

Clone the repository:

```bash
git clone https://github.com/CM71103/Master-Bluffer.git
cd Master-Bluffer
```

**Terminal 1: start the server**

```bash
cd server
npm ci
npm start
```

Server listens on `http://localhost:3000` by default. Check `http://localhost:3000/health`. A response like `{"ok":true,"mongo":false}` means the server is running without MongoDB.

To enable MongoDB, set `MONGODB_URI` in `server/.env` before starting the server. `MONGODB_DB` is optional and defaults to `bluff_master`. Never commit `.env` or a connection string.

```dotenv
MONGODB_URI=mongodb+srv://<user>:<password>@<cluster>/
MONGODB_DB=bluff_master
```

**Terminal 2: start the Flutter app**

```bash
cd bluff_master
flutter pub get
flutter run --dart-define=SERVER_URL=http://localhost:3000
```

For an **Android emulator**, replace `localhost` with `10.0.2.2`. For a **physical device**, use your computer's LAN IP and ensure the phone and server can reach each other. Platform network security settings may need adjustment for local HTTP. Without `SERVER_URL`, the app uses the hosted URL in [`config.dart`](bluff_master/lib/config.dart). Availability of that deployment is not guaranteed.

> **Firebase setup:** The checked-in `firebase_options.dart` belongs to this project's Firebase configuration. For your own Firebase project, run `flutterfire configure` from `bluff_master/` and supply the corresponding platform files. [Setup details →](bluff_master/FIREBASE_SETUP.md)

## 🧩 Architecture

```text
Master-Bluffer/
├── bluff_master/                Flutter client
│   ├── lib/screens/             Login, lobby, game, profile, leaderboard
│   ├── lib/services/            Socket, REST, Firestore, notifications
│   └── lib/config.dart          Server URL / dart-define override
└── server/                      Node.js + Express + Socket.IO
    ├── index.js                 Rooms, game phases, votes, REST routes
    ├── db.js                    Optional MongoDB persistence / fallback
    ├── word_bank.js             Built-in categorized word pairs
    └── render.yaml              Render deployment configuration
```

**Game state** lives in server memory and is broadcast through Socket.IO. **Firebase** handles client authentication and Firestore profile data. **MongoDB**, when connected, stores server-side game records and serves leaderboard, recent-game, and history APIs. A server restart ends active rooms. Server-side leaderboards and history return empty results without MongoDB.

### Backend endpoints

| Endpoint | Purpose |
| --- | --- |
| `GET /health` | Server and MongoDB connection status |
| `GET /api/leaderboard` | Player win totals |
| `GET /api/recent` | Recent completed games |
| `GET /api/history/:uid` | Game history for a supplied user ID |
| `DELETE /api/history/:id/:uid` | Remove a supplied user ID from a game record |

> **Development caveat:** Backend accepts client-supplied user IDs and does not verify Firebase tokens. Do not treat history endpoints as authenticated or expose personal game data through them without adding server-side authorization.

## ☁️ Deployment

[`server/render.yaml`](server/render.yaml) defines a Render web service with `server/` as its root, `npm ci` as its build command, `npm start` as its start command, and `/health` as its health check. Set `MONGODB_URI` in Render's environment if persistence is needed. Build the client with `--dart-define=SERVER_URL=https://<your-server>` to point at your own deployment. See [Render deployment notes](server/DEPLOY_RENDER.md). Check [`config.dart`](bluff_master/lib/config.dart) for the actual current default URL.

## 🤝 Contributing

Issues and pull requests are welcome. Keep game-flow changes consistent between the Socket.IO server and Flutter client, and avoid committing credentials or generated build output.

---

<div align="center"><strong>Can you spot the bluff?</strong> 🎭</div>
