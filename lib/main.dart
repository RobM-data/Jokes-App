import 'package:flutter/material.dart';
import 'package:swipe_cards/swipe_cards.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  Future<List<Map<String, dynamic>>> fetchJokes() async {
    final data = await supabase.from('jokes').select('text').limit(5);
    return (data as List).cast<Map<String, dynamic>>();
  }

  @override
  void initState() {
    super.initState();

    fetchJokes().then((jokes) {
      for (final row in jokes) {
        _swipeItems.add(
          SwipeItem(
            content: row['text'] as String,
            likeAction: () => print('liked'),
            nopeAction: () => print('noped'),
          ),
        );
    }

      setState(() {
        _matchEngine = MatchEngine(swipeItems: _swipeItems);
      });
    });

  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Jokes App')),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'swipe jokes',
              style: TextStyle(fontSize: 24)
            )
          ),
      
          SizedBox(
            width: double.infinity,
            height: MediaQuery.of(context).size.height * 0.4,
            child: Padding(
              padding: const EdgeInsets.only(left: 20.0, right: 20.0),
              child: SwipeCards(
                matchEngine: _matchEngine!,
                itemBuilder: (BuildContext context, int index) {
                  return Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24)
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
                              style: const TextStyle(fontSize: 25)
                            ),
                          ),
                        ),
                      )
                    )
                  );
                },
                onStackFinished: () {
                  debugPrint('out of cards');
                },
              ),
            ),
          ),
      
        ],
      ),
    );
  }
}
