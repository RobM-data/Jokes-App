import 'package:flutter/material.dart';
import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'services/joke_service.dart';
import 'services/device_user_id.dart';
import 'services/swipe_service.dart';
import 'services/utils.dart';
import 'services/report_joke.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  runApp(const MyApp());
}

final supabase = Supabase.instance.client;

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(useMaterial3: true, colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue)),
      home: const JokeSwipePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class JokeSwipePage extends StatefulWidget {
  const JokeSwipePage({super.key});
  @override
  State<JokeSwipePage> createState() => _JokeSwipePageState();
}

class _JokeSwipePageState extends State<JokeSwipePage> with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _jokes = [];
  late String deviceUserId;
  late final JokeService _jokeService;
  bool isLoading = false;

  Offset _position = Offset.zero;
  bool _isDragging = false;
  Size _screenSize = Size.zero;

  late AnimationController _animationController;
  Animation<Offset>? _swipeAnimation; // Made this nullable

  @override
  void initState() {
    super.initState();
    _jokeService = JokeService(supabase);
    
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250), // Slightly slower for a smoother fly-away
    );

    // One global listener that only updates if there's an active animation
    _animationController.addListener(() {
      if (_swipeAnimation != null) {
        setState(() => _position = _swipeAnimation!.value);
      }
    });

    _init();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    deviceUserId = await DeviceUserId.getUserId();
    await _reloadJokes();
  }

  Future<void> _reloadJokes() async {
    if (isLoading) return;
    setState(() => isLoading = true);
    try {
      final newJokes = await _jokeService.fetchJokes(limit: 10, userId: deviceUserId);
      setState(() => _jokes.addAll(newJokes));
    } catch (e) {
      debugPrint('Fetch Error: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _onPanStart(DragStartDetails details) {
    if (_animationController.isAnimating) return; // Prevent grabbing while flying away
    setState(() => _isDragging = true);
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() => _position += details.delta);
  }

  void _onPanEnd(DragEndDetails details) {
    final x = _position.dx;
    final threshold = _screenSize.width * 0.35;

    if (x > threshold) {
      _animateOffScreen(true);
    } else if (x < -threshold) {
      _animateOffScreen(false);
    } else {
      _resetPosition();
    }
  }

  void _animateOffScreen(bool isLike) {
    final endX = isLike ? _screenSize.width * 1.5 : -_screenSize.width * 1.5;
    
    _swipeAnimation = Tween<Offset>(
      begin: _position,
      end: Offset(endX, _position.dy),
    ).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeIn));

    _animationController.forward(from: 0.0).then((_) {
      _swipeAnimation = null; // Detach the animation before resetting!
      _executeSwipe(isLike);
    });
  }

  void _resetPosition() {
    _swipeAnimation = Tween<Offset>(
      begin: _position,
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeOut));

    _animationController.forward(from: 0.0).then((_) {
      _swipeAnimation = null; // Detach here too
      setState(() => _isDragging = false);
    });
  }

  void _executeSwipe(bool isLike) {
    if (_jokes.isEmpty) return;
    final jokeId = _jokes.first['joke_id'];
    updateSwipes(jokeId, isLike ? 'like' : 'nope', deviceUserId, supabase);

    setState(() {
      _jokes.removeAt(0);
      _position = Offset.zero; // This will now safely hold the new card in the center
      _isDragging = false;
    });
    if (_jokes.length < 5) _reloadJokes();
  }

  void _reportCurrent() async {
    if (_jokes.isEmpty) return;
    final jokeId = _jokes.first['joke_id'];
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Report Joke'),
        children: [
          SimpleDialogOption(onPressed: () => Navigator.pop(context, 'Not a Joke'), child: const Text('Not a Joke')),
          const Divider(),
          SimpleDialogOption(onPressed: () => Navigator.pop(context, null), child: const Text('Cancel')),
        ],
      ),
    );
    if (reason != null) {
      await reportJoke(jokeId, reason, deviceUserId, supabase);
      _animateOffScreen(false);
    }
  }

  Color get _backgroundColor {
    if (_position.dx == 0) return Colors.white;
    double ratio = (_position.dx / (_screenSize.width * 0.45)).abs().clamp(0.0, 1.0);
    if (_position.dx > 0) {
      return Color.lerp(Colors.white, Colors.green.shade100, ratio)!;
    } else {
      return Color.lerp(Colors.white, Colors.red.shade100, ratio)!;
    }
  }

  @override
  Widget build(BuildContext context) {
    _screenSize = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(title: const Text("Joke Swipe")),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                if (_jokes.isEmpty && !isLoading)
                  const Center(child: Text("No more jokes!"))
                else if (_jokes.isEmpty && isLoading)
                  const Center(child: CircularProgressIndicator())
                else
                  ..._jokes.asMap().entries.map((entry) {
                    int index = entry.key;
                    if (index > 1) return const SizedBox.shrink();
                    return _buildCard(entry.value, index == 0);
                  }).toList().reversed,
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 40),
            child: ElevatedButton.icon(
              onPressed: _reportCurrent,
              icon: const Icon(Icons.report_problem, color: Colors.red),
              label: const Text("Report Joke"),
            ),
          ),
        ],
      ),
      // Here are your buttons back!
      bottomNavigationBar: BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.swipe), label: 'Swipe'),
          BottomNavigationBarItem(icon: Icon(Icons.style), label: 'Decks'),
          BottomNavigationBarItem(icon: Icon(Icons.create), label: 'Submit'),
        ],
      ),
    );
  }

  Widget _buildCard(Map<String, dynamic> joke, bool isFront) {
    final angle = isFront ? (_position.dx / _screenSize.width) * 0.4 : 0.0;
    return Center(
      child: GestureDetector(
        onPanStart: isFront ? _onPanStart : null,
        onPanUpdate: isFront ? _onPanUpdate : null,
        onPanEnd: isFront ? _onPanEnd : null,
        child: Transform.translate(
          offset: isFront ? _position : Offset.zero,
          child: Transform.rotate(
            angle: angle,
            child: _CardContent(text: joke['text'] ?? "", isFront: isFront),
          ),
        ),
      ),
    );
  }
}

class _CardContent extends StatelessWidget {
  final String text;
  final bool isFront;
  const _CardContent({required this.text, required this.isFront});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: MediaQuery.of(context).size.width * 0.85,
      height: MediaQuery.of(context).size.height * 0.55,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(isFront ? 0.15 : 0.05), blurRadius: 10, spreadRadius: 2)],
      ),
      padding: const EdgeInsets.all(30),
      alignment: Alignment.center,
      child: SingleChildScrollView(
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: JokeUtils.fontSizeForJoke(text), fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}