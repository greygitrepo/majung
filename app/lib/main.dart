import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'app.dart';
import 'app_controller.dart';
import 'config.dart';
import 'data/facility_repository.dart';
import 'services/launcher.dart';
import 'services/location_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const config = AppConfig();
  final dir = await getApplicationSupportDirectory();
  final repository = FacilityRepository(
    loadBundled: () => rootBundle.loadString('assets/data/facilities.json'),
    cache: FileDatasetCache(File('${dir.path}/facilities.json')),
    remoteUrl: config.dataUrl,
  );
  final controller = AppController(
    repository: repository,
    location: GeolocatorLocationService(),
    originStore: PrefsOriginStore(),
  );
  runApp(MajungApp(
    controller: controller,
    launcher: UrlActionLauncher(appId: config.appId),
    config: config,
  ));
  await controller.start();
}
