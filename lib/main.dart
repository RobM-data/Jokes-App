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
  List<SwipeItem> _swipeItems = <SwipeItem>[];
  MatchEngine? _matchEngine;

  @override
  void initState() {
    for (int i = 0; i < 20; i++) {
      _swipeItems.add(
        SwipeItem(
          content: Text('card $i', style: const TextStyle(fontSize: 100)),
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
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Jokes App')),
      body: Container(
        height: MediaQuery.of(context).size.height - kToolbarHeight,
        child: SwipeCards(
          matchEngine: _matchEngine!,
          itemBuilder: (BuildContext context, int index) {
            return Container(
              alignment: Alignment.center,
              color: Colors.blue,
              child: _swipeItems[index].content as Widget,
            );
          },
          onStackFinished: () {
            print('out of cards');
          },
        ),
      ),
    );
  }
}
