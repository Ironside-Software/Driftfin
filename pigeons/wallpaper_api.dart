import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/src/wallpaper_api.g.dart',
    kotlinOut: 'android/app/src/main/kotlin/io/github/hamadtheironside/driftfin/wallpaper/WallpaperApi.g.kt',
    kotlinOptions: KotlinOptions(package: 'io.github.hamadtheironside.driftfin.wallpaper', includeErrorClass: true),
    dartPackageName: 'io_github_hamadtheironside_driftfin.wallpaper',
  ),
)
@HostApi()
abstract class WallpaperApi {
  @async
  bool openWallpaperPopup(String filePath);
}
