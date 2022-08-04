#!/bin/sh

# Generate the platform messages used by cronet_http.

flutter pub run pigeon \
  --input pigeons/messages.dart \
  --dart_out lib/src/messages.dart \
  --java_out android/src/main/java/io/flutter/plugins/cronet_http/Messages.java \
  --java_package "io.flutter.plugins.cronet_http"