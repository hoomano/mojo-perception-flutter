## 1.0.4

- Calculate the frame rate of Face Detection

## 1.0.3

- Fix defaultCallBacks by introducing one for callbacks taking arguments and one for callback with no argument.

- Add try catch on initInterpreter when loading from buffer to catch errors on specific missing files

- Add a condition to check if cameraController is streaming images before trying to stop it.


## 1.0.2

Made it safer to restart API after stop by reseting boolean variables.
Provide new function "noFaceDetected" called when no face is detected on a camera frame.

## 1.0.1

Fix link to demo_image in README.md

## 1.0.0

Init version Mojo Perception Flutter API