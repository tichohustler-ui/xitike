import 'package:logger/logger.dart';

final logger = Logger(
  printer: PrettyPrinter(
    methodCount: 0,
    errorMethodCount: 5,
    lineLength: 80,
    colors: true,
    printEmojis: true,
    // printTime: true, // ⚠ antigo e depreciado
    dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart, // ✅ substituto
  ),
);
