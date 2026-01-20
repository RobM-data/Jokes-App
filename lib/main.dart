import 'package:flutter/material.dart';
import 'package:swipe_cards/swipe_cards.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'services/joke_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://ejdsujnylmsbpjavohhm.supabase.co',
    anonKey: 'sb_publishable_Wl8K7XU1pvyRxL31oKAcjA_YP1LEvNY',
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

  Future<void> _reloadJokes() async {
    setState(() {
      _matchEngine = null;
      _swipeItems.clear();
    });

    try {
      final jokes = await _jokeService.fetchJokes(limit: 10);

      final newItems = jokes.map((row) {
        return SwipeItem(
          content: row['text'] as String,
          likeAction: () => debugPrint('liked'),
          nopeAction: () => debugPrint('noped'),
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


  @override
  void initState() {
    super.initState();

    _jokeService = JokeService(supabase);

    _reloadJokes();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Jokes App')),
      body: Column(
        children: [
          const Padding(padding: EdgeInsets.all(16)),

          SizedBox(
            width: double.infinity,
            height: MediaQuery.of(context).size.height * 0.4,
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
                                    style: const TextStyle(fontSize: 25),
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
