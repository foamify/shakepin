# Notarize Manually

rm -rf ./dist/ShakePin.dmg

cd dist
ditto ../macos/packaging/dmg/appdmg.json config.json
ditto ../macos/packaging/dmg/background.png background.png
appdmg config.json ShakePin.dmg
cd ..

xcrun notarytool submit ./dist/ShakePin.dmg --keychain-profile "notarytool-password" --wait

xcrun stapler staple ./dist/ShakePin.dmg

# xcrun notarytool log <REPLACE WITH ACTUAL ID FROM THE RESULT OF `notarytool submit` Ex."6f98dfd0-1eec-4478-963c-1a19c15e48e3"> --keychain-profile "notarytool-password" logs.json
# open logs.json

spctl -a -vvv -t install ./dist/ShakePin.dmg

open ./dist