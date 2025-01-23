ditto -ck --keepParent dist/notarized/ShakePin.app dist/notarized/ShakePin.zip
rm -rf dist/temp
ditto dist/notarized/ShakePin.zip dist/temp/ShakePin.zip

./generate_appcast dist/temp -o dist/appcast.xml
rm -rf dist/temp
