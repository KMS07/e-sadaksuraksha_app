import 'dart:developer' as dev;
import 'dart:convert';
import 'driver_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:io';
import 'dart:math' show asin, cos, log, sqrt;
import 'package:flutter_html/flutter_html.dart' as html;
import 'package:http/http.dart' as http;
import 'package:geocoding/geocoding.dart' as geocoding;
import 'package:uuid/uuid.dart';

class RouteOpt extends StatefulWidget {
  @override
  _MapViewState createState() => _MapViewState();
}

class _MapViewState extends State<RouteOpt> {
  CameraPosition _initialLocation = CameraPosition(target: LatLng(0.0, 0.0));
  late GoogleMapController mapController;
  List<dynamic> placesList = [];
  late Position _currentPosition;
  String _currentAddress = '';

  final startAddressController = TextEditingController();
  final destinationAddressController = TextEditingController();

  final startAddressFocusNode = FocusNode();
  final desrinationAddressFocusNode = FocusNode();

  String _startAddress = '';
  String _destinationAddress = '';
  String? _placeDistance;

  Set<Marker> markers = {};

  late PolylinePoints polylinePoints;
  Map<PolylineId, Polyline> polylines = {};
  List<LatLng> polylineCoordinates = [];
  List<dynamic> steps = [];

  final _scaffoldKey = GlobalKey<ScaffoldState>();

  Widget _textField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String label,
    required String hint,
    required double width,
    required Icon prefixIcon,
    Widget? suffixIcon,
    required Function(String) locationCallback,
  }) {
    return Container(
      width: width * 0.8,
      child: TextField(
        onChanged: (value) {
          locationCallback(value);
        },
        controller: controller,
        focusNode: focusNode,
        decoration: new InputDecoration(
          prefixIcon: prefixIcon,
          suffixIcon: suffixIcon,
          labelText: label,
          filled: true,
          fillColor: Colors.white,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(
              Radius.circular(10.0),
            ),
            borderSide: BorderSide(
              color: Colors.grey.shade400,
              width: 2,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(
              Radius.circular(10.0),
            ),
            borderSide: BorderSide(
              color: Colors.blue.shade300,
              width: 2,
            ),
          ),
          contentPadding: EdgeInsets.all(15),
          hintText: hint,
        ),
      ),
    );
  }

  // Method for retrieving the current location
  _getCurrentLocation() async {
    await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high)
        .then((Position position) async {
      setState(() {
        _currentPosition = position;
        print('CURRENT POS: $_currentPosition');
        mapController.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: LatLng(position.latitude, position.longitude),
              zoom: 18.0,
            ),
          ),
        );
      });
      await _getAddress();
    }).catchError((e) {
      print(e);
    });
  }

  // Method for retrieving the address
  _getAddress() async {
    try {
      List<Placemark> p = await placemarkFromCoordinates(
          _currentPosition.latitude, _currentPosition.longitude);

      Placemark place = p[0];

      setState(() {
        _currentAddress =
            "${place.name}, ${place.locality}, ${place.postalCode}, ${place.country}";
        startAddressController.text = _currentAddress;
        _startAddress = _currentAddress;
      });
    } catch (e) {
      print(e);
    }
  }

  // Method for calculating the distance between two places
  Future<bool> _calculateDistance() async {
    try {
      // Retrieving placemarks from addresses
      List<Location> startPlacemark = await locationFromAddress(_startAddress);
      List<Location> destinationPlacemark =
          await locationFromAddress(_destinationAddress);

      // Use the retrieved coordinates of the current position,
      // instead of the address if the start position is user's
      // current position, as it results in better accuracy.
      double startLatitude = _startAddress == _currentAddress
          ? _currentPosition.latitude
          : startPlacemark[0].latitude;

      double startLongitude = _startAddress == _currentAddress
          ? _currentPosition.longitude
          : startPlacemark[0].longitude;

      double destinationLatitude = destinationPlacemark[0].latitude;
      double destinationLongitude = destinationPlacemark[0].longitude;

      String startCoordinatesString = '($startLatitude, $startLongitude)';
      String destinationCoordinatesString =
          '($destinationLatitude, $destinationLongitude)';

      // Start Location Marker
      Marker startMarker = Marker(
        markerId: MarkerId(startCoordinatesString),
        position: LatLng(startLatitude, startLongitude),
        infoWindow: InfoWindow(
          title: 'Start $startCoordinatesString',
          snippet: _startAddress,
        ),
        icon: BitmapDescriptor.defaultMarker,
      );

      // Destination Location Marker
      Marker destinationMarker = Marker(
        markerId: MarkerId(destinationCoordinatesString),
        position: LatLng(destinationLatitude, destinationLongitude),
        infoWindow: InfoWindow(
          title: 'Destination $destinationCoordinatesString',
          snippet: _destinationAddress,
        ),
        icon: BitmapDescriptor.defaultMarker,
      );

      // Adding the markers to the list
      markers.add(startMarker);
      markers.add(destinationMarker);

      print(
        'START COORDINATES: ($startLatitude, $startLongitude)',
      );
      print(
        'DESTINATION COORDINATES: ($destinationLatitude, $destinationLongitude)',
      );

      // Calculating to check that the position relative
      // to the frame, and pan & zoom the camera accordingly.
      double miny = (startLatitude <= destinationLatitude)
          ? startLatitude
          : destinationLatitude;
      double minx = (startLongitude <= destinationLongitude)
          ? startLongitude
          : destinationLongitude;
      double maxy = (startLatitude <= destinationLatitude)
          ? destinationLatitude
          : startLatitude;
      double maxx = (startLongitude <= destinationLongitude)
          ? destinationLongitude
          : startLongitude;

      double southWestLatitude = miny;
      double southWestLongitude = minx;

      double northEastLatitude = maxy;
      double northEastLongitude = maxx;

      // Accommodate the two locations within the
      // camera view of the map
      mapController.animateCamera(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(
            northeast: LatLng(northEastLatitude, northEastLongitude),
            southwest: LatLng(southWestLatitude, southWestLongitude),
          ),
          100.0,
        ),
      );

      // Calculating the distance between the start and the end positions
      // with a straight path, without considering any route
      // double distanceInMeters = await Geolocator.bearingBetween(
      //   startLatitude,
      //   startLongitude,
      //   destinationLatitude,
      //   destinationLongitude,
      // );

      await _createPolylines(startLatitude, startLongitude, destinationLatitude,
          destinationLongitude);

      double totalDistance = 0.0;

      // Calculating the total distance by adding the distance
      // between small segments
      for (int i = 0; i < polylineCoordinates.length - 1; i++) {
        totalDistance += _coordinateDistance(
          polylineCoordinates[i].latitude,
          polylineCoordinates[i].longitude,
          polylineCoordinates[i + 1].latitude,
          polylineCoordinates[i + 1].longitude,
        );
      }

      setState(() {
        _placeDistance = totalDistance.toStringAsFixed(2);
        print('DISTANCE: $_placeDistance km');
      });

      return true;
    } catch (e) {
      print(e);
    }
    return false;
  }

  // Formula for calculating distance between two coordinates
  // https://stackoverflow.com/a/54138876/11910277
  double _coordinateDistance(lat1, lon1, lat2, lon2) {
    var p = 0.017453292519943295;
    var c = cos;
    var a = 0.5 -
        c((lat2 - lat1) * p) / 2 +
        c(lat1 * p) * c(lat2 * p) * (1 - c((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a));
  }

  Future<String> getAddressFromCoordinates(
      double latitude, double longitude) async {
    const apiKey =
        'AIzaSyAmD2yMXYYHJJnuaYii2ek8npmz2HS-lB0'; // Replace with your Google Maps API key
    final apiUrl =
        'https://maps.googleapis.com/maps/api/geocode/json?latlng=$latitude,$longitude&key=$apiKey';

    final response = await http.get(Uri.parse(apiUrl));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final results = data['results'] as List<dynamic>;
      if (results.isNotEmpty) {
        return results[0]['formatted_address'];
      }
    }
    return 'Address not found';
  }

  // Create the polylines for showing the route between two places
  _createPolylines(
    double startLatitude,
    double startLongitude,
    double destinationLatitude,
    double destinationLongitude,
  ) async {
    // polylinePoints = PolylinePoints();
    // PolylineResult result = await polylinePoints.getRouteBetweenCoordinates(
    //   'AIzaSyAmD2yMXYYHJJnuaYii2ek8npmz2HS-lB0', // Google Maps API Key
    //   PointLatLng(startLatitude, startLongitude),
    //   PointLatLng(destinationLatitude, destinationLongitude),
    //   travelMode: TravelMode.driving,
    // );
    //
    // if (result.points.isNotEmpty) {
    //   result.points.forEach((PointLatLng point) {
    //     polylineCoordinates.add(LatLng(point.latitude, point.longitude));
    //   });
    // }
    //
    // PolylineId id = PolylineId('poly');
    // Polyline polyline = Polyline(
    //   polylineId: id,
    //   color: Colors.red,
    //   points: polylineCoordinates,
    //   width: 3,
    // );
    // polylines[id] = polyline;
    polylinePoints = PolylinePoints();

    String origin =
        await getAddressFromCoordinates(startLatitude, startLongitude);
    String destination = await getAddressFromCoordinates(
        destinationLatitude, destinationLongitude);

    String apiKey =
        "AIzaSyAmD2yMXYYHJJnuaYii2ek8npmz2HS-lB0"; // Replace with your actual API key

    String url = 'https://maps.googleapis.com/maps/api/directions/json';
    String requestUrl =
        '$url?origin=$origin&destination=$destination&mode=driving&traffic_model=best_guess&departure_time=now&key=$apiKey';

    try {
      http.Response response = await http.get(Uri.parse(requestUrl));
      print('yes');
      if (response.statusCode == 200) {
        Map<String, dynamic> data = jsonDecode(response.body);
        if (data['routes'] != null && data['routes'].length > 0) {
          int shortestDuration = double.maxFinite.toInt();
          Map<String, dynamic> bestRoute = data['routes'][0];
          for (var route in data['routes']) {
            int duration = route['legs'][0]['duration']['value'];
            if (duration < shortestDuration) {
              shortestDuration = duration;
              bestRoute = route;
            }
          }
          // Print directions steps for the best route
          steps = bestRoute['legs'][0]['steps'];
          print('Directions steps for the best route:');
          for (var step in steps) {
            print(step['html_instructions']);
          }
          print('duration $shortestDuration');
          List<PointLatLng> points = polylinePoints
              .decodePolyline(bestRoute['overview_polyline']['points']);
          points.forEach((PointLatLng point) {
            polylineCoordinates.add(LatLng(point.latitude, point.longitude));
          });
        } else {
          print('No routes found');
          return;
        }
      } else {
        print('Failed to fetch route: ${response.statusCode}');
        return;
      }
    } catch (e) {
      print('Error fetching route: $e');
      return;
    }

    // Add polylines to the map
    PolylineId id = PolylineId('poly');
    Polyline polyline = Polyline(
      polylineId: id,
      color: Colors.red,
      points: polylineCoordinates,
      width: 3,
    );
    polylines[id] = polyline;

    // String url = '';
    // String origin = await getAddressFromCoordinates(startLatitude,startLongitude);
    // String end = await getAddressFromCoordinates(destinationLatitude,destinationLongitude);
    // dev.log(origin);
    // dev.log(end);
    // Map<String, dynamic> payload = {
    //   'origin': {'address': origin},
    //   'destination': {'address': end},
    //   'travelMode': 'DRIVE',
    //   'extraComputations': ['TRAFFIC_ON_POLYLINE'],
    //   'routingPreference': 'TRAFFIC_AWARE_OPTIMAL',
    // };
    //
    // Map<String, String> headers = {
    //   'Content-Type': 'application/json',
    //   'X-Goog-Api-Key': 'AIzaSyAmD2yMXYYHJJnuaYii2ek8npmz2HS-lB0',
    //   'X-Goog-FieldMask': 'routes.duration,routes.distanceMeters,routes.polyline,routes.legs.polyline,routes.travelAdvisory,routes.legs.travelAdvisory',
    // };
    // try {
    //   print(origin);
    //   var response = await http.post(
    //     Uri.parse(url),
    //     headers: headers,
    //     body: jsonEncode(payload),
    //   );
    //   log(response.statusCode);
    //   if (response.statusCode == 200) {
    //     var data = jsonDecode(response.body);
    //     List<LatLng> polylineCoordinates1 = [];
    //     if (data['routes'] != null && data['routes'].length > 0) {
    //       // Extract points from the first route
    //       List<PointLatLng> points = polylinePoints.decodePolyline(data['routes'][0]['polyline']['points']);
    //       points.forEach((PointLatLng point) {
    //         polylineCoordinates1.add(LatLng(point.latitude, point.longitude));
    //       });
    //     }
    //     PolylineId id1 = PolylineId('poly1');
    //     Polyline polyline1 = Polyline(
    //       polylineId: id1,
    //       color: _getPolylineColor(data),
    //       points: polylineCoordinates1,
    //       width: 3,
    //     );
    //     polylines[id1] = polyline1;
    //   } else {
    //     print('Request failed with status: ${response.statusCode}');
    //     print('Error message: ${response.body}');
    //   }
    // } catch (e) {
    //   print('Failed to send request: $e');
    // }
  }

  Color _getPolylineColor(Map<String, dynamic> data) {
    // Function to determine polyline color based on traffic condition
    String trafficCondition =
        data['routes'][0]['legs'][0]['traffic_speed_entry'].toString();

    if (trafficCondition == 'slow') {
      return Colors.red; // Slow traffic, red color
    } else if (trafficCondition == 'moderate') {
      return Colors.orange; // Moderate traffic, orange color
    } else {
      return Colors.green; // No or light traffic, green color
    }
  }

  @override
  void initState() {
    super.initState();
    destinationAddressController.addListener(() {
      onChange();
    });
    _getCurrentLocation();
  }
  var uuid  = Uuid();
  String _sessionToken = "123456";

  void onChange(){
    if(_sessionToken == null){
      setState(() {
        _sessionToken = uuid.v4();
      });
    }
    getSuggestion(destinationAddressController.text);
  }
  bool _showSteps = false;
  void _showStepsDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Steps'),
          content: Container(
            width: MediaQuery.of(context).size.width *
                0.8, // Example width constraint
            height: MediaQuery.of(context).size.height *
                0.6, // Example height constraint
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  for (var step in steps)
                    ListTile(
                      title: html.Html(data: step['html_instructions']),
                    ),
                ],
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void getSuggestion(String input) async{
    String api_key = "AIzaSyAmD2yMXYYHJJnuaYii2ek8npmz2HS-lB0";
    String baseURL = 'https://maps.googleapis.com/maps/api/place/autocomplete/json';
    String request = '$baseURL?input=$input&key=$api_key&sessiontoken=$_sessionToken';

    var response = await http.get(Uri.parse(request));

    print(response.body.toString());
    if(response.statusCode == 200){
      placesList = jsonDecode(response.body.toString())['predictions'];
    }else{
      throw Exception("flailed to load data");
    }
  }
  @override
  Widget build(BuildContext context) {
    var height = MediaQuery.of(context).size.height;
    var width = MediaQuery.of(context).size.width;

    return Scaffold(
      appBar: AppBar(
        title: Text('Get optimized route'),
      ),
      key: _scaffoldKey,
      body: Stack(
        children: <Widget>[
          // Map View
          GoogleMap(
            markers: Set<Marker>.from(markers),
            initialCameraPosition: _initialLocation,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            mapType: MapType.normal,
            zoomGesturesEnabled: true,
            zoomControlsEnabled: false,
            polylines: Set<Polyline>.of(polylines.values),
            onMapCreated: (GoogleMapController controller) {
              mapController = controller;
            },
          ),
          // Show zoom buttons
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(left: 10.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  ClipOval(
                    child: Material(
                      color: Colors.blue.shade100, // button color
                      child: InkWell(
                        splashColor: Colors.blue, // inkwell color
                        child: SizedBox(
                          width: 50,
                          height: 50,
                          child: Icon(Icons.add),
                        ),
                        onTap: () {
                          mapController.animateCamera(
                            CameraUpdate.zoomIn(),
                          );
                        },
                      ),
                    ),
                  ),
                  SizedBox(height: 20),
                  ClipOval(
                    child: Material(
                      color: Colors.blue.shade100, // button color
                      child: InkWell(
                        splashColor: Colors.blue, // inkwell color
                        child: SizedBox(
                          width: 50,
                          height: 50,
                          child: Icon(Icons.remove),
                        ),
                        onTap: () {
                          mapController.animateCamera(
                            CameraUpdate.zoomOut(),
                          );
                        },
                      ),
                    ),
                  )
                ],
              ),
            ),
          ),
          // Show the place input fields & button for
          // showing the route
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(top: 10.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white70,
                    borderRadius: BorderRadius.all(
                      Radius.circular(20.0),
                    ),
                  ),
                  width: width * 0.9,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 10.0, bottom: 10.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          'Places',
                          style: TextStyle(fontSize: 20.0),
                        ),
                        SizedBox(height: 10),
                        _textField(
                            label: 'Start',
                            hint: 'Choose starting point',
                            prefixIcon: Icon(Icons.looks_one),
                            suffixIcon: IconButton(
                              icon: Icon(Icons.my_location),
                              onPressed: () {
                                startAddressController.text = _currentAddress;
                                _startAddress = _currentAddress;
                              },
                            ),
                            controller: startAddressController,
                            focusNode: startAddressFocusNode,
                            width: width,
                            locationCallback: (String value) {
                              setState(() {
                                _startAddress = value;
                              });
                            }),
                        SizedBox(height: 10),
                        _textField(
                            label: 'Destination',
                            hint: 'Choose destination',
                            prefixIcon: Icon(Icons.looks_two),
                            controller: destinationAddressController,
                            focusNode: desrinationAddressFocusNode,
                            width: width,
                            locationCallback: (String value) {
                              setState(() {
                                _destinationAddress = value;
                              });
                            }),
                        Expanded(
                            flex: 1,
                            child: ListView.builder(
                                itemCount: placesList.length,
                                itemBuilder: (context, index) {
                                  return ListTile(
                                    onTap: () async {
                                      setState(() {
                                        _destinationAddress = placesList[index]['description'];
                                      });
                                      // Set the text in the destination address field
                                      destinationAddressController.text = placesList[index]['description'];
                                      // Collapse the view
                                      desrinationAddressFocusNode.unfocus();
                                    },
                                    title:
                                        Text(placesList[index]['description']),
                                  );
                                })),
                        SizedBox(height: 10),
                        Visibility(
                          visible: _placeDistance == null ? false : true,
                          child: Text(
                            'DISTANCE: $_placeDistance km',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        SizedBox(height: 5),
                        ElevatedButton(
                          onPressed:
                              (_startAddress != '' && _destinationAddress != '')
                                  ? () async {
                                      startAddressFocusNode.unfocus();
                                      desrinationAddressFocusNode.unfocus();
                                      setState(() {
                                        if (markers.isNotEmpty) markers.clear();
                                        if (polylines.isNotEmpty) {
                                          polylines.clear();
                                        }
                                        if (polylineCoordinates.isNotEmpty) {
                                          polylineCoordinates.clear();
                                        }
                                        if (steps.isNotEmpty) {
                                          steps.clear();
                                        }
                                        _placeDistance = null;
                                      });
                                      _showSteps = true;
                                      _calculateDistance().then((isCalculated) {
                                        if (isCalculated) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                  'Distance Calculated Sucessfully'),
                                            ),
                                          );
                                        } else {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                  'Error Calculating Distance'),
                                            ),
                                          );
                                        }
                                      });
                                    }
                                  : null,
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                              'Show Route'.toUpperCase(),
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20.0,
                              ),
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20.0),
                            ),
                          ),
                        ),
                      ],
                    )
                  ),
                ),
              ),
            ),
          ),
          Visibility(
            visible: _showSteps,
            child: ElevatedButton(
              onPressed: _showStepsDialog,
              child: Text('Steps'),
            ),
          ),
          // Show current location button
          SafeArea(
            child: Align(
              alignment: Alignment.bottomRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 10.0, bottom: 10.0),
                child: ClipOval(
                  child: Material(
                    color: Colors.orange.shade100, // button color
                    child: InkWell(
                      splashColor: Colors.orange, // inkwell color
                      child: SizedBox(
                        width: 56,
                        height: 56,
                        child: Icon(Icons.my_location),
                      ),
                      onTap: () {
                        mapController.animateCamera(
                          CameraUpdate.newCameraPosition(
                            CameraPosition(
                              target: LatLng(
                                _currentPosition.latitude,
                                _currentPosition.longitude,
                              ),
                              zoom: 18.0,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
