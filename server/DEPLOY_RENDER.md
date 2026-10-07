# Deploy the Bluff Master backend to Render

The Node backend is in this folder; the Flutter client is in `bluff_master/`.

1. Push the repository to GitHub.
2. In Render, create a Blueprint from the repository and use this `render.yaml`.
3. Set `MONGODB_URI` in Render's Environment settings to your MongoDB Atlas URI. Do not commit real credentials or put the MongoDB URI in Flutter. `MONGODB_DB` defaults to `bluff_master`.
4. Deploy, then check `https://<service>.onrender.com/health`; expect `ok: true` and `mongo: true` if connected.
5. The Flutter app defaults to `https://bluff-master-server.onrender.com` for REST and Socket.IO. To target another deployment or a local server, override it at build/run time:

   ```powershell
   flutter run --dart-define=SERVER_URL=http://localhost:3000
   ```

The live room state is held in server memory, so a server restart ends in-progress rooms.
