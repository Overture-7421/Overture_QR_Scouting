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
      title: 'RebuiltQR',
      theme: ThemeData.dark().copyWith(
        primaryColor: Colors.deepPurpleAccent,
        scaffoldBackgroundColor: const Color(0xFF0A0A0A),
        cardColor: const Color(0xFF1A1A1A),
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

class _ScoutingHomePageState extends State<ScoutingHomePage> with SingleTickerProviderStateMixin {
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

  // Tab controller for navigation
  TabController? _tabController;

  // YouTube state
  YoutubePlayerController? _ytController;
  bool _showVideo = false;
  String? _currentVideoId;

  // External Firebase state
  String? _externalDatabaseURL;
  bool _externalFirebaseEnabled = false;
  FirebaseApp? _externalFirebaseApp;

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
      _tabController = TabController(length: _sections.length, vsync: this);
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

  Future<void> _sendDataToExternalFirebase(Map<String, dynamic> scoutingData) async {
    if (!_externalFirebaseEnabled || _externalFirebaseApp == null) {
      return;
    }

    try {
      final DatabaseReference ref = FirebaseDatabase.instanceFor(
        app: _externalFirebaseApp!,
      ).ref('scouting_data');
      
      // Add timestamp to data
      final dataWithTimestamp = {
        ...scoutingData,
        'timestamp': ServerValue.timestamp,
      };
      
      // Push data to database
      await ref.push().set(dataWithTimestamp);
      
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
          _tabController?.dispose();
          _tabController = TabController(length: _sections.length, vsync: this);
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
    return Container(
      margin: const EdgeInsets.only(bottom: 20.0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF2A2A2A),
            Color(0xFF1F1F1F),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.deepPurpleAccent.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF9C4DFF), Color(0xFF7C4DFF)],
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.event, size: 20, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _eventName != null ? _eventName! : 'Schedule Loaded',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.deepPurpleAccent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.deepPurpleAccent.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.person, size: 14, color: Colors.deepPurpleAccent),
                      const SizedBox(width: 6),
                      Text(
                        _selectedScouterId!,
                        style: const TextStyle(
                          color: Colors.deepPurpleAccent,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF1A1A1A),
                    Color(0xFF151515),
                  ],
                ),
              ),
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Match Selection',
                  labelStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFB0B0B0),
                    letterSpacing: 0.5,
                  ),
                  floatingLabelStyle: const TextStyle(
                    color: Colors.deepPurpleAccent,
                    fontWeight: FontWeight.bold,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: current.match,
                    isExpanded: true,
                    icon: const Icon(Icons.keyboard_arrow_down, color: Colors.deepPurpleAccent),
                    items: list
                        .map((a) => DropdownMenuItem<int>(
                              value: a.match,
                              child: Text(
                                'Match ${a.match} — ${a.position} — Team ${a.team}',
                                style: const TextStyle(fontWeight: FontWeight.w500),
                              ),
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
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.deepPurpleAccent.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: const [
                  Icon(Icons.auto_awesome, size: 14, color: Colors.deepPurpleAccent),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Auto-fills scouter, match, position, and team.',
                      style: TextStyle(fontSize: 11, color: Colors.white60, fontWeight: FontWeight.w500),
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

  Widget _buildField(_FieldConfig field) {
    switch (field.type) {
      case 'text':
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 10.0),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF1F1F1F),
                  Color(0xFF2A2A2A),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: TextField(
              controller: _controllers[field.key],
              decoration: InputDecoration(
                labelText: field.label,
                labelStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFB0B0B0),
                  letterSpacing: 0.5,
                ),
                floatingLabelStyle: const TextStyle(
                  color: Colors.deepPurpleAccent,
                  fontWeight: FontWeight.bold,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 20.0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Colors.deepPurpleAccent, width: 2.5),
                ),
              ),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
              onChanged: (val) => _formData[field.key] = val,
            ),
          ),
        );
      case 'number':
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 10.0),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF1F1F1F),
                  Color(0xFF2A2A2A),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: TextField(
              controller: _controllers[field.key],
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: field.label,
                labelStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFB0B0B0),
                  letterSpacing: 0.5,
                ),
                floatingLabelStyle: const TextStyle(
                  color: Colors.deepPurpleAccent,
                  fontWeight: FontWeight.bold,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 20.0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Colors.deepPurpleAccent, width: 2.5),
                ),
              ),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
              onChanged: (val) => _formData[field.key] = val,
            ),
          ),
        );
      case 'dropdown':
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 10.0),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF1F1F1F),
                  Color(0xFF2A2A2A),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: field.label,
                labelStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFB0B0B0),
                  letterSpacing: 0.5,
                ),
                floatingLabelStyle: const TextStyle(
                  color: Colors.deepPurpleAccent,
                  fontWeight: FontWeight.bold,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 20.0),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _formData[field.key],
                  isExpanded: true,
                  icon: const Icon(Icons.keyboard_arrow_down, color: Colors.deepPurpleAccent),
                  items: field.options!.map<DropdownMenuItem<String>>((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                    );
                  }).toList(),
                  onChanged: (val) => setState(() => _formData[field.key] = val),
                ),
              ),
            ),
          ),
        );
      case 'switch':
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 10.0),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF1F1F1F),
                  Color(0xFF2A2A2A),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: SwitchListTile(
              title: Text(
                field.label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
              value: _formData[field.key] ?? false,
              onChanged: (val) => setState(() => _formData[field.key] = val),
              contentPadding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
            ),
          ),
        );
      case 'counter':
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 10.0),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF1F1F1F),
                  Color(0xFF2A2A2A),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    field.label,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFB0B0B0),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(50),
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFF0D0D0D),
                            Color(0xFF1A1A1A),
                          ],
                        ),
                        border: Border.all(
                          color: Colors.deepPurpleAccent.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: (_formData[field.key] ?? 0) > 0
                                  ? () => setState(() => _formData[field.key] = (_formData[field.key] ?? 0) - 1)
                                  : null,
                              borderRadius: BorderRadius.circular(25),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: (_formData[field.key] ?? 0) > 0
                                      ? LinearGradient(
                                          colors: [Colors.red[400]!, Colors.red[600]!],
                                        )
                                      : null,
                                  color: (_formData[field.key] ?? 0) > 0 ? null : Colors.grey[800],
                                ),
                                child: Icon(
                                  Icons.remove,
                                  color: (_formData[field.key] ?? 0) > 0 ? Colors.white : Colors.grey[600],
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                          Container(
                            width: 80,
                            alignment: Alignment.center,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              '${_formData[field.key] ?? 0}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Colors.deepPurpleAccent,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => setState(() => _formData[field.key] = (_formData[field.key] ?? 0) + 1),
                              borderRadius: BorderRadius.circular(25),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    colors: [Colors.green[400]!, Colors.green[600]!],
                                  ),
                                ),
                                child: const Icon(
                                  Icons.add,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
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

    // Determine current section index
    final int currentIndex = _sections.indexOf(section);
    final bool isLastSection = currentIndex == _sections.length - 1;

    // Add navigation/action buttons at the bottom
    if (isLastSection) {
      // ENDGAME section - show Commit and Reset buttons
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(top: 32.0, bottom: 16.0),
          child: Column(
            children: [
              // Commit button (primary action)
              Container(
                width: double.infinity,
                height: 64,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF9C4DFF),
                      Color(0xFF7C4DFF),
                      Color(0xFF6A3DE8),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.deepPurpleAccent.withOpacity(0.5),
                      blurRadius: 20,
                      spreadRadius: 0,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _commitData,
                    borderRadius: BorderRadius.circular(20),
                    child: Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.qr_code_scanner, size: 26, color: Colors.white),
                          SizedBox(width: 14),
                          Text(
                            'COMMIT DATA',
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.5,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              // Reset button (secondary action)
              Container(
                width: double.infinity,
                height: 56,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.2),
                    width: 2,
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFF2A2A2A).withOpacity(0.5),
                      const Color(0xFF1F1F1F).withOpacity(0.5),
                    ],
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _resetForm,
                    borderRadius: BorderRadius.circular(18),
                    child: Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.refresh_rounded, size: 22, color: Colors.white70),
                          SizedBox(width: 10),
                          Text(
                            'RESET FORM',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      // Other sections - show NEXT PERIOD button
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(top: 32.0, bottom: 16.0),
          child: Container(
            width: double.infinity,
            height: 64,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF9C4DFF),
                  Color(0xFF7C4DFF),
                  Color(0xFF6A3DE8),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.deepPurpleAccent.withOpacity(0.5),
                  blurRadius: 20,
                  spreadRadius: 0,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  if (_tabController != null && currentIndex < _sections.length - 1) {
                    _tabController!.animateTo(currentIndex + 1);
                  }
                },
                borderRadius: BorderRadius.circular(20),
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Text(
                        'NEXT PERIOD',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(width: 14),
                      Icon(Icons.arrow_forward_rounded, size: 26, color: Colors.white),
                    ],
                  ),
                ),
              ),
            ),
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(children: widgets),
          );
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Column(children: left)),
              const SizedBox(width: 20),
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
        if (field.type == 'text' || field.type == 'number') {
          value = _controllers[field.key]?.text ?? '';
        } else {
          value = _formData[field.key]?.toString() ?? '';
        }
        data.add(value);
        scoutingDataMap[field.key] = value;
      }
    }
    
    final String qrData = data.join('\t');
    final String columnData = columnHeaders.join(',');
    
    // Send data to external Firebase if enabled (async, non-blocking)
    // We don't await this so the QR code dialog shows immediately
    // Success/error feedback is shown via SnackBar from within the method
    _sendDataToExternalFirebase(scoutingDataMap);
    
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
    _tabController?.dispose();
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_configLoaded || _tabController == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF0A0A0A),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF9C4DFF), Color(0xFF7C4DFF)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.qr_code_scanner, size: 50, color: Colors.white),
              ),
              const SizedBox(height: 24),
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.deepPurpleAccent),
              ),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        title: ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xFFB388FF), Color(0xFF7C4DFF)],
          ).createShader(bounds),
          child: const Text(
            'Overture RebuiltQR',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.0,
              color: Colors.white,
            ),
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: const Color(0xFF0A0A0A),
        actions: [
          _buildAppBarIconButton(Icons.ondemand_video_rounded, 'YouTube Video', _promptForYouTubeLink),
          _buildAppBarIconButton(Icons.upload_file_rounded, 'Load Schedule', _pickAndLoadSchedule),
          _buildAppBarIconButton(
            Icons.badge_rounded,
            'Select Scouter',
            _scheduleByScouter.isEmpty ? null : _promptForScouterId,
          ),
          _buildAppBarIconButton(Icons.folder_open_rounded, 'Load Config', _pickAndLoadConfig),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Column(
            children: [
              TabBar(
                controller: _tabController,
                isScrollable: true,
                indicatorColor: Colors.transparent,
                indicator: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF9C4DFF), Color(0xFF7C4DFF)],
                  ),
                ),
                labelStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white54,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                tabs: _sections.map((s) => Tab(
                  height: 42,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text(s.title.toUpperCase()),
                  ),
                )).toList(),
              ),
              const SizedBox(height: 4),
            ],
          ),
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
          // Main form content - takes remaining space
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: _sections.map((section) => _buildTabContent(section)).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBarIconButton(IconData icon, String tooltip, VoidCallback? onPressed) {
    return Container(
      margin: const EdgeInsets.only(right: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: onPressed != null ? Colors.white.withOpacity(0.05) : Colors.transparent,
      ),
      child: IconButton(
        icon: Icon(icon, size: 22),
        tooltip: tooltip,
        onPressed: onPressed,
        color: onPressed != null ? Colors.white : Colors.white24,
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
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 10.0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF2A2A2A),
            Color(0xFF1F1F1F),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.deepPurpleAccent.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF9C4DFF), Color(0xFF7C4DFF)],
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.ondemand_video_rounded, size: 20, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Match Video',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _promptForYouTubeLink,
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.link_rounded, color: Colors.white70, size: 20),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          setState(() => _showVideo = false);
                          _ytController?.pauseVideo();
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final screenH = MediaQuery.of(context).size.height;
                  final width = constraints.maxWidth;
                  final idealHeight = width / (16 / 9);
                  // Cap player height between 180 and 40% of screen height to avoid overflow
                  final maxAllowed = screenH * 0.4;
                  final height = idealHeight.clamp(180.0, maxAllowed);
                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.black,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    height: height,
                    width: double.infinity,
                    child: _ytController == null
                        ? const Center(child: Text('No video loaded'))
                        : YoutubePlayer(controller: _ytController!),
                  );
                },
              ),
            ),
            if (_currentVideoId != null)
              Padding(
                padding: const EdgeInsets.only(top: 12.0),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.deepPurpleAccent.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.play_circle_outline, size: 14, color: Colors.deepPurpleAccent),
                      const SizedBox(width: 8),
                      Text(
                        'Video ID: $_currentVideoId',
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}