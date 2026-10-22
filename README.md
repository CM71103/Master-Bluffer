Bluff Master
Bluff Master is a multiplayer bluffing and impostor-detection game built with Flutter. Players join a room, receive a secret word or an impostor role, give clues over multiple rounds, vote for the suspected impostor, and view the game results.

The project contains a Flutter client and a Node.js backend. Firebase is used for authentication and user-related game data, while the backend provides REST endpoints and real-time multiplayer communication through Socket.IO.
Features
- User sign-in with Firebase Authentication (check the Firebase console configuration for enabled providers).
- Create and join multiplayer game rooms using room codes.
- Choose a word category and number of rounds.
- Real-time game phases, timers, clues, voting, and results using Socket.IO.
- Player profiles, game history, and statistics stored in Firestore.
- Leaderboard and recent-game endpoints provided by the backend.
- Local device notifications for supported mobile platforms. Notifications are not supported by the current implementation on web.
- Flutter screens for login, home, lobby, gameplay, profile, and leaderboard.
Technology Stack
Frontend
- Flutter and Dart
- Firebase Core and Firebase Authentication
- Cloud Firestore
- Riverpod
- GoRouter
- Socket.IO client
- HTTP client
- Flutter Local Notifications
Backend
- Node.js
- Express
- Socket.IO
- MongoDB
