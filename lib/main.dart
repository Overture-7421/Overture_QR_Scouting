import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart'; // Import QR package
import 'package:flutter/services.dart'; // Import for Clipboard
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:file_picker/file_picker.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

void main() {
  runApp(const ScoutingApp());
}

class ScoutingApp extends StatelessWidget {
  const ScoutingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Overture reefscape Scouting',
      // Use a dark theme similar to the image
      theme: ThemeData.dark().copyWith(
        primaryColor: Colors.deepPurpleAccent,
        scaffoldBackgroundColor: const Color(0xFF121212), // Dark background
        cardColor: const Color(0xFF1E1E1E), // Slightly lighter card background
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.deepPurpleAccent),
          ),
          labelStyle: TextStyle(color: Colors.white70),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.deepPurpleAccent, // Button color
            foregroundColor: Colors.white, // Text color on button
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
            return null; // Default
          }),
          trackColor: MaterialStateProperty.resolveWith<Color?>((states) {
            if (states.contains(MaterialState.selected)) {
              return Colors.deepPurpleAccent.withOpacity(0.5);
            }
            return null; // Default
          }),
        ),
        dropdownMenuTheme: DropdownMenuThemeData(
          // filled: true, // Moved to InputDecorationTheme below
          // fillColor: const Color(0xFF2A2A2A), // Moved to InputDecorationTheme below
          inputDecorationTheme: const InputDecorationTheme( // Need InputDecorationTheme here for filled/fillColor
             filled: true, // Keep it here
             fillColor: Color(0xFF2A2A2A), // Keep it here
             border: InputBorder.none, // Optional: remove border if using filled style
          ),
          textStyle: const TextStyle(color: Colors.white), // Ensure text is visible
          menuStyle: MenuStyle(
             backgroundColor: MaterialStateProperty.all(const Color(0xFF2A2A2A)), // Background of the dropdown menu itself
          ),
          // iconEnabledColor: Colors.deepPurpleAccent, // This property doesn't exist directly on DropdownMenuThemeData
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

// ---------------------- Schedule Models ----------------------
class _Assignment {
  final String scouterId;
  final int match;
  final String position; // e.g., "Blue 1", "Red 3"
  final int team;
  const _Assignment({required this.scouterId, required this.match, required this.position, required this.team});
}

class _ParsedSchedule {
  final String? eventName;
  final List<_Assignment> assignments;
  final Map<String, List<_Assignment>> groupedByScouter;
  const _ParsedSchedule({required this.eventName, required this.assignments, required this.groupedByScouter});
}

class _ScoutingHomePageState extends State<ScoutingHomePage> {
  // --- State Variables ---
  Map<String, dynamic> _formData = {};
  List<_SectionConfig> _sections = [];
  bool _configLoaded = false;

  // --- Schedule State ---
  String? _eventName; // From schedule file header
  final Map<String, List<_Assignment>> _scheduleByScouter = {}; // scouterId -> assignments
  String? _selectedScouterId;
  int? _selectedMatchNumber; // currently selected match for scouter

  // Controllers for text fields
  final Map<String, TextEditingController> _controllers = {};

  // --- YouTube Player State ---
  YoutubePlayerController? _ytController;
  bool _showVideo = false;
  String? _currentVideoId;

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
          // Set default values
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load config: $e')),
        );
      }
    }
  }

  // ---------------------- Schedule (.txt) load & apply ----------------------
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

    // Prompt for scouter ID after successful load
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
                        SnackBar(content: Text('ID \"$entered\" not found in schedule.')),
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
    // Fill PREMATCH fields from assignment
    final String scouter = _selectedScouterId ?? '';
    if (alsoSetScouter && _controllers.containsKey('scouterInitials')) {
      _controllers['scouterInitials']!.text = scouter;
      _formData['scouterInitials'] = scouter;
    }
    if (_controllers.containsKey('matchNumber')) {
      _controllers['matchNumber']!.text = a.match.toString();
      _formData['matchNumber'] = a.match.toString();
    }
  // Robot dropdown
  _formData['robot'] = _normalizeRobotPosition(a.position);
    // Team number
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
    // default
    return 'Blue 1';
  }

  _ParsedSchedule _parseScheduleText(String text) {
    // Simple flexible format:
    // Event: <Event Name>
    // # comments allowed
    // scouterId, match, position, team
    // Example: JDO, 1, Blue 1, 1234
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
      // split by comma, tab, or multiple spaces
      final parts = line.split(RegExp(r',|\t+|\s{2,}'))
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
    // Group by scouter
  final Map<String, List<_Assignment>> grouped = {};
    for (final a in items) {
      grouped.putIfAbsent(a.scouterId, () => []).add(a);
    }
    // Sort each scouter's assignments by match
    for (final v in grouped.values) {
      v.sort((a, b) => a.match.compareTo(b.match));
    }
    return _ParsedSchedule(eventName: evt, assignments: items, groupedByScouter: grouped);
  }

  // Data types for schedule
  // ignore: unused_element
  String? get _currentEventName => _eventName;

  // ---------------------- UI helpers for schedule ----------------------
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
            Text('Auto-fills scouter, match, position, and team.', style: const TextStyle(fontSize: 12, color: Colors.white70)),
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

  Widget _buildSectionCard(String title, List<Widget> children) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 5.0),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.deepPurpleAccent[100],
              ),
            ),
            const SizedBox(height: 10),
            ...children,
          ],
        ),
      ),
    );
  }

  void _commitData() {
    // Gather all data points in order of config
    final List<String> data = [];
    final List<String> columnHeaders = [];
    for (final section in _sections) {
      for (final field in section.fields) {
        columnHeaders.add(field.label);
        if (field.type == 'text' || field.type == 'number') {
          data.add(_controllers[field.key]?.text ?? '');
        } else {
          data.add(_formData[field.key]?.toString() ?? '');
        }
      }
    }
    final String qrData = data.join('\t');
    final String columnData = columnHeaders.join(',');
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
    print("QR Data String:\n$qrData");
    print("Column Headers String (CSV):\n$columnData");
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
    return Scaffold(
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
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(10.0),
        child: Column(
          children: [
            if (_showVideo) _buildYouTubeCard(),
            // Schedule header (if a schedule is loaded and a scouter is selected)
            _buildScheduleHeaderCard(),
            // --- Sections ---
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    children: _sections
                        .sublist(0, (_sections.length / 2).ceil())
                        .map((section) => _buildSectionCard(
                              section.title,
                              section.fields.map(_buildField).toList(),
                            ))
                        .toList(),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    children: _sections
                        .sublist((_sections.length / 2).ceil())
                        .map((section) => _buildSectionCard(
                              section.title,
                              section.fields.map(_buildField).toList(),
                            ))
                        .toList(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5.0),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.qr_code_scanner),
                      label: const Text('Commit'),
                      onPressed: _commitData,
                      style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reset Form'),
                      onPressed: _resetForm,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        backgroundColor: Colors.grey[700],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // ---------------------- YouTube helpers ----------------------
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
        // youtu.be/<id>
        if (uri.host.contains('youtu.be')) {
          final id = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null;
          return (id != null && id.isNotEmpty) ? id : null;
        }
        // youtube.com/watch?v=<id>
        if (uri.queryParameters.containsKey('v')) {
          final id = uri.queryParameters['v'];
          return (id != null && id.isNotEmpty) ? id : null;
        }
        // youtube.com/embed/<id>
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
                        // pause video
                        _ytController?.pauseVideo();
                      },
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            AspectRatio(
              aspectRatio: 16 / 9,
              child: _ytController == null
                  ? const Center(child: Text('No video loaded'))
                  : YoutubePlayer(controller: _ytController!),
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