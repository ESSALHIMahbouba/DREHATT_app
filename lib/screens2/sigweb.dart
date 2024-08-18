import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:file_picker/file_picker.dart';

class SigWeb extends StatefulWidget {
  const SigWeb({super.key, required this.title});

  final String title;

  @override
  State<SigWeb> createState() => _SigWebState();
}

class _SigWebState extends State<SigWeb> {
  bool loadingData = false;
  GoogleMapController? mapController;
  String _selectedGeoJsonDocumentId = '';
  Set<Polygon> polygons = {};
  MapType _currentMapType = MapType.normal;

  final Map<String, Color> layerColorMap = {
    'EQUIP': Color(0xff0e38c0),
    '1 UAa1': Color(0xffdb7979),
    '1 E': Colors.red,
    '1 UAa4': Color(0xff4caf50),
    '1 UVa': Color(0xff2196f3),
    '1 NAa': Color(0xffff9800),
    '1 UVb': Color(0xff9c27b0),
    '1 UBa': Color(0xffe91e63),
    '0 fonts': Color(0xff93C572),
  };

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showGeoJsonSelectionDialog();
    });
  }

  LatLngBounds calculateBoundingBox(List<LatLng> points) {
    double? minLat, maxLat, minLon, maxLon;

    for (var point in points) {
      if (minLat == null || point.latitude < minLat) minLat = point.latitude;
      if (maxLat == null || point.latitude > maxLat) maxLat = point.latitude;
      if (minLon == null || point.longitude < minLon) minLon = point.longitude;
      if (maxLon == null || point.longitude > maxLon) maxLon = point.longitude;
    }

    return LatLngBounds(
      southwest: LatLng(minLat ?? 0, minLon ?? 0),
      northeast: LatLng(maxLat ?? 0, maxLon ?? 0),
    );
  }

  Future<void> loadGeoJsonFromFirestore(String documentId) async {
    if (mapController == null) {
      print('Map controller is not initialized');
      return;
    }

    try {
      setState(() {
        loadingData = true;
      });

      final firestore = FirebaseFirestore.instance;
      final docSnapshot =
          await firestore.collection('geojson_files').doc(documentId).get();

      if (docSnapshot.exists) {
        final geoJsonData = docSnapshot.data()?['geojson'] as String?;
        if (geoJsonData != null) {
          final decodedGeoJson = json.decode(geoJsonData);

          final Set<Polygon> newPolygons = {};

          for (var feature in decodedGeoJson['features']) {
            if (feature['geometry']['type'] == 'MultiPolygon') {
              final String layer = feature['properties']['Layer'] ?? 'default';
              final String? fillHex = feature['properties']['fill'];
              final double fillOpacity =
                  feature['properties']['fill-opacity'] ?? 0.5;
              final Color fillColor = fillHex != null
                  ? Color(int.parse(fillHex.replaceFirst('#', '0xFF')))
                  : Colors.transparent;

              final List<LatLng> points = [];
              for (var polygon in feature['geometry']['coordinates']) {
                for (var ring in polygon) {
                  for (var coord in ring) {
                    points.add(LatLng(coord[1], coord[0]));
                  }
                }
              }

              newPolygons.add(
                Polygon(
                  polygonId: PolygonId(
                      feature['properties']['EntityHand'] ?? 'polygon_id'),
                  points: points,
                  strokeColor: feature['properties']['stroke'] != null
                      ? Color(int.parse(feature['properties']['stroke']
                          .replaceFirst('#', '0xFF')))
                      : Colors.black,
                  strokeWidth:
                      feature['properties']['stroke-width']?.toDouble() ?? 2.0,
                  fillColor: fillColor.withOpacity(fillOpacity),
                  onTap: () {
                    _showPolygonInfo(feature['properties']);
                  },
                ),
              );
            }
          }

          setState(() {
            polygons = newPolygons;
          });

          if (newPolygons.isNotEmpty) {
            final bounds = calculateBoundingBox(
                newPolygons.expand((polygon) => polygon.points).toList());
            mapController!.animateCamera(
              CameraUpdate.newLatLngBounds(bounds, 50),
            );
          }

          print('GeoJSON loaded and parsed successfully');
        } else {
          print('Field "geojson" does not exist in the document');
        }
      } else {
        print('Document does not exist');
      }
    } catch (e) {
      print('Error loading GeoJSON: $e');
    } finally {
      setState(() {
        loadingData = false;
      });
    }
  }

  Future<void> uploadGeoJsonToFirestore(
      String documentId, String geoJsonData) async {
    try {
      final firestore = FirebaseFirestore.instance;
      await firestore.collection('geojson_files').doc(documentId).set({
        'geojson': geoJsonData,
      });
      print('GeoJSON uploaded successfully');
    } catch (e) {
      print('Error uploading GeoJSON: $e');
    }
  }

  Future<void> _showGeoJsonSelectionDialog() async {
    final firestore = FirebaseFirestore.instance;
    final querySnapshot = await firestore.collection('geojson_files').get();

    final documents = querySnapshot.docs;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Select a GeoJSON File'),
          content: Container(
            width: double.maxFinite,
            child: ListView(
              children: documents.map((doc) {
                final documentId = doc.id;
                final fileName = documentId;

                return ListTile(
                  title: Text(fileName),
                  onTap: () {
                    Navigator.of(context).pop(); // Close the dialog
                    _selectGeoJson(documentId);
                  },
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  Future<void> _selectGeoJson(String documentId) async {
    try {
      await loadGeoJsonFromFirestore(documentId);
    } catch (e) {
      print('Error selecting GeoJSON file: $e');
    }
  }

  Future<void> _uploadGeoJsonFile() async {
    try {
      final result = await FilePicker.platform
          .pickFiles(type: FileType.custom, allowedExtensions: ['geojson']);
      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;

        final Uint8List fileBytes = file.bytes!;
        final geoJsonData = String.fromCharCodes(fileBytes);
        final fileName = file.name;

        await uploadGeoJsonToFirestore(fileName, geoJsonData);

        print('File uploaded successfully: $fileName');
      } else {
        print('No file selected');
      }
    } catch (e) {
      print('Error uploading file: $e');
    }
  }

  void _changeMapType(MapType mapType) {
    setState(() {
      _currentMapType = mapType;
    });
  }

  void _showMapTypeSelectionDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Select Map Type'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text('Normal'),
                onTap: () {
                  _changeMapType(MapType.normal);
                  Navigator.of(context).pop(); // Ferme le dialogue
                },
              ),
              ListTile(
                title: Text('Satellite'),
                onTap: () {
                  _changeMapType(MapType.satellite);
                  Navigator.of(context).pop(); // Ferme le dialogue
                },
              ),
              ListTile(
                title: Text('Terrain'),
                onTap: () {
                  _changeMapType(MapType.terrain);
                  Navigator.of(context).pop(); // Ferme le dialogue
                },
              ),
              ListTile(
                title: Text('Hybrid'),
                onTap: () {
                  _changeMapType(MapType.hybrid);
                  Navigator.of(context).pop(); // Ferme le dialogue
                },
              ),
            ],
          ),
        );
      },
    );
  }
void _showPolygonInfo(Map<String, dynamic> properties) {
  String layerName = properties['Layer'] ?? 'Unknown Layer'; // Default text if 'Layer' is not available
  Color polygonColor = Colors.white; // Default color

  // Extract color if 'fill' property exists
  if (properties.containsKey('fill')) {
    String? fillHex = properties['fill'];
    if (fillHex != null) {
      polygonColor = Color(int.parse(fillHex.replaceFirst('#', '0xFF')));
    }
  }

  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text('Polygon Info'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                height: 50.0,
                color: polygonColor,
                child: Center(
                  child: Text(
                    layerName,
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              SizedBox(height: 16.0),
              ...properties.entries.map((entry) {
                return Text('${entry.key}: ${entry.value}');
              }).toList(),
            ],
          ),
        ),
        actions: [
          TextButton(
            child: Text('OK'),
            onPressed: () {
              Navigator.of(context).pop(); // Close the dialog
            },
          ),
        ],
      );
    },
  );
}

  @override
  void initState() {
    super.initState();
    Firebase.initializeApp();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Suivi des PAUS'),
        actions: [
          IconButton(
            icon: Icon(Icons.upload_file),
            onPressed: _uploadGeoJsonFile,
          ),
          IconButton(
            icon: Icon(Icons.file_open),
            onPressed: _showGeoJsonSelectionDialog,
          ),
          IconButton(
            icon: Icon(Icons.layers),
            onPressed: _showMapTypeSelectionDialog,
          ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: _onMapCreated,
            polygons: polygons,
            mapType: _currentMapType,
            initialCameraPosition: CameraPosition(
              target: LatLng(
                  32.9295, 10.4518), // Position initiale à Tataouine, Tunisie
              zoom: 12,
            ),
          ),
          if (loadingData)
            Center(
              child: CircularProgressIndicator(),
            ),
        ],
      ),
    );
  }
}
