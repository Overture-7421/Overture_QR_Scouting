import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart'; // Import QR package
import 'package:flutter/services.dart'; // Import for Clipboard
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'bluealliance_screen.dart';

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

class _ScoutingHomePageState extends State<ScoutingHomePage> {
  // --- State Variables ---
  Map<String, dynamic> _formData = {};
  List<_SectionConfig> _sections = [];
  bool _configLoaded = false;

  // Controllers for text fields
  final Map<String, TextEditingController> _controllers = {};

  Future<File> _getUserConfigFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/config.json');
  }

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    try {
      String configString;
      if (!kIsWeb) {
        final userFile = await _getUserConfigFile();
        if (await userFile.exists()) {
          configString = await userFile.readAsString();
        } else {
          configString = await rootBundle.loadString('lib/config.json');
        }
      } else {
        configString = await rootBundle.loadString('lib/config.json');
      }

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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load config: $e')),
        );
      }
    }
  }

  Future<void> _pickAndLoadConfig() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['json']);
    if (result != null) {
      try {
        String configString;
        if (result.files.single.bytes != null) {
          configString = String.fromCharCodes(result.files.single.bytes!);
        } else if (result.files.single.path != null && !kIsWeb) {
          configString = await File(result.files.single.path!).readAsString();
        } else {
          throw 'Unsupported platform or missing file bytes.';
        }
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
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Config loaded for this session.')),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load config: $e')),
        );
      }
    }
  }

  Future<void> _importConfigAndSaveDefault() async {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saving default config is not supported on Web. Use Load Config instead.')),
      );
      return;
    }
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['json']);
    if (result != null) {
      try {
        String configString;
        if (result.files.single.bytes != null) {
          configString = String.fromCharCodes(result.files.single.bytes!);
        } else if (result.files.single.path != null) {
          configString = await File(result.files.single.path!).readAsString();
        } else {
          throw 'Unsupported selection.';
        }
        final Map<String, dynamic> configJson = json.decode(configString);
        if (configJson['sections'] is! List) {
          throw 'Invalid config format: missing sections array';
        }
        final file = await _getUserConfigFile();
        await file.writeAsString(configString);
        await _loadConfig();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Default config saved to ${file.path}')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to save config: $e')),
          );
        }
      }
    }
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
        final int current = (_formData[field.key] ?? 0) as int;
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
                      onPressed: current > 0
                          ? () => setState(() => _formData[field.key] = current - 1)
                          : null,
                      color: current > 0 ? Colors.redAccent : Colors.grey,
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      tooltip: 'Decrease',
                    ),
                    SizedBox(
                      width: 36,
                      child: Text(
                        '$current',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: () => setState(() => _formData[field.key] = current + 1),
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
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.deepPurpleAccent.withOpacity(0.2)),
      ),
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 5.0),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.assignment, color: Colors.deepPurpleAccent[100]),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurpleAccent[100],
                  ),
                ),
              ],
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
    final sectionWidgets = _sections
        .map((section) => _buildSectionCard(
              section.title,
              section.fields.map(_buildField).toList(),
            ))
        .toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('OVERTURE REEFSCAPE QR SCOUTING OFFICIAL'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.api),
            tooltip: 'BlueAlliance Integration',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const BlueAllianceScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.folder_open),
            tooltip: 'Load Config (session only)',
            onPressed: _pickAndLoadConfig,
          ),
          IconButton(
            icon: const Icon(Icons.upload_file),
            tooltip: 'Import as Default',
            onPressed: _importConfigAndSaveDefault,
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 900;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(10.0),
            child: isWide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          children: sectionWidgets
                              .sublist(0, (sectionWidgets.length / 2).ceil()),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          children: sectionWidgets
                              .sublist((sectionWidgets.length / 2).ceil()),
                        ),
                      ),
                    ],
                  )
                : Column(children: sectionWidgets),
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('Commit'),
                  onPressed: _commitData,
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reset Form'),
                  onPressed: _resetForm,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor: Colors.grey[700],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}