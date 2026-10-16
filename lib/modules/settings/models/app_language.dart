enum AppLanguage {
  english('en', 'English', 'English', 'Language', 'Settings'),
  hindi('hi', 'हिन्दी', 'Hindi', 'भाषा', 'सेटिंग्स'),
  malayalam('ml', 'മലയാളം', 'Malayalam', 'ഭാഷ', 'ക്രമീകരണങ്ങൾ'),
  tamil('ta', 'தமிழ்', 'Tamil', 'மொழி', 'அமைப்புகள்'),
  telugu('te', 'తెలుగు', 'Telugu', 'భాష', 'సెట్టింగ్‌లు'),
  kannada('kn', 'ಕನ್ನಡ', 'Kannada', 'ಭಾಷೆ', 'ಸೆಟ್ಟಿಂಗ್‌ಗಳು');

  const AppLanguage(
    this.code,
    this.nativeName,
    this.englishName,
    this.languageLabel,
    this.settingsLabel,
  );
  final String code, nativeName, englishName, languageLabel, settingsLabel;
  static AppLanguage fromCode(String? code) => values.firstWhere(
    (language) => language.code == code,
    orElse: () => english,
  );
}
