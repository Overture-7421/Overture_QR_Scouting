# Deployment Guide

This guide covers how to deploy the Overture QR Scouting app with the new features.

## New Features

### 1. Default Schedule Loading
The app now automatically loads `lib/sample_schedule.txt` on startup, so your team always has a default schedule ready when the app is deployed.

### 2. External Firebase Database Integration
The app can send all scouting data to an external Firebase Realtime Database for centralized storage and analysis.

## Pre-Deployment Checklist

### Configure Default Schedule

1. **Edit the default schedule** (`lib/sample_schedule.txt`):
   ```
   Event: Your Event Name 2025
   # ScouterID , Match , Position , Team
   SCOUT1, 1, Blue 1, 1234
   SCOUT2, 2, Red 2, 5678
   ```

2. **Verify the format**:
   - First line (optional): `Event: <Event Name>`
   - Subsequent lines: `ScouterID, MatchNumber, Position, TeamNumber`
   - Separators: commas, tabs, or multiple spaces
   - Comments: Lines starting with `#` are ignored

### Configure External Firebase (Optional)

1. **Edit external Firebase config** (`lib/external_firebase_config.json`):
   ```json
   {
     "databaseURL": "https://your-project-default-rtdb.firebaseio.com",
     "enabled": true
   }
   ```

2. **Get your Firebase Database URL**:
   - Go to [Firebase Console](https://console.firebase.google.com/)
   - Select your external project
   - Navigate to Realtime Database
   - Create a database if you haven't already
   - Copy the database URL

3. **Set up database rules** (for development):
   ```json
   {
     "rules": {
       "scouting_data": {
         ".read": true,
         ".write": true
       }
     }
   }
   ```

   **Important**: Use proper authentication for production!

## Build Commands

### For Web (Firebase Hosting)

```bash
# Install dependencies
flutter pub get

# Build for web
flutter build web

# Deploy to Firebase Hosting
firebase deploy --only hosting
```

### For Android

```bash
# Install dependencies
flutter pub get

# Build APK
flutter build apk

# Or build App Bundle (recommended for Play Store)
flutter build appbundle
```

### For Windows

```bash
# Install dependencies
flutter pub get

# Build for Windows
flutter build windows
```

### For macOS

```bash
# Install dependencies
flutter pub get

# Build for macOS
flutter build macos
```

## Deployment Steps

### Firebase Hosting (Web)

1. **Ensure Firebase CLI is installed**:
   ```bash
   npm install -g firebase-tools
   firebase login
   ```

2. **Build the web app**:
   ```bash
   flutter build web
   ```

3. **Copy built files to public directory**:
   ```bash
   cp -r build/web/* public/
   ```

4. **Deploy**:
   ```bash
   firebase deploy --only hosting
   ```

5. **Verify deployment**:
   - Visit your Firebase Hosting URL
   - Check that the default schedule is loaded
   - Test the external Firebase integration (if enabled)

### Mobile App Distribution

#### Android

1. **Build the APK**:
   ```bash
   flutter build apk --release
   ```

2. **Find the APK**:
   - Location: `build/app/outputs/flutter-apk/app-release.apk`

3. **Distribute**:
   - Upload to Google Play Store, or
   - Share APK directly with team members

#### iOS (requires macOS)

1. **Build the iOS app**:
   ```bash
   flutter build ios --release
   ```

2. **Archive and distribute** using Xcode

## Post-Deployment Verification

### Test Default Schedule

1. Open the deployed app
2. Check if the event name appears at the top
3. Verify that the "Select Scouter ID" button is enabled
4. Test selecting a scouter ID and match

### Test External Firebase (if enabled)

1. Fill out a scouting form
2. Click "Commit"
3. Look for the success message: "Data successfully sent to external database!"
4. Check your Firebase Console → Realtime Database
5. Verify the data appears under `scouting_data/`

### Test Override Functionality

1. Click the "Load Schedule" button
2. Upload a different schedule file
3. Verify it replaces the default schedule

## Troubleshooting

### Default Schedule Not Loading

- **Check**: Is `lib/sample_schedule.txt` included in `pubspec.yaml` under `assets:`?
- **Fix**: Ensure the file path is correct and rebuild

### External Firebase Not Working

- **Check**: Is `enabled: true` in `external_firebase_config.json`?
- **Check**: Is the database URL correct?
- **Check**: Are database rules allowing writes?
- **Check**: Browser console for error messages

### Build Errors

- **Run**: `flutter clean` then `flutter pub get`
- **Update**: `flutter upgrade`
- **Check**: Flutter version compatibility with dependencies

## Environment-Specific Configurations

### Development
```json
{
  "databaseURL": "https://dev-project-rtdb.firebaseio.com",
  "enabled": true
}
```

### Production
```json
{
  "databaseURL": "https://prod-project-rtdb.firebaseio.com",
  "enabled": true
}
```

Remember to rebuild the app after changing configurations!

## Security Best Practices

1. **Never commit sensitive credentials** to version control
2. **Use proper Firebase security rules** in production
3. **Enable Firebase Authentication** for production databases
4. **Monitor Firebase usage** to prevent abuse
5. **Keep dependencies updated** for security patches

## Support

For detailed information on specific features:
- **External Firebase Setup**: See [EXTERNAL_FIREBASE_SETUP.md](EXTERNAL_FIREBASE_SETUP.md)
- **Spanish Guide**: See [CONFIGURACION_FIREBASE_EXTERNO.md](CONFIGURACION_FIREBASE_EXTERNO.md)
- **Example Configurations**: See `external_firebase_config.example.json` and `sample_schedule.example.txt`
