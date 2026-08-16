class InputSanitizer {
  static String sanitizeText(String input) {
    return input
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'[<>";&]'), '')
        .trim();
  }

  static String sanitizePhone(String input) {
    return input.replaceAll(RegExp(r'[^\d+]'), '').trim();
  }

  static String sanitizeEmail(String input) {
    return input.trim().toLowerCase();
  }

  static String sanitizeSearchQuery(String input) {
    return input
        .replaceAll(RegExp(r'[^\w\s\-.,]'), '')
        .trim();
  }

  static double? sanitizePrice(String input) {
    final cleaned = input.replaceAll(RegExp(r'[^\d.]'), '');
    return double.tryParse(cleaned);
  }

  static String sanitizeAddress(String input) {
    return input
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'[<>";&]'), '')
        .trim();
  }
}
