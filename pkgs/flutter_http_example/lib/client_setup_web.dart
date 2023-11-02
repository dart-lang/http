import 'package:http/http.dart';
import 'package:fetch_client/fetch_client.dart';

Client http_client() => FetchClient(mode: RequestMode.cors);
