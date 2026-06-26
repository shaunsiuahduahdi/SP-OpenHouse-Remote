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
  try { await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform); } catch (e) { debugPrint('Firebase init: $e'); }
  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});
  @override
  Widget build(BuildContext ctx) => MaterialApp(
    debugShowCheckedModeBanner: false, title: 'osu!pose Remote',
    theme: ThemeData(brightness: Brightness.dark, scaffoldBackgroundColor: const Color(0xFF08061A),
      colorScheme: const ColorScheme.dark(primary: Color(0xFFFF4466), secondary: Color(0xFF44CCDD), surface: Color(0xFF120E24)),
      fontFamily: 'RobotoMono',
      appBarTheme: const AppBarTheme(backgroundColor: Color(0xFF0C0A1E), elevation: 0, centerTitle: true),
      cardTheme: CardThemeData(color: const Color(0xFF140E28), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFF2A1A4A)))),
      elevatedButtonTheme: ElevatedButtonThemeData(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF4466), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)))),
      inputDecorationTheme: InputDecorationTheme(filled: true, fillColor: const Color(0xFF0E0A20), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF2A1A4A))), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFFF4466), width: 2)))),
    home: const Nav());
}

class Nav extends StatefulWidget { const Nav({super.key}); @override State<Nav> createState() => _NavS(); }
class _NavS extends State<Nav> {
  int _t = 0;
  @override
  Widget build(BuildContext ctx) => Scaffold(
    body: IndexedStack(index: _t, children: const [RemotePage(), QuestionsPage()]),
    bottomNavigationBar: BottomNavigationBar(currentIndex: _t, onTap: (i) => setState(() => _t = i),
      backgroundColor: const Color(0xFF0C0A1E), selectedItemColor: const Color(0xFFFF4466), unselectedItemColor: const Color(0xFF443355),
      items: const [BottomNavigationBarItem(icon: Icon(Icons.gamepad), label: 'REMOTE'), BottomNavigationBarItem(icon: Icon(Icons.quiz), label: 'QUESTIONS')]));
}

// ═══════════════════════════════════════
// REMOTE
// ═══════════════════════════════════════
class RemotePage extends StatefulWidget { const RemotePage({super.key}); @override State<RemotePage> createState() => _RemoteS(); }
class _RemoteS extends State<RemotePage> {
  String? _sid; final _cc = TextEditingController(); bool _on = false; String _phase = 'menu'; String _mode = 'single';

  DocumentReference get _ref => FirebaseFirestore.instance.collection('osu_remote_sessions').doc(_sid);

  Future<void> _connect() async {
    final code = _cc.text.trim().toUpperCase(); if (code.isEmpty) return;
    try { final doc = await FirebaseFirestore.instance.collection('osu_remote_sessions').doc(code).get();
      if (!doc.exists) { if (!mounted) return; ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Session not found'), backgroundColor: Color(0xFFFF3355))); return; }
      setState(() { _sid = code; _on = true; _phase = 'menu'; }); await _ref.update({'controllerConnected': true});
    } catch (e) { if (!mounted) return; ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: const Color(0xFFFF3355))); }
  }

  Future<void> _cmd(String c, [Map<String, dynamic>? d]) async { if (_sid == null) return; try { await _ref.update({'command': c, 'commandData': d ?? {}, 'commandTimestamp': FieldValue.serverTimestamp()}); } catch (_) {} }
  void _disc() { if (_sid != null) _ref.update({'controllerConnected': false}).catchError((_) {}); setState(() { _sid = null; _on = false; _phase = 'menu'; }); }

  @override
  Widget build(BuildContext ctx) => Scaffold(
    appBar: AppBar(title: const Text('osu!pose', style: TextStyle(letterSpacing: 3, fontWeight: FontWeight.w900, color: Color(0xFFFF4466)))),
    body: Padding(padding: const EdgeInsets.all(16), child: !_on ? _connectUI() : Column(children: [
      Card(child: ListTile(leading: const Icon(Icons.link, color: Color(0xFF44DD88)),
        title: Text('SESSION: $_sid', style: const TextStyle(color: Color(0xFF44DD88), letterSpacing: 2, fontSize: 14)),
        trailing: IconButton(icon: const Icon(Icons.close, color: Color(0xFFFF3355)), onPressed: _disc))),
      const SizedBox(height: 16), Expanded(child: SingleChildScrollView(child: _phaseUI()))])));

  Widget _connectUI() => Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    const Icon(Icons.music_note, size: 56, color: Color(0xFF2A1A4A)), const SizedBox(height: 16),
    const Text('ENTER SESSION CODE', style: TextStyle(color: Color(0xFF8866AA), letterSpacing: 2, fontSize: 12)), const SizedBox(height: 12),
    TextField(controller: _cc, textAlign: TextAlign.center, style: const TextStyle(fontSize: 28, letterSpacing: 8, color: Color(0xFFFF4466)),
      textCapitalization: TextCapitalization.characters, decoration: const InputDecoration(hintText: '_ _ _ _', hintStyle: TextStyle(color: Color(0xFF2A1A4A), fontSize: 28, letterSpacing: 8)), onSubmitted: (_) => _connect()),
    const SizedBox(height: 16), SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _connect, child: const Text('CONNECT')))]);

  Widget _phaseUI() { switch (_phase) { case 'menu': return _menuUI(); case 'play': return _playingUI(); case 'go': return _gameOverUI(); default: return _menuUI(); } }

  Widget _menuUI() => Column(children: [
    const Text('SELECT MODE', style: TextStyle(color: Color(0xFF8866AA), letterSpacing: 2, fontSize: 12, fontWeight: FontWeight.bold)), const SizedBox(height: 20),
    _modeBtn(Icons.person, 'SINGLE PLAYER', const Color(0xFF44CCDD), 'single'),
    const SizedBox(height: 10), _modeBtn(Icons.wifi, 'ONLINE', const Color(0xFFFF4466), 'multi'),
    const SizedBox(height: 10), _modeBtn(Icons.people, 'DUAL SPLIT', const Color(0xFF8844FF), 'dual')]);

  Widget _modeBtn(IconData icon, String label, Color color, String mode) => SizedBox(width: double.infinity, height: 70, child: ElevatedButton(
    onPressed: () { _cmd('selectMode', {'mode': mode}); setState(() { _phase = 'play'; _mode = mode; }); },
    style: ElevatedButton.styleFrom(backgroundColor: color),
    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, size: 28), const SizedBox(width: 12), Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 2))])));

  Widget _playingUI() {
    final modeColor = _mode == 'dual' ? const Color(0xFF8844FF) : _mode == 'multi' ? const Color(0xFFFF4466) : const Color(0xFF44CCDD);
    final modeLabel = _mode == 'dual' ? '🎭 DUAL' : _mode == 'multi' ? '🌐 ONLINE' : '🎮 SINGLE';
    return Column(children: [
      Center(child: Text(modeLabel, style: TextStyle(color: modeColor, fontSize: 14, letterSpacing: 2, fontWeight: FontWeight.bold))),
      const SizedBox(height: 30), const Icon(Icons.music_note, size: 64, color: Color(0xFFFF4466)),
      const SizedBox(height: 12), const Text('PLAYING', style: TextStyle(color: Color(0xFFFF4466), fontSize: 18, letterSpacing: 3, fontWeight: FontWeight.w900)),
      const SizedBox(height: 40),
      SizedBox(width: double.infinity, height: 56, child: ElevatedButton.icon(onPressed: () { _cmd('stop'); setState(() => _phase = 'menu'); },
        icon: const Icon(Icons.stop, size: 24), label: const Text('STOP', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF3355)))),
      const SizedBox(height: 12),
      SizedBox(width: double.infinity, height: 56, child: ElevatedButton.icon(onPressed: () { _cmd('restart'); },
        icon: const Icon(Icons.refresh, size: 24), label: const Text('RESTART', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFAA00))))]);
  }

  Widget _gameOverUI() => Column(children: [
    const SizedBox(height: 40), const Icon(Icons.flag, size: 64, color: Color(0xFFFFAA00)),
    const SizedBox(height: 12), const Text('GAME OVER', style: TextStyle(color: Color(0xFFFFAA00), fontSize: 18, letterSpacing: 3, fontWeight: FontWeight.w900)),
    const SizedBox(height: 40),
    SizedBox(width: double.infinity, height: 56, child: ElevatedButton.icon(onPressed: () { _cmd('restart'); setState(() => _phase = 'play'); },
      icon: const Icon(Icons.refresh, size: 24), label: const Text('PLAY AGAIN', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 2)),
      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF44DD88)))),
    const SizedBox(height: 12),
    SizedBox(width: double.infinity, height: 48, child: OutlinedButton.icon(onPressed: () { _cmd('backToMenu'); setState(() => _phase = 'menu'); },
      icon: const Icon(Icons.arrow_back, color: Color(0xFF8866AA)), label: const Text('BACK TO MENU', style: TextStyle(color: Color(0xFF8866AA))),
      style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFF443355)))))]);
}

// ═══════════════════════════════════════
// QUESTIONS — 100% mirror of RunningMan
// ═══════════════════════════════════════
class QuestionsPage extends StatefulWidget { const QuestionsPage({super.key}); @override State<QuestionsPage> createState() => _QuestionsS(); }
class _QuestionsS extends State<QuestionsPage> {
  String _target = 'custom'; bool _uploading = false; bool _generating = false; bool _smartParsing = false;
  List<Map<String, dynamic>> _questions = []; final _aiPrompt = TextEditingController(); int _aiCount = 10;
  Set<int> _selected = {}; bool _selectMode = false;

  static const String groqKey = 'YOUR_GROQ_API_KEY';
  static const String groqUrl = 'https://api.groq.com/openai/v1/chat/completions';
  static const _presets = [
    _Preset('📗 SP Easy', 'sp_focused_easy', 'assets/presets/sp_focused_easy.json', Color(0xFF00DD88)),
    _Preset('📕 SP Hard', 'sp_focused_hard', 'assets/presets/sp_focused_hard.json', Color(0xFFFF6644)),
    _Preset('📘 Tech Easy', 'tech_focused_easy', 'assets/presets/tech_focused_easy.json', Color(0xFF00BBFF)),
    _Preset('📙 Tech Hard', 'tech_focused_hard', 'assets/presets/tech_focused_hard.json', Color(0xFFFFAA00))];

  void _snack(String msg, {bool error = false}) { if (!mounted) return; ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: error ? const Color(0xFFFF3355) : const Color(0xFF00DD88), behavior: SnackBarBehavior.floating)); }

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

  Future<void> _aiGenerate() async { final p = _aiPrompt.text.trim(); if (p.isEmpty) { _snack('Type a topic first', error: true); return; } setState(() => _generating = true);
    try { final r = await _askGroq('You are a trivia question generator. Generate exactly $_aiCount questions.\nJSON array only: [{"q":"question","l":"left","r":"right","c":"left or right"}]', p); if (r.isEmpty) { _snack('No questions', error: true); return; } setState(() => _questions.addAll(r)); _snack('Generated ${r.length}'); } catch (e) { _snack('Failed: $e', error: true); }
    finally { if (mounted) setState(() => _generating = false); } }

  Future<void> _importSmart() async {
    try { final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['docx', 'txt', 'doc', 'rtf', 'md'], withData: true);
      if (result == null || result.files.isEmpty) return; final file = result.files.first; final bytes = file.bytes; if (bytes == null) { _snack('Could not read', error: true); return; }
      setState(() => _smartParsing = true); String text = file.name.endsWith('.docx') ? _extractDocxText(bytes) : utf8.decode(bytes, allowMalformed: true);
      if (text.trim().isEmpty) { _snack('No text', error: true); setState(() => _smartParsing = false); return; } if (text.length > 6000) text = text.substring(0, 6000);
      final r = await _askGroq('Extract questions from text. JSON array: [{"q":"...","l":"...","r":"...","c":"left or right"}]. Only JSON.', text);
      if (r.isEmpty) { _snack('No questions found', error: true); return; } setState(() => _questions.addAll(r)); _snack('Parsed ${r.length}');
    } catch (e) { _snack('Failed: $e', error: true); } finally { if (mounted) setState(() => _smartParsing = false); } }

  String _extractDocxText(List<int> bytes) { try { final a = ZipDecoder().decodeBytes(bytes); for (final f in a) { if (f.name == 'word/document.xml') { return RegExp(r'<w:t[^>]*>(.*?)</w:t>').allMatches(utf8.decode(f.content as List<int>)).map((m) => m.group(1) ?? '').join(' ').replaceAll(RegExp(r'\s+'), ' ').trim(); } } } catch (_) {} return ''; }

  Future<void> _showExport() async {
    if (_questions.isEmpty) { _snack('No questions', error: true); return; }
    final fmt = await showModalBottomSheet<String>(context: context, backgroundColor: const Color(0xFF140E28), shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Padding(padding: const EdgeInsets.all(20), child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('EXPORT FORMAT', style: TextStyle(color: Color(0xFF8866AA), fontSize: 12, letterSpacing: 2)), const SizedBox(height: 16),
        ListTile(leading: const Icon(Icons.code, color: Color(0xFF00DD88)), title: const Text('JSON'), onTap: () => Navigator.pop(ctx, 'json')),
        ListTile(leading: const Icon(Icons.table_chart, color: Color(0xFFFFAA00)), title: const Text('CSV'), onTap: () => Navigator.pop(ctx, 'csv')),
        ListTile(leading: const Icon(Icons.description, color: Color(0xFF00BBFF)), title: const Text('TXT'), onTap: () => Navigator.pop(ctx, 'txt')),
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL'))])));
    if (fmt == null) return;
    try { String c; String fn; MimeType m;
      switch (fmt) { case 'json': c = const JsonEncoder.withIndent('  ').convert(_questions); fn = 'q_${DateTime.now().millisecondsSinceEpoch}.json'; m = MimeType.json;
        case 'csv': final b = StringBuffer('question,left,right,correct\n'); for (final q in _questions) { esc(String s) => '"${s.replaceAll('"', '""')}"'; b.writeln('${esc(q['q'] ?? '')},${esc(q['l'] ?? '')},${esc(q['r'] ?? '')},${q['c'] ?? 'left'}'); } c = b.toString(); fn = 'q_${DateTime.now().millisecondsSinceEpoch}.csv'; m = MimeType.csv;
        default: final b = StringBuffer(); for (var i = 0; i < _questions.length; i++) { final q = _questions[i]; b.writeln('${i + 1}. ${q['q']}\n   L: ${q['l']}\n   R: ${q['r']}\n   Answer: ${q['c'] == 'left' ? q['l'] : q['r']} (${q['c']})\n'); } c = b.toString(); fn = 'q_${DateTime.now().millisecondsSinceEpoch}.txt'; m = MimeType.text; }
      await FileSaver.instance.saveFile(name: fn, bytes: Uint8List.fromList(utf8.encode(c)), mimeType: m); _snack('Saved $fn');
    } catch (e) { _snack('Export failed: $e', error: true); } }

  Future<void> _loadPreset(_Preset p) async { try { final raw = jsonDecode(await rootBundle.loadString(p.assetPath)); List<dynamic>? list = raw is List ? raw : (raw is Map ? raw.values.whereType<List>().firstOrNull : null); if (list == null) { _snack('Empty', error: true); return; } setState(() => _questions = list.map((e) => Map<String, dynamic>.from(e as Map)).toList()); _snack('Loaded ${_questions.length}'); } catch (e) { _snack('Failed: $e', error: true); } }
  Future<void> _importJson() async { try { final r = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['json'], withData: true); if (r == null) return; final b = r.files.first.bytes; if (b == null) return; final l = _extractList(jsonDecode(utf8.decode(b))); if (l.isEmpty) { _snack('No questions', error: true); return; } setState(() => _questions.addAll(l)); _snack('Added ${l.length}'); } catch (e) { _snack('Failed: $e', error: true); } }
  Future<void> _importCsv() async { try { final r = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['csv', 'txt'], withData: true); if (r == null) return; final b = r.files.first.bytes; if (b == null) return; final p = _parseSep(utf8.decode(b), ','); if (p.isEmpty) { _snack('No rows', error: true); return; } setState(() => _questions.addAll(p)); _snack('Added ${p.length}'); } catch (e) { _snack('Failed: $e', error: true); } }
  Future<void> _importPaste() async {
    final ctrl = TextEditingController();
    final r = await showDialog<String>(context: context, builder: (ctx) => AlertDialog(backgroundColor: const Color(0xFF140E28), title: const Text('PASTE QUESTIONS', style: TextStyle(color: Color(0xFFBB88FF), fontSize: 16, letterSpacing: 2)),
      content: SizedBox(width: double.maxFinite, height: 300, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('question | left | right | left/right', style: TextStyle(color: Color(0xFF8866AA), fontSize: 11)), const SizedBox(height: 12),
        Expanded(child: TextField(controller: ctrl, maxLines: null, expands: true, textAlignVertical: TextAlignVertical.top, style: const TextStyle(fontSize: 12, fontFamily: 'monospace'), decoration: const InputDecoration(hintText: 'Paste here...')))])),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL')), ElevatedButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('ADD'))]));
    if (r == null || r.trim().isEmpty) return; final p = _parseSep(r, '|'); if (p.isEmpty) { _snack('No valid lines', error: true); return; } setState(() => _questions.addAll(p)); _snack('Added ${p.length}'); }

  Future<void> _addManual() async { final r = await _qDialog('ADD', const Color(0xFFFF4466)); if (r != null) { setState(() => _questions.add(r)); _snack('Added'); } }
  Future<void> _edit(int i) async { final r = await _qDialog('EDIT', const Color(0xFFFFAA00), initial: _questions[i], del: true); if (r == null) return; if (r.containsKey('_delete')) { setState(() => _questions.removeAt(i)); _snack('Deleted'); } else { setState(() => _questions[i] = r); _snack('Updated'); } }
  void _deleteSel() { final s = _selected.toList()..sort((a, b) => b.compareTo(a)); for (final i in s) _questions.removeAt(i); final c = s.length; setState(() { _selected.clear(); _selectMode = false; }); _snack('Deleted $c'); }

  Future<Map<String, dynamic>?> _qDialog(String title, Color color, {Map<String, dynamic>? initial, bool del = false}) {
    final qC = TextEditingController(text: initial?['q'] ?? ''); final lC = TextEditingController(text: initial?['l'] ?? ''); final rC = TextEditingController(text: initial?['r'] ?? ''); String cor = initial?['c'] ?? 'left';
    return showDialog<Map<String, dynamic>>(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, ss) => AlertDialog(backgroundColor: const Color(0xFF140E28), title: Text(title, style: TextStyle(color: color, fontSize: 16, letterSpacing: 2)),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: qC, decoration: const InputDecoration(labelText: 'Question'), maxLines: 2), const SizedBox(height: 12), TextField(controller: lC, decoration: const InputDecoration(labelText: 'Left')), const SizedBox(height: 12), TextField(controller: rC, decoration: const InputDecoration(labelText: 'Right')), const SizedBox(height: 16),
        SegmentedButton<String>(segments: const [ButtonSegment(value: 'left', label: Text('← LEFT')), ButtonSegment(value: 'right', label: Text('RIGHT →'))], selected: {cor}, onSelectionChanged: (s) => ss(() => cor = s.first))])),
      actions: [if (del) TextButton(onPressed: () => Navigator.pop(ctx, {'_delete': true}), child: const Text('DELETE', style: TextStyle(color: Color(0xFFFF3355)))), if (del) const Spacer(),
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL')),
        ElevatedButton(onPressed: () { if (qC.text.trim().isEmpty || lC.text.trim().isEmpty || rC.text.trim().isEmpty) return; Navigator.pop(ctx, {'q': qC.text.trim(), 'l': lC.text.trim(), 'r': rC.text.trim(), 'c': cor}); }, style: ElevatedButton.styleFrom(backgroundColor: color), child: Text(initial == null ? 'ADD' : 'SAVE'))]))); }

  Future<void> _upload() async {
    if (_questions.isEmpty || _uploading) return; setState(() => _uploading = true);
    try { final ref = FirebaseFirestore.instance.collection('osu_question_pools').doc(_target).collection('questions');
      final ex = await ref.get(); final batch = FirebaseFirestore.instance.batch(); for (final d in ex.docs) batch.delete(d.reference); await batch.commit();
      int c = 0; for (final q in _questions) { if (q['q'] != null && q['l'] != null && q['r'] != null && q['c'] != null) { await ref.add({'q': q['q'], 'l': q['l'], 'r': q['r'], 'c': q['c'], 'created_at': FieldValue.serverTimestamp()}); c++; } } _snack('Uploaded $c to $_target');
    } catch (e) { _snack('Failed: $e', error: true); } finally { if (mounted) setState(() => _uploading = false); } }

  List<Map<String, dynamic>> _extractList(dynamic d) { List<dynamic>? r; if (d is List) r = d; else if (d is Map) { for (final v in d.values) { if (v is List) { r = v; break; } } } if (r == null) return []; return r.whereType<Map>().where((m) => m['q'] != null && m['l'] != null && m['r'] != null && m['c'] != null).map((m) => Map<String, dynamic>.from(m)).toList(); }
  List<Map<String, dynamic>> _parseSep(String t, String sep) => t.split('\n').where((l) => l.trim().isNotEmpty).map((l) { final p = l.split(sep).map((s) => s.trim()).toList(); if (p.length < 4) return null; final c = p[3].toLowerCase(); if (c != 'left' && c != 'right') return null; return {'q': p[0], 'l': p[1], 'r': p[2], 'c': c}; }).whereType<Map<String, dynamic>>().toList();

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: _selectMode ? Text('${_selected.length} SELECTED') : const Text('QUESTIONS', style: TextStyle(letterSpacing: 3, fontWeight: FontWeight.w900)),
      leading: _selectMode ? IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() { _selectMode = false; _selected.clear(); })) : null,
      actions: [if (_selectMode) ...[IconButton(icon: const Icon(Icons.select_all, color: Color(0xFFFF4466)), onPressed: () => setState(() { if (_selected.length == _questions.length) _selected.clear(); else _selected = Set.from(List.generate(_questions.length, (i) => i)); })), IconButton(icon: const Icon(Icons.delete, color: Color(0xFFFF3355)), onPressed: _deleteSel)]
        else ...[if (_questions.isNotEmpty) IconButton(icon: const Icon(Icons.download, color: Color(0xFF44DD88)), onPressed: _showExport), if (_questions.isNotEmpty) IconButton(icon: const Icon(Icons.delete_sweep, color: Color(0xFFFF3355)), onPressed: () => setState(() => _questions.clear()))]]),
    floatingActionButton: _selectMode ? null : FloatingActionButton(onPressed: _addManual, backgroundColor: const Color(0xFFFF4466), child: const Icon(Icons.add, color: Colors.white)),
    body: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (!_selectMode) Card(color: const Color(0xFF0E0A1E), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFF4A2A6A))),
        child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [Icon(Icons.auto_awesome, color: Color(0xFFBB88FF), size: 18), SizedBox(width: 8), Text('AI GENERATE', style: TextStyle(color: Color(0xFFBB88FF), fontSize: 11, letterSpacing: 2, fontWeight: FontWeight.bold))]),
          const SizedBox(height: 8),
          Row(children: [Expanded(child: TextField(controller: _aiPrompt, style: const TextStyle(fontSize: 13), decoration: const InputDecoration(hintText: 'e.g. "SP history"', hintStyle: TextStyle(color: Color(0xFF443355), fontSize: 12), border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)), onSubmitted: (_) => _aiGenerate())),
            const SizedBox(width: 8), Container(padding: const EdgeInsets.symmetric(horizontal: 8), decoration: BoxDecoration(color: const Color(0xFF0E0A20), borderRadius: BorderRadius.circular(8)),
              child: DropdownButton<int>(value: _aiCount, dropdownColor: const Color(0xFF140E28), underline: const SizedBox(), style: const TextStyle(color: Color(0xFFBB88FF), fontSize: 12), items: [5, 10, 15, 20].map((n) => DropdownMenuItem(value: n, child: Text('$n'))).toList(), onChanged: (v) { if (v != null) setState(() => _aiCount = v); })),
            const SizedBox(width: 8), SizedBox(height: 40, child: ElevatedButton(onPressed: _generating ? null : _aiGenerate, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFBB88FF), padding: const EdgeInsets.symmetric(horizontal: 16)),
              child: _generating ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.auto_awesome, size: 18)))])]))),
      if (!_selectMode) const SizedBox(height: 12),
      if (!_selectMode) SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
        _ib(Icons.psychology, 'Smart Import', const Color(0xFFFF6688), _smartParsing ? null : _importSmart, loading: _smartParsing),
        const SizedBox(width: 8), _ib(Icons.folder_special, 'Presets', const Color(0xFF44CCDD), _showPresets),
        const SizedBox(width: 8), _ib(Icons.upload_file, 'JSON', const Color(0xFF00DD88), _importJson),
        const SizedBox(width: 8), _ib(Icons.table_chart, 'CSV', const Color(0xFFFFAA00), _importCsv),
        const SizedBox(width: 8), _ib(Icons.paste, 'Paste', const Color(0xFFBB88FF), _importPaste)])),
      if (!_selectMode) const SizedBox(height: 12),
      Row(children: [Text('${_questions.length} QUESTIONS', style: const TextStyle(color: Color(0xFFFF4466), fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1)),
        if (_selectMode) Text('  (${_selected.length})', style: const TextStyle(color: Color(0xFFFFAA00), fontSize: 12)), const Spacer(),
        if (!_selectMode) ...[const Text('To: ', style: TextStyle(color: Color(0xFF443355), fontSize: 11)),
          DropdownButton<String>(value: _target, dropdownColor: const Color(0xFF140E28), underline: const SizedBox(), style: const TextStyle(color: Color(0xFFFF4466), fontSize: 12),
            items: ['custom', 'sp_focused_easy', 'sp_focused_hard', 'tech_focused_easy', 'tech_focused_hard'].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(), onChanged: (v) { if (v != null) setState(() => _target = v); })]]),
      const SizedBox(height: 8),
      Expanded(child: _questions.isEmpty
          ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.quiz_outlined, size: 48, color: Color(0xFF2A1A4A)), const SizedBox(height: 12), const Text('No questions yet', style: TextStyle(color: Color(0xFF443355)))]))
          : Container(decoration: BoxDecoration(color: const Color(0xFF0A0816), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFF2A1A4A))),
              child: ListView.separated(padding: const EdgeInsets.all(10), itemCount: _questions.length, separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFF1A1228)),
                itemBuilder: (ctx, i) { final q = _questions[i]; final isL = q['c'] == 'left'; final isSel = _selected.contains(i);
                  return Dismissible(key: ValueKey('$i-${q['q']}'), direction: _selectMode ? DismissDirection.none : DismissDirection.endToStart,
                    background: Container(alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20), color: const Color(0xFFFF3355).withOpacity(0.2), child: const Icon(Icons.delete, color: Color(0xFFFF3355))),
                    onDismissed: (_) { setState(() => _questions.removeAt(i)); _snack('Removed'); },
                    child: InkWell(onTap: () { if (_selectMode) { setState(() { if (isSel) _selected.remove(i); else _selected.add(i); if (_selected.isEmpty) _selectMode = false; }); } else { _edit(i); } },
                      onLongPress: () => setState(() { _selectMode = true; _selected.add(i); }),
                      child: Container(color: isSel ? const Color(0xFFFF4466).withOpacity(0.08) : null, padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          if (_selectMode) Padding(padding: const EdgeInsets.only(right: 8, top: 2), child: Icon(isSel ? Icons.check_circle : Icons.circle_outlined, size: 20, color: isSel ? const Color(0xFFFF4466) : const Color(0xFF443355))),
                          SizedBox(width: 28, child: Text('${i + 1}', style: const TextStyle(color: Color(0xFF443355), fontSize: 12, fontWeight: FontWeight.bold))),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(q['q'] ?? '', style: const TextStyle(color: Colors.white70, fontSize: 13)), const SizedBox(height: 4),
                            Row(children: [Icon(isL ? Icons.check_circle : Icons.circle_outlined, size: 12, color: isL ? const Color(0xFF44DD88) : const Color(0xFF443355)), const SizedBox(width: 4), Expanded(child: Text(q['l'] ?? '', style: TextStyle(color: isL ? const Color(0xFF44CCDD) : const Color(0xFF554466), fontSize: 12)))]),
                            const SizedBox(height: 2),
                            Row(children: [Icon(!isL ? Icons.check_circle : Icons.circle_outlined, size: 12, color: !isL ? const Color(0xFF44DD88) : const Color(0xFF443355)), const SizedBox(width: 4), Expanded(child: Text(q['r'] ?? '', style: TextStyle(color: !isL ? const Color(0xFFFF8888) : const Color(0xFF554466), fontSize: 12)))])])),
                          if (!_selectMode) const Icon(Icons.edit, size: 14, color: Color(0xFF443355))]))));}))),
      const SizedBox(height: 12),
      if (!_selectMode) SizedBox(width: double.infinity, height: 52, child: ElevatedButton.icon(
        onPressed: _questions.isEmpty || _uploading ? null : _upload,
        icon: _uploading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.cloud_upload, size: 22),
        label: Text(_uploading ? 'UPLOADING...' : 'UPLOAD ${_questions.length} → $_target', style: const TextStyle(fontSize: 13, letterSpacing: 1))))])));

  void _showPresets() { showModalBottomSheet(context: context, backgroundColor: const Color(0xFF140E28), shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (ctx) => Padding(padding: const EdgeInsets.all(20), child: Column(mainAxisSize: MainAxisSize.min, children: [const Text('LOAD PRESET', style: TextStyle(color: Color(0xFF8866AA), fontSize: 12, letterSpacing: 2)), const SizedBox(height: 16),
      ..._presets.map((p) => ListTile(leading: Icon(Icons.folder, color: p.color), title: Text(p.label, style: TextStyle(color: p.color)), onTap: () { Navigator.pop(ctx); _loadPreset(p); })),
      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL'))]))); }

  Widget _ib(IconData icon, String label, Color c, VoidCallback? onTap, {bool loading = false}) => OutlinedButton.icon(onPressed: onTap,
    icon: loading ? SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: c)) : Icon(icon, size: 16, color: c),
    label: Text(label, style: TextStyle(color: c, fontSize: 11)), style: OutlinedButton.styleFrom(side: BorderSide(color: c.withOpacity(0.3)), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10)));
}

class _Preset { final String label, category, assetPath; final Color color; const _Preset(this.label, this.category, this.assetPath, this.color); }