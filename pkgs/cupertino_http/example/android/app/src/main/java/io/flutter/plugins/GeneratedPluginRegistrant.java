package io.flutter.plugins;

import io.flutter.plugin.common.PluginRegistry;
import dev.flutter.plugins.integration_test.IntegrationTestPlugin;

/**
 * Generated file. Do not edit.
 */
public final class GeneratedPluginRegistrant {
  public static void registerWith(PluginRegistry registry) {
    if (alreadyRegisteredWith(registry)) {
      return;
    }
    IntegrationTestPlugin.registerWith(registry.registrarFor("dev.flutter.plugins.integration_test.IntegrationTestPlugin"));
  }

  private static boolean alreadyRegisteredWith(PluginRegistry registry) {
    final String key = GeneratedPluginRegistrant.class.getCanonicalName();
    if (registry.hasPlugin(key)) {
      return true;
    }
    registry.registrarFor(key);
    return false;
  }
}
