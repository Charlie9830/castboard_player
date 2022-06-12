import 'dart:io';

import 'package:castboard_core/models/system_controller/SystemConfig.dart';
import 'package:castboard_performer/system_controller/SystemConfigCommitResult.dart';
import 'package:castboard_performer/system_controller/platform_implementations/rpi_linux/SystemControllerRpiLinux.dart';
import 'package:castboard_performer/system_controller/platform_implementations/noop/SystemControllerNoop.dart';

enum UpdateStatus { none, success, started, failed }

abstract class SystemController {
  static SystemController? _instance;

  factory SystemController() {
    // If first time build and cache new instance.
    _instance = _instance ?? _buildInstance();
    return _instance!;
  }

  static SystemController _buildInstance() {
    if (const String.fromEnvironment('ELINUX_IS_DESKTOP') == 'true') {
      // Running Flutter-Elinux Desktop (X64), Use Noop Controller.
      return SystemControllerNoop();
    }

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

  /// Writes the provided [SystemConfig] to all relevant locations. Returns a Future that resolves to a bool representing if the device needs to be rebooted
  /// for changes to take affect.
  Future<SystemConfigCommitResult> commitSystemConfig(SystemConfig config);

  Future<SystemConfig> getSystemConfig();

  // Updates the application using the provided zip file.
  Future<bool> updateApplication(List<int> byteData);

  // Checks if the player has just been updated and is booting for the first time
  // since.
  Future<UpdateStatus> getUpdateStatus();

  // Resets the update status.
  Future<void> resetUpdateStatus();

  Future<void> dispose();
}
