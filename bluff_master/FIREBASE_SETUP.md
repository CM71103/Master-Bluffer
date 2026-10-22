# Firebase Setup Guide for Bluff Master

## Step 1: Create Firebase Project

1. Go to https://console.firebase.google.com/
2. Click "Add project"
3. Enter project name: "Bluff Master"
4. Disable Google Analytics (optional)
5. Click "Create project"

## Step 2: Add Android App

1. In Firebase console, click "Android" icon
2. Enter package name: `com.example.bluff_master`
3. Download `google-services.json`
4. Place it in: `bluff_master/android/app/google-services.json`

## Step 3: Enable Authentication Methods

1. In Firebase console, go to **Authentication** → **Sign-in method**
2. Enable **Google** sign-in
   - Set email support email
   - Save
3. Enable **Anonymous** sign-in
   - Save

## Step 4: Add iOS App

1. In Firebase console, click "Add app" → iOS icon
2. Enter Bundle ID: `com.example.bluffMaster`
3. Download `GoogleService-Info.plist`
4. Drag into Xcode project under `Runner` folder
5. Open in Xcode: confirm file was added

## Step 5: Update ios/Runner/Info.plist

Add these keys to your Info.plist (in Xcode or text editor):

```xml
<key>GADApplicationIdentifier</key>
<string>Your_AdMob_App_ID</string>

<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleTypeRole</key>
    <string>Editor</string>
    <key>CFBundleURLSchemes</key>
    <array>
      <!-- Replace with your REVERSED_CLIENT_ID from GoogleService-Info.plist -->
      <string>com.google.apps.id.YOUR_REVERSED_CLIENT_ID</string>
    </array>
  </dict>
</array>
```

## Step 6: Run the App

```bash
cd bluff_master
flutter clean
flutter pub get
flutter run
```

---

## Important: google-services.json Location

After downloading from Firebase, place this file at:
```
bluff_master/android/app/google-services.json
```

---

## Testing Credentials (Optional)

You can test with dummy credentials first:
- Use Anonymous sign-in (no real credentials needed)
- Or create a test Google account