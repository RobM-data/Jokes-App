class JokeUtils {
  static double fontSizeForJoke(String joke) {
    final length = joke.length.toDouble();

    const maxSize = 40.0;
    const minSize = 20.0;
    const maxLength = 350.0;

    final t = (length / maxLength).clamp(0.0, 1.0);
    return maxSize - (maxSize - minSize) * t;
  }
}
