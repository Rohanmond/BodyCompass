# Commands

Run commands from repo root unless noted.

## Swift Core Check

```sh
cd ios/BodyCompass
swift run BodyCompassCoreCheck
```

## Backend Tests

```sh
cd server
npm test
```

## Backend Dev Server

```sh
cd server
cp .env.example .env
npm run dev
```

## Xcode Project List

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild -list -project ios/BodyCompass/BodyCompass.xcodeproj
```

## Xcode Simulator Build

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild \
  -project ios/BodyCompass/BodyCompass.xcodeproj \
  -scheme BodyCompass \
  -configuration Debug \
  -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath ios/BodyCompass/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
```

## Local API Smoke Tests

```sh
curl http://127.0.0.1:8080/health
```

```sh
curl -X POST http://127.0.0.1:8080/api/goal/projection \
  -H 'content-type: application/json' \
  -d '{"weightKg":80,"bodyFatPercentage":22,"targetBodyFatPercentage":12,"adherenceScore":0.8}'
```
