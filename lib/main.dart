import 'package:flutter/material.dart';
import 'package:swipe_cards/swipe_cards.dart';

void main() {
  runApp(const MyApp());
}

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

  final List<String> _jokes = [
    'What do you call a magic dog? A labracadabrador!',
    'What do you call a pony with a cough? A little horse!',
    'What\'s orange and sounds like a carrot? A parrot!',
    'What did the pirate say when he turned 80? Aye matey!',
    'Why did the frog take the bus to work today? His car got toad away!'
  ];

  @override
  void initState() {
    super.initState();
    
    for (int i = 0; i < 5; i++) {
      _swipeItems.add(
        SwipeItem(
          content: _jokes[i],
          likeAction: () {
            print('liked');
          },
          nopeAction: () {
            print('noped');
          },
        ),
      );
    }

    _matchEngine = MatchEngine(swipeItems: _swipeItems);
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
