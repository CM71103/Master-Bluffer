# Party Bluffing Game - Updated Copy

Your original project was NOT modified. This folder is a separate copy with the changes below.

## What changed (mapped to the Review 1 rubric)

| Rubric | Change |
|---|---|
| A. UI | Splash screen, shared dark-purple theme (`lib/theme.dart`), `ResponsiveBody` caps width so phone and browser both look right, Material 3 inputs/buttons |
| B1 | Email/password **Register + Login** (plus existing Google and Guest) |
| B2 | Form validation, friendly error messages, forgot-password, session restored on restart via `authStateChanges`, logout clears the stack and disconnects the socket |
| C1 | Create/join room, leave room, copy code, host handover, Profile screen with game history; swipe or tap the bin to delete (cancel) a record |
| C2 | Named routes, `AuthGate` root, lobby listeners restored after returning from the game |
| D1 | Room saved to Firestore `rooms/{code}`, "Room Created / Joined" confirmation dialog with details; each finished game saved to `users/{uid}/games` |
| D2 | Local device notifications: room created/joined, game started, round result (`flutter_local_notifications`; not shown on web) |
| Bug fixes | Server crash in `endRound` (`imposterId` undefined), role message arriving before the game screen existed (word showed `???`), joiner never saw the room code, missing `INTERNET` permission in release builds, dispose order in the game screen |

## Setup before running

1. Install packages:
   ```
   cd bluff_master
   flutter pub get
   ```
2. **Firebase console**
   - Authentication > Sign-in method: enable **Email/Password**, Google, Anonymous.
   - Firestore Database: create a database, then set these rules:
     ```
     rules_version = '2';
     service cloud.firestore {
       match /databases/{db}/documents {
         match /users/{uid}/{document=**} {
           allow read, write: if request.auth != null && request.auth.uid == uid;
         }
         match /rooms/{code} {
           allow read, write: if request.auth != null;
         }
       }
     }
     ```
3. **Start the game server** (needed for every demo):
   ```
   cd server
   npm install
   node index.js
   ```
4. **Run the app**
   - Android emulator: `flutter run` (uses 10.0.2.2:3000 automatically)
   - Real phone (same Wi-Fi as the laptop): `flutter run --dart-define=SERVER_URL=http://<LAPTOP-IP>:3000`
   - Web: `flutter run -d chrome` (uses localhost:3000)
   - For the web demo, add `localhost` to Firebase Auth > Settings > Authorized domains if Google sign-in complains.

## Not verified

Flutter and Node were not available where this copy was edited, so it has not been compiled or run. Run `flutter pub get` and `flutter analyze` first and fix any small version mismatch (the notification package API changes between major versions).

---

# MongoDB addition (this folder: updated1)

## What MongoDB does here
The Node server (`server/db.js`) stores game data in MongoDB. Firebase still handles login, room booking records and notifications (the rubric asks for Firebase).

| Collection | Contents |
|---|---|
| `words` | Word pairs (seeded automatically the first time) - the game picks a random pair from here |
| `rooms` | Every room created (code, host, time) |
| `games` | Every finished game: players, imposter, winner, words, time |

The app reads it through REST routes on the server:
`GET /api/leaderboard`, `GET /api/recent`, `GET /api/history/:uid`, `DELETE /api/history/:id/:uid`, `GET /health`.
New screen: **Home > Leaderboard** (Top Players, My Games with delete, Recent).

If MongoDB is not configured, the server still runs and the game works with built-in words; only the Leaderboard screen will be empty.

## Set up MongoDB (free Atlas cluster, ~5 minutes)
1. Go to https://www.mongodb.com/atlas, sign up, and create a free **M0** cluster.
2. Database Access > add a database user (note the username and password).
3. Network Access > add IP address **0.0.0.0/0** (allow from anywhere) for the demo.
4. Cluster > Connect > Drivers > copy the connection string.
5. In the `server` folder, copy `.env.example` to `.env` and put your string in `MONGODB_URI` (replace `<user>` and `<password>`).
6. Install and start:
   ```
   cd server
   npm install
   node index.js
   ```
   You should see `MongoDB connected` and `Server running on port 3000`.
7. Check it in a browser: http://localhost:3000/health should show `{"ok":true,"mongo":true}`.

Then in `bluff_master` run `flutter pub get` (a new `http` package was added) and run the app as before.
