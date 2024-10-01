yq eval 'del(.dependencies.ffmpeg_kit_flutter_video)' -i pubspec.yaml

dart run remove_comment.dart

sed -i '' '1s/^\/\/ //' lib/app/minify_app.dart
sed -i '' '2s/^/\/\/ /' lib/app/minify_app.dart

# flutter pub get