import 'package:flutter/material.dart';
import 'package:wifi_scan/wifi_scan.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class WifiSurveyPage extends StatefulWidget {
  @override
  _WifiSurveyPageState createState() => _WifiSurveyPageState();
}

class _WifiSurveyPageState extends State<WifiSurveyPage> {
  List<WiFiAccessPoint> accessPoints = [];
  String status = "Press Scan to capture WiFi APs";
  File? csvFile;

  @override
  void initState() {
    super.initState();
    initFile();
  }

  Future<void> initFile() async {
    final dir = await getApplicationDocumentsDirectory();
    csvFile = File('${dir.path}/ap_database.csv');
    if (!(await csvFile!.exists())) {
      await csvFile!.writeAsString("timestamp,ssid,bssid,lat,lon,accuracy\n");
    }
  }

  Future<void> scanAndSave() async {
    // Check permissions
    final can = await WiFiScan.instance.canStartScan(askPermissions: true);
    if (can != CanStartScan.yes) {
      setState(() => status = "WiFi scan not allowed: $can");
      return;
    }

    // Get GPS location
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() => status = "Enable GPS");
      return;
    }
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
      setState(() => status = "GPS permission denied");
      return;
    }

    Position pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best);

    // Start WiFi scan
    await WiFiScan.instance.startScan();
    await Future.delayed(Duration(seconds: 1));
    final results = await WiFiScan.instance.getScannedResults();

    // Pick the *strongest AP* = one closest to you
    results.sort((a, b) => b.level.compareTo(a.level));
    final strongest = results.first;

    final now = DateTime.now().toIso8601String();
    final line =
        "$now,${strongest.ssid},${strongest.bssid},${pos.latitude},${pos.longitude},${pos.accuracy}\n";

    await csvFile!.writeAsString(line, mode: FileMode.append);

    setState(() {
      accessPoints = results;
      status =
      "Stored: ${strongest.ssid} (${strongest.bssid}) at ${pos.latitude}, ${pos.longitude}";
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Triangulate")),
      body: Column(
        children: [
          ElevatedButton(onPressed: scanAndSave, child: Text("Scan Nearby WiFi")),
          Text(status),
          Expanded(
            child: ListView.builder(
              itemCount: accessPoints.length,
              itemBuilder: (context, index) {
                final ap = accessPoints[index];
                return ListTile(
                  title: Text(ap.ssid.isEmpty ? "<hidden>" : ap.ssid),
                  subtitle: Text("BSSID: ${ap.bssid} | RSSI: ${ap.level} dBm"),
                );
              },
            ),
          )
        ],
      ),
    );
  }
}
