import SwiftUI
import FirebaseCore
import FirebaseAuth
import GoogleSignIn
import UIKit

@MainActor
final class AuthManager: ObservableObject {
    @Published private(set) var user: FirebaseAuth.User?
    @Published var errorMessage: String?
    @Published private(set) var isConfigured = false
    private var listener: AuthStateDidChangeListenerHandle?

    init() {
        if Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil {
            FirebaseApp.configure()
            isConfigured = true
            user = Auth.auth().currentUser
            listener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
                Task { @MainActor in self?.user = user }
            }
        }
    }

    func signInWithGoogle() {
        guard isConfigured else {
            errorMessage = "Google sign-in needs your Firebase GoogleService-Info.plist. Add it to the Folio app target, then try again."
            return
        }
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            errorMessage = "The Firebase client ID is missing. Check your GoogleService-Info.plist."
            return
        }
        guard let presenter = Self.topViewController() else {
            errorMessage = "Folio couldn't open the Google sign-in window. Please try again."
            return
        }
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.signIn(withPresenting: presenter) { [weak self] result, error in
            if let error {
                Task { @MainActor in self?.errorMessage = error.localizedDescription }
                return
            }
            guard let user = result?.user,
                  let idToken = user.idToken?.tokenString else {
                Task { @MainActor in self?.errorMessage = "Google didn't return an ID token." }
                return
            }
            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: user.accessToken.tokenString
            )
            Auth.auth().signIn(with: credential) { authResult, error in
                Task { @MainActor in
                    if let error { self?.errorMessage = error.localizedDescription }
                    else { self?.user = authResult?.user }
                }
            }
        }
    }

    func signOut() {
        do {
            try Auth.auth().signOut()
            GIDSignIn.sharedInstance.signOut()
            user = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private static func topViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let root = scenes.flatMap(\.windows).first(where: \.isKeyWindow)?.rootViewController
        var top = root
        while let presented = top?.presentedViewController { top = presented }
        return top
    }
}
