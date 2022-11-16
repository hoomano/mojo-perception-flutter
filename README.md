# Mojo Perception Flutter API

Facial Expression Recognition for your Flutter application in a few lines of code.

Mojo Facial Expression Recognition provides :

❤️ 3 emotions :

- amusement
- confusion
- surprise


🎉 3 social cues :

- attention
- engagement
- interaction status

> 💡 Open Source API
> ⚡️ Real-time
> 🔐 private-by-design

No images are never sent to the the cloud.

Handle your user's emotional reactions to build on top of your amazing app

![demo_image.jpg](https://docs.mojo.ai/images/demo_image.jpeg)

## Requirement

Get your [free trial API key](https://hoomano.com/free-facial-expression-recognition/).

## Installation

Add this line like this to your project's pubspec.yaml and run flutter pub get:
```
dependencies:
  mojo_perception: ^2.0.0
```


## (Important) Initial setup
 
### `IOS`:
#### Permissions
Add row to the ios/Runner/Info.plist with the key Privacy - Camera Usage Description and a usage description :
```
<key>NSCameraUsageDescription</key>
<string>Can I use the camera please?</string>
```

#### Model
In the pubspec.yaml add the following line:
```
assets:
    - packages/mojo_perception/assets/face_landmark_with_attention.tflite
    - packages/mojo_perception/assets/face_detection_short_range.tflite
```

Run
```
flutter pub get
```

#### Dynamic libraries
1. Download [TensorFlowLiteC.framework.zip](https://git.hoomano.com/hoomano/mojo-perception-flutter/-/blob/master/TensorFlowLiteC.framework.zip) (TensorFlowLiteC framework with Mediapipe special ops).

2. Unzip `TensorFlowLiteC.framework` in the pub-cache folder of tflite_flutter package:
[Pub-Cache folder location](https://dart.dev/tools/pub/cmd/pub-get#the-system-package-cache):

-  ~/.pub-cache/hosted/pub.dartlang.org/tflite_flutter-0.9.0/ios/ (Linux/ Mac)
- %LOCALAPPDATA%\Pub\Cache\hosted\pub.dartlang.org\tflite_flutter-0.9.0\ios\ (Windows)



### `ANDROID`:
#### Dynamic libraries
1. Download [jniLibs.zip](https://git.hoomano.com/hoomano/mojo-perception-flutter/-/blob/master/jniLibs.zip).

2. Extract in your project path : `android > app > src > main`

#### Model
In the pubspec.yaml add the following line:
```
assets:
    - packages/mojo_perception/assets/face_landmark_with_attention.tflite
    - packages/mojo_perception/assets/face_detection_short_range.tflite
```
Run
```
flutter pub get
```

### minSdkVersion
If you encounter an error concerning minSdkVersion:

- Go to `android > src > app > build.gradle`

- Find line `minSdkVersion flutter.minSdkVersion`

- Change `flutter.minSdkVersion` by 21


## Usage

Import it:
```
import 'package:mojo_perception/mojo_perception.dart';
``` 

Create an object MojoPerceptionAPI:

```
MojoPerceptionAPI mojoPerceptionApi = MojoPerceptionAPI(
      '<auth_token>',
      '<host>',
      '<port>',
      '<user_namespace>');
```

Please note that the user token 'auth_token' is different from the API Key.

🙏 We take a particular care with publishable user token for applications. See below for more info and best practices.


### Best Practices : One token per user
To make things safe and easy, we have a REST API ready to create user tokens on-the-fly.

When using the API for a web application, you should implement a backend function that will get a token for each user. We recommend to use tokens with expiration date.

To do so, you can use the REST API of Mojo Perception API.

Below, an example using `curl` :
In your terminal, replace `<YOUR_API_KEY_HERE>` by one of your API Keys and run :

```
curl -X PUT -i -H 'Authorization: <YOUR_API_KEY_HERE>' -d '{"datetime": "2022-01-01T00:00:00.000000","expiration":360}' -H 'Content-Type: application/json' https://api.mojo.ai/mojo_perception_api/user
```


This will give you something like this, and note that we have set expiration: 360, for a 60 x 60 seconds duration period :
```
HTTP/2 200 
server: nginx
date: Tue, 18 Jan 2022 16:53:54 GMT
content-type: application/json
content-length: 350

{"user_namespace": "a5fa97ded6584cb4a7ff3933aa66025c", "auth_token": "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpYXQiOjE2NDI1MjQ4MzQsInN1YiI6ImE1ZmE5N2RlLWQ2NTgtNGNiNC1hN2ZmLTM5MzliYTY2MDI1YyIsImV4cCI6MTY0MjUyNDg0NH0.7FuLJ6Hmozi2DbX9zooVxYvnp_f91H4vzodstDZbLzI", "host_name": "socket.mojo.ai", "port": "443"}
```


You can use the `auth_token` and given `host_name`,`port` and `user_namespace` to configure your API endpoint in the API, with the [setOptions() method](https://docs.mojo.ai/).

## Checkout the `Tutorials`

>💡   Have a look to the tutorials section


## Troubleshooting

>  If you face a "JsonWebTokenError", maybe that's because of the expiration.
You can try to increase the user token duration to match your need. Default value of 360 seconds might be too short.

## mojo_perception_flutter Documentation

- [mojo_perception_flutter Docs & API References](https://docs.mojo.ai/)
- [mojo_perception_flutter Tutorials](https://docs.mojo.ai/facial-expression-recognition/tutorials/create-flutter-app-with-facial-expression-recognition/)

## Acknowledgement
Special thanks to [JaeHeee](https://github.com/JaeHeee) for [this project](https://github.com/JaeHeee/FlutterWithMediaPipe) that inspired us implementing mediapipe part.
