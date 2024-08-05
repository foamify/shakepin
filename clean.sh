rm pubspec.lock
flutter clean
rm -rf macos/Pods
rm macos/Podfile.lock
flutter pub get
cd macos
pod install
cd ..
