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
          content: 'card $i While developing this dating app I tried various flutter libraries but none oWhile developing this dating app I tried various flutter libraries but none oWhile developing this dating app I tried various flutter libraries but none oWhile developing this dating app I tried various flutter libraries but none oWhile developing this dating app I tried various flutter libraries but none oWhile developing this dating app I tried various flutter libraries but none oWhile developing this dating app I tried various flutter libraries but none o',
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
            height: MediaQuery.of(context).size.height * 0.5,
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
                        child: Text(
                          _swipeItems[index].content as String,
                          style: const TextStyle(fontSize: 48)
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
