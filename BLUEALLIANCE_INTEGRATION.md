# BlueAlliance API Integration

## Overview

The Overture QR Scouting app now includes integration with The Blue Alliance (TBA) API, allowing users to:
- Select FRC events and matches from live data
- View match videos while interacting with scouting forms
- Access team and match information directly within the app

## Features

### Event and Match Selection
- **Year Selection**: Choose any FRC season year to browse events
- **Event Browsing**: View all events for the selected year with detailed information
- **Match Selection**: Browse all matches within a selected event
- **Video Integration**: Automatically load available videos for selected matches

### Video Player
- **YouTube Support**: Integrated YouTube video player for match videos
- **Interactive Controls**: Continue using scouting form controls while video plays
- **External Launch**: Option to open videos in external YouTube app/browser
- **Fallback Support**: Graceful handling when videos are unavailable

### Interactive Demonstration
- **Demo Counter**: Test form interactions while video is playing
- **Button Controls**: Increment/decrement counters and buttons work simultaneously with video playback
- **Real-time Updates**: All form controls remain responsive during video playback

## Setup Instructions

### 1. API Key Configuration (Optional)

For access to live TBA data, configure your API key:

```dart
// In your app initialization or before using the service
BlueAllianceService.setApiKey('your_tba_api_key_here');
```

**Getting a TBA API Key:**
1. Visit [The Blue Alliance](https://www.thebluealliance.com/)
2. Create an account or log in
3. Go to [Account Settings > Read API Keys](https://www.thebluealliance.com/account)
4. Create a new Read API Key
5. Copy the generated key

**Note**: If no API key is configured, the app uses mock data for demonstration purposes.

### 2. Using the Integration

1. **Access BlueAlliance Features**:
   - Open the main scouting app
   - Tap the API icon (🔌) in the app bar
   - This opens the BlueAlliance Integration screen

2. **Select Event and Match**:
   - Choose a year from the dropdown
   - Select an event from the loaded list
   - Choose a specific match from the event
   - Videos will automatically load if available

3. **Video Interaction**:
   - Videos play in an embedded player
   - Use the demo counter controls while video is playing
   - Verify that form interactions work simultaneously with video playback
   - For YouTube videos on mobile, use "Open in YouTube" button

### 3. Form Integration

The BlueAlliance screen demonstrates the core requirement: **video playback concurrent with form interactions**

- **Counter Controls**: Increment/decrement buttons work while video plays
- **Reset Functions**: Clear and batch operations function normally
- **Responsive UI**: All controls remain responsive during video playback
- **State Management**: Form state is maintained independently of video state

## Technical Implementation

### Components

1. **BlueAllianceService** (`lib/bluealliance_service.dart`)
   - Handles API communication with TBA
   - Provides mock data fallback
   - Manages event, match, and video data retrieval

2. **MatchVideoPlayer** (`lib/match_video_player.dart`)
   - Custom video player widget using video_player and chewie packages
   - YouTube video support with external launching
   - Error handling and loading states

3. **BlueAllianceScreen** (`lib/bluealliance_screen.dart`)
   - Main UI for event/match selection
   - Integrates video player with interactive form controls
   - Demonstrates concurrent video playback and form interaction

### Dependencies Added

```yaml
dependencies:
  http: ^1.1.0                 # API communication
  video_player: ^2.8.2         # Video playback
  chewie: ^1.7.5               # Video player controls
  url_launcher: ^6.2.2         # External link launching
```

## Usage Examples

### Basic Usage
```dart
// Navigate to BlueAlliance screen from main app
Navigator.of(context).push(
  MaterialPageRoute(
    builder: (context) => const BlueAllianceScreen(),
  ),
);
```

### Configuring API Key
```dart
// Set API key before using the service
BlueAllianceService.setApiKey('your_actual_api_key');
```

### Video Player Integration
```dart
MatchVideoPlayer(
  videoUrl: videoUrl,
  matchName: matchName,
  onVideoError: () {
    // Handle video loading errors
  },
)
```

## Troubleshooting

### Common Issues

1. **No Events Loading**:
   - Check internet connection
   - Verify API key if using live data
   - App falls back to mock data automatically

2. **Videos Not Playing**:
   - YouTube videos require external app on mobile
   - Check video URL validity
   - Some matches may not have recorded videos

3. **Form Controls Not Responding**:
   - Ensure video player is not in fullscreen mode
   - Check if device has sufficient resources
   - Try reloading the screen

### Mock Data

When API is not configured or fails, the app uses mock data:
- Sample FRC events (Houston Championship, Los Angeles Regional, NYC Regional)
- Demo matches with team numbers
- YouTube demo video (Rick Roll for testing)

## Future Enhancements

Potential improvements:
- Persistent API key storage
- Enhanced video controls
- Team statistics integration
- Match prediction features
- Offline video caching

## Support

For issues or questions:
1. Check that all dependencies are properly installed
2. Verify Flutter version compatibility
3. Test with mock data first before configuring real API access
4. Review console logs for detailed error information