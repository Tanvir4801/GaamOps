import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../constants/app_colors.dart';

class MarkerHelper {
  MarkerHelper._();

  static Future<BitmapDescriptor> createCircleMarker({
    required Color color,
    double size = 40,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint()..color = color;
    canvas.drawCircle(Offset(size / 2, size / 2), size / 2, paint);
    final picture = recorder.endRecording();
    final img = await picture.toImage(size.toInt(), size.toInt());
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(data!.buffer.asUint8List());
  }

  static Future<Map<String, BitmapDescriptor>> createMapMarkers() async {
    final customer = await createCircleMarker(color: Colors.blue, size: 30);
    final saathi = await createCircleMarker(color: AppColors.primaryGreen, size: 30);
    return {'customer': customer, 'saathi': saathi};
  }
}
