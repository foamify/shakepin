import 'dart:ui';
import 'constant.dart';

bool detectShake(List<Offset> positions, final List<Duration> timestamps) {
  if (positions.length < shakeThreshold) return false;

  int directionChangesX = 0;
  int directionChangesY = 0;
  bool isSpeedThresholdMet = false;

  double totalDistanceX = 0;
  double totalDistanceY = 0;
  Duration totalDuration = Duration.zero;

  int lastDirectionX = 0;
  int lastDirectionY = 0;

  for (int i = 1; i < positions.length; i++) {
    double dx = positions[i].dx - positions[i - 1].dx;
    double dy = positions[i].dy - positions[i - 1].dy;

    int currentDirectionX = dx.sign.toInt();
    int currentDirectionY = dy.sign.toInt();

    // Check for direction changes
    if (i > 1 &&
        currentDirectionX != 0 &&
        currentDirectionX != lastDirectionX) {
      directionChangesX++;
      // Calculate speed for X direction
      Duration duration = timestamps[i - 1] - timestamps[0];
      double speed = totalDistanceX / duration.inMicroseconds * 1000000;
      if (speed >= speedThreshold) isSpeedThresholdMet = true;
      totalDistanceX = 0;
      totalDuration = Duration.zero;
    }

    if (i > 1 &&
        currentDirectionY != 0 &&
        currentDirectionY != lastDirectionY) {
      directionChangesY++;
      // Calculate speed for Y direction
      Duration duration = timestamps[i - 1] - timestamps[0];
      double speed = totalDistanceY / duration.inMicroseconds * 1000000;
      if (speed >= speedThreshold) isSpeedThresholdMet = true;
      totalDistanceY = 0;
      totalDuration = Duration.zero;
    }

    totalDistanceX += dx.abs();
    totalDistanceY += dy.abs();
    totalDuration += timestamps[i] - timestamps[i - 1];

    lastDirectionX =
        currentDirectionX != 0 ? currentDirectionX : lastDirectionX;
    lastDirectionY =
        currentDirectionY != 0 ? currentDirectionY : lastDirectionY;
  }

// Check final segment
  if (totalDuration.inMicroseconds > 0) {
    double speedX = totalDistanceX / totalDuration.inMicroseconds * 1000000;
    double speedY = totalDistanceY / totalDuration.inMicroseconds * 1000000;
    if (speedX >= speedThreshold || speedY >= speedThreshold) {
      isSpeedThresholdMet = true;
    }
  }

// Detect shake if there are at least 2 direction changes in either axis and speed threshold is met
  return (directionChangesX >= 5 || directionChangesY >= 5) &&
      isSpeedThresholdMet;
}
