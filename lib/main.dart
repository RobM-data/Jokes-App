import 'package:flutter/material.dart';
import 'package:swipe_cards/draggable_card.dart';
import 'package:swipe_cards/swipe_cards.dart';
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

  debugPrint('Supabase URL: $supabaseUrl');
  debugPrint('Supabase Key: $supabaseAnonKey');

  assert(supabaseUrl.isNotEmpty, 'SUPABASE_URL not set');
  assert(supabaseAnonKey.isNotEmpty, 'SUPABASE_ANON_KEY not set');

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

  String? _currentJokeId;
  Map<String, String>? _currentJokeData;

  final List<SwipeItem> _swipeItems = <SwipeItem>[];
  MatchEngine? _matchEngine;

  late final JokeService _jokeService;

  double _swipeProgress = 0.0;

  Color get _backgroundColor {
    if (_swipeProgress > 0) {
      return Color.lerp(
        Colors.white,
        Colors.green.shade200,
        _swipeProgress.clamp(0.0, 1.0),
      )!;
    } else if (_swipeProgress < 0) {
      return Color.lerp(
        Colors.white,
        Colors.red.shade200,
        (-_swipeProgress).clamp(0.0, 1.0),
      )!;
    }
    return Colors.white;
  }

  bool isLoading = false;

  Future<void> _reloadJokes() async {
    if (isLoading) return;
    isLoading = true;

    try {
      final jokes = await _jokeService.fetchJokes(
        limit: 10,
        userId: deviceUserId,
      );

      final newItems = jokes.map((row) {
        return SwipeItem(
          content: {'text':row['text'] as String,
                    'id': row['joke_id'] as String},
          likeAction: () {
            debugPrint('LIKE pressed for id=${row['joke_id']}');
            updateSwipes(row['joke_id'] as String, 'like', deviceUserId, supabase);
          },
          nopeAction: () {
            debugPrint('NOPE pressed for id=${row['joke_id']}');
            updateSwipes(row['joke_id'] as String, 'nope', deviceUserId, supabase);
          },
          onSlideUpdate: (SlideRegion? region) {
            setState(() {
              if (region == SlideRegion.inLikeRegion) {
                _swipeProgress = 0.6;
              } else if (region == SlideRegion.inNopeRegion) {
                _swipeProgress = -0.6;
              } else {
                _swipeProgress = 0.0;
              }
            });
            return Future(() => null);
          },
        );
      }).toList();

      setState(() {
        _swipeItems.addAll(newItems);
        _matchEngine = MatchEngine(swipeItems: _swipeItems);
      });
    } catch (e, st) {
      debugPrint('Error reloading jokes: $e\n$st');
    } finally {
      isLoading = false;
    }
  }

  late String deviceUserId;

  @override
  void initState() {
    super.initState();
    _jokeService = JokeService(supabase);
    _matchEngine = MatchEngine(swipeItems: _swipeItems);
    _reloadJokes();
    _init();
  }

  Future<void> _init() async {
    deviceUserId = await DeviceUserId.getUserId(); // or getOrCreate()
    await _reloadJokes();
    if (mounted) setState(() {});
  }

  void reportPressed() async {
    if (_currentJokeId == null) {
      debugPrint('No joke selected to report');
      return;
    }

    final reason = await showDialog<String>(
      context: context,
      builder: (context) {
        return SimpleDialog(
          title: const Text('Report Joke'),
          children: [
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, 'Not a Joke'),
              child: const Text('Not a Joke'),
            ),
            const Divider(),
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, null),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );

    if (reason == null) return;

    await reportJoke(_currentJokeId!, reason, deviceUserId, supabase);

    if (_swipeItems.isNotEmpty) {
      setState(() {
        _swipeItems.removeAt(0);
        _matchEngine = MatchEngine(swipeItems: _swipeItems);
      });
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report submitted')),
      );
    }
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

      body: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        color: _backgroundColor,
        child: Column(
          children: [
            const Padding(padding: EdgeInsets.all(22)),

            SizedBox(
              width: double.infinity,
              height: MediaQuery.of(context).size.height * 0.55,
              child: Padding(
                padding: const EdgeInsets.only(left: 40.0, right: 40.0),
                child: _matchEngine == null
                    ? const Center(child: CircularProgressIndicator())
                    : SwipeCards(
                        matchEngine: _matchEngine!,
                        itemBuilder: (BuildContext context, int index) {
                          final data = _swipeItems[index].content as Map<String, String>;
                          final text = data['text']!;

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
                                      text,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: JokeUtils.fontSizeForJoke(text),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                        itemChanged: (SwipeItem item, int index) {
                          final data = item.content as Map<String, String>;
                          _currentJokeData = data;
                          _currentJokeId = data['id'];

                          if (_swipeItems.length - index < 5) {
                            _reloadJokes();
                          }
                        },
                        onStackFinished: () {
                          _reloadJokes();
                          debugPrint('out of cards');
                        },
                      ),
              ),
            ),
            ElevatedButton(
              onPressed: reportPressed, 
              child: Text('Report'),
            ),
          ],
        ),
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
