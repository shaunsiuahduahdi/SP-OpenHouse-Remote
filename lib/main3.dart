import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle, Uint8List;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'dart:convert';
import 'dart:math';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:archive/archive.dart';
import 'package:file_saver/file_saver.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (e) {
    debugPrint('Firebase already initialized: $e');
  }
  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});
  @override
  Widget build(BuildContext ctx) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'System Reboot',
    theme: ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF060A14),
      colorScheme: const ColorScheme.dark(primary: Color(0xFF00DDFF), secondary: Color(0xFF00FF88), surface: Color(0xFF0C1018)),
      fontFamily: 'RobotoMono',
      appBarTheme: const AppBarTheme(backgroundColor: Color(0xFF0A0E18), elevation: 0, centerTitle: true),
      cardTheme: CardThemeData(color: const Color(0xFF0C1420), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFF1A2A3A)))),
      elevatedButtonTheme: ElevatedButtonThemeData(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00DDFF), foregroundColor: const Color(0xFF060A14), padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)))),
      inputDecorationTheme: InputDecorationTheme(filled: true, fillColor: const Color(0xFF0A1420), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF1A3A4A))), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF00DDFF), width: 2))),
    ),
    home: const Nav(),
  );
}

class Nav extends StatefulWidget {
  const Nav({super.key});
  @override
  State<Nav> createState() => _NavS();
}

class _NavS extends State<Nav> {
  int _t = 0;
  @override
  Widget build(BuildContext ctx) => Scaffold(
    body: IndexedStack(index: _t, children: const [RemotePage(), QuestionsPage()]),
    bottomNavigationBar: BottomNavigationBar(
      currentIndex: _t, onTap: (i) => setState(() => _t = i),
      backgroundColor: const Color(0xFF0A0E18), selectedItemColor: const Color(0xFF00DDFF), unselectedItemColor: const Color(0xFF334455),
      items: const [BottomNavigationBarItem(icon: Icon(Icons.gamepad), label: 'REMOTE'), BottomNavigationBarItem(icon: Icon(Icons.quiz), label: 'QUESTIONS')],
    ),
  );
}

// ═══════════════════════════════════════
// REMOTE
// ═══════════════════════════════════════
class RemotePage extends StatefulWidget {
  const RemotePage({super.key});
  @override
  State<RemotePage> createState() => _RemoteS();
}

class _RemoteS extends State<RemotePage> {
  String? _sid;
  final _cc = TextEditingController();
  bool _on = false;
  String _phase = 'menu';
  String _mode = 'single';

  String _diff = 'hard';
  Map<String, bool> _obs = {
    'walls': true, 'trivia': true, 'cables': true, 'virus': true,
    'counter': true, 'hold': true, 'jumba': true, 'security': true,
  };

  DocumentReference get _ref =>
      FirebaseFirestore.instance.collection('remote_sessions').doc(_sid);

  Future<void> _connect() async {
    final code = _cc.text.trim().toUpperCase();
    if (code.isEmpty) return;
    try {
      final doc = await FirebaseFirestore.instance.collection('remote_sessions').doc(code).get();
      if (!doc.exists) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Session not found'), backgroundColor: Color(0xFFFF3355)));
        return;
      }
      setState(() { _sid = code; _on = true; _phase = 'menu'; });
      await _ref.update({'controllerConnected': true});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: const Color(0xFFFF3355)));
    }
  }

  Future<void> _cmd(String c, [Map<String, dynamic>? d]) async {
    if (_sid == null) return;
    try {
      await _ref.update({'command': c, 'commandData': d ?? {}, 'commandTimestamp': FieldValue.serverTimestamp()});
    } catch (_) {}
  }

  void _disc() {
    if (_sid != null) _ref.update({'controllerConnected': false}).catchError((_) {});
    setState(() { _sid = null; _on = false; _phase = 'menu'; });
  }

  @override
  Widget build(BuildContext ctx) {
    return Scaffold(
      appBar: AppBar(title: const Text('REMOTE', style: TextStyle(letterSpacing: 3, fontWeight: FontWeight.w900))),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: !_on ? _connectUI() : Column(children: [
          Card(child: ListTile(
            leading: const Icon(Icons.link, color: Color(0xFF00FF88)),
            title: Text('SESSION: $_sid', style: const TextStyle(color: Color(0xFF00FF88), letterSpacing: 2, fontSize: 14)),
            trailing: IconButton(icon: const Icon(Icons.close, color: Color(0xFFFF3355)), onPressed: _disc),
          )),
          const SizedBox(height: 16),
          Expanded(child: SingleChildScrollView(child: _phaseUI())),
        ]),
      ),
    );
  }

  Widget _connectUI() => Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    const Icon(Icons.link, size: 56, color: Color(0xFF1A3A4A)),
    const SizedBox(height: 16),
    const Text('ENTER SESSION CODE', style: TextStyle(color: Color(0xFF6688AA), letterSpacing: 2, fontSize: 12)),
    const SizedBox(height: 12),
    TextField(
      controller: _cc, textAlign: TextAlign.center,
      style: const TextStyle(fontSize: 28, letterSpacing: 8, color: Color(0xFF00DDFF)),
      textCapitalization: TextCapitalization.characters,
      decoration: const InputDecoration(hintText: '_ _ _ _', hintStyle: TextStyle(color: Color(0xFF1A3A4A), fontSize: 28, letterSpacing: 8)),
      onSubmitted: (_) => _connect(),
    ),
    const SizedBox(height: 16),
    SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _connect, child: const Text('CONNECT'))),
  ]);

  Widget _phaseUI() {
    switch (_phase) {
      case 'menu': return _menuUI();
      case 'start': return _configUI();
      case 'cd': case 'play': return _playingUI();
      case 'go': return _gameOverUI();
      default: return _menuUI();
    }
  }

  Widget _menuUI() => Column(children: [
    const Text('SELECT MODE', style: TextStyle(color: Color(0xFF6688AA), letterSpacing: 2, fontSize: 12, fontWeight: FontWeight.bold)),
    const SizedBox(height: 20),
    SizedBox(width: double.infinity, height: 80, child: ElevatedButton(
      onPressed: () { _cmd('selectMode', {'mode': 'single'}); setState(() { _phase = 'start'; _mode = 'single'; }); },
      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00FF88)),
      child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.person, size: 32), SizedBox(width: 12),
        Text('SINGLE PLAYER', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 2)),
      ]),
    )),
    const SizedBox(height: 12),
    SizedBox(width: double.infinity, height: 80, child: ElevatedButton(
      onPressed: () { _cmd('selectMode', {'mode': 'multi'}); setState(() { _phase = 'start'; _mode = 'multi'; }); },
      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF6644)),
      child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.people, size: 32), SizedBox(width: 12),
        Text('MULTIPLAYER', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 2)),
      ]),
    )),
  ]);

  Widget _configUI() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Center(child: Text(
      _mode == 'multi' ? '⚔️ MULTIPLAYER' : '🎮 SINGLE PLAYER',
      style: TextStyle(color: _mode == 'multi' ? const Color(0xFFFF6644) : const Color(0xFF00FF88), fontSize: 14, letterSpacing: 2, fontWeight: FontWeight.bold),
    )),
    const SizedBox(height: 16),
    const Text('DIFFICULTY', style: TextStyle(color: Color(0xFF6688AA), letterSpacing: 2, fontSize: 12, fontWeight: FontWeight.bold)),
    const SizedBox(height: 8),
    SizedBox(width: double.infinity, child: SegmentedButton<String>(
      segments: const [ButtonSegment(value: 'easy', label: Text('Easy')), ButtonSegment(value: 'hard', label: Text('Normal'))],
      selected: {_diff},
      onSelectionChanged: (s) { setState(() => _diff = s.first); _cmd('setDifficulty', {'difficulty': s.first}); },
    )),
    const SizedBox(height: 20),
    const Text('OBSTACLES', style: TextStyle(color: Color(0xFF6688AA), letterSpacing: 2, fontSize: 12, fontWeight: FontWeight.bold)),
    const SizedBox(height: 8),
    ..._obs.entries.map((e) => SwitchListTile(
      dense: true, title: Text(e.key.toUpperCase(), style: const TextStyle(fontSize: 13, letterSpacing: 1)),
      value: e.value, activeColor: const Color(0xFF00DDFF),
      onChanged: (v) { setState(() => _obs[e.key] = v); _cmd('toggleObstacle', {'obstacle': e.key, 'enabled': v}); },
    )),
    const SizedBox(height: 24),
    SizedBox(width: double.infinity, height: 60, child: ElevatedButton.icon(
      onPressed: () { _cmd('start'); setState(() => _phase = 'play'); },
      icon: const Icon(Icons.play_arrow, size: 28),
      label: const Text('PLAY', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 4)),
      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00FF88)),
    )),
    const SizedBox(height: 8),
    SizedBox(width: double.infinity, child: TextButton(
      onPressed: () { _cmd('backToMenu'); setState(() => _phase = 'menu'); },
      child: const Text('← BACK TO MENU', style: TextStyle(color: Color(0xFF668899))),
    )),
  ]);

  Widget _playingUI() => Column(children: [
    const SizedBox(height: 40),
    const Icon(Icons.directions_run, size: 64, color: Color(0xFF00FF88)),
    const SizedBox(height: 12),
    const Text('GAME RUNNING', style: TextStyle(color: Color(0xFF00FF88), fontSize: 18, letterSpacing: 3, fontWeight: FontWeight.w900)),
    const SizedBox(height: 40),
    SizedBox(width: double.infinity, height: 56, child: ElevatedButton.icon(
      onPressed: () { _cmd('stop'); setState(() => _phase = 'start'); },
      icon: const Icon(Icons.stop, size: 24),
      label: const Text('STOP', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF3355)),
    )),
    const SizedBox(height: 12),
    SizedBox(width: double.infinity, height: 56, child: ElevatedButton.icon(
      onPressed: () { _cmd('restart'); setState(() => _phase = 'play'); },
      icon: const Icon(Icons.refresh, size: 24),
      label: const Text('RESTART', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFAA00)),
    )),
  ]);

  Widget _gameOverUI() => Column(children: [
    const SizedBox(height: 40),
    const Icon(Icons.flag, size: 64, color: Color(0xFFFFAA00)),
    const SizedBox(height: 12),
    const Text('GAME OVER', style: TextStyle(color: Color(0xFFFFAA00), fontSize: 18, letterSpacing: 3, fontWeight: FontWeight.w900)),
    const SizedBox(height: 40),
    SizedBox(width: double.infinity, height: 56, child: ElevatedButton.icon(
      onPressed: () { _cmd('restart'); setState(() => _phase = 'play'); },
      icon: const Icon(Icons.refresh, size: 24),
      label: const Text('PLAY AGAIN', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 2)),
      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00FF88)),
    )),
    const SizedBox(height: 12),
    SizedBox(width: double.infinity, height: 48, child: OutlinedButton.icon(
      onPressed: () { _cmd('backToMenu'); setState(() => _phase = 'menu'); },
      icon: const Icon(Icons.arrow_back, color: Color(0xFF668899)),
      label: const Text('BACK TO MENU', style: TextStyle(color: Color(0xFF668899))),
      style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFF334455))),
    )),
  ]);
}

// ═══════════════════════════════════════
// QUESTIONS PAGE
// ═══════════════════════════════════════
class QuestionsPage extends StatefulWidget {
  const QuestionsPage({super.key});
  @override
  State<QuestionsPage> createState() => _QuestionsS();
}

class _QuestionsS extends State<QuestionsPage> {
  String _target = 'custom';
  bool _uploading = false;
  bool _generating = false;
  bool _smartParsing = false;
  List<Map<String, dynamic>> _questions = [];
  final _aiPrompt = TextEditingController();
  int _aiCount = 10;
  Set<int> _selected = {};
  bool _selectMode = false;

  static const String groqKey = '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';
  static const String groqUrl = 'https://api.groq.com/openai/v1/chat/completions';

  static const _presets = [
    _Preset('📗 SP Easy', 'sp_focused_easy', 'assets/presets/sp_focused_easy.json', Color(0xFF00DD88)),
    _Preset('📕 SP Hard', 'sp_focused_hard', 'assets/presets/sp_focused_hard.json', Color(0xFFFF6644)),
    _Preset('📘 Tech Easy', 'tech_focused_easy', 'assets/presets/tech_focused_easy.json', Color(0xFF00BBFF)),
    _Preset('📙 Tech Hard', 'tech_focused_hard', 'assets/presets/tech_focused_hard.json', Color(0xFFFFAA00)),
  ];

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: error ? const Color(0xFFFF3355) : const Color(0xFF00DD88), behavior: SnackBarBehavior.floating));
  }

  Future<List<Map<String, dynamic>>> _askGroq(String systemPrompt, String userContent) async {
    final response = await http.post(Uri.parse(groqUrl), headers: {'Authorization': 'Bearer $groqKey', 'Content-Type': 'application/json'},
      body: jsonEncode({'model': 'llama-3.3-70b-versatile', 'messages': [{'role': 'system', 'content': systemPrompt}, {'role': 'user', 'content': userContent}], 'max_tokens': 4000, 'temperature': 0.3}));
    if (response.statusCode != 200) throw Exception('Groq ${response.statusCode}');
    final data = jsonDecode(response.body);
    String content = data['choices'][0]['message']['content'].toString().trim();
    content = content.replaceAll(RegExp(r'^```json\s*', multiLine: true), '').replaceAll(RegExp(r'^```\s*', multiLine: true), '').trim();
    final List<dynamic> parsed = jsonDecode(content);
    final results = parsed.whereType<Map>().where((m) => m['q'] != null && m['l'] != null && m['r'] != null && m['c'] != null).map((m) => Map<String, dynamic>.from(m)).toList();
    final rng = Random();
    for (final q in results) { if (rng.nextBool()) { final tmp = q['l']; q['l'] = q['r']; q['r'] = tmp; q['c'] = q['c'] == 'left' ? 'right' : 'left'; } }
    return results;
  }

  Future<void> _aiGenerate() async {
    final prompt = _aiPrompt.text.trim();
    if (prompt.isEmpty) { _snack('Type a topic first', error: true); return; }
    setState(() => _generating = true);
    try {
      final results = await _askGroq('You are a trivia question generator. Generate exactly $_aiCount multiple-choice questions.\nRespond with ONLY a JSON array. Each question has 2 choices.\nFormat: [{"q":"question","l":"left choice","r":"right choice","c":"left or right"}]\n"c" = which side is correct. Mix up correct sides randomly. No markdown, ONLY JSON.', prompt);
      if (results.isEmpty) { _snack('No valid questions', error: true); return; }
      setState(() => _questions.addAll(results));
      _snack('AI generated ${results.length} questions');
    } catch (e) { _snack('AI failed: $e', error: true); }
    finally { if (mounted) setState(() => _generating = false); }
  }

  Future<void> _importSmart() async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['docx', 'txt', 'doc', 'rtf', 'md'], withData: true);
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first; final bytes = file.bytes;
      if (bytes == null) { _snack('Could not read file', error: true); return; }
      setState(() => _smartParsing = true);
      String text = file.name.endsWith('.docx') ? _extractDocxText(bytes) : utf8.decode(bytes, allowMalformed: true);
      if (text.trim().isEmpty) { _snack('No text found', error: true); setState(() => _smartParsing = false); return; }
      if (text.length > 6000) text = text.substring(0, 6000);
      final results = await _askGroq('You are a question parser. The user will give you raw messy text from a document containing quiz questions and answers.\nExtract every question and return as JSON array.\nFormat: [{"q":"question text","l":"one answer","r":"other answer","c":"left or right"}]\nRules:\n- "c" indicates which choice is correct\n- If correct answers are marked, use them. Otherwise guess.\n- If more than 2 choices, pick the 2 most distinct\n- If only questions with no answers, generate answers yourself\n- Clean up formatting\n- Respond with ONLY the JSON array', text);
      if (results.isEmpty) { _snack('Could not parse questions', error: true); return; }
      setState(() => _questions.addAll(results));
      _snack('Parsed ${results.length} from ${file.name}');
    } catch (e) { _snack('Smart import failed: $e', error: true); }
    finally { if (mounted) setState(() => _smartParsing = false); }
  }

  String _extractDocxText(List<int> bytes) {
    try { final archive = ZipDecoder().decodeBytes(bytes); for (final file in archive) { if (file.name == 'word/document.xml') { final xml = utf8.decode(file.content as List<int>); return RegExp(r'<w:t[^>]*>(.*?)</w:t>').allMatches(xml).map((m) => m.group(1) ?? '').join(' ').replaceAll(RegExp(r'\s+'), ' ').trim(); } } } catch (_) {} return '';
  }

  Future<void> _showExport() async {
    if (_questions.isEmpty) { _snack('No questions to export', error: true); return; }
    final format = await showModalBottomSheet<String>(context: context, backgroundColor: const Color(0xFF0C1420), shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Padding(padding: const EdgeInsets.all(20), child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('EXPORT FORMAT', style: TextStyle(color: Color(0xFF6688AA), fontSize: 12, letterSpacing: 2, fontWeight: FontWeight.bold)), const SizedBox(height: 16),
        ListTile(leading: const Icon(Icons.code, color: Color(0xFF00DD88)), title: const Text('JSON', style: TextStyle(color: Color(0xFF00DD88))), subtitle: const Text('Best for re-importing', style: TextStyle(fontSize: 11, color: Color(0xFF445566))), onTap: () => Navigator.pop(ctx, 'json')),
        ListTile(leading: const Icon(Icons.table_chart, color: Color(0xFFFFAA00)), title: const Text('CSV', style: TextStyle(color: Color(0xFFFFAA00))), subtitle: const Text('Excel / Google Sheets', style: TextStyle(fontSize: 11, color: Color(0xFF445566))), onTap: () => Navigator.pop(ctx, 'csv')),
        ListTile(leading: const Icon(Icons.description, color: Color(0xFF00BBFF)), title: const Text('TXT', style: TextStyle(color: Color(0xFF00BBFF))), subtitle: const Text('Plain text', style: TextStyle(fontSize: 11, color: Color(0xFF445566))), onTap: () => Navigator.pop(ctx, 'txt')),
        const SizedBox(height: 8), TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL')),
      ])));
    if (format == null) return;
    try {
      String content; String filename; MimeType mime;
      switch (format) {
        case 'json': content = const JsonEncoder.withIndent('  ').convert(_questions); filename = 'questions_${DateTime.now().millisecondsSinceEpoch}.json'; mime = MimeType.json;
        case 'csv': final buf = StringBuffer('question,left,right,correct\n'); for (final q in _questions) { esc(String s) => '"${s.replaceAll('"', '""')}"'; buf.writeln('${esc(q['q'] ?? '')},${esc(q['l'] ?? '')},${esc(q['r'] ?? '')},${q['c'] ?? 'left'}'); } content = buf.toString(); filename = 'questions_${DateTime.now().millisecondsSinceEpoch}.csv'; mime = MimeType.csv;
        default: final buf = StringBuffer(); for (var i = 0; i < _questions.length; i++) { final q = _questions[i]; buf.writeln('${i + 1}. ${q['q']}'); buf.writeln('   L: ${q['l']}'); buf.writeln('   R: ${q['r']}'); buf.writeln('   Answer: ${q['c'] == 'left' ? q['l'] : q['r']} (${q['c']})'); buf.writeln(); } content = buf.toString(); filename = 'questions_${DateTime.now().millisecondsSinceEpoch}.txt'; mime = MimeType.text;
      }
      await FileSaver.instance.saveFile(name: filename, bytes: Uint8List.fromList(utf8.encode(content)), mimeType: mime);
      _snack('Saved $filename');
    } catch (e) { _snack('Export failed: $e', error: true); }
  }

  Future<void> _loadPreset(_Preset p) async { try { final raw = jsonDecode(await rootBundle.loadString(p.assetPath)); List<dynamic>? list = raw is List ? raw : (raw is Map ? raw.values.whereType<List>().firstOrNull : null); if (list == null || list.isEmpty) { _snack('No questions found', error: true); return; } setState(() => _questions = list.map((e) => Map<String, dynamic>.from(e as Map)).toList()); _snack('Loaded ${_questions.length} from ${p.label}'); } catch (e) { _snack('Load failed: $e', error: true); } }
  Future<void> _importJson() async { try { final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['json'], withData: true); if (result == null || result.files.isEmpty) return; final bytes = result.files.first.bytes; if (bytes == null) return; final list = _extractList(jsonDecode(utf8.decode(bytes))); if (list.isEmpty) { _snack('No valid questions', error: true); return; } setState(() => _questions.addAll(list)); _snack('Added ${list.length} from JSON'); } catch (e) { _snack('JSON failed: $e', error: true); } }
  Future<void> _importCsv() async { try { final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['csv', 'txt'], withData: true); if (result == null || result.files.isEmpty) return; final bytes = result.files.first.bytes; if (bytes == null) return; final parsed = _parseSeparated(utf8.decode(bytes), ','); if (parsed.isEmpty) { _snack('No valid rows', error: true); return; } setState(() => _questions.addAll(parsed)); _snack('Added ${parsed.length} from CSV'); } catch (e) { _snack('CSV failed: $e', error: true); } }

  Future<void> _importPaste() async {
    final ctrl = TextEditingController();
    final result = await showDialog<String>(context: context, builder: (ctx) => AlertDialog(backgroundColor: const Color(0xFF0C1420), title: const Text('PASTE QUESTIONS', style: TextStyle(color: Color(0xFFBB88FF), fontSize: 16, letterSpacing: 2)),
      content: SizedBox(width: double.maxFinite, height: 300, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('One per line:  question | left | right | left/right', style: TextStyle(color: Color(0xFF668899), fontSize: 11)), const SizedBox(height: 12), Expanded(child: TextField(controller: ctrl, maxLines: null, expands: true, textAlignVertical: TextAlignVertical.top, style: const TextStyle(fontSize: 12, fontFamily: 'monospace'), decoration: const InputDecoration(hintText: 'Paste here...', hintStyle: TextStyle(color: Color(0xFF334455)))))])),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL')), ElevatedButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('ADD'))]));
    if (result == null || result.trim().isEmpty) return;
    final parsed = _parseSeparated(result, '|');
    if (parsed.isEmpty) { _snack('No valid lines', error: true); return; }
    setState(() => _questions.addAll(parsed)); _snack('Added ${parsed.length} questions');
  }

  Future<void> _addManual() async { final result = await _questionDialog('ADD QUESTION', const Color(0xFF00DDFF)); if (result == null) return; setState(() => _questions.add(result)); _snack('Question added'); }
  Future<void> _edit(int i) async { final result = await _questionDialog('EDIT QUESTION', const Color(0xFFFFAA00), initial: _questions[i], showDelete: true); if (result == null) return; if (result.containsKey('_delete')) { setState(() => _questions.removeAt(i)); _snack('Deleted'); } else { setState(() => _questions[i] = result); _snack('Updated'); } }
  void _deleteSelected() { final sorted = _selected.toList()..sort((a, b) => b.compareTo(a)); for (final i in sorted) _questions.removeAt(i); final count = sorted.length; setState(() { _selected.clear(); _selectMode = false; }); _snack('Deleted $count questions'); }

  Future<Map<String, dynamic>?> _questionDialog(String title, Color color, {Map<String, dynamic>? initial, bool showDelete = false}) {
    final qC = TextEditingController(text: initial?['q'] ?? ''); final lC = TextEditingController(text: initial?['l'] ?? ''); final rC = TextEditingController(text: initial?['r'] ?? ''); String correct = initial?['c'] ?? 'left';
    return showDialog<Map<String, dynamic>>(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setDlg) => AlertDialog(backgroundColor: const Color(0xFF0C1420), title: Text(title, style: TextStyle(color: color, fontSize: 16, letterSpacing: 2)),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: qC, decoration: const InputDecoration(labelText: 'Question'), maxLines: 2), const SizedBox(height: 12), TextField(controller: lC, decoration: const InputDecoration(labelText: 'Left answer')), const SizedBox(height: 12), TextField(controller: rC, decoration: const InputDecoration(labelText: 'Right answer')), const SizedBox(height: 16), SegmentedButton<String>(segments: const [ButtonSegment(value: 'left', label: Text('← LEFT')), ButtonSegment(value: 'right', label: Text('RIGHT →'))], selected: {correct}, onSelectionChanged: (s) => setDlg(() => correct = s.first))])),
      actions: [if (showDelete) TextButton(onPressed: () => Navigator.pop(ctx, {'_delete': true}), child: const Text('DELETE', style: TextStyle(color: Color(0xFFFF3355)))), if (showDelete) const Spacer(), TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL')),
        ElevatedButton(onPressed: () { if (qC.text.trim().isEmpty || lC.text.trim().isEmpty || rC.text.trim().isEmpty) return; Navigator.pop(ctx, {'q': qC.text.trim(), 'l': lC.text.trim(), 'r': rC.text.trim(), 'c': correct}); }, style: ElevatedButton.styleFrom(backgroundColor: color), child: Text(initial == null ? 'ADD' : 'SAVE'))])));
  }

  Future<void> _upload() async {
    if (_questions.isEmpty || _uploading) return; setState(() => _uploading = true);
    try { final ref = FirebaseFirestore.instance.collection('question_pools').doc(_target).collection('questions'); final existing = await ref.get(); final batch = FirebaseFirestore.instance.batch(); for (final d in existing.docs) batch.delete(d.reference); await batch.commit(); int count = 0; for (final q in _questions) { if (q['q'] != null && q['l'] != null && q['r'] != null && q['c'] != null) { await ref.add({'q': q['q'], 'l': q['l'], 'r': q['r'], 'c': q['c'], 'created_at': FieldValue.serverTimestamp()}); count++; } } _snack('Uploaded $count to $_target'); } catch (e) { _snack('Upload failed: $e', error: true); }
    finally { if (mounted) setState(() => _uploading = false); }
  }

  List<Map<String, dynamic>> _extractList(dynamic data) { List<dynamic>? raw; if (data is List) raw = data; else if (data is Map) { for (final v in data.values) { if (v is List) { raw = v; break; } } } if (raw == null) return []; return raw.whereType<Map>().where((m) => m['q'] != null && m['l'] != null && m['r'] != null && m['c'] != null).map((m) => Map<String, dynamic>.from(m)).toList(); }
  List<Map<String, dynamic>> _parseSeparated(String text, String sep) { return text.split('\n').where((l) => l.trim().isNotEmpty).map((line) { final parts = line.split(sep).map((s) => s.trim()).toList(); if (parts.length < 4) return null; final c = parts[3].toLowerCase(); if (c != 'left' && c != 'right') return null; return {'q': parts[0], 'l': parts[1], 'r': parts[2], 'c': c}; }).whereType<Map<String, dynamic>>().toList(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _selectMode ? Text('${_selected.length} SELECTED', style: const TextStyle(letterSpacing: 2, fontSize: 16)) : const Text('QUESTIONS', style: TextStyle(letterSpacing: 3, fontWeight: FontWeight.w900)),
        leading: _selectMode ? IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() { _selectMode = false; _selected.clear(); })) : null,
        actions: [
          if (_selectMode) ...[IconButton(icon: const Icon(Icons.select_all, color: Color(0xFF00DDFF)), onPressed: () => setState(() { if (_selected.length == _questions.length) _selected.clear(); else _selected = Set.from(List.generate(_questions.length, (i) => i)); })), IconButton(icon: const Icon(Icons.delete, color: Color(0xFFFF3355)), onPressed: _deleteSelected)]
          else ...[if (_questions.isNotEmpty) IconButton(icon: const Icon(Icons.download, color: Color(0xFF00FF88)), onPressed: _showExport), if (_questions.isNotEmpty) IconButton(icon: const Icon(Icons.delete_sweep, color: Color(0xFFFF3355)), onPressed: () => setState(() => _questions.clear()))],
        ],
      ),
      floatingActionButton: _selectMode ? null : FloatingActionButton(onPressed: _addManual, backgroundColor: const Color(0xFF00FF88), child: const Icon(Icons.add, color: Color(0xFF060A14))),
      body: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (!_selectMode) Card(color: const Color(0xFF0A0E1A), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFF3A1A5A))),
          child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Row(children: [Icon(Icons.auto_awesome, color: Color(0xFFBB88FF), size: 18), SizedBox(width: 8), Text('AI GENERATE', style: TextStyle(color: Color(0xFFBB88FF), fontSize: 11, letterSpacing: 2, fontWeight: FontWeight.bold))]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: TextField(controller: _aiPrompt, style: const TextStyle(fontSize: 13), decoration: const InputDecoration(hintText: 'e.g. "SP history and courses"', hintStyle: TextStyle(color: Color(0xFF445566), fontSize: 12), border: InputBorder.none, fillColor: Color(0xFF0C1420), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)), onSubmitted: (_) => _aiGenerate())),
              const SizedBox(width: 8),
              Container(padding: const EdgeInsets.symmetric(horizontal: 8), decoration: BoxDecoration(color: const Color(0xFF0C1420), borderRadius: BorderRadius.circular(8)),
                child: DropdownButton<int>(value: _aiCount, dropdownColor: const Color(0xFF0C1420), underline: const SizedBox(), style: const TextStyle(color: Color(0xFFBB88FF), fontSize: 12), items: [5, 10, 15, 20].map((n) => DropdownMenuItem(value: n, child: Text('$n'))).toList(), onChanged: (v) { if (v != null) setState(() => _aiCount = v); })),
              const SizedBox(width: 8),
              SizedBox(height: 40, child: ElevatedButton(onPressed: _generating ? null : _aiGenerate, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFBB88FF), padding: const EdgeInsets.symmetric(horizontal: 16)),
                child: _generating ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF060A14))) : const Icon(Icons.auto_awesome, size: 18))),
            ]),
          ]))),
        if (!_selectMode) const SizedBox(height: 12),
        if (!_selectMode) SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
          _importBtn(Icons.psychology, 'Smart Import', const Color(0xFFFF6688), _smartParsing ? null : _importSmart, loading: _smartParsing),
          const SizedBox(width: 8), _importBtn(Icons.folder_special, 'Presets', const Color(0xFF00DDFF), _showPresets),
          const SizedBox(width: 8), _importBtn(Icons.upload_file, 'JSON', const Color(0xFF00DD88), _importJson),
          const SizedBox(width: 8), _importBtn(Icons.table_chart, 'CSV', const Color(0xFFFFAA00), _importCsv),
          const SizedBox(width: 8), _importBtn(Icons.paste, 'Paste', const Color(0xFFBB88FF), _importPaste),
        ])),
        if (!_selectMode) const SizedBox(height: 12),
        Row(children: [
          Text('${_questions.length} QUESTIONS', style: const TextStyle(color: Color(0xFF00DDFF), fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1)),
          if (_selectMode) Text('  (${_selected.length} selected)', style: const TextStyle(color: Color(0xFFFFAA00), fontSize: 12)),
          const Spacer(),
          if (!_selectMode) ...[const Text('To: ', style: TextStyle(color: Color(0xFF445566), fontSize: 11)),
            DropdownButton<String>(value: _target, dropdownColor: const Color(0xFF0C1420), underline: const SizedBox(), style: const TextStyle(color: Color(0xFF00DDFF), fontSize: 12),
              items: ['custom', 'sp_focused_easy', 'sp_focused_hard', 'tech_focused_easy', 'tech_focused_hard'].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(), onChanged: (v) { if (v != null) setState(() => _target = v); })],
        ]),
        const SizedBox(height: 8),
        Expanded(child: _questions.isEmpty
            ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.quiz_outlined, size: 48, color: Color(0xFF1A3A4A)), const SizedBox(height: 12), const Text('No questions yet', style: TextStyle(color: Color(0xFF334455), fontSize: 14)), const SizedBox(height: 4), const Text('Use AI, Smart Import, or tap + to add', style: TextStyle(color: Color(0xFF223344), fontSize: 12))]))
            : Container(decoration: BoxDecoration(color: const Color(0xFF080C16), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFF1A2A3A))),
                child: ListView.separated(padding: const EdgeInsets.all(10), itemCount: _questions.length, separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFF111822)),
                  itemBuilder: (ctx, i) { final q = _questions[i]; final isL = q['c'] == 'left'; final isSel = _selected.contains(i);
                    return Dismissible(key: ValueKey('$i-${q['q']}'), direction: _selectMode ? DismissDirection.none : DismissDirection.endToStart,
                      background: Container(alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20), color: const Color(0xFFFF3355).withOpacity(0.2), child: const Icon(Icons.delete, color: Color(0xFFFF3355))),
                      onDismissed: (_) { setState(() => _questions.removeAt(i)); _snack('Removed'); },
                      child: InkWell(
                        onTap: () { if (_selectMode) { setState(() { if (isSel) _selected.remove(i); else _selected.add(i); if (_selected.isEmpty) _selectMode = false; }); } else { _edit(i); } },
                        onLongPress: () => setState(() { _selectMode = true; _selected.add(i); }),
                        child: Container(color: isSel ? const Color(0xFF00DDFF).withOpacity(0.08) : null, padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            if (_selectMode) Padding(padding: const EdgeInsets.only(right: 8, top: 2), child: Icon(isSel ? Icons.check_circle : Icons.circle_outlined, size: 20, color: isSel ? const Color(0xFF00DDFF) : const Color(0xFF334455))),
                            SizedBox(width: 28, child: Text('${i + 1}', style: const TextStyle(color: Color(0xFF334455), fontSize: 12, fontWeight: FontWeight.bold))),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(q['q'] ?? '', style: const TextStyle(color: Colors.white70, fontSize: 13)), const SizedBox(height: 4),
                              Row(children: [Icon(isL ? Icons.check_circle : Icons.circle_outlined, size: 12, color: isL ? const Color(0xFF00FF88) : const Color(0xFF334455)), const SizedBox(width: 4), Expanded(child: Text(q['l'] ?? '', style: TextStyle(color: isL ? const Color(0xFF00DDFF) : const Color(0xFF445566), fontSize: 12)))]),
                              const SizedBox(height: 2),
                              Row(children: [Icon(!isL ? Icons.check_circle : Icons.circle_outlined, size: 12, color: !isL ? const Color(0xFF00FF88) : const Color(0xFF334455)), const SizedBox(width: 4), Expanded(child: Text(q['r'] ?? '', style: TextStyle(color: !isL ? const Color(0xFFFF8888) : const Color(0xFF445566), fontSize: 12)))]),
                            ])),
                            if (!_selectMode) const Icon(Icons.edit, size: 14, color: Color(0xFF334455)),
                          ])))); }))),
        const SizedBox(height: 12),
        if (!_selectMode) SizedBox(width: double.infinity, height: 52, child: ElevatedButton.icon(
          onPressed: _questions.isEmpty || _uploading ? null : _upload,
          icon: _uploading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF060A14))) : const Icon(Icons.cloud_upload, size: 22),
          label: Text(_uploading ? 'UPLOADING...' : 'UPLOAD ${_questions.length} → $_target', style: const TextStyle(fontSize: 13, letterSpacing: 1)))),
      ])),
    );
  }

  void _showPresets() { showModalBottomSheet(context: context, backgroundColor: const Color(0xFF0C1420), shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (ctx) => Padding(padding: const EdgeInsets.all(20), child: Column(mainAxisSize: MainAxisSize.min, children: [const Text('LOAD PRESET', style: TextStyle(color: Color(0xFF6688AA), fontSize: 12, letterSpacing: 2, fontWeight: FontWeight.bold)), const SizedBox(height: 16),
      ..._presets.map((p) => ListTile(leading: Icon(Icons.folder, color: p.color), title: Text(p.label, style: TextStyle(color: p.color)), trailing: const Icon(Icons.download, color: Color(0xFF334455)), onTap: () { Navigator.pop(ctx); _loadPreset(p); })), const SizedBox(height: 8), TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL'))]))); }

  Widget _importBtn(IconData icon, String label, Color c, VoidCallback? onTap, {bool loading = false}) => OutlinedButton.icon(onPressed: onTap,
    icon: loading ? SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: c)) : Icon(icon, size: 16, color: c),
    label: Text(label, style: TextStyle(color: c, fontSize: 11)), style: OutlinedButton.styleFrom(side: BorderSide(color: c.withOpacity(0.3)), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10)));
}

class _Preset { final String label, category, assetPath; final Color color; const _Preset(this.label, this.category, this.assetPath, this.color); }