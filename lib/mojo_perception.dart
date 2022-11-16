/// @license
/// Copyright 2022 Hoomano SAS. All Rights Reserved.
/// Licensed under the MIT License, (the "License");
/// you may not use this file except in compliance with the License.
///
/// Permission is hereby granted, free of charge, to any person obtaining a copy
/// of this software and associated documentation files (the "Software"), to deal
/// in the Software without restriction, including without limitation the rights
/// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
/// copies of the Software, and to permit persons to whom the Software is
/// furnished to do so, subject to the following conditions:
///
/// The above copyright notice and this permission notice shall be included in
/// all copies or substantial portions of the Software.
///
/// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
/// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
/// FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
/// COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
/// IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
/// CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
///
/// =============================================================================
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:logging/logging.dart';
import 'package:mojo_perception/services/face_detection/face_detection_service.dart';
import 'package:mojo_perception/services/facemesh_service.dart';
import 'package:mojo_perception/services/image_converter.dart';
import 'package:mojo_perception/services/isolate_utils.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:tflite_flutter/tflite_flutter.dart';

/// Flutter client for Mojo Perception API
///
/// See README for a procedure to generate the required parameters:
/// auth_token, host, port and user_namespace
class MojoPerceptionAPI {
  final logger = Logger('MojoPerceptionAPI');

  /// Access key given by the API backend (access token with expiration date depending on the subscription)
  String authToken;

  /// Socket io stream host
  String host;

  /// Socket io stream port
  String port;

  /// Namespace for the user token
  String userNamespace;

  /// Complete URI for connection to Socket IO server
  late String socketIoUri;

  /// Socket io
  late io.Socket apiSocket;

  /// Set to false to stop sending to the API
  bool sending = false;

  /// Default emotions computed by the API
  ///
  /// ['attention','confusion','surprise','amusement', 'engagement', 'interaction']
  List<String> emotions = [
    'attention',
    'confusion',
    'surprise',
    'amusement',
    'engagement',
    'interaction'
  ];

  /// Calculate the frame rate of Face Detection
  late double faceDetectionFrameRate;

  /// Controller to get camera imageStream
  CameraController? cameraController;

  /// Variable used for multi-threading
  late IsolateUtils _isolateUtils;

  /// Variable to use the model that extract anonymized facial keypoints
  late Interpreter facemeshInterpreter;

  /// Variable to use the model that extract anonymized facial keypoints
  late Interpreter faceDetectionInterpreter;

  /// Shape of landmarks detection model inputs
  late List<int> facemeshInputShape;

  /// Shape of face detection model inputs
  late List<int> faceDetectionInputShape;

  /// Shapes of landmarks detection model outputs
  late List<List<int>> facemeshOutputsShapes = [];

  /// Shapes of face detection model outputs
  late List<List<int>> faceDetectionOutputsShapes = [];

  /// Handler for real-time attention calculation received
  late Function attentionCallback;

  /// Handler for real-time amusement calculation received
  late Function amusementCallback;

  /// Handler for real-time confusion calculation received
  late Function confusionCallback;

  /// Handler for real-time surprise calculation received
  late Function surpriseCallback;

  /// Handler for real-time engagement calculation received
  late Function engagementCallback;

  /// Handler for real-time interaction calculation received
  late Function interactionCallback;

  /// Called when first emit to SocketIO stream server has been done
  late Function firstEmitDoneCallback;

  /// Indicate if the first emit has been done to the SocketIO stream server
  bool firstEmitDone = false;

  /// Called if an error occurs
  late Function onErrorCallback;

  /// Called when API is stopped
  late Function onStopCallback;

  /// Called on face detected
  late Function faceDetectedCallback;

  /// Called on no face detected
  late Function noFaceDetectedCallback;

  /// Flag to indicate if the API subscribes to real-time calculation (optional)
  bool subscribeRealtimeOutput = false;

  /// Whether the [faceDetectionInterpreter] is busy generating a prediction or not
  bool _predictingFaceDetection = false;

  /// Whether the [facemeshInterpreter] is busy generating a prediction or not
  bool _predictingFacemesh = false;

  /// Used by default for all callbacks taking "data" as parameter. Does nothing.
  /// [message] not used
  void defaultDataCallback(data) {
    return;
  }

  /// Used by default for all callbacks taking no parameter. Does nothing.
  /// [message] not used
  void defaultNoDataCallback() {
    return;
  }

  /// Called by default when the first emit to the Stream SocketIO server is done.
  void defaultFirstEmitDoneFallback() {
    return;
  }

  /// Called by default when the API is stopped
  void defaultOnStopCallback() {
    return;
  }

  /// Initializes the MojoPerceptionAPI client.
  ///
  /// Sets the SocketIoURI [host], [port] and [userNamespace]. Sets [authToken].
  /// Places default callbacks on calculation reception for each emotion,
  /// firstEmit, error and stop callbacks
  MojoPerceptionAPI(this.authToken, this.host, this.port, this.userNamespace) {
    socketIoUri = 'https://$host:$port/$userNamespace';
    attentionCallback = defaultDataCallback;
    amusementCallback = defaultDataCallback;
    confusionCallback = defaultDataCallback;
    surpriseCallback = defaultDataCallback;
    engagementCallback = defaultDataCallback;
    interactionCallback = defaultDataCallback;
    onErrorCallback = defaultDataCallback;
    onStopCallback = defaultOnStopCallback;
    firstEmitDoneCallback = defaultFirstEmitDoneFallback;
    faceDetectedCallback = defaultDataCallback;
    noFaceDetectedCallback = defaultNoDataCallback;
  }

  /// Returns a string representing the MojoPerceptionAPI object
  ///
  /// The strings contains [emotions], [socketIoUri], [subscribeRealtimeOutput] and [authToken].
  @override
  String toString() {
    return '\nemotions=$emotions\nsocketIoURI=$socketIoUri\nsubscribeRealtimeOutput=$subscribeRealtimeOutput\nkey=$authToken';
  }

  /// Sets options for MojoPerceptionAPI, to change the list of emotions calculated and
  /// manages subscription to realtime output
  ///
  /// options["emotions"] is a list of the emotions to be calculated by the API
  /// options["subscribeRealtimeOutput"] is a boolean. If true, it activates the callbacks
  ///
  /// See: * [attentionCallBack]
  void setOptions(Map<String, dynamic> options) {
    try {
      if (options['emotions'] != null) {
        emotions = options['emotions'];
      }
      if (options['subscribeRealtimeOutput'] != null) {
        subscribeRealtimeOutput = options['subscribeRealtimeOutput'];
      }
    } catch (e) {
      logger.warning('Could not setOptions $options');
    }
  }

  /// Loads tflite model for landmarks detection from assets in [facemeshInterpreter]
  Future<bool> initInterpreters() async {
    try {
      // face detection
      String faceDetectionModel =
          "packages/mojo_perception/assets/face_detection_short_range.tflite";
      ByteData faceDetectionRawAssetFile =
          await rootBundle.load(faceDetectionModel);

      Uint8List faceDetectionRawBytes =
          faceDetectionRawAssetFile.buffer.asUint8List();

      try {
        faceDetectionInterpreter =
            Interpreter.fromBuffer(faceDetectionRawBytes);
      } catch (e) {
        onErrorCallback(e);
        return false;
      }
      faceDetectionInputShape =
          faceDetectionInterpreter.getInputTensor(0).shape;
      final faceDetectionOutputTensors =
          faceDetectionInterpreter.getOutputTensors();

      faceDetectionOutputTensors.forEach((tensor) {
        faceDetectionOutputsShapes.add(tensor.shape);
      });

      // facemesh
      final interpreterOptions = InterpreterOptions();
      String facemeshModel =
          "packages/mojo_perception/assets/face_landmark_with_attention.tflite";
      ByteData facemeshRawAssetFile = await rootBundle.load(facemeshModel);

      Uint8List facemeshRawBytes = facemeshRawAssetFile.buffer.asUint8List();

      try {
        facemeshInterpreter = Interpreter.fromBuffer(facemeshRawBytes,
            options: interpreterOptions);
      } catch (e) {
        onErrorCallback(e);
        return false;
      }
      facemeshInputShape = facemeshInterpreter.getInputTensor(0).shape;
      final facemeshOutputTensors = facemeshInterpreter.getOutputTensors();

      facemeshOutputTensors.forEach((tensor) {
        facemeshOutputsShapes.add(tensor.shape);
      });
      return true;
    } on Exception catch (e) {
      onErrorCallback(e);
      return false;
    }
  }

  /// Handles message coming on "calculation" event form socketio
  /// and dispatch to appropriate emotions callbacks.
  void handleCalculationMessage(Map<String, dynamic> msg) {
    try {
      if (msg['attention'] != null) {
        attentionCallback(msg['attention']);
      }
      if (msg['surprise'] != null) {
        surpriseCallback(msg['surprise']);
      }
      if (msg['amusement'] != null) {
        amusementCallback(msg['amusement']);
      }
      if (msg['confusion'] != null) {
        confusionCallback(msg['confusion']);
      }
      if (msg['engagement'] != null) {
        engagementCallback(msg['engagement']);
      }
      if (msg['interaction'] != null) {
        interactionCallback(msg['interaction']);
      }
    } on Exception catch (e) {
      onErrorCallback(e);
    }
  }

  /// Called at each new [cameraImage] from camera image stream
  ///
  /// Calls [facemeshInference] to get anonymized face landmarks predictions to send to the API.
  Future<void> handleCameraImage(CameraImage cameraImage) async {
    var detection = await faceDetectionInference(cameraImage: cameraImage);
    if (detection == null) {
      return;
    }
    if (!detection.containsKey('bbox') || detection['bbox'] == null) {
      await noFaceDetectedCallback();
      return;
    }
    Rect detectedFace = detection["bbox"];
    await faceDetectedCallback(detectedFace);

    img.Image? image = ImageConverter.convertCameraImage(cameraImage);
    if (Platform.isAndroid) {
      image = img.copyRotate(image!, -90);
      image = img.flipHorizontal(image);
    }

    double xMargin = detectedFace.width * 0.25 / 2;
    double yMargin = detectedFace.height * 0.25 / 2;
    img.Image cropped = img.copyCrop(
        image!,
        (detectedFace.topLeft.dx - xMargin).round(),
        (detectedFace.topLeft.dy - yMargin).round(),
        (detectedFace.width + xMargin).round(),
        (detectedFace.height + yMargin).round());

    var result = await facemeshInference(cameraImage: cropped);

    if (result != null) {
      emitFacemesh(result["facemesh"]);
    }
  }

  /// Initializes [_isolateUtils] and [facemeshInterpreter]
  /// Gets access to the camera, and starts imageStream.
  /// Connects to socketIO.
  Future<CameraController?> startCameraAndConnectAPI() async {
    _predictingFaceDetection = false;
    _predictingFacemesh = false;
    firstEmitDone = false;

    _isolateUtils = IsolateUtils();
    await _isolateUtils.initIsolate();
    bool initInterpretersDone = await initInterpreters();
    if (!initInterpretersDone) {
      return null;
    }
    var cameraDirection = CameraLensDirection.front;
    List<CameraDescription> cameras = await availableCameras();
    var cameraDescription = cameras.firstWhere(
      (CameraDescription camera) => camera.lensDirection == cameraDirection,
    );
    cameraController = CameraController(
      cameraDescription,
      ResolutionPreset.medium,
      enableAudio: false,
    );
    await cameraController!.initialize();

    await cameraController!.startImageStream(
      (CameraImage cameraImage) async {
        await handleCameraImage(cameraImage);
      },
    );
    apiSocket = io.io(
        socketIoUri,
        io.OptionBuilder()
            .setTransports(['websocket'])
            .disableAutoConnect()
            .setAuth({'token': authToken})
            .build());

    // callback on messages
    if (subscribeRealtimeOutput) {
      apiSocket.on('calculation', (msg) {
        handleCalculationMessage(msg);
      });
    }

    // Handler if error
    apiSocket.on('error', (msg) async {
      onErrorCallback(msg);
      await stopFacialExpressionRecognitionAPI();
    });

    apiSocket.onConnect((_) {
      logger.info('Connected to ');
    });
    apiSocket.onConnectError((data) => onErrorCallback(data));
    apiSocket.connect();
    return cameraController;
  }

  /// Computes box limit of detected face for [cameraImage] using [_isolateUtils]
  ///
  /// If already [_predictingFaceDetection], returns null
  Future<Map<String, dynamic>?> faceDetectionInference(
      {required CameraImage cameraImage}) async {
    if (_predictingFaceDetection) {
      return null;
    }
    _predictingFaceDetection = true;
    final responsePort = ReceivePort();

    _isolateUtils.sendMessage(
      handler: runFaceDetection,
      params: {
        'cameraImage': cameraImage,
        'detectorAddress': faceDetectionInterpreter.address,
        'inputShape': faceDetectionInputShape,
        'outputsShapes': faceDetectionOutputsShapes
      },
      sendPort: _isolateUtils.sendPort,
      responsePort: responsePort,
    );

    Map<String, dynamic>? inferenceResults = await responsePort.first;
    faceDetectionFrameRate = inferenceResults!["frameRate"];
    responsePort.close();
    _predictingFaceDetection = false;
    return inferenceResults;
  }

  /// Computes anonymized facemesh for [cameraImage] using [_isolateUtils]
  ///
  /// If already [_predictingFacemesh], returns null
  Future<Map<String, dynamic>?> facemeshInference(
      {required img.Image cameraImage}) async {
    if (_predictingFacemesh) {
      return null;
    }

    _predictingFacemesh = true;

    final responsePort = ReceivePort();

    _isolateUtils.sendMessage(
      handler: runFaceMesh,
      params: {
        'cameraImage': cameraImage,
        'detectorAddress': facemeshInterpreter.address,
        'inputShape': facemeshInputShape,
        'outputsShapes': facemeshOutputsShapes
      },
      sendPort: _isolateUtils.sendPort,
      responsePort: responsePort,
    );

    Map<String, dynamic>? inferenceResults = await responsePort.first;
    responsePort.close();

    _predictingFacemesh = false;
    return inferenceResults;
  }

  /// Sends the [facemesh] to the streaming SocketIO server
  ///
  /// On first emit, sets [sending] and [firstEmitDone] to true
  /// and calls [firstEmitDoneCallback]
  void emitFacemesh(List<List<double>>? facemesh) {
    try {
      if (facemesh == null) {
        return;
      }
      apiSocket.emit('facemesh', {
        'facemesh': facemesh,
        'timestamp': DateTime.now().toIso8601String(),
        'output': emotions,
      });
      if (!firstEmitDone) {
        firstEmitDone = true;
        sending = true;
        firstEmitDoneCallback();
      }
    } catch (e) {
      onErrorCallback(e);
    }
  }

  /// Stops sending to the API, stops camera imageStream,
  /// disconnects from the stream and dispose [_isolateUtils]
  Future<void> stopFacialExpressionRecognitionAPI() async {
    try {
      if (firstEmitDone && sending == false) {
        return;
      }
      sending = false;

      /// disconnect from API
      apiSocket.disconnect();
      onStopCallback();
      if (cameraController!.value.isStreamingImages) {
        await cameraController?.stopImageStream();
      }
      cameraController?.dispose();
      cameraController = null;
      _isolateUtils.dispose();
    } catch (e) {
      onErrorCallback(e);
    }
  }
}
