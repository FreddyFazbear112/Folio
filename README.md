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
- Reader profile editing, persistent local photo picker, and cloud-synced name/bio
- Firebase Authentication integration with Google Sign-In
- Firestore-backed community posts, book reviews, comments, and reader profiles
- GitHub Actions simulator build artifact
- Optional signed device IPA export when Apple signing secrets are configured

## Open in Xcode

Open `Folio.xcodeproj`, let Swift Package Manager resolve Firebase and Google Sign-In, then select an iPhone simulator and run.

## Firebase and Google setup

Google authentication and shared community data require a Firebase project you control.

1. Create a project in the [Firebase Console](https://console.firebase.google.com/).
2. Add an iOS app with bundle identifier `com.folio.app`.
3. Enable **Google** under Authentication → Sign-in method.
4. Create a Cloud Firestore database and enable Firebase Storage.
5. Download `GoogleService-Info.plist` and add it to the `Folio` app target in Xcode (the app checks for this file at launch).
6. In the Xcode target's **Info → URL Types**, add the value of `REVERSED_CLIENT_ID` from that plist as a URL scheme. This is required for Google Sign-In to return to Folio.
7. Publish the repository's `firestore.rules` file to your Firebase project's Firestore Rules tab and `storage.rules` to Storage Rules. You can deploy both with `firebase deploy --only firestore:rules,storage` after installing and signing into the Firebase CLI.

Do not commit private credentials or service-account keys. The Firebase client plist contains app identifiers and client configuration, not an administrative service-account key; keep your Firebase security rules restrictive.

Without Firebase configuration, the local bookshelf and sample reading-room content still work, but Google sign-in, publishing, and cloud comments remain unavailable.

## Current implementation notes

- The initial social feed contains sample posts so the screen has life before a Firebase project is connected. New posts and comments use Firestore after sign-in.
- ISBN lookup also fetches Open Library cover art when a matching edition has a cover; books without cover art use Folio's original typographic shelf design.
- Profile photos are resized, stored locally, and uploaded to Firebase Storage when signed in; reader name and bio sync to Firestore.
- ISBN lookup depends on network access to Open Library.
- Google Sign-In needs the Firebase plist and reversed client URL scheme described above.

## Building an IPA

Every push builds an unsigned iOS Simulator artifact. To also export an installable, App Store Connect-signed IPA, add these repository Actions secrets under Settings → Secrets and variables → Actions:

- `IOS_CERTIFICATE_BASE64`: base64-encoded Apple Distribution `.p12` certificate
- `IOS_CERTIFICATE_PASSWORD`: password used when exporting that `.p12`
- `IOS_PROVISIONING_PROFILE_BASE64`: base64-encoded App Store provisioning profile for `com.folio.app`
- `IOS_TEAM_ID`: your 10-character Apple Developer Team ID

The workflow imports the signing assets on a temporary macOS keychain, archives the app, and uploads `Folio-iOS-IPA` as a workflow artifact. Without those secrets, the IPA job safely skips while the simulator build continues. Never commit signing certificates, provisioning profiles, passwords, or Firebase service-account credentials to the repository.
