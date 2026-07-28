void main() {
  final regex = RegExp(r'(#\w+)|@([a-zA-Z0-9_]+(?:\s[a-zA-Z0-9_]+)?)');
  final text = "Hello @David Niyonshuti how are you";
  for (final match in regex.allMatches(text)) {
    print("Match: ${match.group(2)}");
  }
}
