import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:overture_qr_scouting/firebase_options.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

Future<void> main() async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
);
  runApp(const ScoutingApp());
}

class ScoutingApp extends StatelessWidget {
  const ScoutingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Overture reefscape Scouting',
      theme: ThemeData.dark().copyWith(
        primaryColor: Colors.deepPurpleAccent,
        scaffoldBackgroundColor: const Color(0xFF121212),
        cardColor: const Color(0xFF1E1E1E),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.deepPurpleAccent),
          ),
          labelStyle: TextStyle(color: Colors.white70),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.deepPurpleAccent,
            foregroundColor: Colors.white,
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E1E1E),
          titleTextStyle: TextStyle(
            color: Colors.deepPurpleAccent,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        switchTheme: SwitchThemeData(
          thumbColor: MaterialStateProperty.resolveWith<Color?>((states) {
            if (states.contains(MaterialState.selected)) {
              return Colors.deepPurpleAccent;
            }
            return null;
          }),
          trackColor: MaterialStateProperty.resolveWith<Color?>((states) {
            if (states.contains(MaterialState.selected)) {
              return Colors.deepPurpleAccent.withOpacity(0.5);
            }
            return null;
          }),
        ),
        dropdownMenuTheme: DropdownMenuThemeData(
          inputDecorationTheme: const InputDecorationTheme(
            filled: true,
            fillColor: Color(0xFF2A2A2A),
            border: InputBorder.none,
          ),
          textStyle: const TextStyle(color: Colors.white),
          menuStyle: MenuStyle(
            backgroundColor: MaterialStateProperty.all(const Color(0xFF2A2A2A)),
          ),
        ),
        textSelectionTheme: TextSelectionThemeData(
          cursorColor: Colors.deepPurpleAccent,
          selectionColor: Colors.deepPurpleAccent.withOpacity(0.4),
          selectionHandleColor: Colors.deepPurpleAccent,
        ),
      ),
      home: const ScoutingHomePage(),
    );
  }
}

class ScoutingHomePage extends StatefulWidget {
  const ScoutingHomePage({super.key});

  @override
  State<ScoutingHomePage> createState() => _ScoutingHomePageState();
}

class _FieldConfig {
  final String type;
  final String label;
  final String key;
  final List<String>? options;
  _FieldConfig({required this.type, required this.label, required this.key, this.options});

  factory _FieldConfig.fromJson(Map<String, dynamic> json) {
    return _FieldConfig(
      type: json['type'],
      label: json['label'],
      key: json['key'],
      options: json['options'] != null ? List<String>.from(json['options']) : null,
    );
  }
}

class _SectionConfig {
  final String title;
  final List<_FieldConfig> fields;
  _SectionConfig({required this.title, required this.fields});

  factory _SectionConfig.fromJson(Map<String, dynamic> json) {
    return _SectionConfig(
      title: json['title'],
      fields: (json['fields'] as List).map((f) => _FieldConfig.fromJson(f)).toList(),
    );
  }
}

class _Assignment {
  final String scouterId;
  final int match;
  final String position;
  final int team;
  const _Assignment({required this.scouterId, required this.match, required this.position, required this.team});
}

class _ParsedSchedule {
  final String? eventName;
  final List<_Assignment> assignments;
  final Map<String, List<_Assignment>> groupedByScouter;
  const _ParsedSchedule({required this.eventName, required this.assignments, required this.groupedByScouter});
}

class _DatabaseTarget {
  final String name;
  final String pathTemplate;
  final bool enabled;
  _DatabaseTarget({required this.name, required this.pathTemplate, this.enabled = true});

  factory _DatabaseTarget.fromJson(Map<String, dynamic> json) {
    return _DatabaseTarget(
      name: json['name'],
      pathTemplate: json['path_template'],
      enabled: json['enabled'] ?? true,
    );
  }
}

class _ScoutingHomePageState extends State<ScoutingHomePage> {
  // Form state
  Map<String, dynamic> _formData = {};
  List<_SectionConfig> _sections = [];
  bool _configLoaded = false;

  // Schedule state
  String? _eventName;
  final Map<String, List<_Assignment>> _scheduleByScouter = {};
  String? _selectedScouterId;
  int? _selectedMatchNumber;

  // Controllers for text fields
  final Map<String, TextEditingController> _controllers = {};

  // YouTube state
  YoutubePlayerController? _ytController;
  bool _showVideo = false;
  String? _currentVideoId;

  // External Firebase state
  String? _externalDatabaseURL;
  bool _externalFirebaseEnabled = false;
  FirebaseApp? _externalFirebaseApp;

  // Database target selection state
  List<_DatabaseTarget> _databaseTargets = [];
  _DatabaseTarget? _selectedDatabaseTarget;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    final String configString = await rootBundle.loadString('lib/config.json');
    final Map<String, dynamic> configJson = json.decode(configString);
    final List<_SectionConfig> sections = (configJson['sections'] as List)
        .map((s) => _SectionConfig.fromJson(s))
        .toList();
    setState(() {
      _sections = sections;
      for (final section in _sections) {
        for (final field in section.fields) {
          if (field.type == 'text' || field.type == 'number') {
            _controllers[field.key] = TextEditingController();
          }
          if (field.type == 'dropdown' && field.options != null && field.options!.isNotEmpty) {
            _formData[field.key] = field.options![0];
          } else if (field.type == 'switch') {
            _formData[field.key] = false;
          } else if (field.type == 'counter') {
            _formData[field.key] = 0;
          }
        }
      }
      _configLoaded = true;
    });
    
    // Load default schedule
    await _loadDefaultSchedule();
    
    // Load external Firebase configuration
    await _loadExternalFirebaseConfig();
    
    // Load database configuration
    await _loadDatabaseConfig();
  }

  Future<void> _loadDefaultSchedule() async {
    try {
      final String scheduleText = await rootBundle.loadString('lib/sample_schedule.txt');
      final _ParsedSchedule parsed = _parseScheduleText(scheduleText);
      if (parsed.assignments.isNotEmpty) {
        setState(() {
          _eventName = parsed.eventName;
          _scheduleByScouter
            ..clear()
            ..addAll(parsed.groupedByScouter);
        });
      }
    } catch (e) {
      // If default schedule doesn't exist or fails to load, just continue without it
      debugPrint('Failed to load default schedule: $e');
    }
  }

  Future<void> _loadExternalFirebaseConfig() async {
    try {
      final String configString = await rootBundle.loadString('lib/external_firebase_config.json');
      final Map<String, dynamic> config = json.decode(configString);
      setState(() {
        _externalDatabaseURL = config['databaseURL'] as String?;
        _externalFirebaseEnabled = config['enabled'] as bool? ?? false;
      });
      
      // Initialize external Firebase app if enabled
      if (_externalFirebaseEnabled && _externalDatabaseURL != null && _externalDatabaseURL!.isNotEmpty) {
        // Validate that we're not using placeholder values
        if (_externalDatabaseURL!.contains('YOUR_EXTERNAL_PROJECT') || 
            _externalDatabaseURL!.contains('your-project') ||
            _externalDatabaseURL!.contains('your-external-project')) {
          debugPrint('External Firebase database URL contains placeholder values. Please update external_firebase_config.json with your actual database URL.');
          setState(() {
            _externalFirebaseEnabled = false;
          });
          return;
        }
        
        try {
          _externalFirebaseApp = await Firebase.initializeApp(
            name: 'external_scouting_db',
            options: FirebaseOptions(
              // Note: These are placeholder values. For Realtime Database access,
              // authentication and authorization are controlled by database security rules,
              // not by these API credentials. The databaseURL is the only critical value.
              apiKey: 'PLACEHOLDER_NOT_USED_FOR_RTDB',
              appId: '1:000000000000:web:0000000000000000000000',
              messagingSenderId: '000000000000',
              projectId: 'external-project-placeholder',
              databaseURL: _externalDatabaseURL,
            ),
          );
        } catch (e) {
          debugPrint('Failed to initialize external Firebase app: $e');
          // If app already exists, get it
          try {
            _externalFirebaseApp = Firebase.app('external_scouting_db');
          } catch (e2) {
            debugPrint('Failed to get existing external Firebase app: $e2');
          }
        }
      }
    } catch (e) {
      debugPrint('Failed to load external Firebase config: $e');
    }
  }

  Future<void> _loadDatabaseConfig() async {
    try {
      final String configString = await rootBundle.loadString('lib/database_config.json');
      final Map<String, dynamic> config = json.decode(configString);
      final List<_DatabaseTarget> allTargets = (config['databases'] as List)
          .map((d) => _DatabaseTarget.fromJson(d))
          .toList();
      // Filter to only enabled targets
      final List<_DatabaseTarget> enabledTargets = allTargets.where((t) => t.enabled).toList();
      
      setState(() {
        _databaseTargets = enabledTargets;
        if (enabledTargets.isNotEmpty) {
          // Set OffSeasonAllStar as default if available
          _selectedDatabaseTarget = enabledTargets.firstWhere(
            (t) => t.name == 'OffSeasonAllStar',
            orElse: () => enabledTargets.first,
          );
        }
      });
    } catch (e) {
      debugPrint('Failed to load database config: $e');
    }
  }

  Map<String, dynamic> _formatDataForDatabase(Map<String, dynamic> formData) {
    // Create the mapping from formData keys to database keys
    final Map<String, String> keyMapping = {
      'scouterInitials': 'SCOUTER INITIALS',
      'robot': 'ROBOT',
      'futureAlliance': 'FUTURE ALLIANCE IN QUALY?',
      'startingPosition': 'STARTING POSITION',
      'noShow': 'NO SHOW',
      'moved': 'MOVED?',
      'coralL1Auto': 'CORAL L1 SCORED AUTO',
      'coralL2Auto': 'CORAL L2 SCORED AUTO',
      'coralL3Auto': 'CORAL L3 SCORED AUTO',
      'coralL4Auto': 'CORAL L4 SCORED AUTO',
      'bargeAlgaeAuto': 'BARGE ALGAE SCORED AUTO',
      'processorAlgaeAuto': 'PROCESSOR ALGAE SCORED AUTO',
      'dislodgedAlgaeAuto': 'DISLODGED ALGAE? AUTO',
      'autoFoul': 'AUTO FOUL',
      'dislodgedAlgaeTeleop': 'DISLODGED ALGAE? TELEOP',
      'pickupLocation': 'PICKUP LOCATION',
      'coralL1Teleop': 'CORAL L1 SCORED TELEOP',
      'coralL2Teleop': 'CORAL L2 SCORED TELEOP',
      'coralL3Teleop': 'CORAL L3 SCORED TELEOP',
      'coralL4Teleop': 'CORAL L4 SCORED TELEOP',
      'bargeAlgaeTeleop': 'BARGE ALGAE SCORED TELEOP',
      'processorAlgaeTeleop': 'PROCESSOR ALGAE SCORED TELEOP',
      'crossedFieldDefense': 'CROSSED FIELD/PLAYED DEFENSE?',
      'tippedFell': 'TIPPED/FELL OVER?',
      'touchedOpposingCage': 'TOUCHED OPPOSING CAGE',
      'died': 'DIED?',
      'endPosition': 'END POSITION',
      'broke': 'BROKE?',
      'defended': 'DEFENDED?',
      'coralHpMistake': 'CORAL HP MISTAKE?',
      'yellowRedCard': 'YELLOW/RED CARD',
    };

    final Map<String, dynamic> formatted = {};
    
    for (final entry in formData.entries) {
      final databaseKey = keyMapping[entry.key];
      if (databaseKey != null) {
        var value = entry.value;
        
        // Convert string values to appropriate types for number fields
        if (value is String && value.isNotEmpty) {
          // Try to parse as int for numeric fields
          final intValue = int.tryParse(value);
          if (intValue != null) {
            value = intValue;
          }
          // Convert "true"/"false" strings to boolean
          else {
            final lowerValue = value.toLowerCase();
            if (lowerValue == 'true' || lowerValue == 'false') {
              value = lowerValue == 'true';
            }
          }
        }
        
        formatted[databaseKey] = value;
      }
    }
    
    return formatted;
  }

  String _generateDatabasePath(Map<String, dynamic> formData) {
    if (_selectedDatabaseTarget == null) {
      return 'scouting_data';
    }

    String path = _selectedDatabaseTarget!.pathTemplate;
    
    // Replace placeholders with actual values
    final teamNumber = formData['teamNumber']?.toString() ?? '';
    final matchNumber = formData['matchNumber']?.toString() ?? '';
    
    // Validate that required placeholders have values
    if (path.contains('{teamNumber}') && teamNumber.isEmpty) {
      debugPrint('Warning: teamNumber is empty, using fallback path');
      return 'scouting_data';
    }
    if (path.contains('{matchNumber}') && matchNumber.isEmpty) {
      debugPrint('Warning: matchNumber is empty, using fallback path');
      return 'scouting_data';
    }
    
    path = path.replaceAll('{teamNumber}', teamNumber);
    path = path.replaceAll('{matchNumber}', matchNumber);
    
    return path;
  }

  Future<void> _sendDataToExternalFirebase(String path, Map<String, dynamic> scoutingData) async {
    if (!_externalFirebaseEnabled || _externalFirebaseApp == null) {
      return;
    }

    try {
      final DatabaseReference ref = FirebaseDatabase.instanceFor(
        app: _externalFirebaseApp!,
      ).ref(path);
      
      // Set data at the specified path
      await ref.set(scoutingData);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Data successfully sent to external database!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Failed to send data to external Firebase: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to send data to external database. Please check your connection and database configuration.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> _pickAndLoadConfig() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['json']);
    if (result != null && result.files.single.bytes != null) {
      try {
        final String configString = String.fromCharCodes(result.files.single.bytes!);
        final Map<String, dynamic> configJson = json.decode(configString);
        final List<_SectionConfig> sections = (configJson['sections'] as List)
            .map((s) => _SectionConfig.fromJson(s))
            .toList();
        setState(() {
          _sections = sections;
          _controllers.clear();
          _formData.clear();
          for (final section in _sections) {
            for (final field in section.fields) {
              if (field.type == 'text' || field.type == 'number') {
                _controllers[field.key] = TextEditingController();
              }
              if (field.type == 'dropdown' && field.options != null && field.options!.isNotEmpty) {
                _formData[field.key] = field.options![0];
              } else if (field.type == 'switch') {
                _formData[field.key] = false;
              } else if (field.type == 'counter') {
                _formData[field.key] = 0;
              }
            }
          }
          _configLoaded = true;
        });
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load config: $e')),
        );
      }
    }
  }

  Future<void> _pickAndLoadSchedule() async {
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['txt'],
    );
    if (result == null || result.files.single.bytes == null) return;

    final String text = String.fromCharCodes(result.files.single.bytes!);
    final _ParsedSchedule parsed = _parseScheduleText(text);
    if (parsed.assignments.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No schedule entries found in file.')),
        );
      }
      return;
    }
    setState(() {
      _eventName = parsed.eventName;
      _scheduleByScouter
        ..clear()
        ..addAll(parsed.groupedByScouter);
      _selectedScouterId = null;
      _selectedMatchNumber = null;
    });

    _promptForScouterId();
  }

  void _promptForScouterId() {
    final List<String> knownIds = _scheduleByScouter.keys.toList()..sort();
    final TextEditingController idCtrl = TextEditingController(text: _selectedScouterId ?? '');

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        String? dropdownVal = knownIds.isNotEmpty ? knownIds.first : null;
        return StatefulBuilder(
          builder: (ctx, setStateDialog) {
            return AlertDialog(
              title: const Text('Enter Scouter ID'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_eventName != null) Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Text('Event: ${_eventName!}', style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  TextField(
                    controller: idCtrl,
                    decoration: const InputDecoration(labelText: 'Scouter ID'),
                  ),
                  if (knownIds.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    const Text('Or pick from file:', style: TextStyle(fontSize: 12, color: Colors.white70)),
                    DropdownButton<String>(
                      value: dropdownVal,
                      isExpanded: true,
                      items: knownIds.map((id) => DropdownMenuItem(value: id, child: Text(id))).toList(),
                      onChanged: (val) {
                        setStateDialog(() {
                          dropdownVal = val;
                          idCtrl.text = val ?? '';
                        });
                      },
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                  },
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final String entered = idCtrl.text.trim();
                    if (!_scheduleByScouter.containsKey(entered)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('ID "$entered" not found in schedule.')),
                      );
                      return;
                    }
                    final list = _scheduleByScouter[entered]!;
                    final first = list.first;
                    setState(() {
                      _selectedScouterId = entered;
                      _selectedMatchNumber = first.match;
                    });
                    _applyAssignment(first);
                    Navigator.of(ctx).pop();
                  },
                  child: const Text('Use ID'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _applyAssignment(_Assignment a, {bool alsoSetScouter = true}) {
    final String scouter = _selectedScouterId ?? '';
    if (alsoSetScouter && _controllers.containsKey('scouterInitials')) {
      _controllers['scouterInitials']!.text = scouter;
      _formData['scouterInitials'] = scouter;
    }
    if (_controllers.containsKey('matchNumber')) {
      _controllers['matchNumber']!.text = a.match.toString();
      _formData['matchNumber'] = a.match.toString();
    }
    _formData['robot'] = _normalizeRobotPosition(a.position);
    if (_controllers.containsKey('teamNumber')) {
      _controllers['teamNumber']!.text = a.team.toString();
      _formData['teamNumber'] = a.team.toString();
    }
    setState(() {});
  }

  String _normalizeRobotPosition(String s) {
    final v = s.trim().toLowerCase();
    if (v.contains('blue')) {
      if (v.contains('1')) return 'Blue 1';
      if (v.contains('2')) return 'Blue 2';
      if (v.contains('3')) return 'Blue 3';
      return 'Blue 1';
    }
    if (v.contains('red')) {
      if (v.contains('1')) return 'Red 1';
      if (v.contains('2')) return 'Red 2';
      if (v.contains('3')) return 'Red 3';
      return 'Red 1';
    }
    return 'Blue 1';
  }

  _ParsedSchedule _parseScheduleText(String text) {
    final lines = text.split(RegExp(r'\r?\n'));
    String? evt;
    final List<_Assignment> items = [];
    for (final raw in lines) {
      final line = raw.trim();
      if (line.isEmpty || line.startsWith('#')) continue;
      if (line.toLowerCase().startsWith('event:')) {
        evt = line.substring(line.indexOf(':') + 1).trim();
        continue;
      }
      final parts = line
          .split(RegExp(r',|\t+|\s{2,}'))
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      if (parts.length < 4) continue;
      final String scouterId = parts[0];
      final int? match = int.tryParse(parts[1]);
      final String position = parts[2];
      final int? team = int.tryParse(parts[3]);
      if (match == null || team == null) continue;
      items.add(_Assignment(scouterId: scouterId, match: match, position: position, team: team));
    }
    final Map<String, List<_Assignment>> grouped = {};
    for (final a in items) {
      grouped.putIfAbsent(a.scouterId, () => []).add(a);
    }
    for (final v in grouped.values) {
      v.sort((a, b) => a.match.compareTo(b.match));
    }
    return _ParsedSchedule(eventName: evt, assignments: items, groupedByScouter: grouped);
  }

  

  Widget _buildScheduleHeaderCard() {
    if (_selectedScouterId == null) return const SizedBox.shrink();
    final List<_Assignment> list = _scheduleByScouter[_selectedScouterId!] ?? [];
    if (list.isEmpty) return const SizedBox.shrink();
    final int currentMatch = _selectedMatchNumber ?? list.first.match;
    final _Assignment current = list.firstWhere(
      (a) => a.match == currentMatch,
      orElse: () => list.first,
    );
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 5.0),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _eventName != null ? 'Event: ${_eventName!}' : 'Schedule Loaded',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text('Scouter: ${_selectedScouterId!}', style: const TextStyle(color: Colors.white70)),
              ],
            ),
            const SizedBox(height: 8),
            InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Select Match',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(vertical: 0.0, horizontal: 12.0),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: current.match,
                  isExpanded: true,
                  items: list
                      .map((a) => DropdownMenuItem<int>(
                            value: a.match,
                            child: Text('Match ${a.match} — ${a.position} — Team ${a.team}'),
                          ))
                      .toList(),
                  onChanged: (val) {
                    if (val == null) return;
                    final _Assignment sel = list.firstWhere((a) => a.match == val, orElse: () => list.first);
                    setState(() {
                      _selectedMatchNumber = sel.match;
                    });
                    _applyAssignment(sel);
                  },
                ),
              ),
            ),
            const SizedBox(height: 6),
            const Text('Auto-fills scouter, match, position, and team.', style: TextStyle(fontSize: 12, color: Colors.white70)),
          ],
        ),
      ),
    );
  }

  Widget _buildField(_FieldConfig field) {
    switch (field.type) {
      case 'text':
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6.0),
          child: TextField(
            controller: _controllers[field.key],
            decoration: InputDecoration(
              labelText: field.label,
              contentPadding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 12.0),
            ),
            onChanged: (val) => _formData[field.key] = val,
          ),
        );
      case 'number':
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6.0),
          child: TextField(
            controller: _controllers[field.key],
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: field.label,
              contentPadding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 12.0),
            ),
            onChanged: (val) => _formData[field.key] = val,
          ),
        );
      case 'dropdown':
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6.0),
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: field.label,
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.symmetric(vertical: 0.0, horizontal: 12.0),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _formData[field.key],
                isExpanded: true,
                items: field.options!.map<DropdownMenuItem<String>>((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (val) => setState(() => _formData[field.key] = val),
              ),
            ),
          ),
        );
      case 'switch':
        return SwitchListTile(
          title: Text(field.label),
          value: _formData[field.key] ?? false,
          onChanged: (val) => setState(() => _formData[field.key] = val),
          contentPadding: EdgeInsets.zero,
        );
      case 'counter':
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6.0),
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: field.label,
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.symmetric(vertical: 5.0, horizontal: 12.0),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Spacer(),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: (_formData[field.key] ?? 0) > 0
                          ? () => setState(() => _formData[field.key] = (_formData[field.key] ?? 0) - 1)
                          : null,
                      color: (_formData[field.key] ?? 0) > 0 ? Colors.redAccent : Colors.grey,
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      tooltip: 'Decrease',
                    ),
                    SizedBox(
                      width: 30,
                      child: Text(
                        '${_formData[field.key] ?? 0}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: () => setState(() => _formData[field.key] = (_formData[field.key] ?? 0) + 1),
                      color: Colors.greenAccent,
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      tooltip: 'Increase',
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildTabContent(_SectionConfig section) {
    final widgets = section.fields.map(_buildField).toList();
    
    // Add schedule header for PREMATCH section
    if (section.title.toUpperCase().contains('PREMATCH') && _selectedScouterId != null) {
      widgets.insert(0, _buildScheduleHeaderCard());
    }
    
    // Add commit/reset buttons for ENDGAME section
    if (section.title.toUpperCase().contains('ENDGAME')) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.qr_code_scanner, size: 18),
                  label: const Text('Commit'),
                  onPressed: _commitData,
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Reset'),
                  onPressed: _resetForm,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    backgroundColor: Colors.grey[700],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    final mid = (widgets.length / 2).ceil();
    final left = widgets.sublist(0, mid);
    final right = widgets.sublist(mid);
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth > 800;
        if (!wide) {
          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Column(children: widgets),
          );
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Column(children: left)),
              const SizedBox(width: 10),
              Expanded(child: Column(children: right)),
            ],
          ),
        );
      },
    );
  }

  void _commitData() {
    final List<String> data = [];
    final List<String> columnHeaders = [];
    final Map<String, dynamic> scoutingDataMap = {};
    
    for (final section in _sections) {
      for (final field in section.fields) {
        columnHeaders.add(field.label);
        String value;
        dynamic rawValue;
        if (field.type == 'text' || field.type == 'number') {
          value = _controllers[field.key]?.text ?? '';
          rawValue = value;
        } else {
          rawValue = _formData[field.key];
          value = rawValue?.toString() ?? '';
        }
        data.add(value);
        scoutingDataMap[field.key] = rawValue;
      }
    }
    
    final String qrData = data.join('\t');
    final String columnData = columnHeaders.join(',');
    
    // Send data to external Firebase if enabled (async, non-blocking)
    // We don't await this so the QR code dialog shows immediately
    // Success/error feedback is shown via SnackBar from within the method
    if (_externalFirebaseEnabled && _selectedDatabaseTarget != null) {
      // Format data for database and generate path
      final formattedData = _formatDataForDatabase(scoutingDataMap);
      final path = _generateDatabasePath(scoutingDataMap);
      _sendDataToExternalFirebase(path, formattedData);
    }
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Scan QR Code'),
          content: SizedBox(
            width: 250,
            height: 250,
            child: QrImageView(
              data: qrData,
              version: QrVersions.auto,
              size: 250.0,
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              gapless: false,
              errorCorrectionLevel: QrErrorCorrectLevel.M,
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Copy Info'),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: qrData));
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('QR data copied to clipboard!')),
                );
              },
            ),
            TextButton(
              child: const Text('Copy Columns'),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: columnData));
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Column names (CSV) copied to clipboard!')),
                );
              },
            ),
            TextButton(
              child: const Text('Close'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _resetForm() {
    setState(() {
      for (final section in _sections) {
        for (final field in section.fields) {
          if (field.type == 'text' || field.type == 'number') {
            _controllers[field.key]?.clear();
          } else if (field.type == 'dropdown' && field.options != null && field.options!.isNotEmpty) {
            _formData[field.key] = field.options![0];
          } else if (field.type == 'switch') {
            _formData[field.key] = false;
          } else if (field.type == 'counter') {
            _formData[field.key] = 0;
          }
        }
      }
    });
  }

  @override
  void dispose() {
    _ytController?.close();
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_configLoaded) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return DefaultTabController(
      length: _sections.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('OVERTURE REEFSCAPE QR SCOUTING OFFICIAL'),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.ondemand_video),
              tooltip: 'Open YouTube Video',
              onPressed: _promptForYouTubeLink,
            ),
            IconButton(
              icon: const Icon(Icons.upload_file),
              tooltip: 'Load Schedule (.txt)',
              onPressed: _pickAndLoadSchedule,
            ),
            IconButton(
              icon: const Icon(Icons.badge),
              tooltip: 'Select Scouter ID',
              onPressed: _scheduleByScouter.isEmpty ? null : _promptForScouterId,
            ),
            IconButton(
              icon: const Icon(Icons.folder_open),
              tooltip: 'Load Config',
              onPressed: _pickAndLoadConfig,
            ),
          ],
          bottom: TabBar(
            isScrollable: true,
            tabs: _sections.map((s) => Tab(text: s.title)).toList(),
          ),
        ),
        body: Column(
          children: [
            // Scrollable header area for video only
            if (_showVideo)
              Flexible(
                flex: 0,
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(10.0),
                    child: _buildYouTubeCard(),
                  ),
                ),
              ),
            // Database selection dropdown
            if (_externalFirebaseEnabled && _databaseTargets.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Row(
                  children: [
                    const Text(
                      'Database Target:',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedDatabaseTarget?.name,
                            isExpanded: true,
                            items: _databaseTargets.map((target) {
                              return DropdownMenuItem<String>(
                                value: target.name,
                                child: Text(target.name),
                              );
                            }).toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() {
                                  _selectedDatabaseTarget = _databaseTargets.firstWhere(
                                    (t) => t.name == value,
                                    orElse: () => _databaseTargets.first,
                                  );
                                });
                              }
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            // Main form content - takes remaining space
            Expanded(
              child: TabBarView(
                children: _sections.map((section) => _buildTabContent(section)).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _promptForYouTubeLink() {
    final TextEditingController linkCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Paste YouTube Link'),
          content: TextField(
            controller: linkCtrl,
            decoration: const InputDecoration(hintText: 'https://youtu.be/... or https://www.youtube.com/watch?v=...'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final url = linkCtrl.text.trim();
                final vid = _extractYouTubeId(url);
                if (vid == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Invalid YouTube URL')),
                  );
                  return;
                }
                _loadYouTubeVideo(vid);
                Navigator.of(ctx).pop();
              },
              child: const Text('Load'),
            ),
          ],
        );
      },
    );
  }

  String? _extractYouTubeId(String url) {
    try {
      final uri = Uri.parse(url);
      if ((uri.host.contains('youtube.com') || uri.host.contains('youtu.be'))) {
        if (uri.host.contains('youtu.be')) {
          final id = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null;
          return (id != null && id.isNotEmpty) ? id : null;
        }
        if (uri.queryParameters.containsKey('v')) {
          final id = uri.queryParameters['v'];
          return (id != null && id.isNotEmpty) ? id : null;
        }
        if (uri.pathSegments.contains('embed')) {
          final idx = uri.pathSegments.indexOf('embed');
          if (idx >= 0 && idx + 1 < uri.pathSegments.length) {
            final id = uri.pathSegments[idx + 1];
            return (id.isNotEmpty) ? id : null;
          }
        }
      }
    } catch (_) {}
    return null;
  }

  void _loadYouTubeVideo(String videoId) {
    if (_ytController == null) {
      _ytController = YoutubePlayerController(
        params: const YoutubePlayerParams(
          showFullscreenButton: true,
          strictRelatedVideos: true,
          enableKeyboard: true,
          playsInline: true,
        ),
      );
    }
    _currentVideoId = videoId;
    _ytController!.loadVideoById(videoId: videoId);
    _ytController!.playVideo();
    setState(() => _showVideo = true);
  }

  Widget _buildYouTubeCard() {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 5.0),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Match Video', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Change Video',
                      icon: const Icon(Icons.link),
                      onPressed: _promptForYouTubeLink,
                    ),
                    IconButton(
                      tooltip: 'Close Video',
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        setState(() => _showVideo = false);
                        _ytController?.pauseVideo();
                      },
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            LayoutBuilder(
              builder: (context, constraints) {
                final screenH = MediaQuery.of(context).size.height;
                final width = constraints.maxWidth;
                final idealHeight = width / (16 / 9);
                // Cap player height between 180 and 40% of screen height to avoid overflow
                final maxAllowed = screenH * 0.4;
                final height = idealHeight.clamp(180.0, maxAllowed);
                return SizedBox(
                  height: height,
                  width: double.infinity,
                  child: _ytController == null
                      ? const Center(child: Text('No video loaded'))
                      : YoutubePlayer(controller: _ytController!),
                );
              },
            ),
            if (_currentVideoId != null)
              Padding(
                padding: const EdgeInsets.only(top: 6.0),
                child: Text('Video ID: $_currentVideoId', style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ),
          ],
        ),
      ),
    );
  }
}