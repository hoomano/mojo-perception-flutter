import 'package:image/image.dart' as image_lib;
import 'package:logging/logging.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:tflite_flutter_helper/tflite_flutter_helper.dart';

/// FaceMeshService runs predictions for anonymized landmarks
class FaceMeshService {
  final Logger logger = Logger("FaceMeshService");

  /// Tflite [Interpreter] to evaluate tflite model
  Interpreter interpreter;

  /// Shape of model's input
  late List<int> inputShape;

  /// Shapes of model's outputs
  late List<List<int>> outputsShapes;

  /// Creates a FaceMeshService from [interpreter] containing tflite model
  /// to generate anonymized face landmarks.
  ///
  /// Sets [inputShape], [outputShapes] and [outputTypes] from [interpreter]
  FaceMeshService(this.interpreter, this.inputShape, this.outputsShapes);

  /// Process given [inputImage] to prepare for feeding the model
  TensorImage getProcessedImage(TensorImage inputImage) {
    final imageProcessor = ImageProcessorBuilder()
        .add(ResizeOp(inputShape[1], inputShape[2], ResizeMethod.BILINEAR))
        .add(NormalizeOp(0, 255))
        .build();

    inputImage = imageProcessor.process(inputImage);
    return inputImage;
  }

  /// Predicts anonymized face landmarks from [image]
  Map<String, dynamic>? predict(image_lib.Image image) {
    final tensorImage = TensorImage(TfLiteType.float32);
    tensorImage.loadImage(image);

    final inputImage = getProcessedImage(tensorImage);

    // from https://drive.google.com/file/d/1tV7EJb3XgMS7FwOErTgLU1ZocYyNmwlf/preview
    TensorBuffer outputLandmarks = TensorBufferFloat(outputsShapes[0]);
    TensorBuffer outputLips = TensorBufferFloat(outputsShapes[1]);
    TensorBuffer outputLeftEyeBrow = TensorBufferFloat(outputsShapes[2]);
    TensorBuffer outputRightEyeBrow = TensorBufferFloat(outputsShapes[3]);
    TensorBuffer outputLeftIris = TensorBufferFloat(outputsShapes[4]);
    TensorBuffer outputRightIris = TensorBufferFloat(outputsShapes[5]);
    TensorBuffer outputScores = TensorBufferFloat(outputsShapes[6]);

    final inputs = <Object>[inputImage.buffer];

    final outputs = <int, Object>{
      0: outputLandmarks.buffer,
      1: outputLips.buffer,
      2: outputLeftEyeBrow.buffer,
      3: outputRightEyeBrow.buffer,
      4: outputLeftIris.buffer,
      5: outputRightIris.buffer,
      6: outputScores.buffer,
    };

    interpreter.runForMultipleInputs(inputs, outputs);

    final score = outputScores.getDoubleList()[0];
    if (score < 0) {
      return null;
    }

    final landmarkPoints = outputLandmarks.getDoubleList().reshape([468, 3]);
    var leftIrisPoints = outputLeftIris.getDoubleList().reshape([5, 2]);
    var rightIrisPoints = outputRightIris.getDoubleList().reshape([5, 2]);

    final landmarkResults = <List<double>>[];
    for (var point in landmarkPoints) {
      landmarkResults.add([point[0], point[1], point[2]]);
    }
    for (var point in leftIrisPoints) {
      landmarkResults.add([point[0], point[1], 0]);
    }
    for (var point in rightIrisPoints) {
      landmarkResults.add([point[0], point[1], 0]);
    }

    return {'facemesh': landmarkResults};
  }
}

/// Function called by [Isolate] to process [image]
/// and predict anonymized face landmarks
Map<String, dynamic>? runFaceMesh(Map<String, dynamic> params) {
  final faceMesh = FaceMeshService(
      Interpreter.fromAddress(params['detectorAddress']),
      params["inputShape"],
      params["outputsShapes"]);
  final result = faceMesh.predict(params['cameraImage']!);

  return result;
}
