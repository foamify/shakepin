ditto -ck --keepParent dist/ShakePin.app dist/ShakePin.zip
rm -rf dist/temp
ditto dist/ShakePin.zip dist/temp/ShakePin.zip

./generate_appcast dist/temp -o skpn-appcast.xml
rm -rf dist/temp
