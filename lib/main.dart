import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart'; // Import QR package
import 'package:flutter/services.dart'; // Import for Clipboard

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

class _ScoutingHomePageState extends State<ScoutingHomePage> {
  // --- State Variables ---

  // Prematch
  final TextEditingController _scouterInitialsController = TextEditingController();
  final TextEditingController _matchNumberController = TextEditingController();
  String? _robotValue = 'Blue 1'; // Default value
  bool _futureAlliance = false;
  final TextEditingController _teamNumberController = TextEditingController();
  String? _startingPosition = 'Middle'; // Default value
  bool _noShow = false;

  // Autonomous
  bool _moved = false;
  int _coralL1Auto = 0;
  int _coralL2Auto = 0;
  int _coralL3Auto = 0;
  int _coralL4Auto = 0;
  int _bargeAlgaeAuto = 0;
  int _processorAlgaeAuto = 0;
  bool _dislodgedAlgaeAuto = false; // Assuming this toggle is for Auto
  int _autoFoul = 0;

  // Teleop
  bool _dislodgedAlgaeTeleop = false;
  String? _pickupLocation = 'Ground'; // Default value
  int _coralL1Teleop = 0;
  int _coralL2Teleop = 0;
  int _coralL3Teleop = 0;
  int _coralL4Teleop = 0;
  int _bargeAlgaeTeleop = 0;
  int _processorAlgaeTeleop = 0;
  bool _crossedFieldDefense = false;
  bool _tippedFell = false;
  int _touchedOpposingCage = 0;
  bool _died = false;

  // Endgame
  String? _endPosition = 'Shallow Climb'; // Default value
  bool _broke = false;
  bool _defended = false;
  bool _coralHpMistake = false;
  String? _yellowRedCard = 'None'; // Default value

  // Dropdown options (adjust as needed)
  final List<String> _robotOptions = ['Blue 1', 'Blue 2', 'Blue 3', 'Red 1', 'Red 2', 'Red 3'];
  final List<String> _startPositionOptions = ['Processor Side', 'Middle', 'No-Processor Side'];
  final List<String> _pickupLocationOptions = ['Ground', 'Source', 'Both'];
  final List<String> _endPositionOptions = ['None', 'Parked', 'Shallow Climb', 'Deep Climb'];
  final List<String> _cardOptions = ['None', 'Yellow Card', 'Red Card'];

  // Define column headers in the correct order
  static const List<String> _columnHeaders = [
    'Scouter Initials',
    'Match Number',
    'Robot',
    'Future Alliance',
    'Team Number',
    'Starting Position',
    'No Show',
    'Moved (Auto)',
    'Coral L1 (Auto)',
    'Coral L2 (Auto)',
    'Coral L3 (Auto)',
    'Coral L4 (Auto)',
    'Barge Algae (Auto)',
    'Processor Algae (Auto)',
    'Dislodged Algae (Auto)',
    'Foul (Auto)',
    'Dislodged Algae (Teleop)',
    'Pickup Location',
    'Coral L1 (Teleop)',
    'Coral L2 (Teleop)',
    'Coral L3 (Teleop)',
    'Coral L4 (Teleop)',
    'Barge Algae (Teleop)',
    'Processor Algae (Teleop)',
    'Crossed Field/Defense',
    'Tipped/Fell',
    'Touched Opposing Cage',
    'Died',
    'End Position',
    'Broke',
    'Defended',
    'Coral HP Mistake',
    'Yellow/Red Card',
  ];

  // --- Helper Functions ---

  // Builds a section card with a title
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
            ...children, // Spread operator to insert list elements
          ],
        ),
      ),
    );
  }

  // Builds a text input field
  Widget _buildTextField(String label, TextEditingController controller, {TextInputType keyboardType = TextInputType.text}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          contentPadding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 12.0),
        ),
      ),
    );
  }

  // Builds a dropdown field
  Widget _buildDropdownField(String label, String? currentValue, List<String> options, ValueChanged<String?> onChanged) {
     return Padding(
       padding: const EdgeInsets.symmetric(vertical: 6.0),
       child: InputDecorator(
         decoration: InputDecoration(
           labelText: label,
           border: const OutlineInputBorder(),
           contentPadding: const EdgeInsets.symmetric(vertical: 0.0, horizontal: 12.0),
         ),
         child: DropdownButtonHideUnderline(
           child: DropdownButton<String>(
             value: currentValue,
             isExpanded: true,
             items: options.map<DropdownMenuItem<String>>((String value) {
               return DropdownMenuItem<String>(
                 value: value,
                 child: Text(value),
               );
             }).toList(),
             onChanged: onChanged,
             // Adding dropdown specific styling if needed, otherwise relies on theme
             // style: TextStyle(color: Colors.white),
             // dropdownColor: const Color(0xFF2A2A2A),
           ),
         ),
       ),
     );
   }

  // Builds a switch tile
  Widget _buildSwitchTile(String title, bool value, ValueChanged<bool> onChanged) {
    return SwitchListTile(
      title: Text(title),
      value: value,
      onChanged: onChanged,
      contentPadding: EdgeInsets.zero,
      // Active track color defined in theme
      // activeColor: Colors.deepPurpleAccent, // Thumb color defined in theme
    );
  }

  // Builds a counter field
  Widget _buildCounterField(String label, int currentValue, VoidCallback onDecrement, VoidCallback onIncrement) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: InputDecorator(
         decoration: InputDecoration(
           labelText: label,
           border: const OutlineInputBorder(),
           contentPadding: const EdgeInsets.symmetric(vertical: 5.0, horizontal: 12.0),
         ),
         child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Flexible prevents overflow if label is too long
            // Flexible(child: Text(label, style: const TextStyle(fontSize: 16))),
            const Spacer(), // Push counter to the right
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: currentValue > 0 ? onDecrement : null, // Disable if 0
                  color: currentValue > 0 ? Colors.redAccent : Colors.grey,
                  constraints: const BoxConstraints(), // Remove extra padding
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  tooltip: 'Decrease',
                ),
                SizedBox(
                  width: 30, // Fixed width for the number
                  child: Text(
                    '$currentValue',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: onIncrement,
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
  }

  // --- Data Handling ---

  void _commitData() {
    // 1. Gather all data points IN ORDER
    final List<String> data = [
      // Prematch
      _scouterInitialsController.text,
      _matchNumberController.text,
      _robotValue ?? '',
      _futureAlliance.toString(),
      _teamNumberController.text,
      _startingPosition ?? '',
      _noShow.toString(),
      // Autonomous
      _moved.toString(),
      _coralL1Auto.toString(),
      _coralL2Auto.toString(),
      _coralL3Auto.toString(),
      _coralL4Auto.toString(),
      _bargeAlgaeAuto.toString(),
      _processorAlgaeAuto.toString(),
      _dislodgedAlgaeAuto.toString(),
      _autoFoul.toString(),
      // Teleop
      _dislodgedAlgaeTeleop.toString(),
      _pickupLocation ?? '',
      _coralL1Teleop.toString(),
      _coralL2Teleop.toString(),
      _coralL3Teleop.toString(),
      _coralL4Teleop.toString(),
      _bargeAlgaeTeleop.toString(),
      _processorAlgaeTeleop.toString(),
      _crossedFieldDefense.toString(),
      _tippedFell.toString(),
      _touchedOpposingCage.toString(),
      _died.toString(),
      // Endgame
      _endPosition ?? '',
      _broke.toString(),
      _defended.toString(),
      _coralHpMistake.toString(),
      _yellowRedCard ?? '',
    ];

    // 2. Format as tab-separated string for QR, comma-separated for columns
    final String qrData = data.join('\t'); // Use tab as separator for QR data
    final String columnData = _columnHeaders.join(','); // Join headers with commas

    // 3. Show QR Code in a dialog
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Scan QR Code'),
          content: SizedBox(
            width: 250, // Adjust size as needed
            height: 250,
            child: QrImageView(
              data: qrData,
              version: QrVersions.auto,
              size: 250.0,
              backgroundColor: Colors.white, // QR code background
              foregroundColor: Colors.black, // QR code foreground
              gapless: false, // Recommended for better scanability
              errorCorrectionLevel: QrErrorCorrectLevel.M, // Medium error correction
            ),
          ),
          actions: <Widget>[
             TextButton(
              child: const Text('Copy Info'),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: qrData));
                Navigator.of(context).pop(); // Close dialog after copying
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('QR data copied to clipboard!')),
                );
              },
            ),
            TextButton(
              child: const Text('Copy Columns'),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: columnData));
                Navigator.of(context).pop(); // Close dialog after copying
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Column names (CSV) copied to clipboard!')), // Updated message
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
     print("QR Data String:\n$qrData"); // Optional: Print for debugging
     print("Column Headers String (CSV):\n$columnData"); // Optional: Print for debugging
  }

  void _resetForm() {
    setState(() {
      // Prematch - Keep Scouter Initials and Robot, Increment Match Number
      // _scouterInitialsController.clear(); // Keep scouter initials
      final currentMatchNumber = int.tryParse(_matchNumberController.text);
      if (currentMatchNumber != null) {
        _matchNumberController.text = (currentMatchNumber + 1).toString();
      } else {
        _matchNumberController.clear(); // Clear if not a valid number
      }
      // _robotValue = _robotOptions[0]; // Keep robot value
      _futureAlliance = false;
      _teamNumberController.clear();
      _startingPosition = _startPositionOptions[1]; // Reset to Middle
      _noShow = false;

      // Autonomous
      _moved = false;
      _coralL1Auto = 0;
      _coralL2Auto = 0;
      _coralL3Auto = 0;
      _coralL4Auto = 0;
      _bargeAlgaeAuto = 0;
      _processorAlgaeAuto = 0;
      _dislodgedAlgaeAuto = false;
      _autoFoul = 0;

      // Teleop
      _dislodgedAlgaeTeleop = false;
      _pickupLocation = _pickupLocationOptions[0]; // Reset to Ground
      _coralL1Teleop = 0;
      _coralL2Teleop = 0;
      _coralL3Teleop = 0;
      _coralL4Teleop = 0;
      _bargeAlgaeTeleop = 0;
      _processorAlgaeTeleop = 0;
      _crossedFieldDefense = false;
      _tippedFell = false;
      _touchedOpposingCage = 0;
      _died = false;

      // Endgame
      _endPosition = _endPositionOptions[2]; // Reset to Shallow Climb
      _broke = false;
      _defended = false;
      _coralHpMistake = false;
      _yellowRedCard = _cardOptions[0]; // Reset to None
    });
  }

  @override
  void dispose() {
    // Clean up the controllers when the widget is disposed.
    _scouterInitialsController.dispose();
    _matchNumberController.dispose();
    _teamNumberController.dispose();
    super.dispose();
  }

  // --- Build Method ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('OVERTURE REEFSCAPE QR SCOUTING OFFICIAL'), // Title from image
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(10.0),
        child: Column(
          children: [
            // --- Sections ---
            Row(
              crossAxisAlignment: CrossAxisAlignment.start, // Align cards top
              children: [
                // Column 1: Prematch & Autonomous
                Expanded(
                  child: Column(
                    children: [
                      // Prematch Section
                      _buildSectionCard('PREMATCH', [
                        _buildTextField('SCOUTER INITIALS', _scouterInitialsController),
                        _buildTextField('MATCH NUMBER', _matchNumberController, keyboardType: TextInputType.number),
                        _buildDropdownField('ROBOT', _robotValue, _robotOptions, (val) => setState(() => _robotValue = val)),
                        _buildSwitchTile('FUTURE ALLIANCE IN QUALY?', _futureAlliance, (val) => setState(() => _futureAlliance = val)),
                        _buildTextField('TEAM NUMBER', _teamNumberController, keyboardType: TextInputType.number),
                        _buildDropdownField('STARTING POSITION', _startingPosition, _startPositionOptions, (val) => setState(() => _startingPosition = val)),
                        _buildSwitchTile('NO SHOW', _noShow, (val) => setState(() => _noShow = val)),
                      ]),

                      // Autonomous Section
                      _buildSectionCard('AUTONOMOUS', [
                         _buildSwitchTile('MOVED?', _moved, (val) => setState(() => _moved = val)),
                         _buildCounterField('CORAL L1 SCORED', _coralL1Auto, () => setState(() => _coralL1Auto--), () => setState(() => _coralL1Auto++)),
                         _buildCounterField('CORAL L2 SCORED', _coralL2Auto, () => setState(() => _coralL2Auto--), () => setState(() => _coralL2Auto++)),
                         _buildCounterField('CORAL L3 SCORED', _coralL3Auto, () => setState(() => _coralL3Auto--), () => setState(() => _coralL3Auto++)),
                         _buildCounterField('CORAL L4 SCORED', _coralL4Auto, () => setState(() => _coralL4Auto--), () => setState(() => _coralL4Auto++)),
                         _buildCounterField('BARGE ALGAE SCORED', _bargeAlgaeAuto, () => setState(() => _bargeAlgaeAuto--), () => setState(() => _bargeAlgaeAuto++)),
                         _buildCounterField('PROCESSOR ALGAE SCORED', _processorAlgaeAuto, () => setState(() => _processorAlgaeAuto--), () => setState(() => _processorAlgaeAuto++)),
                         _buildSwitchTile('DISLODGED ALGAE?', _dislodgedAlgaeAuto, (val) => setState(() => _dislodgedAlgaeAuto = val)), // Assuming this belongs here
                         _buildCounterField('AUTO FOUL', _autoFoul, () => setState(() => _autoFoul--), () => setState(() => _autoFoul++)),
                      ]),
                    ],
                  ),
                ),
                const SizedBox(width: 10), // Spacing between columns

                // Column 2: Teleop & Endgame
                Expanded(
                  child: Column(
                    children: [
                      // Teleop Section
                      _buildSectionCard('TELEOP', [
                          _buildSwitchTile('DISLODGED ALGAE?', _dislodgedAlgaeTeleop, (val) => setState(() => _dislodgedAlgaeTeleop = val)), // Separate Teleop toggle
                          _buildDropdownField('PICKUP LOCATION', _pickupLocation, _pickupLocationOptions, (val) => setState(() => _pickupLocation = val)),
                          _buildCounterField('CORAL L1 SCORED', _coralL1Teleop, () => setState(() => _coralL1Teleop--), () => setState(() => _coralL1Teleop++)),
                          _buildCounterField('CORAL L2 SCORED', _coralL2Teleop, () => setState(() => _coralL2Teleop--), () => setState(() => _coralL2Teleop++)),
                          _buildCounterField('CORAL L3 SCORED', _coralL3Teleop, () => setState(() => _coralL3Teleop--), () => setState(() => _coralL3Teleop++)),
                          _buildCounterField('CORAL L4 SCORED', _coralL4Teleop, () => setState(() => _coralL4Teleop--), () => setState(() => _coralL4Teleop++)),
                          _buildCounterField('BARGE ALGAE SCORED', _bargeAlgaeTeleop, () => setState(() => _bargeAlgaeTeleop--), () => setState(() => _bargeAlgaeTeleop++)),
                          _buildCounterField('PROCESSOR ALGAE SCORED', _processorAlgaeTeleop, () => setState(() => _processorAlgaeTeleop--), () => setState(() => _processorAlgaeTeleop++)),
                          _buildSwitchTile('CROSSED FIELD/PLAYED DEFENSE?', _crossedFieldDefense, (val) => setState(() => _crossedFieldDefense = val)),
                          _buildSwitchTile('TIPPED/FELL OVER?', _tippedFell, (val) => setState(() => _tippedFell = val)),
                          _buildCounterField('TOUCHED OPPOSING CAGE', _touchedOpposingCage, () => setState(() => _touchedOpposingCage--), () => setState(() => _touchedOpposingCage++)),
                          _buildSwitchTile('DIED?', _died, (val) => setState(() => _died = val)),
                      ]),

                      // Endgame Section
                      _buildSectionCard('ENDGAME', [
                        _buildDropdownField('END POSITION', _endPosition, _endPositionOptions, (val) => setState(() => _endPosition = val)),
                        _buildSwitchTile('BROKE?', _broke, (val) => setState(() => _broke = val)),
                        _buildSwitchTile('DEFENDED?', _defended, (val) => setState(() => _defended = val)),
                        _buildSwitchTile('CORAL HP MISTAKE?', _coralHpMistake, (val) => setState(() => _coralHpMistake = val)),
                        _buildDropdownField('YELLOW/RED CARD', _yellowRedCard, _cardOptions, (val) => setState(() => _yellowRedCard = val)),
                      ]),
                    ],
                  ),
                ),
              ],
            ),

            // --- Action Buttons ---
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
                        backgroundColor: Colors.grey[700], // Different color for reset
                      ),
                                     ),
                   ),
                ],
              ),
            ),
            const SizedBox(height: 20), // Bottom padding
          ],
        ),
      ),
    );
  }
}