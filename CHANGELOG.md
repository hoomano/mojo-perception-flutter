## 2.0.0

- 2 new available social cues : "Engagement" and "Interaction".

* Engagement is the process by which participants establish, maintain and terminate their connection with the device. The notion of engagement is composed of 4 phases : “engaging”, “engaged”, “disengaging”, “idle”.

* Interaction status is an estimation of the state of a user within the course of an interaction. The state is derived from the transitions of the engagement. Interaction status can be 5 differents stages :

idle: The user is visible, not engaged and attention low.

possible: The user is changing to an engaging status, this is a transitional status.

ready: The user is engaged, and attention is high.

in_short_interruption: The user used to be engaged, changing to disengaging for less than 3 seconds. 

in_long_interruption: The user used to be in short interruption status, for a period between 3 to 8 seconds.

- We removed "pitching" and "yawing" social cues estimation.

## 1.0.5

- Fix the problem of converting Camera images in YUV420 format to Image in RGB format on android

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