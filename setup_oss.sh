yq eval 'del(.dependencies.ffmpeg_kit_flutter_video)' -i pubspec.yaml

flutter clean
flutter pub get