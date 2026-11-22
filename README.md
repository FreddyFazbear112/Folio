# Folio

A warm, tactile reading companion for iPhone. Folio is built with SwiftUI and native Apple frameworks, with Firebase-backed account and community foundations.

## Included in the current build

- Animated welcome experience and three-tab navigation
- Personal bookshelf with To Read, Reading, and Read shelves
- Local library persistence between launches
- Add books manually or scan ISBN barcodes with VisionKit
- Book metadata lookup through the Open Library search API
- Interactive SceneKit 3D book preview
- Tactile system sound feedback
- Reader profile editing and photo picker
- Firebase Authentication integration with Google Sign-In
- Firestore-backed community posts and comments
- GitHub Actions simulator build

## Open in Xcode

Open `Folio.xcodeproj`, let Swift Package Manager resolve Firebase and Google Sign-In, then select an iPhone simulator and run.

## Firebase and Google setup

Google authentication and shared community data require a Firebase project you control.

1. Create a project in the [Firebase Console](https://console.firebase.google.com/).
2. Add an iOS app with bundle identifier `com.folio.app`.
3. Enable **Google** under Authentication → Sign-in method.
4. Create a Cloud Firestore database.
5. Download `GoogleService-Info.plist` and add it to the `Folio` app target in Xcode (the app checks for this file at launch).
6. In the Xcode target's **Info → URL Types**, add the value of `REVERSED_CLIENT_ID` from that plist as a URL scheme. This is required for Google Sign-In to return to Folio.
7. Publish the repository's `firestore.rules` file to your Firebase project's Firestore Rules tab.

Do not commit private credentials or service-account keys. The Firebase client plist contains app identifiers and client configuration, not an administrative service-account key; keep your Firebase security rules restrictive.

Without Firebase configuration, the local bookshelf and sample reading-room content still work, but Google sign-in, publishing, and cloud comments remain unavailable.

## Current implementation notes

- The initial social feed contains sample posts so the screen has life before a Firebase project is connected. New posts and comments use Firestore after sign-in.
- Book covers are represented as original 3D book objects and stylized bookshelf spines; real cover-art fetching is a future enhancement.
- Profile photo selection is currently local to the active app session.
- ISBN lookup depends on network access to Open Library.
- Google Sign-In needs the Firebase plist and reversed client URL scheme described above.

## Building an IPA

The GitHub Actions workflow currently builds the app for the iOS Simulator without signing. An installable device IPA requires an Apple Developer Team, distribution certificate, provisioning profile, and signing configuration. Those credentials must be supplied by the app owner through protected GitHub Actions secrets; they should never be committed to this repository.
