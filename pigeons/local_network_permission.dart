import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/src/local_network_permission_pigeon.g.dart',
    dartOptions: DartOptions(),
    kotlinOut: 'android/app/src/main/kotlin/io/github/hamadtheironside/driftfin/api/LocalNetworkPermissionPigeon.g.kt',
    kotlinOptions: KotlinOptions(
      includeErrorClass: false,
    ),
    dartPackageName: 'io_github_hamadtheironside_driftfin.settings',
  ),
)
@HostApi()
abstract class LocalNetworkPermissionPigeon {
  int getAndroidSdkInt();
}
