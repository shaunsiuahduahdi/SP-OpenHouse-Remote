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
import 'package:excel/excel.dart' as xl;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try { await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform); } catch (_) {}
  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});
  @override
  Widget build(BuildContext ctx) => MaterialApp(debugShowCheckedModeBanner: false, title: 'SP Open House',
    theme: ThemeData(brightness: Brightness.dark, scaffoldBackgroundColor: const Color(0xFF080A14),
      colorScheme: const ColorScheme.dark(primary: Color(0xFF22C55E), secondary: Color(0xFFF43F5E), surface: Color(0xFF0E1220)),
      fontFamily: 'RobotoMono',
      appBarTheme: const AppBarTheme(backgroundColor: Color(0xFF0A0E1A), elevation: 0, centerTitle: true),
      elevatedButtonTheme: ElevatedButtonThemeData(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF22C55E), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)))),
      inputDecorationTheme: InputDecorationTheme(filled: true, fillColor: const Color(0xFF0E1220), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF1A2040))), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF22C55E), width: 2)))),
    home: const HubApp());
}

class GameDef {
  final String id, title, sub, icon, qCollection;
  final Color color; final List<String> modes;
  const GameDef({required this.id, required this.title, required this.sub, required this.icon, required this.color, required this.qCollection, required this.modes});
}
const _games = [
  GameDef(id: 'running', title: 'RunningMan', sub: 'System Reboot', icon: '🏃', color: Color(0xFF00FF88), qCollection: 'question_pools', modes: ['single', 'multi']),
  GameDef(id: 'osu', title: 'osu!pose', sub: 'Rhythm Meets Motion', icon: '🎵', color: Color(0xFFF43F5E), qCollection: 'osu_question_pools', modes: ['single', 'multi', 'dual']),
  GameDef(id: 'fruit', title: 'LED Fruit Ninja', sub: 'Circuit Builder', icon: '⚡', color: Color(0xFFF59E0B), qCollection: 'fruit_question_pools', modes: ['single', 'multi', 'dual']),
];

class HubApp extends StatefulWidget { const HubApp({super.key}); @override State<HubApp> createState() => _HubS(); }
class _HubS extends State<HubApp> {
  String? _sid; final _cc = TextEditingController(); bool _on = false;
  GameDef? _game; int _tab = 0;
  String _phase = 'menu'; String _mode = 'single';
  String _diff = 'hard';
  Map<String, bool> _obs = {'walls': true, 'trivia': true, 'cables': true, 'virus': true, 'counter': true, 'hold': true, 'jumba': true, 'security': true};

  DocumentReference get _ref => FirebaseFirestore.instance.collection('hub_sessions').doc(_sid);

  Future<void> _connect() async {
    final code = _cc.text.trim().toUpperCase(); if (code.isEmpty) return;
    try { final snap = await FirebaseFirestore.instance.collection('hub_sessions').doc(code).get();
      if (!snap.exists) { if (!mounted) return; ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Session not found'), backgroundColor: Color(0xFFEF4444))); return; }
      setState(() { _sid = code; _on = true; }); await _ref.update({'controllerConnected': true});
    } catch (e) { if (!mounted) return; ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: const Color(0xFFEF4444))); } }

  Future<void> _cmd(String c, [Map<String, dynamic>? d]) async { if (_sid == null) return; try { await _ref.update({'command': c, 'commandData': d ?? {}, 'commandTimestamp': FieldValue.serverTimestamp()}); } catch (_) {} }
  void _selectGame(GameDef g) { setState(() { _game = g; _phase = 'menu'; _tab = 0; _diff = 'hard'; _obs = {'walls': true, 'trivia': true, 'cables': true, 'virus': true, 'counter': true, 'hold': true, 'jumba': true, 'security': true}; }); _cmd('selectGame', {'game': g.id}); }
  void _backToHub() { setState(() { _game = null; _phase = 'menu'; }); _cmd('backToHub'); }
  void _disc() { if (_sid != null) _ref.update({'controllerConnected': false}).catchError((_) {}); setState(() { _sid = null; _on = false; _game = null; }); }

  @override
  Widget build(BuildContext ctx) { if (!_on) return _connectScreen(); if (_game == null) return _gamePicker(); return _gameCtrl(); }

  Widget _connectScreen() => Scaffold(body: Center(child: Padding(padding: const EdgeInsets.all(32), child: Column(mainAxisSize: MainAxisSize.min, children: [
    const Text('SP', style: TextStyle(fontSize: 52, fontWeight: FontWeight.w900, color: Color(0xFF22C55E))),
    const Text('Open House', style: TextStyle(fontSize: 20, color: Color(0xFF4A5878))),
    const SizedBox(height: 40),
    const Text('ENTER HUB CODE', style: TextStyle(color: Color(0xFF3A4868), letterSpacing: 2, fontSize: 12, fontWeight: FontWeight.w700)),
    const SizedBox(height: 12),
    TextField(controller: _cc, textAlign: TextAlign.center, style: const TextStyle(fontSize: 32, letterSpacing: 10, color: Color(0xFF22C55E), fontWeight: FontWeight.w900), textCapitalization: TextCapitalization.characters,
      decoration: const InputDecoration(hintText: '_ _ _ _', hintStyle: TextStyle(color: Color(0xFF1A2040), fontSize: 32, letterSpacing: 10)), onSubmitted: (_) => _connect()),
    const SizedBox(height: 20),
    SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _connect, child: const Text('CONNECT', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 2)))),
  ]))));

  Widget _gamePicker() => Scaffold(
    appBar: AppBar(title: const Text('SP OPEN HOUSE', style: TextStyle(letterSpacing: 3, fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF22C55E))),
      actions: [IconButton(icon: const Icon(Icons.close, color: Color(0xFFEF4444)), onPressed: _disc)]),
    body: Padding(padding: const EdgeInsets.all(20), child: Column(children: [
      Card(child: ListTile(leading: const Icon(Icons.link, color: Color(0xFF22C55E)),
        title: Text('HUB: $_sid', style: const TextStyle(color: Color(0xFF22C55E), letterSpacing: 3, fontSize: 14, fontWeight: FontWeight.w700)))),
      const SizedBox(height: 24),
      const Text('SELECT A GAME', style: TextStyle(color: Color(0xFF3A4868), letterSpacing: 2, fontSize: 12, fontWeight: FontWeight.w700)),
      const SizedBox(height: 16),
      ..._games.map((g) => Padding(padding: const EdgeInsets.only(bottom: 10), child: InkWell(onTap: () => _selectGame(g), borderRadius: BorderRadius.circular(14),
        child: Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: g.color.withOpacity(0.2)),
          gradient: LinearGradient(colors: [g.color.withOpacity(0.06), Colors.transparent])),
          child: Row(children: [Text(g.icon, style: const TextStyle(fontSize: 36)), const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(g.title, style: TextStyle(color: g.color, fontSize: 18, fontWeight: FontWeight.w800)), Text(g.sub, style: const TextStyle(color: Color(0xFF4A5878), fontSize: 12))])),
            Icon(Icons.chevron_right, color: g.color.withOpacity(0.5))]))))),
    ])));

  Widget _gameCtrl() {
    final g = _game!;
    return Scaffold(
      appBar: AppBar(leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: _backToHub),
        title: Text(g.title, style: TextStyle(letterSpacing: 2, fontWeight: FontWeight.w900, color: g.color, fontSize: 16))),
      body: IndexedStack(index: _tab, children: [_remoteTab(g), QuestionsPage(gameColor: g.color, qCollection: g.qCollection)]),
      bottomNavigationBar: BottomNavigationBar(currentIndex: _tab, onTap: (i) => setState(() => _tab = i),
        backgroundColor: const Color(0xFF0A0E1A), selectedItemColor: g.color, unselectedItemColor: const Color(0xFF2A3050),
        items: const [BottomNavigationBarItem(icon: Icon(Icons.gamepad), label: 'REMOTE'), BottomNavigationBarItem(icon: Icon(Icons.quiz), label: 'QUESTIONS')]));
  }

  Widget _remoteTab(GameDef g) => Padding(padding: const EdgeInsets.all(16), child: Column(children: [
    Card(child: ListTile(leading: Icon(Icons.videogame_asset, color: g.color),
      title: Text(g.title, style: TextStyle(color: g.color, letterSpacing: 2, fontSize: 14, fontWeight: FontWeight.w700)))),
    const SizedBox(height: 16),
    Expanded(child: SingleChildScrollView(child: g.id == 'running' ? _runningRemote(g) : _simpleRemote(g)))]));

  Widget _runningRemote(GameDef g) { switch (_phase) { case 'menu': return _rmMenu(g); case 'config': return _rmConfig(g); case 'play': return _rmPlay(g); case 'go': return _rmGameOver(g); default: return _rmMenu(g); } }

  Widget _rmMenu(GameDef g) => Column(children: [
    const Text('SELECT MODE', style: TextStyle(color: Color(0xFF6688AA), letterSpacing: 2, fontSize: 12, fontWeight: FontWeight.bold)),
    const SizedBox(height: 20),
    SizedBox(width: double.infinity, height: 80, child: ElevatedButton(
      onPressed: () { _cmd('selectMode', {'mode': 'single'}); setState(() { _phase = 'config'; _mode = 'single'; }); },
      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00FF88)),
      child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.person, size: 32), SizedBox(width: 12), Text('SINGLE PLAYER', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 2))]))),
    const SizedBox(height: 12),
    SizedBox(width: double.infinity, height: 80, child: ElevatedButton(
      onPressed: () { _cmd('selectMode', {'mode': 'multi'}); setState(() { _phase = 'config'; _mode = 'multi'; }); },
      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF6644)),
      child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.people, size: 32), SizedBox(width: 12), Text('MULTIPLAYER', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 2))]))),
  ]);

  Widget _rmConfig(GameDef g) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Center(child: Text(_mode == 'multi' ? '⚔️ MULTIPLAYER' : '🎮 SINGLE PLAYER',
      style: TextStyle(color: _mode == 'multi' ? const Color(0xFFFF6644) : const Color(0xFF00FF88), fontSize: 14, letterSpacing: 2, fontWeight: FontWeight.bold))),
    const SizedBox(height: 16),
    const Text('DIFFICULTY', style: TextStyle(color: Color(0xFF6688AA), letterSpacing: 2, fontSize: 12, fontWeight: FontWeight.bold)),
    const SizedBox(height: 8),
    SizedBox(width: double.infinity, child: SegmentedButton<String>(
      segments: const [ButtonSegment(value: 'easy', label: Text('Easy')), ButtonSegment(value: 'hard', label: Text('Normal'))],
      selected: {_diff}, onSelectionChanged: (s) { setState(() => _diff = s.first); _cmd('setDifficulty', {'difficulty': s.first}); })),
    const SizedBox(height: 20),
    const Text('OBSTACLES', style: TextStyle(color: Color(0xFF6688AA), letterSpacing: 2, fontSize: 12, fontWeight: FontWeight.bold)),
    const SizedBox(height: 8),
    ..._obs.entries.map((e) => SwitchListTile(dense: true, title: Text(e.key.toUpperCase(), style: const TextStyle(fontSize: 13, letterSpacing: 1)),
      value: e.value, activeColor: const Color(0xFF00DDFF),
      onChanged: (v) { setState(() => _obs[e.key] = v); _cmd('toggleObstacle', {'obstacle': e.key, 'enabled': v}); })),
    const SizedBox(height: 24),
    SizedBox(width: double.infinity, height: 60, child: ElevatedButton.icon(
      onPressed: () { _cmd('startGame'); setState(() => _phase = 'play'); },
      icon: const Icon(Icons.play_arrow, size: 28),
      label: const Text('PLAY', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 4)),
      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00FF88)))),
    const SizedBox(height: 8),
    SizedBox(width: double.infinity, child: TextButton(onPressed: () { _cmd('backToMenu'); setState(() => _phase = 'menu'); },
      child: const Text('← BACK TO MENU', style: TextStyle(color: Color(0xFF668899))))),
  ]);

  Widget _rmPlay(GameDef g) => Column(children: [
    const SizedBox(height: 40), const Icon(Icons.directions_run, size: 64, color: Color(0xFF00FF88)),
    const SizedBox(height: 12), const Text('GAME RUNNING', style: TextStyle(color: Color(0xFF00FF88), fontSize: 18, letterSpacing: 3, fontWeight: FontWeight.w900)),
    const SizedBox(height: 40),
    SizedBox(width: double.infinity, height: 56, child: ElevatedButton.icon(
      onPressed: () { _cmd('stop'); setState(() => _phase = 'menu'); },
      icon: const Icon(Icons.stop, size: 24), label: const Text('STOP', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF3355)))),
    const SizedBox(height: 12),
    SizedBox(width: double.infinity, height: 56, child: ElevatedButton.icon(
      onPressed: () { _cmd('restart'); },
      icon: const Icon(Icons.refresh, size: 24), label: const Text('RESTART', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFAA00)))),
  ]);

  Widget _rmGameOver(GameDef g) => Column(children: [
    const SizedBox(height: 40), const Icon(Icons.flag, size: 64, color: Color(0xFFFFAA00)),
    const SizedBox(height: 12), const Text('GAME OVER', style: TextStyle(color: Color(0xFFFFAA00), fontSize: 18, letterSpacing: 3, fontWeight: FontWeight.w900)),
    const SizedBox(height: 40),
    SizedBox(width: double.infinity, height: 56, child: ElevatedButton.icon(
      onPressed: () { _cmd('restart'); setState(() => _phase = 'play'); },
      icon: const Icon(Icons.refresh), label: const Text('PLAY AGAIN', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 2)),
      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00FF88)))),
    const SizedBox(height: 12),
    SizedBox(width: double.infinity, height: 48, child: OutlinedButton.icon(
      onPressed: () { _cmd('backToMenu'); setState(() => _phase = 'menu'); },
      icon: const Icon(Icons.arrow_back, color: Color(0xFF668899)),
      label: const Text('BACK TO MENU', style: TextStyle(color: Color(0xFF668899))),
      style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFF334455))))),
  ]);

  Widget _simpleRemote(GameDef g) { switch (_phase) { case 'menu': return _simpleMenu(g); case 'play': return _simplePlay(g); case 'go': return _simpleGO(g); default: return _simpleMenu(g); } }

  Widget _simpleMenu(GameDef g) => Column(children: [
    const Text('SELECT MODE', style: TextStyle(color: Color(0xFF4A5878), letterSpacing: 2, fontSize: 12, fontWeight: FontWeight.w700)),
    const SizedBox(height: 16),
    ...g.modes.map((m) { final isS = m == 'single'; final isM = m == 'multi';
      final col = isS ? const Color(0xFF22C55E) : isM ? g.color : const Color(0xFF7C4DFF);
      final icon = isS ? Icons.person : isM ? Icons.wifi : Icons.people;
      final label = isS ? 'SINGLE PLAYER' : isM ? 'ONLINE' : 'DUAL SPLIT';
      return Padding(padding: const EdgeInsets.only(bottom: 10), child: SizedBox(width: double.infinity, height: 64, child: ElevatedButton(
        onPressed: () { _cmd('selectMode', {'mode': m}); setState(() { _phase = 'play'; _mode = m; }); },
        style: ElevatedButton.styleFrom(backgroundColor: col),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, size: 24), const SizedBox(width: 12), Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: 2))])))); }),
  ]);

  Widget _simplePlay(GameDef g) {
    final col = _mode == 'dual' ? const Color(0xFF7C4DFF) : _mode == 'multi' ? g.color : const Color(0xFF22C55E);
    final label = _mode == 'dual' ? '🎭 DUAL' : _mode == 'multi' ? '🌐 ONLINE' : '🎮 SINGLE';
    return Column(children: [
      Text(label, style: TextStyle(color: col, fontSize: 14, letterSpacing: 2, fontWeight: FontWeight.w700)),
      const SizedBox(height: 24), Text(g.icon, style: const TextStyle(fontSize: 56)),
      const SizedBox(height: 8), Text('PLAYING', style: TextStyle(color: g.color, fontSize: 18, letterSpacing: 3, fontWeight: FontWeight.w900)),
      const SizedBox(height: 32),
      SizedBox(width: double.infinity, height: 52, child: ElevatedButton.icon(
        onPressed: () { _cmd('stop'); setState(() => _phase = 'menu'); },
        icon: const Icon(Icons.stop, size: 22), label: const Text('STOP', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)))),
      const SizedBox(height: 10),
      SizedBox(width: double.infinity, height: 52, child: ElevatedButton.icon(
        onPressed: () => _cmd('restart'),
        icon: const Icon(Icons.refresh, size: 22), label: const Text('RESTART', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF59E0B)))),
    ]);
  }

  Widget _simpleGO(GameDef g) => Column(children: [
    const SizedBox(height: 32), const Text('GAME OVER', style: TextStyle(color: Color(0xFFF59E0B), fontSize: 18, letterSpacing: 3, fontWeight: FontWeight.w900)),
    const SizedBox(height: 32),
    SizedBox(width: double.infinity, height: 52, child: ElevatedButton.icon(
      onPressed: () { _cmd('restart'); setState(() => _phase = 'play'); },
      icon: const Icon(Icons.refresh), label: const Text('PLAY AGAIN', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 2)),
      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF22C55E)))),
    const SizedBox(height: 10),
    SizedBox(width: double.infinity, height: 44, child: OutlinedButton.icon(
      onPressed: () { _cmd('backToMenu'); setState(() => _phase = 'menu'); },
      icon: const Icon(Icons.arrow_back, color: Color(0xFF4A5878)),
      label: const Text('BACK TO MENU', style: TextStyle(color: Color(0xFF4A5878))),
      style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFF1A2040))))),
  ]);
}

// ═══════════════════════════════════════
// QUESTIONS PAGE
// ═══════════════════════════════════════
class QuestionsPage extends StatefulWidget {
  final Color gameColor; final String qCollection;
  const QuestionsPage({super.key, required this.gameColor, required this.qCollection});
  @override State<QuestionsPage> createState() => _QS();
}
class _QS extends State<QuestionsPage> {
  String _target = 'custom'; bool _uploading = false; bool _generating = false; bool _smartParsing = false;
  List<Map<String, dynamic>> _questions = []; final _aiPrompt = TextEditingController(); int _aiCount = 10;
  Set<int> _selected = {}; bool _selectMode = false;

  static const String groqKey = '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';
  static const String groqUrl = 'https://api.groq.com/openai/v1/chat/completions';
  static const _presets = [
    _Preset('📗 SP Easy', 'sp_focused_easy', 'assets/presets/sp_focused_easy.json', Color(0xFF00DD88)),
    _Preset('📕 SP Hard', 'sp_focused_hard', 'assets/presets/sp_focused_hard.json', Color(0xFFFF6644)),
    _Preset('📘 Tech Easy', 'tech_focused_easy', 'assets/presets/tech_focused_easy.json', Color(0xFF00BBFF)),
    _Preset('📙 Tech Hard', 'tech_focused_hard', 'assets/presets/tech_focused_hard.json', Color(0xFFFFAA00)),
  ];
  Color get gc => widget.gameColor;

  void _snack(String msg, {bool err = false}) { if (!mounted) return; ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: err ? const Color(0xFFEF4444) : const Color(0xFF22C55E), behavior: SnackBarBehavior.floating)); }

  Future<List<Map<String, dynamic>>> _askGroq(String sys, String usr) async {
    final r = await http.post(Uri.parse(groqUrl), headers: {'Authorization': 'Bearer $groqKey', 'Content-Type': 'application/json'},
      body: jsonEncode({'model': 'llama-3.3-70b-versatile', 'messages': [{'role': 'system', 'content': sys}, {'role': 'user', 'content': usr}], 'max_tokens': 4000, 'temperature': 0.3}));
    if (r.statusCode != 200) throw Exception('Groq ${r.statusCode}');
    String c = jsonDecode(r.body)['choices'][0]['message']['content'].toString().trim();
    c = c.replaceAll(RegExp(r'^```json\s*', multiLine: true), '').replaceAll(RegExp(r'^```\s*', multiLine: true), '').trim();
    final results = (jsonDecode(c) as List).whereType<Map>().where((m) => m['q'] != null && m['l'] != null && m['r'] != null && m['c'] != null).map((m) => Map<String, dynamic>.from(m)).toList();
    final rng = Random(); for (final q in results) { if (rng.nextBool()) { final tmp = q['l']; q['l'] = q['r']; q['r'] = tmp; q['c'] = q['c'] == 'left' ? 'right' : 'left'; } }
    return results;
  }

  Future<void> _aiGenerate() async { final p = _aiPrompt.text.trim(); if (p.isEmpty) { _snack('Type a topic', err: true); return; } setState(() => _generating = true);
    try { final r = await _askGroq('Generate exactly $_aiCount trivia questions.\nJSON array only: [{"q":"...","l":"left","r":"right","c":"left or right"}]\nMix correct sides. No markdown.', p); if (r.isEmpty) { _snack('No questions', err: true); return; } setState(() => _questions.addAll(r)); _snack('Generated ${r.length}'); } catch (e) { _snack('Failed: $e', err: true); }
    finally { if (mounted) setState(() => _generating = false); } }

  Future<void> _importSmart() async {
    try { final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['docx', 'txt', 'doc', 'rtf', 'md'], withData: true);
      if (result == null) return; final file = result.files.first; final bytes = file.bytes; if (bytes == null) return;
      setState(() => _smartParsing = true); String text = file.name.endsWith('.docx') ? _extractDocx(bytes) : utf8.decode(bytes, allowMalformed: true);
      if (text.trim().isEmpty) { _snack('No text', err: true); setState(() => _smartParsing = false); return; } if (text.length > 6000) text = text.substring(0, 6000);
      final r = await _askGroq('Extract questions from text. JSON array: [{"q":"...","l":"...","r":"...","c":"left or right"}]. Only JSON.', text);
      if (r.isEmpty) { _snack('No questions found', err: true); return; } setState(() => _questions.addAll(r)); _snack('Parsed ${r.length}');
    } catch (e) { _snack('Failed: $e', err: true); } finally { if (mounted) setState(() => _smartParsing = false); } }

  String _extractDocx(List<int> b) { try { final a = ZipDecoder().decodeBytes(b); for (final f in a) { if (f.name == 'word/document.xml') { return RegExp(r'<w:t[^>]*>(.*?)</w:t>').allMatches(utf8.decode(f.content as List<int>)).map((m) => m.group(1) ?? '').join(' ').replaceAll(RegExp(r'\s+'), ' ').trim(); } } } catch (_) {} return ''; }

  // ═══ EXCEL IMPORT ═══
  Future<void> _importExcel() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom, allowedExtensions: ['xlsx', 'xls'], withData: true);
      if (result == null) return;
      final bytes = result.files.first.bytes;
      if (bytes == null) return;

      final excel = xl.Excel.decodeBytes(bytes);
      final List<Map<String, dynamic>> parsed = [];

      for (final sheetName in excel.tables.keys) {
        final sheet = excel.tables[sheetName];
        if (sheet == null || sheet.rows.isEmpty) continue;

        // Detect header row — look for q/question, l/left, r/right, c/correct
        int qCol = -1, lCol = -1, rCol = -1, cCol = -1;
        int startRow = 0;
        final firstRow = sheet.rows.first;

        for (int ci = 0; ci < firstRow.length; ci++) {
          final val = firstRow[ci]?.value?.toString().toLowerCase().trim() ?? '';
          if (val == 'q' || val == 'question' || val == 'questions') qCol = ci;
          else if (val == 'l' || val == 'left' || val == 'left answer') lCol = ci;
          else if (val == 'r' || val == 'right' || val == 'right answer') rCol = ci;
          else if (val == 'c' || val == 'correct' || val == 'answer') cCol = ci;
        }

        if (qCol >= 0 && lCol >= 0 && rCol >= 0 && cCol >= 0) {
          startRow = 1; // skip header
        } else {
          // No header detected — assume columns are in order: q, l, r, c
          qCol = 0; lCol = 1; rCol = 2; cCol = 3;
          startRow = 0;
        }

        for (int ri = startRow; ri < sheet.rows.length; ri++) {
          final row = sheet.rows[ri];
          String cell(int ci) => (ci < row.length ? row[ci]?.value?.toString().trim() : null) ?? '';
          final q = cell(qCol), l = cell(lCol), r = cell(rCol);
          var c = cell(cCol).toLowerCase();
          if (q.isEmpty || l.isEmpty || r.isEmpty) continue;
          if (c != 'left' && c != 'right') c = 'left'; // default
          parsed.add({'q': q, 'l': l, 'r': r, 'c': c});
        }
      }

      if (parsed.isEmpty) { _snack('No valid rows found', err: true); return; }
      setState(() => _questions.addAll(parsed));
      _snack('Imported ${parsed.length} from Excel');
    } catch (e) { _snack('Excel import failed: $e', err: true); }
  }

  Future<void> _loadPreset(_Preset p) async { try { final raw = jsonDecode(await rootBundle.loadString(p.assetPath)); List<dynamic>? list = raw is List ? raw : (raw is Map ? raw.values.whereType<List>().firstOrNull : null); if (list == null) { _snack('Empty', err: true); return; } setState(() => _questions = list.map((e) => Map<String, dynamic>.from(e as Map)).toList()); _snack('Loaded ${_questions.length}'); } catch (e) { _snack('Failed: $e', err: true); } }
  Future<void> _importJson() async { try { final r = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['json'], withData: true); if (r == null) return; final b = r.files.first.bytes; if (b == null) return; final l = _extractList(jsonDecode(utf8.decode(b))); if (l.isEmpty) { _snack('Empty', err: true); return; } setState(() => _questions.addAll(l)); _snack('Added ${l.length}'); } catch (e) { _snack('Failed: $e', err: true); } }
  Future<void> _importCsv() async { try { final r = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['csv', 'txt'], withData: true); if (r == null) return; final b = r.files.first.bytes; if (b == null) return; final p = _parseSep(utf8.decode(b), ','); if (p.isEmpty) { _snack('Empty', err: true); return; } setState(() => _questions.addAll(p)); _snack('Added ${p.length}'); } catch (e) { _snack('Failed: $e', err: true); } }
  Future<void> _importPaste() async {
    final ctrl = TextEditingController();
    final r = await showDialog<String>(context: context, builder: (ctx) => AlertDialog(backgroundColor: const Color(0xFF0E1220), title: Text('PASTE QUESTIONS', style: TextStyle(color: gc, fontSize: 16, letterSpacing: 2)),
      content: SizedBox(width: double.maxFinite, height: 300, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('question | left | right | left/right', style: TextStyle(color: Color(0xFF4A5878), fontSize: 11)), const SizedBox(height: 12),
        Expanded(child: TextField(controller: ctrl, maxLines: null, expands: true, textAlignVertical: TextAlignVertical.top, style: const TextStyle(fontSize: 12, fontFamily: 'monospace'), decoration: const InputDecoration(hintText: 'Paste here...')))])),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL')), ElevatedButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('ADD'))]));
    if (r == null || r.trim().isEmpty) return; final p = _parseSep(r, '|'); if (p.isEmpty) { _snack('No valid lines', err: true); return; } setState(() => _questions.addAll(p)); _snack('Added ${p.length}'); }

  Future<void> _addManual() async { final r = await _qDlg('ADD', gc); if (r != null) { setState(() => _questions.add(r)); _snack('Added'); } }
  Future<void> _edit(int i) async { final r = await _qDlg('EDIT', gc, initial: _questions[i], del: true); if (r == null) return; if (r.containsKey('_delete')) { setState(() => _questions.removeAt(i)); _snack('Deleted'); } else { setState(() => _questions[i] = r); _snack('Updated'); } }
  void _deleteSel() { final s = _selected.toList()..sort((a, b) => b.compareTo(a)); for (final i in s) _questions.removeAt(i); final c = s.length; setState(() { _selected.clear(); _selectMode = false; }); _snack('Deleted $c'); }
  Future<Map<String, dynamic>?> _qDlg(String title, Color color, {Map<String, dynamic>? initial, bool del = false}) {
    final qC = TextEditingController(text: initial?['q'] ?? ''); final lC = TextEditingController(text: initial?['l'] ?? ''); final rC = TextEditingController(text: initial?['r'] ?? ''); String cor = initial?['c'] ?? 'left';
    return showDialog<Map<String, dynamic>>(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, ss) => AlertDialog(backgroundColor: const Color(0xFF0E1220), title: Text(title, style: TextStyle(color: color, fontSize: 16, letterSpacing: 2)),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: qC, decoration: const InputDecoration(labelText: 'Question'), maxLines: 2), const SizedBox(height: 12), TextField(controller: lC, decoration: const InputDecoration(labelText: 'Left')), const SizedBox(height: 12), TextField(controller: rC, decoration: const InputDecoration(labelText: 'Right')), const SizedBox(height: 16),
        SegmentedButton<String>(segments: const [ButtonSegment(value: 'left', label: Text('← LEFT')), ButtonSegment(value: 'right', label: Text('RIGHT →'))], selected: {cor}, onSelectionChanged: (s) => ss(() => cor = s.first))])),
      actions: [if (del) TextButton(onPressed: () => Navigator.pop(ctx, {'_delete': true}), child: const Text('DELETE', style: TextStyle(color: Color(0xFFEF4444)))), if (del) const Spacer(),
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL')),
        ElevatedButton(onPressed: () { if (qC.text.trim().isEmpty || lC.text.trim().isEmpty || rC.text.trim().isEmpty) return; Navigator.pop(ctx, {'q': qC.text.trim(), 'l': lC.text.trim(), 'r': rC.text.trim(), 'c': cor}); }, style: ElevatedButton.styleFrom(backgroundColor: color), child: Text(initial == null ? 'ADD' : 'SAVE'))]))); }

  Future<void> _upload() async {
    if (_questions.isEmpty || _uploading) return; setState(() => _uploading = true);
    try { final ref = FirebaseFirestore.instance.collection(widget.qCollection).doc(_target).collection('questions');
      final ex = await ref.get(); final batch = FirebaseFirestore.instance.batch(); for (final d in ex.docs) batch.delete(d.reference); await batch.commit();
      int c = 0; for (final q in _questions) { if (q['q'] != null) { await ref.add({...q, 'created_at': FieldValue.serverTimestamp()}); c++; } } _snack('Uploaded $c → ${widget.qCollection}/$_target');
    } catch (e) { _snack('Failed: $e', err: true); } finally { if (mounted) setState(() => _uploading = false); } }

  Future<void> _showExport() async {
    if (_questions.isEmpty) { _snack('No questions', err: true); return; }
    final fmt = await showModalBottomSheet<String>(context: context, backgroundColor: const Color(0xFF0E1220), shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Padding(padding: const EdgeInsets.all(20), child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('EXPORT FORMAT', style: TextStyle(color: Color(0xFF4A5878), fontSize: 12, letterSpacing: 2, fontWeight: FontWeight.bold)), const SizedBox(height: 16),
        ListTile(leading: const Icon(Icons.code, color: Color(0xFF22C55E)), title: const Text('JSON'), subtitle: const Text('Best for re-importing', style: TextStyle(fontSize: 11, color: Color(0xFF3A4868))), onTap: () => Navigator.pop(ctx, 'json')),
        ListTile(leading: const Icon(Icons.table_chart, color: Color(0xFFF59E0B)), title: const Text('CSV'), subtitle: const Text('Excel / Google Sheets', style: TextStyle(fontSize: 11, color: Color(0xFF3A4868))), onTap: () => Navigator.pop(ctx, 'csv')),
        ListTile(leading: const Icon(Icons.description, color: Color(0xFF60A5FA)), title: const Text('TXT'), subtitle: const Text('Plain text', style: TextStyle(fontSize: 11, color: Color(0xFF3A4868))), onTap: () => Navigator.pop(ctx, 'txt')),
        const SizedBox(height: 8), TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL'))])));
    if (fmt == null) return;
    try { String content; String fn; MimeType m;
      switch (fmt) { case 'json': content = const JsonEncoder.withIndent('  ').convert(_questions); fn = 'q_${DateTime.now().millisecondsSinceEpoch}.json'; m = MimeType.json;
        case 'csv': final b = StringBuffer('question,left,right,correct\n'); for (final q in _questions) { esc(String s) => '"${s.replaceAll('"', '""')}"'; b.writeln('${esc(q['q'] ?? '')},${esc(q['l'] ?? '')},${esc(q['r'] ?? '')},${q['c'] ?? 'left'}'); } content = b.toString(); fn = 'q_${DateTime.now().millisecondsSinceEpoch}.csv'; m = MimeType.csv;
        default: final b = StringBuffer(); for (var i = 0; i < _questions.length; i++) { final q = _questions[i]; b.writeln('${i + 1}. ${q['q']}\n   L: ${q['l']}\n   R: ${q['r']}\n   Answer: ${q['c'] == 'left' ? q['l'] : q['r']} (${q['c']})\n'); } content = b.toString(); fn = 'q_${DateTime.now().millisecondsSinceEpoch}.txt'; m = MimeType.text; }
      await FileSaver.instance.saveFile(name: fn, bytes: Uint8List.fromList(utf8.encode(content)), mimeType: m); _snack('Saved $fn');
    } catch (e) { _snack('Export failed: $e', err: true); } }

  List<Map<String, dynamic>> _extractList(dynamic d) { List<dynamic>? r; if (d is List) r = d; else if (d is Map) { for (final v in d.values) { if (v is List) { r = v; break; } } } if (r == null) return []; return r.whereType<Map>().where((m) => m['q'] != null && m['l'] != null && m['r'] != null && m['c'] != null).map((m) => Map<String, dynamic>.from(m)).toList(); }
  List<Map<String, dynamic>> _parseSep(String t, String sep) => t.split('\n').where((l) => l.trim().isNotEmpty).map((l) { final p = l.split(sep).map((s) => s.trim()).toList(); if (p.length < 4) return null; final c = p[3].toLowerCase(); if (c != 'left' && c != 'right') return null; return {'q': p[0], 'l': p[1], 'r': p[2], 'c': c}; }).whereType<Map<String, dynamic>>().toList();

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: _selectMode ? Text('${_selected.length} SELECTED') : const Text('QUESTIONS', style: TextStyle(letterSpacing: 3, fontWeight: FontWeight.w900, fontSize: 14)),
      leading: _selectMode ? IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() { _selectMode = false; _selected.clear(); })) : null,
      actions: [if (_selectMode) ...[IconButton(icon: Icon(Icons.select_all, color: gc), onPressed: () => setState(() { if (_selected.length == _questions.length) _selected.clear(); else _selected = Set.from(List.generate(_questions.length, (i) => i)); })), IconButton(icon: const Icon(Icons.delete, color: Color(0xFFEF4444)), onPressed: _deleteSel)]
        else ...[if (_questions.isNotEmpty) IconButton(icon: const Icon(Icons.download, color: Color(0xFF22C55E)), onPressed: _showExport), if (_questions.isNotEmpty) IconButton(icon: const Icon(Icons.delete_sweep, color: Color(0xFFEF4444)), onPressed: () => setState(() => _questions.clear()))]]),
    floatingActionButton: _selectMode ? null : FloatingActionButton(onPressed: _addManual, backgroundColor: gc, child: const Icon(Icons.add, color: Colors.white)),
    body: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (!_selectMode) Card(color: const Color(0xFF0A0E18), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: gc.withOpacity(0.2))),
        child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Icon(Icons.auto_awesome, color: gc, size: 18), const SizedBox(width: 8), Text('AI GENERATE', style: TextStyle(color: gc, fontSize: 11, letterSpacing: 2, fontWeight: FontWeight.w700))]),
          const SizedBox(height: 8),
          Row(children: [Expanded(child: TextField(controller: _aiPrompt, style: const TextStyle(fontSize: 13), decoration: const InputDecoration(hintText: 'Topic...', border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)), onSubmitted: (_) => _aiGenerate())),
            const SizedBox(width: 8), Container(padding: const EdgeInsets.symmetric(horizontal: 8), decoration: BoxDecoration(color: const Color(0xFF0A0E18), borderRadius: BorderRadius.circular(8)),
              child: DropdownButton<int>(value: _aiCount, dropdownColor: const Color(0xFF0E1220), underline: const SizedBox(), style: TextStyle(color: gc, fontSize: 12), items: [5, 10, 15, 20].map((n) => DropdownMenuItem(value: n, child: Text('$n'))).toList(), onChanged: (v) { if (v != null) setState(() => _aiCount = v); })),
            const SizedBox(width: 8), SizedBox(height: 40, child: ElevatedButton(onPressed: _generating ? null : _aiGenerate, style: ElevatedButton.styleFrom(backgroundColor: gc, padding: const EdgeInsets.symmetric(horizontal: 16)),
              child: _generating ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.auto_awesome, size: 18)))])]))),
      if (!_selectMode) const SizedBox(height: 10),
      if (!_selectMode) SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
        _ib(Icons.psychology, 'Smart', gc, _smartParsing ? null : _importSmart, loading: _smartParsing),
        const SizedBox(width: 6), _ib(Icons.folder_special, 'Presets', gc, _showPresets),
        const SizedBox(width: 6), _ib(Icons.upload_file, 'JSON', gc, _importJson),
        const SizedBox(width: 6), _ib(Icons.table_chart, 'CSV', gc, _importCsv),
        const SizedBox(width: 6), _ib(Icons.grid_on, 'Excel', gc, _importExcel),
        const SizedBox(width: 6), _ib(Icons.paste, 'Paste', gc, _importPaste)])),
      if (!_selectMode) const SizedBox(height: 10),
      Row(children: [Text('${_questions.length} QUESTIONS', style: TextStyle(color: gc, fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 1)), const Spacer(),
        if (!_selectMode) DropdownButton<String>(value: _target, dropdownColor: const Color(0xFF0E1220), underline: const SizedBox(), style: TextStyle(color: gc, fontSize: 12),
          items: ['custom', 'sp_focused_easy', 'sp_focused_hard', 'tech_focused_easy', 'tech_focused_hard'].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(), onChanged: (v) { if (v != null) setState(() => _target = v); })]),
      const SizedBox(height: 8),
      Expanded(child: _questions.isEmpty
        ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.quiz_outlined, size: 48, color: gc.withOpacity(0.15)), const SizedBox(height: 12), const Text('No questions yet', style: TextStyle(color: Color(0xFF2A3050)))]))
        : Container(decoration: BoxDecoration(color: const Color(0xFF080A14), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFF1A2040))),
            child: ListView.separated(padding: const EdgeInsets.all(10), itemCount: _questions.length, separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFF121828)),
              itemBuilder: (ctx, i) { final q = _questions[i]; final isL = q['c'] == 'left'; final isSel = _selected.contains(i);
                return Dismissible(key: ValueKey('$i-${q['q']}'), direction: _selectMode ? DismissDirection.none : DismissDirection.endToStart,
                  background: Container(alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20), color: const Color(0xFFEF4444).withOpacity(0.15), child: const Icon(Icons.delete, color: Color(0xFFEF4444))),
                  onDismissed: (_) { setState(() => _questions.removeAt(i)); _snack('Removed'); },
                  child: InkWell(onTap: () { if (_selectMode) { setState(() { if (isSel) _selected.remove(i); else _selected.add(i); if (_selected.isEmpty) _selectMode = false; }); } else _edit(i); },
                    onLongPress: () => setState(() { _selectMode = true; _selected.add(i); }),
                    child: Container(color: isSel ? gc.withOpacity(0.06) : null, padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        if (_selectMode) Padding(padding: const EdgeInsets.only(right: 8, top: 2), child: Icon(isSel ? Icons.check_circle : Icons.circle_outlined, size: 20, color: isSel ? gc : const Color(0xFF2A3050))),
                        SizedBox(width: 28, child: Text('${i + 1}', style: const TextStyle(color: Color(0xFF2A3050), fontSize: 12, fontWeight: FontWeight.w700))),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(q['q'] ?? '', style: const TextStyle(color: Colors.white70, fontSize: 13)), const SizedBox(height: 4),
                          Row(children: [Icon(isL ? Icons.check_circle : Icons.circle_outlined, size: 12, color: isL ? const Color(0xFF22C55E) : const Color(0xFF2A3050)), const SizedBox(width: 4), Expanded(child: Text(q['l'] ?? '', style: TextStyle(color: isL ? gc : const Color(0xFF3A4060), fontSize: 12)))]),
                          Row(children: [Icon(!isL ? Icons.check_circle : Icons.circle_outlined, size: 12, color: !isL ? const Color(0xFF22C55E) : const Color(0xFF2A3050)), const SizedBox(width: 4), Expanded(child: Text(q['r'] ?? '', style: TextStyle(color: !isL ? gc : const Color(0xFF3A4060), fontSize: 12)))])])),
                        if (!_selectMode) const Icon(Icons.edit, size: 14, color: Color(0xFF2A3050))]))));}))),
      const SizedBox(height: 10),
      if (!_selectMode) SizedBox(width: double.infinity, height: 48, child: ElevatedButton.icon(
        onPressed: _questions.isEmpty || _uploading ? null : _upload,
        icon: _uploading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.cloud_upload, size: 20),
        label: Text(_uploading ? 'UPLOADING...' : 'UPLOAD ${_questions.length} → $_target', style: const TextStyle(fontSize: 13, letterSpacing: 1)),
        style: ElevatedButton.styleFrom(backgroundColor: gc)))])));

  void _showPresets() { showModalBottomSheet(context: context, backgroundColor: const Color(0xFF0E1220), shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (ctx) => Padding(padding: const EdgeInsets.all(20), child: Column(mainAxisSize: MainAxisSize.min, children: [const Text('LOAD PRESET', style: TextStyle(color: Color(0xFF4A5878), fontSize: 12, letterSpacing: 2, fontWeight: FontWeight.bold)), const SizedBox(height: 16),
      ..._presets.map((p) => ListTile(leading: Icon(Icons.folder, color: p.color), title: Text(p.label, style: TextStyle(color: p.color)), trailing: const Icon(Icons.download, color: Color(0xFF2A3050)), onTap: () { Navigator.pop(ctx); _loadPreset(p); })),
      const SizedBox(height: 8), TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL'))]))); }

  Widget _ib(IconData icon, String label, Color c, VoidCallback? onTap, {bool loading = false}) => OutlinedButton.icon(onPressed: onTap,
    icon: loading ? SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: c)) : Icon(icon, size: 16, color: c),
    label: Text(label, style: TextStyle(color: c, fontSize: 11)), style: OutlinedButton.styleFrom(side: BorderSide(color: c.withOpacity(0.3)), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)));
}

class _Preset { final String label, category, assetPath; final Color color; const _Preset(this.label, this.category, this.assetPath, this.color); }