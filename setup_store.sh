yq eval '.dependencies.ffmpeg_kit_flutter_video = "^6.0.3"' -i pubspec.yaml

flutter clean
flutter pub get