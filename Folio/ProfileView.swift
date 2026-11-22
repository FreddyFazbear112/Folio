import SwiftUI
import PhotosUI

struct ProfileView: View {
    @EnvironmentObject private var auth: AuthManager
    @AppStorage("folio.readerName") private var name = "A fellow reader"
    @AppStorage("folio.readerBio") private var bio = "Collecting stories, one page at a time."
    @State private var photo: PhotosPickerItem?
    @State private var avatarData: Data?

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.96, green: 0.94, blue: 0.89).ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 22) {
                        VStack(spacing: 12) {
                            PhotosPicker(selection: $photo, matching: .images) {
                                Group {
                                    if let avatarData, let image = UIImage(data: avatarData) {
                                        Image(uiImage: image).resizable().scaledToFill()
                                    } else {
                                        Image(systemName: "person.crop.circle.fill").resizable().scaledToFit()
                                            .foregroundStyle(Color(red: 0.55, green: 0.52, blue: 0.44))
                                    }
                                }
                                .frame(width: 104, height: 104).clipShape(Circle())
                            }
                            Text(auth.user?.displayName ?? name).font(.system(size: 27, design: .serif))
                            Text(auth.user?.email ?? "@your.pages").font(.system(size: 11)).tracking(1.2).foregroundStyle(.secondary)
                        }
                        .padding(.top, 28)

                        VStack(alignment: .leading, spacing: 14) {
                            Text("A LITTLE ABOUT YOU").font(.system(size: 10, weight: .semibold)).tracking(1.6)
                            TextField("Your name", text: $name).textFieldStyle(.roundedBorder)
                            TextField("A line or two about your reading life", text: $bio, axis: .vertical)
                                .lineLimit(2...4).textFieldStyle(.roundedBorder)
                        }
                        .padding(18).background(.white.opacity(0.58)).clipShape(RoundedRectangle(cornerRadius: 5))

                        VStack(alignment: .leading, spacing: 12) {
                            Text("YOUR ACCOUNT").font(.system(size: 10, weight: .semibold)).tracking(1.6)
                            if let user = auth.user {
                                Label(user.isEmailVerified ? "Account connected" : "Google account connected", systemImage: "checkmark.seal")
                                    .font(.system(size: 13, design: .serif))
                                Button("Sign out", role: .destructive) { auth.signOut() }
                                    .font(.system(size: 13, weight: .medium))
                            } else {
                                Button(action: auth.signInWithGoogle) {
                                    HStack {
                                        Image(systemName: "g.circle.fill")
                                        Text("Continue with Google")
                                    }
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(Color(red: 0.96, green: 0.94, blue: 0.89))
                                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                                    .background(Color(red: 0.18, green: 0.20, blue: 0.17))
                                    .clipShape(Capsule())
                                }
                                Text(auth.isConfigured ? "Sign in to keep your reading identity with you." : "Connect Firebase to enable Google sign-in.")
                                    .font(.system(size: 11, design: .serif)).foregroundStyle(.secondary)
                            }
                            if let error = auth.errorMessage {
                                Text(error).font(.system(size: 11)).foregroundStyle(.red)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(22)
                }
            }
            .navigationTitle("Your profile")
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: photo) { _, item in
                Task { avatarData = try? await item?.loadTransferable(type: Data.self) }
            }
        }
    }
}
