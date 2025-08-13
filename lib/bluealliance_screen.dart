import 'package:flutter/material.dart';
import 'bluealliance_service.dart';
import 'match_video_player.dart';

class BlueAllianceScreen extends StatefulWidget {
  const BlueAllianceScreen({super.key});

  @override
  State<BlueAllianceScreen> createState() => _BlueAllianceScreenState();
}

class _BlueAllianceScreenState extends State<BlueAllianceScreen> {
  final BlueAllianceService _apiService = BlueAllianceService();
  
  // State variables
  List<Event> _events = [];
  List<Match> _matches = [];
  List<Video> _videos = [];
  Event? _selectedEvent;
  Match? _selectedMatch;
  Video? _selectedVideo;
  bool _isLoadingEvents = false;
  bool _isLoadingMatches = false;
  bool _isLoadingVideos = false;
  String? _errorMessage;
  int _selectedYear = DateTime.now().year;

  // Counter for demo purposes (simulating form interaction)
  int _demoCounter = 0;

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    setState(() {
      _isLoadingEvents = true;
      _errorMessage = null;
      _events.clear();
      _selectedEvent = null;
      _matches.clear();
      _selectedMatch = null;
      _videos.clear();
      _selectedVideo = null;
    });

    try {
      final events = await _apiService.getEvents(_selectedYear);
      if (mounted) {
        setState(() {
          _events = events;
          _isLoadingEvents = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingEvents = false;
          _errorMessage = 'Failed to load events: $e';
        });
      }
    }
  }

  Future<void> _loadMatches(Event event) async {
    setState(() {
      _isLoadingMatches = true;
      _matches.clear();
      _selectedMatch = null;
      _videos.clear();
      _selectedVideo = null;
    });

    try {
      final matches = await _apiService.getEventMatches(event.key);
      if (mounted) {
        setState(() {
          _matches = matches;
          _isLoadingMatches = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingMatches = false;
          _errorMessage = 'Failed to load matches: $e';
        });
      }
    }
  }

  Future<void> _loadVideos(Match match) async {
    setState(() {
      _isLoadingVideos = true;
      _videos.clear();
      _selectedVideo = null;
    });

    try {
      final videos = await _apiService.getMatchVideos(match.key);
      if (mounted) {
        setState(() {
          _videos = videos;
          _isLoadingVideos = false;
          // Auto-select first video if available
          if (_videos.isNotEmpty) {
            _selectedVideo = _videos.first;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingVideos = false;
          _errorMessage = 'Failed to load videos: $e';
        });
      }
    }
  }

  Widget _buildApiConfigSection() {
    final bool isConfigured = BlueAllianceService.apiKey != 'YOUR_TBA_API_KEY_HERE' && 
                              BlueAllianceService.apiKey.isNotEmpty;
    
    return Card(
      elevation: 2,
      color: isConfigured ? null : Colors.orange.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isConfigured ? Icons.check_circle : Icons.warning,
                  color: isConfigured ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 8),
                Text(
                  'API Configuration',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurpleAccent[100],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (isConfigured)
              const Text(
                'BlueAlliance API is configured ✓',
                style: TextStyle(color: Colors.green),
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Using mock data for demonstration.',
                    style: TextStyle(color: Colors.orange[300]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'To use real data, set your BlueAlliance API key in the service.',
                    style: TextStyle(color: Colors.grey[400], fontSize: 12),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.calendar_today, color: Colors.deepPurpleAccent[100]),
                const SizedBox(width: 8),
                Text(
                  'Select Year',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurpleAccent[100],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _selectedYear,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: List.generate(10, (index) {
                      final year = DateTime.now().year - index;
                      return DropdownMenuItem(
                        value: year,
                        child: Text(year.toString()),
                      );
                    }),
                    onChanged: (int? newYear) {
                      if (newYear != null && newYear != _selectedYear) {
                        setState(() {
                          _selectedYear = newYear;
                        });
                        _loadEvents();
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _isLoadingEvents ? null : _loadEvents,
                  icon: _isLoadingEvents
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                  label: const Text('Refresh'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildYearSelector() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.event, color: Colors.deepPurpleAccent[100]),
                const SizedBox(width: 8),
                Text(
                  'Select Event',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurpleAccent[100],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<Event>(
              value: _selectedEvent,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                hintText: 'Choose an event...',
              ),
              items: _events.map((Event event) {
                return DropdownMenuItem<Event>(
                  value: event,
                  child: Text(
                    event.toString(),
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: _isLoadingEvents
                  ? null
                  : (Event? newEvent) {
                      if (newEvent != null) {
                        setState(() {
                          _selectedEvent = newEvent;
                        });
                        _loadMatches(newEvent);
                      }
                    },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMatchSelector() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.sports_esports, color: Colors.deepPurpleAccent[100]),
                const SizedBox(width: 8),
                Text(
                  'Select Match',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurpleAccent[100],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<Match>(
              value: _selectedMatch,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                hintText: 'Choose a match...',
              ),
              items: _matches.map((Match match) {
                return DropdownMenuItem<Match>(
                  value: match,
                  child: Text(match.toString()),
                );
              }).toList(),
              onChanged: _isLoadingMatches
                  ? null
                  : (Match? newMatch) {
                      if (newMatch != null) {
                        setState(() {
                          _selectedMatch = newMatch;
                        });
                        _loadVideos(newMatch);
                      }
                    },
            ),
            if (_isLoadingMatches)
              const Padding(
                padding: EdgeInsets.only(top: 8.0),
                child: Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoSelector() {
    if (_videos.isEmpty && !_isLoadingVideos) {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.video_library, color: Colors.deepPurpleAccent[100]),
                const SizedBox(width: 8),
                Text(
                  'Available Videos',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurpleAccent[100],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_isLoadingVideos)
              const Center(child: CircularProgressIndicator())
            else if (_videos.isNotEmpty)
              DropdownButtonFormField<Video>(
                value: _selectedVideo,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  hintText: 'Choose a video...',
                ),
                items: _videos.map((Video video) {
                  return DropdownMenuItem<Video>(
                    value: video,
                    child: Text('${video.type.toUpperCase()} Video'),
                  );
                }).toList(),
                onChanged: (Video? newVideo) {
                  setState(() {
                    _selectedVideo = newVideo;
                  });
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInteractiveControls() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.touch_app, color: Colors.deepPurpleAccent[100]),
                const SizedBox(width: 8),
                Text(
                  'Interactive Controls',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurpleAccent[100],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Test interactive buttons while video is playing:',
              style: TextStyle(color: Colors.grey[300]),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('Demo Counter:', style: TextStyle(fontSize: 16)),
                const Spacer(),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: _demoCounter > 0
                          ? () => setState(() => _demoCounter--)
                          : null,
                      color: _demoCounter > 0 ? Colors.redAccent : Colors.grey,
                    ),
                    SizedBox(
                      width: 40,
                      child: Text(
                        '$_demoCounter',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: () => setState(() => _demoCounter++),
                      color: Colors.greenAccent,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => setState(() => _demoCounter = 0),
                    child: const Text('Reset Counter'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => setState(() => _demoCounter += 5),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                    child: const Text('+5'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoPlayer() {
    if (_selectedMatch == null) {
      return const SizedBox.shrink();
    }

    final matchName = '${_selectedEvent?.name ?? "Event"} - ${_selectedMatch!.displayName}';
    final videoUrl = _selectedVideo?.url;

    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.play_circle_filled, color: Colors.deepPurpleAccent[100]),
                const SizedBox(width: 8),
                Text(
                  'Match Video',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurpleAccent[100],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            MatchVideoPlayer(
              videoUrl: videoUrl,
              matchName: matchName,
              onVideoError: () {
                setState(() {
                  _errorMessage = 'Failed to load video for ${_selectedMatch!.displayName}';
                });
              },
            ),
            const SizedBox(height: 12),
            Text(
              matchName,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (_selectedMatch!.redTeams.isNotEmpty || _selectedMatch!.blueTeams.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Red Alliance:',
                            style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                          ),
                          ...(_selectedMatch!.redTeams.take(3).map((team) => 
                            Text(team.replaceFirst('frc', 'Team ')))),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Blue Alliance:',
                            style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
                          ),
                          ...(_selectedMatch!.blueTeams.take(3).map((team) => 
                            Text(team.replaceFirst('frc', 'Team ')))),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('BlueAlliance Integration'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_errorMessage != null)
              Card(
                color: Colors.red.withOpacity(0.1),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      const Icon(Icons.error, color: Colors.red),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.red),
                        onPressed: () => setState(() => _errorMessage = null),
                      ),
                    ],
                  ),
                ),
              ),
            _buildApiConfigSection(),
            const SizedBox(height: 16),
            _buildYearSelector(),
            const SizedBox(height: 16),
            _buildEventSelector(),
            const SizedBox(height: 16),
            if (_selectedEvent != null) _buildMatchSelector(),
            const SizedBox(height: 16),
            if (_selectedMatch != null) _buildVideoSelector(),
            const SizedBox(height: 16),
            if (_selectedMatch != null) _buildVideoPlayer(),
            const SizedBox(height: 16),
            _buildInteractiveControls(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}