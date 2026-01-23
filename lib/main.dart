import 'package:flutter/material.dart';
import 'package:swipe_cards/swipe_cards.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'services/joke_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'services/device_user_id.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: '.env');

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

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
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
        ),
      ),
      home: JokeSwipePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class JokeSwipePage extends StatefulWidget {
  const JokeSwipePage({super.key});

  @override
  State<JokeSwipePage> createState() => _JokeSwipePageState();
}

class _JokeSwipePageState extends State<JokeSwipePage> {
  final List<SwipeItem> _swipeItems = <SwipeItem>[];
  MatchEngine? _matchEngine;

  late final JokeService _jokeService;

  Future<void> updateSwipes(String jokeId, String action) async {
    debugPrint('updateSwipes started');

    try {
      final res = await supabase.from('swipes').upsert({
        'user_id': deviceUserId,
        'joke_id': jokeId,
        'action': action,
      }).select();

      debugPrint('Swipe logged: $res');
    } catch (e, st) {
      debugPrint('Swipe log FAILED: $e\n$st');
    }
  }

  Future<void> _reloadJokes() async {
    setState(() {
      _matchEngine = null;
      _swipeItems.clear();
    });

    try {
      final jokes = await _jokeService.fetchJokes(limit: 10, userId: deviceUserId);

      final newItems = jokes.map((row) {
        return SwipeItem(
          content: row['text'] as String,
          likeAction: () {
            debugPrint('LIKE pressed for id=${row['id']}');
            updateSwipes(row['id'] as String, 'like');
          },
          nopeAction: () {
            debugPrint('NOPE pressed for id=${row['id']}');
            updateSwipes(row['id'] as String, 'nope');
          },
        );
      }).toList();

      setState(() {
        _swipeItems.addAll(newItems);
        _matchEngine = MatchEngine(swipeItems: _swipeItems);
      });
    } catch (e, st) {
      debugPrint('Error reloading jokes: $e\n$st');

      if (mounted) {
        setState(() {
          _matchEngine = MatchEngine(swipeItems: _swipeItems);
        });
      }
    }
  }

  late String deviceUserId;

  @override
  void initState() {
    super.initState();
    _jokeService = JokeService(supabase);
    _init();
  }

  Future<void> _init() async {
    deviceUserId = await DeviceUserId.getUserId(); // or getOrCreate()
    await _reloadJokes();
    if (mounted) setState(() {});
  }

  double _fontSizeForJoke(String joke) {
    final length = joke.length.toDouble();

    const maxSize = 40.0;
    const minSize = 20.0;
    const maxLength = 350.0;

    final t = (length / maxLength).clamp(0.0, 1.0);
    return maxSize - (maxSize - minSize) * t;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Image.asset('assets/logo.png', height: 32),
            ),
          ],
        ),
      ),

      body: Column(
        children: [
          const Padding(padding: EdgeInsets.all(16)),

          SizedBox(
            width: double.infinity,
            height: MediaQuery.of(context).size.height * 0.55,
            child: Padding(
              padding: const EdgeInsets.only(left: 20.0, right: 20.0),
              child: _matchEngine == null
                  ? const Center(child: CircularProgressIndicator())
                  : SwipeCards(
                      matchEngine: _matchEngine!,
                      itemBuilder: (BuildContext context, int index) {
                        return Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          elevation: 8,
                          child: Center(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.vertical,
                              child: Padding(
                                padding: const EdgeInsets.all(20.0),
                                child: Center(
                                  child: Text(
                                    _swipeItems[index].content as String,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: _fontSizeForJoke(
                                        _swipeItems[index].content as String,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                      onStackFinished: () {
                        _reloadJokes();
                        debugPrint('out of cards');
                      },
                    ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.swipe),
            label: 'Swipe Jokes',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.style), label: 'Decks'),
          BottomNavigationBarItem(
            icon: Icon(Icons.create),
            label: 'Submit Joke',
          ),
        ],
      ),
    );
  }
}
