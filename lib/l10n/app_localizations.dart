import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'catalog.dart';

/// Offline UI-only translations. Never changes model/API values or user input.
class AppLocalizations {
  const AppLocalizations(this.locale);
  final Locale locale;
  static const delegate = _AppLocalizationsDelegate();
  static AppLocalizations of(BuildContext context) =>
      Localizations.of<AppLocalizations>(context, AppLocalizations) ??
      const AppLocalizations(Locale('en'));
  String text(String source) => translateUi(source, locale.languageCode);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();
  @override
  bool isSupported(Locale locale) =>
      const ['en', 'hi', 'ml', 'ta', 'te', 'kn'].contains(locale.languageCode);
  @override
  Future<AppLocalizations> load(Locale locale) =>
      SynchronousFuture(AppLocalizations(locale));
  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

String localize(BuildContext context, String text) =>
    AppLocalizations.of(context).text(text);
String? localizeOptional(BuildContext context, String? text) =>
    text == null ? null : localize(context, text);

InputDecoration localizedDecoration(
  BuildContext context,
  InputDecoration value,
) => value.copyWith(
  labelText: localizeOptional(context, value.labelText),
  hintText: localizeOptional(context, value.hintText),
  helperText: localizeOptional(context, value.helperText),
  helperMaxLines: value.helperMaxLines ?? 3,
  errorText: localizeOptional(context, value.errorText),
  errorMaxLines: value.errorMaxLines ?? 3,
  counterText: localizeOptional(context, value.counterText),
);

/// A presentation boundary: English source remains stable for repositories and
/// models; a dependency on Localizations rebuilds even const widgets on switch.
class LocalizedText extends StatelessWidget {
  const LocalizedText(
    this.data, {
    super.key,
    this.style,
    this.strutStyle,
    this.textAlign,
    this.textDirection,
    this.locale,
    this.softWrap,
    this.overflow,
    this.textScaler,
    this.maxLines,
    this.semanticsLabel,
    this.textWidthBasis,
    this.textHeightBehavior,
    this.selectionColor,
  });
  final String data;
  final TextStyle? style;
  final StrutStyle? strutStyle;
  final TextAlign? textAlign;
  final TextDirection? textDirection;
  final Locale? locale;
  final bool? softWrap;
  final TextOverflow? overflow;
  final TextScaler? textScaler;
  final int? maxLines;
  final String? semanticsLabel;
  final TextWidthBasis? textWidthBasis;
  final TextHeightBehavior? textHeightBehavior;
  final Color? selectionColor;
  @override
  Widget build(BuildContext context) => Text(
    localize(context, data),
    style: style,
    strutStyle: strutStyle,
    textAlign: textAlign,
    textDirection: textDirection,
    locale: locale,
    softWrap: softWrap,
    overflow: overflow,
    textScaler: textScaler,
    maxLines: maxLines,
    semanticsLabel: localizeOptional(context, semanticsLabel),
    textWidthBasis: textWidthBasis,
    textHeightBehavior: textHeightBehavior,
    selectionColor: selectionColor,
  );
}
