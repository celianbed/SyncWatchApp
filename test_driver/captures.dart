// Reçoit les captures produites par integration_test/captures_test.dart et les
// écrit sur la machine hôte, dans captures/.
import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  await integrationDriver(
    onScreenshot: (String nom, List<int> octets, [Map<String, Object?>? _]) async {
      final fichier = File('captures/$nom.png');
      await fichier.parent.create(recursive: true);
      await fichier.writeAsBytes(octets);
      stdout.writeln('capture écrite : ${fichier.path} (${octets.length} octets)');
      return true;
    },
  );
}
