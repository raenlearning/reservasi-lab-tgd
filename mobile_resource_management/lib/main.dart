import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'app.dart';
import 'core/utils/date_time_utils.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await initializeDateFormatting(DateTimeUtils.localeId);
  Intl.defaultLocale = DateTimeUtils.localeId;

  runApp(const ProviderScope(child: ReservasiLabApp()));
}
