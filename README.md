# Folio

A warm, tactile reading companion for iPhone. Folio is built with SwiftUI and native Apple frameworks, with Firebase-backed account and community foundations.

## Included in the current build

- Animated welcome experience and three-tab navigation
- Personal bookshelf with To Read, Reading, and Read shelves, starting empty for a new reader
- Local library persistence between launches
- Add books manually or scan ISBN barcodes with VisionKit
- Book metadata lookup through the Open Library search API
- Interactive SceneKit 3D book preview
- Tactile system sound feedback
- Reader profile editing, persistent local photo picker, and cloud-synced name/bio
- Firebase Authentication integration with Google Sign-In
- Firestore-backed community posts, book reviews, comments, and reader profiles
- Guided first-book walkthrough with ISBN scan, catalogue lookup, or manual entry
- Private per-book reading journal with page progress and saved notes
- One unsigned physical-iPhone IPA artifact on every push to `main` (for re-signing with SideStore/Sideloadly)

## Open in Xcode

Open `Folio.xcodeproj`, let Swift Package Manager resolve Firebase and Google Sign-In, then select your connected iPhone and configure your Personal Team for signing.

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

Without Firebase configuration, the personal bookshelf works locally without an account. Google sign-in, publishing, and cloud comments remain unavailable until you configure Firebase.

## Current implementation notes

- The initial social feed contains sample posts so the screen has life before a Firebase project is connected. New posts and comments use Firestore after sign-in.
- ISBN lookup also fetches Open Library cover art when a matching edition has a cover; books without cover art use Folio's original typographic shelf design.
- Profile photos are resized, stored locally, and uploaded to Firebase Storage when signed in; reader name and bio sync to Firestore.
- ISBN lookup depends on network access to Open Library.
- Google Sign-In needs the Firebase plist and reversed client URL scheme described above.

## Building and sideloading Folio

Every push to `main` runs one iPhone-device build and uploads a single artifact named `Folio-iOS-Unsigned-IPA`. The workflow does not build or upload a simulator app and does not create an App Store distribution IPA.

1. Open the latest successful run under [GitHub Actions](https://github.com/FreddyFazbear112/Folio/actions).
2. Download `Folio-iOS-Unsigned-IPA` from the run's Artifacts section.
3. Import `Folio-iOS-Unsigned.ipa` into SideStore or Sideloadly and sign it with your own Apple Account.
4. Follow the signing app's instructions to install it on your iPhone.

The workflow artifact is an unsigned physical-device app package. It is **not directly installable** until SideStore, Sideloadly, or another compatible signing tool signs it for your device. A free Apple Account's Personal Team provisioning is temporary (typically seven days), so the app needs periodic refreshing/re-signing. Each tester should sign the app with their own Apple Account; do not share your personal signing credentials.

For a local build, open `Folio.xcodeproj` in Xcode, sign in with your Apple Account, select your iPhone as the run destination, choose your Personal Team under Signing & Capabilities, and run the app. This is often the simplest way to test on your own phone.

Never commit signing certificates, provisioning profiles, passwords, or Firebase service-account credentials to the repository.
