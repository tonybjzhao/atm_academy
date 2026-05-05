class LocalizedText {
  final String en;
  final String zh;
  final String fr;

  const LocalizedText({required this.en, required this.zh, required this.fr});

  String of(String languageCode) {
    switch (languageCode) {
      case 'zh':
        return zh;
      case 'fr':
        return fr;
      default:
        return en;
    }
  }
}
