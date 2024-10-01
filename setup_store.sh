yq eval '.dependencies.ffmpeg_kit_flutter_video = "^6.0.3"' -i pubspec.yaml

sed -i '' '2s/^\/\/ //' lib/app/minify_app.dart
sed -i '' '1s/^/\/\/ /' lib/app/minify_app.dart

# flutter pub get