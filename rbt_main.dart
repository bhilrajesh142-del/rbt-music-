import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:photo_manager/photo_manager.dart';

const ink = Color(0xFF2B1B5A), acc = Color(0xFFFFB400), pink = Color(0xFFFF4D8D);
const bg = Color(0xFFEBE8F5), night = Color(0xFF1A1233);
final player = AudioPlayer();

String clean(String n) { final i = n.lastIndexOf('.'); return i > 0 ? n.substring(0, i) : n; }
String fmt(Duration d) => '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

class Song {
  final AssetEntity asset;
  final String title;
  Song(this.asset) : title = clean(asset.title ?? 'Unknown');
}

class Ctl extends ChangeNotifier {
  List<Song> songs = [], view = [];
  Song? cur;
  bool shuffle = false, repeat = false;
  Ctl() {
    player.processingStateStream.listen((s) {
      if (s == ProcessingState.completed) {
        if (repeat) { player.seek(Duration.zero); player.play(); } else { step(1); }
      }
    });
    player.playingStream.listen((_) => notifyListeners());
  }
  Future<void> play(Song s) async {
    cur = s; notifyListeners();
    final f = await s.asset.originFile;
    if (f == null) return;
    await player.setFilePath(f.path);
    player.play();
  }
  void step(int d) {
    final a = view.isEmpty ? songs : view;
    if (a.isEmpty) return;
    final i = shuffle ? Random().nextInt(a.length) : (a.indexOf(cur ?? a.first) + d + a.length) % a.length;
    play(a[i]);
  }
  void toggle() => player.playing ? player.pause() : player.play();
  void flip({bool? sh, bool? rp}) { if (sh != null) shuffle = sh; if (rp != null) repeat = rp; notifyListeners(); }
}
final ctl = Ctl();

void main() { WidgetsFlutterBinding.ensureInitialized(); runApp(const App()); }

class App extends StatelessWidget {
  const App({super.key});
  @override
  Widget build(BuildContext c) => MaterialApp(
        title: 'RBT MUSIC',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(colorSchemeSeed: ink, useMaterial3: true, scaffoldBackgroundColor: bg),
        home: const Splash(),
      );
}

Widget record(double size) => Container(
      width: size, height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(colors: [acc, acc, Color(0xFF0D0719), Color(0xFF24164A), Color(0xFF0D0719), Color(0xFF24164A)], stops: [0, .3, .31, .55, .75, 1]),
        boxShadow: [BoxShadow(color: acc.withOpacity(.45), blurRadius: size / 5)],
      ),
      child: Center(child: Container(width: size * .1, height: size * .1, decoration: const BoxDecoration(color: night, shape: BoxShape.circle))),
    );

Widget gradText(String t, double size) => ShaderMask(
      shaderCallback: (r) => const LinearGradient(colors: [acc, pink]).createShader(r),
      child: Text(t, style: TextStyle(fontSize: size, fontWeight: FontWeight.w900, letterSpacing: 4, color: Colors.white)),
    );

// ---------- Start animation ----------
class Splash extends StatefulWidget { const Splash({super.key}); @override State<Splash> createState() => _SplashState(); }
class _SplashState extends State<Splash> with SingleTickerProviderStateMixin {
  late final AnimationController spin = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();
  @override
  void initState() {
    super.initState();
    Timer(const Duration(milliseconds: 3800), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(PageRouteBuilder(
        pageBuilder: (_, __, ___) => const Library(),
        transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
      ));
    });
  }
  @override
  void dispose() { spin.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext c) => Scaffold(
        backgroundColor: night,
        body: Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 1400),
            curve: Curves.elasticOut,
            builder: (_, v, child) => Opacity(opacity: v.clamp(0, 1), child: Transform.scale(scale: v, child: child)),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              RotationTransition(turns: spin, child: record(170)),
              const SizedBox(height: 28),
              gradText('RBT MUSIC', 40),
              const SizedBox(height: 10),
              const Text('Apna Sangeet, Apni Dhun', style: TextStyle(color: Color(0xFFCFC4FF), letterSpacing: 2)),
            ]),
          ),
        ),
      );
}

// ---------- Music list ----------
class Library extends StatefulWidget { const Library({super.key}); @override State<Library> createState() => _LibraryState(); }
class _LibraryState extends State<Library> {
  bool loading = true, denied = false;
  String q = '';
  @override
  void initState() { super.initState(); load(); }
  Future<void> load() async {
    setState(() { loading = true; denied = false; });
    final ps = await PhotoManager.requestPermissionExtend(
      requestOption: const PermissionRequestOption(androidPermission: AndroidPermission(type: RequestType.audio, mediaLocation: false)));
    if (!ps.hasAccess) { setState(() { loading = false; denied = true; }); return; }
    final paths = await PhotoManager.getAssetPathList(type: RequestType.audio, onlyAll: true);
    if (paths.isNotEmpty) {
      final n = await paths.first.assetCountAsync;
      final list = await paths.first.getAssetListRange(start: 0, end: n);
      ctl.songs = list.map(Song.new).toList()..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    }
    setState(() => loading = false);
  }
  @override
  Widget build(BuildContext c) {
    ctl.view = ctl.songs.where((s) => s.title.toLowerCase().contains(q.toLowerCase())).toList();
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), gradient: const LinearGradient(colors: [ink, Color(0xFF4A2A96), Color(0xFF8A2C7A)])),
            child: Row(children: [
              record(58),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                gradText('RBT', 52),
                Text('MUSIC', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: 9,
                    foreground: Paint()..style = PaintingStyle.stroke..strokeWidth = 1.2..color = Colors.white)),
                const SizedBox(height: 8),
                const Text('Apna Sangeet, Apni Dhun', style: TextStyle(color: Color(0xFFD9CFFC), fontSize: 12, letterSpacing: 1.5)),
              ])),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              onChanged: (v) => setState(() => q = v),
              decoration: InputDecoration(hintText: 'Gaana khojiye', prefixIcon: const Icon(Icons.search), filled: true, fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
            ),
          ),
          Padding(padding: const EdgeInsets.all(10), child: Text('${ctl.view.length} gaane', style: const TextStyle(color: Colors.black54))),
          Expanded(child: body()),
          ListenableBuilder(listenable: ctl, builder: (_, __) => ctl.cur == null ? const SizedBox() : miniBar()),
        ]),
      ),
    );
  }
  Widget body() {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (denied) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('Gaane dikhane ke liye music permission chahiye'),
        const SizedBox(height: 10),
        FilledButton(onPressed: load, child: const Text('Permission do')),
        TextButton(onPressed: PhotoManager.openSetting, child: const Text('Settings kholiye')),
      ]));
    }
    if (ctl.view.isEmpty) return const Center(child: Text('Koi gaana nahi mila'));
    return ListenableBuilder(
      listenable: ctl,
      builder: (_, __) => ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: ctl.view.length,
        itemBuilder: (_, i) {
          final s = ctl.view[i];
          final on = s == ctl.cur;
          return Card(
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: on ? acc : const Color(0xFFD9D4EC))),
            child: ListTile(
              leading: Text(on && player.playing ? '♪' : '${i + 1}'),
              title: Text(s.title, maxLines: 1, overflow: TextOverflow.ellipsis),
              onTap: () { ctl.play(s); Navigator.push(context, MaterialPageRoute(builder: (_) => const PlayerPage())); },
            ),
          );
        },
      ),
    );
  }
  Widget miniBar() => GestureDetector(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PlayerPage())),
        child: Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.fromLTRB(16, 6, 6, 6),
          decoration: BoxDecoration(color: ink, borderRadius: BorderRadius.circular(14)),
          child: Row(children: [
            Expanded(child: Text(ctl.cur!.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white))),
            IconButton(onPressed: ctl.toggle, icon: Icon(player.playing ? Icons.pause_circle : Icons.play_circle, color: acc, size: 36)),
          ]),
        ),
      );
}

// ---------- Player ----------
class PlayerPage extends StatefulWidget { const PlayerPage({super.key}); @override State<PlayerPage> createState() => _PlayerPageState(); }
class _PlayerPageState extends State<PlayerPage> with SingleTickerProviderStateMixin {
  late final AnimationController spin = AnimationController(vsync: this, duration: const Duration(seconds: 5));
  late final StreamSubscription sub;
  @override
  void initState() {
    super.initState();
    if (player.playing) spin.repeat();
    sub = player.playingStream.listen((p) => p ? spin.repeat() : spin.stop());
  }
  @override
  void dispose() { sub.cancel(); spin.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext c) => Scaffold(
        appBar: AppBar(backgroundColor: Colors.transparent),
        body: ListenableBuilder(
          listenable: ctl,
          builder: (_, __) => Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              RotationTransition(turns: spin, child: record(MediaQuery.of(c).size.width * .6)),
              const SizedBox(height: 28),
              Text(ctl.cur?.title ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 14),
              StreamBuilder<Duration>(
                stream: player.positionStream,
                builder: (_, snap) {
                  final pos = snap.data ?? Duration.zero;
                  final dur = player.duration ?? Duration.zero;
                  final max = dur.inMilliseconds.toDouble();
                  return Column(children: [
                    Slider(
                      activeColor: acc,
                      value: max == 0 ? 0 : min(pos.inMilliseconds.toDouble(), max),
                      max: max == 0 ? 1 : max,
                      onChanged: (v) => player.seek(Duration(milliseconds: v.toInt())),
                    ),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(fmt(pos)), Text(fmt(dur))]),
                  ]);
                },
              ),
              const SizedBox(height: 10),
              Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                IconButton(onPressed: () => ctl.flip(sh: !ctl.shuffle), icon: Icon(Icons.shuffle, color: ctl.shuffle ? pink : null)),
                IconButton(iconSize: 38, onPressed: () => ctl.step(-1), icon: const Icon(Icons.skip_previous)),
                IconButton.filled(
                  iconSize: 40, style: IconButton.styleFrom(backgroundColor: acc, foregroundColor: ink),
                  onPressed: ctl.toggle, icon: Icon(player.playing ? Icons.pause : Icons.play_arrow)),
                IconButton(iconSize: 38, onPressed: () => ctl.step(1), icon: const Icon(Icons.skip_next)),
                IconButton(onPressed: () => ctl.flip(rp: !ctl.repeat), icon: Icon(Icons.repeat, color: ctl.repeat ? pink : null)),
              ]),
            ]),
          ),
        ),
      );
}
