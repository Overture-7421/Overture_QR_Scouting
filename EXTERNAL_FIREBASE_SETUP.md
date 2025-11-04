# External Firebase Database Setup

This guide explains how to configure the app to send QR scouting data to an external Firebase Realtime Database.

## Overview

The app now supports sending scouting data to a Firebase Realtime Database in a different Firebase project. This allows you to store all your scouting data centrally, even if you're using Firebase Hosting from a different project.

## Features

1. **Default Schedule**: The app now loads the `sample_schedule.txt` file from the project by default when deployed.
2. **External Firebase Database**: Configure an external Firebase Realtime Database to automatically store all committed scouting data.

## Configuration Steps

### 1. Enable External Firebase Database

Edit the file `lib/external_firebase_config.json`:

```json
{
  "databaseURL": "https://YOUR_EXTERNAL_PROJECT.firebaseio.com",
  "enabled": true
}
```

Replace `YOUR_EXTERNAL_PROJECT` with your actual Firebase project ID.

### 2. Get Your Firebase Database URL

1. Go to your external Firebase project in the [Firebase Console](https://console.firebase.google.com/)
2. Navigate to **Realtime Database** in the left sidebar
3. If you haven't created a database yet, click **Create Database**
4. Choose your location and security rules (start in test mode for development)
5. Copy the database URL, which looks like: `https://your-project-id.firebaseio.com` or `https://your-project-id-default-rtdb.firebaseio.com`

### 3. Configure Database Rules

In your external Firebase project, go to **Realtime Database** → **Rules** and set appropriate security rules.

For development/testing (NOT recommended for production):
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

For production, you should use proper authentication and authorization rules.

### 4. Build and Deploy

After configuring `external_firebase_config.json`, rebuild your app:

```bash
flutter pub get
flutter build web
```

Then deploy to Firebase Hosting:

```bash
firebase deploy --only hosting
```

## Data Structure

When you commit scouting data, it's sent to the `scouting_data` node in your external Firebase Realtime Database with the following structure:

```
scouting_data/
  ├── [auto-generated-id-1]/
  │   ├── scouterInitials: "ABC"
  │   ├── matchNumber: "1"
  │   ├── teamNumber: "1234"
  │   ├── robot: "Blue 1"
  │   ├── ... (all other scouting fields)
  │   └── timestamp: 1234567890123
  └── [auto-generated-id-2]/
      ├── scouterInitials: "XYZ"
      ├── ...
```

## Default Schedule

The app now automatically loads the schedule from `lib/sample_schedule.txt` when it starts. Users can still upload their own schedule files, which will override the default.

### Updating the Default Schedule

To update the default schedule that's bundled with the app:

1. Edit `lib/sample_schedule.txt` with your event information
2. Follow the format shown in `sample_schedule.example.txt`:
   ```
   Event: Your Event Name 2025
   # ScouterID , Match , Position , Team
   SCOUTER1, 1, Blue 1, 1234
   SCOUTER1, 2, Blue 3, 7890
   SCOUTER2, 1, Blue 2, 4321
   ```
3. Rebuild the app: `flutter build web` (or your target platform)
4. Redeploy: `firebase deploy --only hosting`

### How It Works

- On app startup, the default schedule from `lib/sample_schedule.txt` is automatically loaded
- If no default schedule exists or it fails to load, the app continues normally without a schedule
- Users can upload their own schedule file at any time, which replaces the default
- The "Load Schedule" button in the app toolbar allows users to upload custom schedules

## Disabling External Firebase

To disable external Firebase integration, set `"enabled": false` in `lib/external_firebase_config.json`:

```json
{
  "databaseURL": "https://YOUR_EXTERNAL_PROJECT.firebaseio.com",
  "enabled": false
}
```

## Troubleshooting

### Data not being sent

- Check that `enabled` is set to `true` in `external_firebase_config.json`
- Verify the database URL is correct
- Check the browser console for error messages
- Ensure your Firebase database rules allow writes

### Database URL format

The database URL should be in one of these formats:
- `https://project-id.firebaseio.com`
- `https://project-id-default-rtdb.firebaseio.com`
- `https://project-id-default-rtdb.europe-west1.firebasedatabase.app` (for regional databases)

### Permission Denied errors

This usually means your database security rules are blocking writes. Update your rules in the Firebase Console to allow the necessary access.

## Notes

- The external Firebase integration works independently of the QR code functionality
- Data is sent when the user clicks "Commit", at the same time the QR code is generated
- If the external database send fails, the user will see an error message but can still use the QR code
- A success message is shown when data is successfully sent to the external database
