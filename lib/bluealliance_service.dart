import 'dart:convert';
import 'package:http/http.dart' as http;

class BlueAllianceService {
  static const String baseUrl = 'https://www.thebluealliance.com/api/v3';
  
  // Default API key - users should set their own
  static String _apiKey = 'YOUR_TBA_API_KEY_HERE';
  
  static void setApiKey(String apiKey) {
    _apiKey = apiKey;
  }
  
  static String get apiKey => _apiKey;
  
  // Event model
  static Map<String, String> get _headers => {
    'X-TBA-Auth-Key': _apiKey,
    'Content-Type': 'application/json',
  };

  // Mock data for demonstration when API is not configured
  static bool get _isApiConfigured => _apiKey != 'YOUR_TBA_API_KEY_HERE' && _apiKey.isNotEmpty;

  Future<List<Event>> getEvents(int year) async {
    if (!_isApiConfigured) {
      return _getMockEvents();
    }
    
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/events/$year'),
        headers: _headers,
      );
      
      if (response.statusCode == 200) {
        final List<dynamic> jsonData = json.decode(response.body);
        return jsonData.map((event) => Event.fromJson(event)).toList();
      } else {
        throw Exception('Failed to load events: ${response.statusCode}');
      }
    } catch (e) {
      // Return mock data if real API fails
      return _getMockEvents();
    }
  }

  Future<List<Match>> getEventMatches(String eventKey) async {
    if (!_isApiConfigured) {
      return _getMockMatches();
    }
    
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/event/$eventKey/matches'),
        headers: _headers,
      );
      
      if (response.statusCode == 200) {
        final List<dynamic> jsonData = json.decode(response.body);
        return jsonData.map((match) => Match.fromJson(match)).toList();
      } else {
        throw Exception('Failed to load matches: ${response.statusCode}');
      }
    } catch (e) {
      return _getMockMatches();
    }
  }

  Future<Match> getMatch(String matchKey) async {
    if (!_isApiConfigured) {
      return _getMockMatches().first;
    }
    
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/match/$matchKey'),
        headers: _headers,
      );
      
      if (response.statusCode == 200) {
        return Match.fromJson(json.decode(response.body));
      } else {
        throw Exception('Failed to load match: ${response.statusCode}');
      }
    } catch (e) {
      return _getMockMatches().first;
    }
  }

  Future<List<Video>> getMatchVideos(String matchKey) async {
    if (!_isApiConfigured) {
      return _getMockVideos();
    }
    
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/match/$matchKey/videos'),
        headers: _headers,
      );
      
      if (response.statusCode == 200) {
        final List<dynamic> jsonData = json.decode(response.body);
        return jsonData.map((video) => Video.fromJson(video)).toList();
      } else {
        throw Exception('Failed to load videos: ${response.statusCode}');
      }
    } catch (e) {
      return _getMockVideos();
    }
  }

  // Mock data for demonstration
  List<Event> _getMockEvents() {
    return [
      Event(
        key: '2024cmptx',
        name: 'FIRST Championship - Houston',
        year: 2024,
        eventCode: 'cmptx',
        city: 'Houston',
        stateProv: 'TX',
        country: 'USA',
      ),
      Event(
        key: '2024cada',
        name: 'Los Angeles Regional',
        year: 2024,
        eventCode: 'cada',
        city: 'Los Angeles',
        stateProv: 'CA',
        country: 'USA',
      ),
      Event(
        key: '2024nyro',
        name: 'New York City Regional',
        year: 2024,
        eventCode: 'nyro',
        city: 'New York',
        stateProv: 'NY',
        country: 'USA',
      ),
    ];
  }

  List<Match> _getMockMatches() {
    return [
      Match(
        key: '2024cmptx_qm1',
        matchNumber: 1,
        compLevel: 'qm',
        setNumber: 1,
        redTeams: ['frc254', 'frc1678', 'frc148'],
        blueTeams: ['frc2056', 'frc971', 'frc1323'],
      ),
      Match(
        key: '2024cmptx_qm2',
        matchNumber: 2,
        compLevel: 'qm',
        setNumber: 1,
        redTeams: ['frc4414', 'frc2767', 'frc5940'],
        blueTeams: ['frc6164', 'frc3476', 'frc118'],
      ),
      Match(
        key: '2024cmptx_qm3',
        matchNumber: 3,
        compLevel: 'qm',
        setNumber: 1,
        redTeams: ['frc3324', 'frc5818', 'frc195'],
        blueTeams: ['frc4534', 'frc2910', 'frc6995'],
      ),
    ];
  }

  List<Video> _getMockVideos() {
    return [
      Video(
        type: 'youtube',
        key: 'dQw4w9WgXcQ', // Rick Roll video for demo
        url: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
      ),
    ];
  }
}

// Event model
class Event {
  final String key;
  final String name;
  final int year;
  final String? eventCode;
  final String? city;
  final String? stateProv;
  final String? country;
  
  Event({
    required this.key,
    required this.name,
    required this.year,
    this.eventCode,
    this.city,
    this.stateProv,
    this.country,
  });

  factory Event.fromJson(Map<String, dynamic> json) {
    return Event(
      key: json['key'] ?? '',
      name: json['name'] ?? '',
      year: json['year'] ?? 0,
      eventCode: json['event_code'],
      city: json['city'],
      stateProv: json['state_prov'],
      country: json['country'],
    );
  }

  @override
  String toString() {
    return '$name ($key)';
  }
}

// Match model
class Match {
  final String key;
  final int matchNumber;
  final String compLevel;
  final int setNumber;
  final List<String> redTeams;
  final List<String> blueTeams;
  
  Match({
    required this.key,
    required this.matchNumber,
    required this.compLevel,
    required this.setNumber,
    required this.redTeams,
    required this.blueTeams,
  });

  factory Match.fromJson(Map<String, dynamic> json) {
    final alliances = json['alliances'] ?? {};
    final red = alliances['red'] ?? {};
    final blue = alliances['blue'] ?? {};
    
    return Match(
      key: json['key'] ?? '',
      matchNumber: json['match_number'] ?? 0,
      compLevel: json['comp_level'] ?? '',
      setNumber: json['set_number'] ?? 0,
      redTeams: List<String>.from(red['team_keys'] ?? []),
      blueTeams: List<String>.from(blue['team_keys'] ?? []),
    );
  }

  String get displayName {
    String level;
    switch (compLevel) {
      case 'qm':
        level = 'Qualification';
        break;
      case 'ef':
      case 'qf':
      case 'sf':
      case 'f':
        level = compLevel.toUpperCase();
        break;
      default:
        level = compLevel;
    }
    return '$level $matchNumber';
  }

  @override
  String toString() {
    return displayName;
  }
}

// Video model
class Video {
  final String type;
  final String key;
  final String? url;
  
  Video({
    required this.type,
    required this.key,
    this.url,
  });

  factory Video.fromJson(Map<String, dynamic> json) {
    String? videoUrl;
    
    // Handle YouTube videos
    if (json['type'] == 'youtube') {
      videoUrl = 'https://www.youtube.com/watch?v=${json['key']}';
    } else if (json['type'] == 'tba') {
      videoUrl = json['key'];
    }
    
    return Video(
      type: json['type'] ?? '',
      key: json['key'] ?? '',
      url: videoUrl,
    );
  }
  
  String? get embedUrl {
    if (type == 'youtube') {
      return 'https://www.youtube.com/embed/$key';
    }
    return url;
  }
}