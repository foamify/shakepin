import 'package:flutter/material.dart';
import 'package:shakepin/state.dart';
import 'package:shakepin/utils/drop_channel.dart';
import 'package:shakepin/utils/utils.dart';

void handleMenuItemClicked(int tag) async {
  Size? appSize;
  switch (tag) {
    case 1: // show
      await showApp();
    case 2: // hide
      await hideApp();
    case 3: // about
      isAboutApp.value = true;
      isLicenseApp.value = false;
      showApp();
    case 4: // reset shared preferences
      await prefs.clear();
    case 5: // input license key
      isLicenseApp.value = true;
      isAboutApp.value = false;
      showApp();
    default:
      break;
  }
}