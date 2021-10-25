import 'dart:io';

import 'package:castboard_core/models/system_controller/DeviceConfig.dart';
import 'package:castboard_core/models/system_controller/DeviceOrientation.dart';
import 'package:castboard_core/models/system_controller/DeviceResolution.dart';
import 'package:castboard_player/system_controller/platform_implementations/rpi_linux/SystemControllerRpiLinux.dart';
import 'package:castboard_player/system_controller/platform_implementations/noop/SystemControllerNoop.dart';

abstract class SystemController {
  static SystemController? _instance;

  factory SystemController() {
    // If first time build and cache new instance.
    _instance = _instance ?? _buildInstance();
    return _instance!;
  }

  static SystemController _buildInstance() {
    /// DBus is only available on Linux. So if we aren't on linux we want to return a NOOP instance.
    if (Platform.isLinux) {
      return SystemControllerRpiLinux();
    }

    return SystemControllerNoop();
  }

  Future<void> initialize();

  /// Triggers a hardware Power Off.
  Future<void> powerOff();

  /// Triggers a hardware reboot.
  Future<void> reboot();

  /// Triggers an application restart.
  Future<void> restart();

  /// Gets the current Framebuffer resolution (Actual output resolution)
  Future<DeviceResolution> getCurrentResolution();

  /// Gets the resolution that the device is set to be at.
  Future<DeviceResolution> getDesiredResolution();

  /// Gets a boolean representing if resolution is in 'Auto' mode.
  Future<bool> getIsAutoResolution();

  /// Gets the current orientation.
  Future<DeviceOrientation> getCurrentOrientation();

  /// Writes the provided [DeviceConfig] to all relevant locations. Returns a Future that resolves to a bool representing if the device needs to be rebooted
  /// for changes to take affect.
  Future<bool> commitDeviceConfig(DeviceConfig config);

  Future<List<DeviceResolution>> getAvailableResolutions();

  Future<void> dispose();
}