import 'package:flutter/material.dart';
import 'package:wifi_scan/wifi_scan.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF121212),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.deepPurpleAccent,
            foregroundColor: Colors.white,
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ),
      home: WifiLocator(),
    );
  }
}

class WifiLocator extends StatefulWidget {
  @override
  _WifiLocatorState createState() => _WifiLocatorState();
}

class _WifiLocatorState extends State<WifiLocator> {
  List<WiFiAccessPoint> accessPoints = [];
  String locationResult = "Press Scan & Locate";

  Future<void> scanWifi() async {
    final can = await WiFiScan.instance.canStartScan(askPermissions: true);
    if (can != CanStartScan.yes) {
      setState(() => locationResult = "WiFi scan permission denied");
      return;
    }

    await WiFiScan.instance.startScan();
    await Future.delayed(const Duration(seconds: 1));
    final results = await WiFiScan.instance.getScannedResults();
    setState(() => accessPoints = results);

    // Send to API for CSV storage
    final wifiList =
        results.map((ap) {
          return {
            "ssid": ap.ssid,
            "macAddress": ap.bssid.toLowerCase(),
            "signalStrength": ap.level,
          };
        }).toList();

    try {
      final response = await http.post(
        Uri.parse("http://10.201.193.6:3000/save-scan"), // Your server IP
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"wifiAccessPoints": wifiList}),
      );

      if (response.statusCode == 200) {
        print("✅ Scan saved to server");
      } else {
        print("❌ Server error: ${response.body}");
      }
    } catch (e) {
      print("⚠️ API request failed: $e");
    }
  }

  Future<void> locate() async {
    if (accessPoints.isEmpty) {
      setState(() => locationResult = "No APs scanned yet");
      return;
    }

    final wifiList =
        accessPoints.map((ap) {
          return {
            "ssid": ap.ssid.isEmpty ? "<hidden>" : ap.ssid,
            "macAddress": ap.bssid.toLowerCase(),
            "signalStrength": ap.level,
          };
        }).toList();

    final response = await http.post(
      Uri.parse("http://10.201.193.6:3000/get-location"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"wifiAccessPoints": wifiList}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final location = data['location'];
      final usedAPs = data['usedAPs'] as List<dynamic>;

      // Map MAC -> SSID from scanned list
      final ssidMap = {
        for (var ap in accessPoints)
          ap.bssid.toLowerCase(): ap.ssid.isEmpty ? "<hidden>" : ap.ssid,
      };

      // Build AP info text
      final apInfo = usedAPs
          .map((ap) {
            final mac = ap['macAddress'];
            final ssid = ssidMap[mac] ?? "<unknown>";
            final rssi = ap['signalStrength'];
            return "$ssid ($mac, $rssi dBm)";
          })
          .join("\n");

      setState(
        () =>
            locationResult =
                "Lat: ${location['lat']}\n"
                "Lng: ${location['lng']}\n"
                "Acc: ${location['accuracy']}m\n\n"
                "📡 Used APs:\n$apInfo",
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("WiFi Trilateration"),
        centerTitle: true,
        backgroundColor: Colors.deepPurpleAccent,
        elevation: 6,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Buttons centered
              ElevatedButton.icon(
                onPressed: scanWifi,
                icon: const Icon(Icons.wifi, color: Colors.white),
                label: const Text("Scan WiFi"),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: locate,
                icon: const Icon(Icons.location_on, color: Colors.white),
                label: const Text("Locate Me"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.greenAccent.shade400,
                  foregroundColor: Colors.black,
                ),
              ),

              const SizedBox(height: 40),

              // Result Card
              Card(
                color: const Color(0xFF1E1E1E),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 8,
                shadowColor: Colors.deepPurpleAccent.withOpacity(0.5),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    locationResult,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white70,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),

              const Spacer(),

              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => WifiListScreen(accessPoints),
                    ),
                  );
                },
                icon: const Icon(Icons.list_alt, color: Colors.white),
                label: const Text("View Scanned WiFi List"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class WifiListScreen extends StatelessWidget {
  final List<WiFiAccessPoint> accessPoints;

  WifiListScreen(this.accessPoints);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Scanned WiFi List"),
        centerTitle: true,
        backgroundColor: Colors.blueAccent,
        elevation: 6,
      ),
      body:
          accessPoints.isEmpty
              ? const Center(child: Text("No WiFi scanned"))
              : ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: accessPoints.length,
                itemBuilder: (ctx, i) {
                  final ap = accessPoints[i];
                  return Card(
                    color: const Color(0xFF1E1E1E),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 5,
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: ListTile(
                      leading: const Icon(
                        Icons.wifi,
                        color: Colors.deepPurpleAccent,
                      ),
                      title: Text(
                        ap.ssid.isEmpty
                            ? "<hidden>"
                            : ap.ssid, // ✅ Show AP name
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(
                        "BSSID: ${ap.bssid}\nRSSI: ${ap.level} dBm",
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ),
                  );
                },
              ),
    );
  }
}
