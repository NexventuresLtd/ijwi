class ReadingTimeCalculator {
  static const int _wordsPerMinute = 225; // Average adult reading speed

  /// Calculates reading time based on plain text length
  static int calculateReadingTimeMins(String plainText) {
    if (plainText.trim().isEmpty) return 1;
    
    // Split by whitespace to count words
    final wordCount = plainText.trim().split(RegExp(r'\s+')).length;
    
    final int minutes = (wordCount / _wordsPerMinute).ceil();
    
    return minutes == 0 ? 1 : minutes;
  }
}
