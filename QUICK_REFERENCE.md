# Quick Reference Guide

## For Users

### Using the Default Schedule

1. **Open the app** - The default schedule loads automatically
2. **Click the badge icon** (Select Scouter ID) in the top toolbar
3. **Enter or select your Scouter ID**
4. **Use the "Select Match" dropdown** to choose your assigned match
5. **Fill out the scouting form** - Scouter, Match, Position, and Team are pre-filled
6. **Click "Commit"** when done
7. **Scan the QR code** or copy the data

### Uploading a Custom Schedule

1. **Click the upload icon** (Load Schedule) in the top toolbar
2. **Select your .txt schedule file**
3. **Enter your Scouter ID** when prompted
4. **Continue as normal** - Your custom schedule replaces the default

## For Administrators

### Setting Up Default Schedule

**Edit**: `lib/sample_schedule.txt`

```
Event: Your Event Name 2025
# ScouterID , Match , Position , Team
SCOUT1, 1, Blue 1, 1234
SCOUT2, 2, Red 2, 5678
```

**Deploy**:
```bash
flutter build web
firebase deploy --only hosting
```

### Setting Up External Firebase Database

**1. Create Database**:
- Go to Firebase Console → Your External Project
- Create a Realtime Database
- Copy the database URL

**2. Configure App**:

Edit `lib/external_firebase_config.json`:
```json
{
  "databaseURL": "https://your-project-rtdb.firebaseio.com",
  "enabled": true
}
```

**3. Set Database Rules**:

Development (Firebase Console → Realtime Database → Rules):
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

**Production**: Use proper authentication!

**4. Deploy**:
```bash
flutter build web
firebase deploy --only hosting
```

### Viewing Collected Data

1. Go to Firebase Console
2. Select your external project
3. Navigate to Realtime Database
4. Browse to `scouting_data/`
5. Export as JSON if needed

## Troubleshooting

| Problem | Solution |
|---------|----------|
| Default schedule not loading | Check `pubspec.yaml` includes `lib/sample_schedule.txt` in assets |
| "Data send failed" message | Check database URL and Firebase rules |
| Can't select scouter ID | Verify schedule file format is correct |
| QR code not showing | This is separate from Firebase - check form data |

## File Locations

| File | Purpose |
|------|---------|
| `lib/sample_schedule.txt` | Default schedule bundled with app |
| `lib/external_firebase_config.json` | External Firebase configuration |
| `lib/config.json` | Form field configuration |

## Configuration Templates

### Sample Schedule Format

```
Event: Beach Blitz 2025
# Comment lines start with #
SCOUTER_ID, MATCH_NUMBER, POSITION, TEAM_NUMBER
ANA, 1, Blue 1, 1234
LEO, 2, Red 3, 5678
```

**Positions**: `Blue 1`, `Blue 2`, `Blue 3`, `Red 1`, `Red 2`, `Red 3`

**Separators**: Commas, tabs, or 2+ spaces

### External Firebase Config

**Disabled** (default):
```json
{
  "databaseURL": "https://your-project-rtdb.firebaseio.com",
  "enabled": false
}
```

**Enabled**:
```json
{
  "databaseURL": "https://your-project-rtdb.firebaseio.com",
  "enabled": true
}
```

## Commands Reference

### Build Commands

```bash
# Web
flutter build web

# Android
flutter build apk

# Windows
flutter build windows

# macOS
flutter build macos
```

### Deploy to Firebase Hosting

```bash
firebase deploy --only hosting
```

### Full Rebuild

```bash
flutter clean
flutter pub get
flutter build web
firebase deploy --only hosting
```

## Security Checklist

- [ ] Update Firebase database rules for production
- [ ] Test with different scouter IDs
- [ ] Verify data appears in external Firebase
- [ ] Test QR code scanning
- [ ] Test with network disconnected (QR should still work)

## Need More Help?

- 📖 **English Guide**: [EXTERNAL_FIREBASE_SETUP.md](EXTERNAL_FIREBASE_SETUP.md)
- 🇪🇸 **Spanish Guide**: [CONFIGURACION_FIREBASE_EXTERNO.md](CONFIGURACION_FIREBASE_EXTERNO.md)
- 🚀 **Deployment**: [DEPLOYMENT.md](DEPLOYMENT.md)
- 📋 **Implementation Details**: [IMPLEMENTATION_SUMMARY.md](IMPLEMENTATION_SUMMARY.md)
