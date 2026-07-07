import 'package:connectivity_plus/connectivity_plus.dart';

Future<bool> hasInternet() async {
  final connectivityResult = await Connectivity().checkConnectivity();

  return connectivityResult.contains(ConnectivityResult.mobile) ||
      connectivityResult.contains(ConnectivityResult.wifi) ||
      connectivityResult.contains(ConnectivityResult.ethernet) ||
      connectivityResult.contains(ConnectivityResult.vpn);
}
