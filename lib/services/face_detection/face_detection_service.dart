import 'dart:io';
import 'dart:ui';

import 'package:image/image.dart' as image_lib;
import 'package:logging/logging.dart';
import 'package:mojo_perception/services/face_detection/anchors.dart';
import 'package:mojo_perception/services/face_detection/generate_anchors.dart';
import 'package:mojo_perception/services/face_detection/non_maximum_suppression.dart';
import 'package:mojo_perception/services/face_detection/options.dart';
import 'package:mojo_perception/services/face_detection/process.dart';
import 'package:mojo_perception/services/image_converter.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:tflite_flutter_helper/tflite_flutter_helper.dart';

/// FaceDetectionService runs predictions for face detection
class FaceDetectionService {
  final Logger logger = Logger("FaceDetectionService");

  /// Tflite [Interpreter] to evaluate tflite model
  Interpreter interpreter;

  /// Shape of model's input
  late List<int> inputShape;

  /// Shapes of model's outputs
  late List<List<int>> outputsShapes;

  /// Creates a FaceDetectionService from [interpreter] containing tflite model
  /// to detect face on image.
  ///
  /// Sets [inputShape], [outputShapes] and [outputTypes] from [interpreter]
  FaceDetectionService(this.interpreter, this.inputShape, this.outputsShapes) {
    final anchorOption = AnchorOption(
        inputSizeHeight: 128,
        inputSizeWidth: 128,
        minScale: 0.1484375,
        maxScale: 0.75,
        anchorOffsetX: 0.5,
        anchorOffsetY: 0.5,
        numLayers: 4,
        featureMapHeight: [],
        featureMapWidth: [],
        strides: [8, 16, 16, 16],
        aspectRatios: [1.0],
        reduceBoxesInLowestLayer: false,
        interpolatedScaleAspectRatio: 1.0,
        fixedAnchorSize: true);
    try {
      _anchors = generateAnchors(anchorOption);
    } catch (e) {
      logger.severe('Error while generating anchors: $e');
    }
  }

  /// Over which confidence threshold we consider there is a face detected
  final double threshold = 0.8;

  /// List of anchors
  late List<Anchor> _anchors;

  /// Image processor
  late ImageProcessor _imageProcessor;

  /// Process given [inputImage] to prepare for feeding the model
  TensorImage getProcessedImage(TensorImage inputImage) {
    _imageProcessor = ImageProcessorBuilder()
        .add(ResizeOp(inputShape[1], inputShape[2], ResizeMethod.BILINEAR))
        .add(NormalizeOp(127.5, 127.5))
        .build();

    inputImage = _imageProcessor.process(inputImage);
    return inputImage;
  }

  /// Predicts from [image] whether there is face on the image
  ///
  /// Returns the 1 face with highest confidence if its probability os over [threshold]
  Map<String, dynamic>? predict(image_lib.Image image) {
    final options = OptionsFace(
        numClasses: 1,
        numBoxes: 896,
        numCoords: 16,
        keypointCoordOffset: 4,
        ignoreClasses: [],
        scoreClippingThresh: 100.0,
        minScoreThresh: 0.75,
        numKeypoints: 6,
        numValuesPerKeypoint: 2,
        reverseOutputOrder: true,
        boxCoordOffset: 0,
        xScale: 128,
        yScale: 128,
        hScale: 128,
        wScale: 128);

    if (Platform.isAndroid) {
      image = image_lib.copyRotate(image, -90);
      image = image_lib.flipHorizontal(image);
    }
    final tensorImage = TensorImage(TfLiteType.float32);
    tensorImage.loadImage(image);
    final inputImage = getProcessedImage(tensorImage);

    TensorBuffer outputFaces = TensorBufferFloat(outputsShapes[0]);
    TensorBuffer outputScores = TensorBufferFloat(outputsShapes[1]);

    final inputs = <Object>[inputImage.buffer];

    final outputs = <int, Object>{
      0: outputFaces.buffer,
      1: outputScores.buffer,
    };

    interpreter.runForMultipleInputs(inputs, outputs);

    final rawBoxes = outputFaces.getDoubleList();
    final rawScores = outputScores.getDoubleList();
    var detections = process(
        options: options,
        rawScores: rawScores,
        rawBoxes: rawBoxes,
        anchors: _anchors);

    detections = nonMaximumSuppression(detections, threshold);
    if (detections.isEmpty) {
      return {};
    }

    final rectFaces = <Map<String, dynamic>>[];

    for (var detection in detections) {
      Rect? bbox;
      final score = detection.score;

      if (score > threshold) {
        bbox = Rect.fromLTRB(
          inputImage.width * detection.xMin,
          inputImage.height * detection.yMin,
          inputImage.width * detection.width,
          inputImage.height * detection.height,
        );

        bbox = _imageProcessor.inverseTransformRect(
            bbox, image.height, image.width);
      }
      rectFaces.add({'bbox': bbox, 'score': score});
    }
    rectFaces.sort((a, b) => b['score'].compareTo(a['score']));

    return rectFaces[0];
  }
}

/// Function called by [Isolate] to process [cameraImage]
/// and detect faces on the image
Map<String, dynamic>? runFaceDetection(Map<String, dynamic> params) {
  int startedTimeRunFaceDetection = DateTime.now().millisecond;
  final faceDetection = FaceDetectionService(
      Interpreter.fromAddress(params['detectorAddress']),
      params["inputShape"],
      params["outputsShapes"]);
  final image = ImageConverter.convertCameraImage(params['cameraImage'])!;
  final result = faceDetection.predict(image);
  int finishedTimeRunFaceDetection = DateTime.now().millisecond;
  result!["frameRate"] = 1000 /
      (finishedTimeRunFaceDetection -
          startedTimeRunFaceDetection); // Convert from ms to HZ

  return result;
}
