#!/bin/sh

# Generate the platform messages used by cronet_http.
cd ../

flutter pub run pigeon \
  --input pigeons/messages.dart \
  --dart_out lib/src/messages.dart \
  --java_out android/src/main/java/io/flutter/plugins/cronet_http/Messages.java \
  --java_package "io.flutter.plugins.cronet_http"

dart format lib/src/messages.dart
