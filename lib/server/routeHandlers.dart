import 'dart:convert';
import 'dart:io';

import 'package:castboard_core/enum-converters/EnumConversionError.dart';
import 'package:castboard_core/logging/LoggingManager.dart';
import 'package:castboard_core/models/RemoteShowData.dart';
import 'package:castboard_core/models/system_controller/AvailableResolutions.dart';
import 'package:castboard_core/storage/Storage.dart';
import 'package:castboard_core/system-commands/SystemCommands.dart';
import 'package:castboard_player/server/Server.dart';
import 'package:shelf/shelf.dart';

Future<Response> handleHeartbeat(
    Request request, void Function(String sessionId) onHeartbeat) async {
  final sessionId = await request.readAsString();

  onHeartbeat(sessionId);

  return Response.ok(null);
}

Future<Response> handleShowDataPull(
    Request request, dynamic onShowDataPull) async {
  if (onShowDataPull == null) {
    return Response.internalServerError(
        body: 'onShowDataPull callback is null.');
  }

  final showData = onShowDataPull?.call();

  if (showData == null) {
    return Response.internalServerError(
        body: 'No data was returned by the onShowDataPull callback');
  }

  final jsonData = json.encoder.convert(showData.toMap());
  final response =
      Response.ok(jsonData, headers: {'Content-Type': 'application/json'});

  return response;
}

Future<Response> handleShowDataPost(
    Request request, OnShowDataReceivedCallback? onShowDataReceived) async {
  if (request.mimeType != 'application/json') {
    return Response.notModified();
  }

  if (onShowDataReceived == null) {
    return Response.internalServerError(body: 'onShowDataReceived is null');
  }

  if (Storage.instance!.isWriting || Storage.instance!.isReading) {
    if (Storage.instance!.isWriting) {
      LoggingManager.instance.server.warning(
          "A show data POST request was denied because the Storage class is busy writing");
    }

    if (Storage.instance!.isReading) {
      LoggingManager.instance.server.warning(
          "A a show data POST request was denied because the Storage class is busy reading");
    }

    return Response.internalServerError(
        body: 'Storage is busy. Please try again');
  }

  final rawJson = await request.readAsString();
  try {
    final rawData = json.decoder.convert(rawJson);
    final result = await onShowDataReceived(RemoteShowData.fromMap(rawData));
    if (result == true) {
      return Response.ok('');
    } else {
      return Response.internalServerError();
    }
  } catch (error) {
    return Response.internalServerError(body: error.toString());
  }
}

Future<Response> handleDownloadReq(Request request) async {
  final file = Storage.instance!.getPlayerStorageFile();

  if (await file.exists() == false) {
    return Response.notFound('File not Found');
  }

  if (Storage.instance!.isWriting || Storage.instance!.isReading) {
    if (Storage.instance!.isWriting) {
      LoggingManager.instance.server.warning(
          "A download request was denied because the Storage class is busy writing");
    }

    if (Storage.instance!.isReading) {
      LoggingManager.instance.server.warning(
          "A download request was denied because the Storage class is busy reading");
    }

    return Response.internalServerError(
        body: 'Storage is busy. Please try again');
  }

  final stat = await file.stat();

  final headers = {
    HttpHeaders.contentLengthHeader: stat.size.toString(),
  };

  return Response.ok(file.openRead(), headers: headers);
}

Future<Response> handleUploadReq(
    Request request, dynamic onShowFileReceived) async {
  if (request.contentLength == null || request.contentLength == 0) {
    return Response(400); // Bad Request.
  }

  final buffer = <int>[];
  await for (var bytes in request.read()) {
    buffer.addAll(bytes.toList());
  }

  if (await Storage.instance!.validateShowFile(buffer) == false) {
    return Response(415); // Unsuported Media Format.
  }

  if (Storage.instance!.isWriting || Storage.instance!.isReading) {
    if (Storage.instance!.isWriting) {
      LoggingManager.instance.server.warning(
          "An upload request was denied because the Storage class is busy writing");
    }

    if (Storage.instance!.isReading) {
      LoggingManager.instance.server.warning(
          "An upload request was denied because the Storage class is busy reading");
    }

    return Response.internalServerError(
        body: 'Storage is busy. Please try again');
  }

  await Storage.instance!.copyShowFileIntoPlayerStorage(buffer);
  onShowFileReceived?.call();

  return Response.ok(null);
}

Future<Response> handlePlaybackReq(
    Request request, dynamic onPlaybackCommand) async {
  await for (var data in request.read()) {
    // TODO: Check the length of that Data isnt something massive, in case we try to send a Binary Blob to this route.
    final String command = utf8.decode(data);
    switch (command) {
      case 'play':
        onPlaybackCommand?.call(PlaybackCommand.play);
        break;
      case 'pause':
        onPlaybackCommand?.call(PlaybackCommand.pause);
        break;
      case 'next':
        onPlaybackCommand?.call(PlaybackCommand.next);
        break;
      case 'prev':
        onPlaybackCommand?.call(PlaybackCommand.prev);
        break;
      default:
        return Response.notFound(null);
    }
  }

  return Response.ok(null);
}

Future<Response> handleSystemCommandReq(
    Request request, OnSystemCommandReceivedCallback? onSystemCommand) async {
  final rawJson = await request.readAsString();
  try {
    final rawData = json.decoder.convert(rawJson);
    final SystemCommand command = SystemCommand.fromMap(rawData);

    if (command.type == SystemCommandType.none) {
      LoggingManager.instance.server.warning('Received a NoneSystemCommand');
      return Response.ok(null);
    }

    onSystemCommand?.call(command);

    return Response.ok(null);
  } on EnumConversionError {
    LoggingManager.instance.server.warning(
        'Failed to parse SystemCommand.type into SystemCommandType enum');
    return Response.ok(null);
  } catch (error) {
    return Response.internalServerError(body: error.toString());
  }
}

Future<Response> handleAvailableResolutionsReq(
    Request request, OnAvailableResolutionsRequestedCallback? callback) async {
  if (callback == null) {
    LoggingManager.instance.server.warning(
        'Tried to call OnAvailableResolutionsRequestedCallback but it was null');
    return Response.internalServerError(
        body: 'handleAvailableResolutionsReq Callback was null');
  }

  final result = await callback();
  final jsonData = json.encoder.convert(AvailableResolutions(result).toMap());
  return Response.ok(jsonData);
}

Future<Response> handleSystemConfigReq(
    Request request, OnSystemConfigPullCallback? callback) async {
  if (callback == null) {
    LoggingManager.instance.server
        .warning('Tried to call OnSystemConfigPullCallback but it was null');
    return Response.internalServerError(
        body: 'OnSystemConfigPull Callback was null');
  }

  final result = await callback();
  final jsonData = json.encoder.convert(result.toMap());
  return Response.ok(jsonData);
}
