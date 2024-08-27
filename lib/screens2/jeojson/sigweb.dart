import 'dart:convert';
import 'dart:typed_data';
import 'package:DREHATT_app/screens2/jeojson/convertGeoJson.dart';
import 'package:DREHATT_app/screens2/kml/KmlMapPage.dart';
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
  Set<Polyline> polylines = {};

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
          final Set<Polyline> newPolylines = {}; // Added for LineString support

          int index = 0; // Initialize index for unique ID
          for (var feature in decodedGeoJson['features']) {
            if (feature['geometry']['type'] == 'MultiPolygon') {
              final List<List<LatLng>> polygonList = [];
              for (var polygon in feature['geometry']['coordinates']) {
                final List<LatLng> ringPoints = [];
                for (var ring in polygon) {
                  for (var coord in ring) {
                    ringPoints.add(LatLng(coord[1], coord[0]));
                  }
                }
                polygonList.add(ringPoints);
              }

              // Generate unique ID using index
              final polygonId = PolygonId('polygon_$index');
              index++; // Increment index for next polygon

              // Extract fill color if exists
              final String? fillHex = feature['properties']['fill'];
              final double fillOpacity =
                  feature['properties']['fill-opacity']?.toDouble() ?? 0.5;
              final Color fillColor = fillHex != null
                  ? Color(int.parse(fillHex.replaceFirst('#', '0xFF')))
                  : Color.fromARGB(0, 236, 125, 125);

              newPolygons.add(
                Polygon(
                  polygonId: polygonId,
                  points: polygonList.expand((ring) => ring).toList(),
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
            } else if (feature['geometry']['type'] == 'LineString') {
              final List<LatLng> linePoints = [];
              for (var coord in feature['geometry']['coordinates']) {
                // Check if coordinates are objects with x and y properties
                if (coord is Map<String, dynamic> &&
                    coord.containsKey('x') &&
                    coord.containsKey('y')) {
                  final double x = coord['x']?.toDouble() ?? 0.0;
                  final double y = coord['y']?.toDouble() ?? 0.0;
                  linePoints.add(LatLng(
                      y, x)); // Note the order: LatLng(latitude, longitude)
                } else if (coord is List<dynamic> && coord.length >= 2) {
                  // Handle the traditional array format [longitude, latitude]
                  final double x = coord[0]?.toDouble() ?? 0.0;
                  final double y = coord[1]?.toDouble() ?? 0.0;
                  linePoints.add(LatLng(
                      y, x)); // Note the order: LatLng(latitude, longitude)
                }
              }

              // Generate unique ID using index
              final polylineId = PolylineId('polyline_$index');
              index++; // Increment index for next polyline

              newPolylines.add(
                Polyline(
                  polylineId: polylineId,
                  points: linePoints,
                  color: const Color.fromARGB(
                      255, 243, 58, 33), // Default color for LineString
                  width: 3, // Default width for LineString
                ),
              );
            }
          }

          setState(() {
            polygons = newPolygons;
            // Add the polylines to the map
            polylines = newPolylines;
          });

          if (newPolygons.isNotEmpty || newPolylines.isNotEmpty) {
            final allPoints =
                newPolygons.expand((polygon) => polygon.points).toList();
            allPoints
                .addAll(newPolylines.expand((polyline) => polyline.points));
            final bounds = calculateBoundingBox(allPoints);
            mapController!
                .animateCamera(CameraUpdate.newLatLngBounds(bounds, 50));
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
    String layerName = properties['Layer'] ??
        'Unknown Layer'; // Default text if 'Layer' is not available
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
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold),
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
            icon: Icon(Icons.change_circle),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => GeoJsonConverterPage()),
              );
            },
            tooltip: 'convertisseur',
          ),
          IconButton(
            icon: Icon(Icons.map_sharp),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => KmlMapPage()),
              );
            },
            tooltip: 'kml reader',
          ),
          IconButton(
            icon: Icon(Icons.file_upload),
            onPressed: _uploadGeoJsonFile,
            tooltip: 'telecharger geojson fils ',
          ),
          IconButton(
            icon: Icon(Icons.file_open),
            onPressed: _showGeoJsonSelectionDialog,
            tooltip: 'liste de paus',
          ),
          IconButton(
            icon: Icon(Icons.layers),
            onPressed: _showMapTypeSelectionDialog,
            tooltip: 'changer layer ',
          ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: _onMapCreated,
            polygons: polygons,
            polylines: polylines, // Ajoutez cette ligne
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
