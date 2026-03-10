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
      title: 'Jokes App',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
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

  // Swipe State
  Offset _position = Offset.zero;
  bool _isDragging = false;
  Size _screenSize = Size.zero;

  // Animation for smooth reset
  late AnimationController _resetController;
  late Animation<Offset> _resetAnimation;

  @override
  void initState() {
    super.initState();
    _jokeService = JokeService(supabase);
    _resetController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _init();
  }

  @override
  void dispose() {
    _resetController.dispose();
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
      final newJokes = await _jokeService.fetchJokes(
        limit: 10,
        userId: deviceUserId,
      );
      setState(() => _jokes.addAll(newJokes));
    } catch (e) {
      debugPrint('Fetch Error: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  // --- Swiping Logic ---

  void _onPanStart(DragStartDetails details) {
    _resetController.stop(); 
    setState(() => _isDragging = true);
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() => _position += details.delta);
  }

  void _onPanEnd(DragEndDetails details) {
    final x = _position.dx;
    final threshold = _screenSize.width * 0.4;

    if (x > threshold) {
      _executeSwipe(true); // Like
    } else if (x < -threshold) {
      _executeSwipe(false); // Nope
    } else {
      _resetPosition();
    }
  }

  void _resetPosition() {
    _resetAnimation = Tween<Offset>(
      begin: _position,
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _resetController,
      curve: Curves.easeOut, // Linear fade back without overshoot bounce
    )..addListener(() {
        setState(() => _position = _resetAnimation.value);
      }));

    _resetController.forward(from: 0.0).then((_) {
      setState(() => _isDragging = false);
    });
  }

  void _executeSwipe(bool isLike) {
    if (_jokes.isEmpty) return;
    
    final jokeId = _jokes.first['joke_id'];
    updateSwipes(jokeId, isLike ? 'like' : 'nope', deviceUserId, supabase);

    setState(() {
      _jokes.removeAt(0);
      _position = Offset.zero;
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
      _executeSwipe(false);
    }
  }

  // --- UI Helpers ---

  Color get _backgroundColor {
    if (_position.dx == 0) return Colors.white;
    // Calculate ratio based on horizontal movement
    double ratio = (_position.dx / (_screenSize.width * 0.45)).abs().clamp(0.0, 1.0);
    
    if (_position.dx > 0) {
      return Color.lerp(Colors.white, Colors.green.shade100, ratio * 0.9)!;
    } else {
      return Color.lerp(Colors.white, Colors.red.shade100, ratio * 0.9)!;
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
                    // Only render top 2 cards for performance
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
    // Rotation logic: rotate slightly based on swipe distance
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
            child: Stack(
              children: [
                _CardContent(text: joke['text'] ?? "", isFront: isFront),
                if (isFront) _buildStamp(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStamp() {
    // Deadzone check: don't show any stamp if the card is near center
    if (_position.dx.abs() < 15) return const SizedBox.shrink();

    double opacity = (_position.dx.abs() / 100).clamp(0.0, 1.0);
    bool isLike = _position.dx > 0;

    return Positioned(
      top: 40,
      left: isLike ? 20 : null,
      right: isLike ? null : 20,
      child: Transform.rotate(
        angle: isLike ? -0.5 : 0.5,
        child: Opacity(
          opacity: opacity,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              border: Border.all(color: isLike ? Colors.green : Colors.red, width: 4),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              isLike ? "LIKE" : "NOPE",
              style: TextStyle(
                color: isLike ? Colors.green : Colors.red,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isFront ? 0.15 : 0.05), 
            blurRadius: 10, 
            spreadRadius: 2
          ),
        ],
      ),
      padding: const EdgeInsets.all(30),
      alignment: Alignment.center,
      child: SingleChildScrollView(
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: JokeUtils.fontSizeForJoke(text),
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}