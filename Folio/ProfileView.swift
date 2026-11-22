import SwiftUI
import PhotosUI

struct ProfileView: View {
    @EnvironmentObject private var auth: AuthManager
    @AppStorage("folio.readerName") private var name = "A fellow reader"
    @AppStorage("folio.readerBio") private var bio = "Collecting stories, one page at a time."
    @State private var photo: PhotosPickerItem?
    @State private var isSaving = false
    @State private var profileMessage: String?
    @State private var avatarNeedsUpload = false
    @AppStorage("folio.avatarURL") private var avatarURLString = ""
    @AppStorage("folio.avatarBase64") private var avatarBase64 = ""

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.96, green: 0.94, blue: 0.89).ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 22) {
                        VStack(spacing: 12) {
                            PhotosPicker(selection: $photo, matching: .images) {
                                Group {
                                    if let data = Data(base64Encoded: avatarBase64), let image = UIImage(data: data) {
                                        Image(uiImage: image).resizable().scaledToFill()
                                    } else if let url = auth.user?.photoURL ?? URL(string: avatarURLString) {
                                        AsyncImage(url: url) { image in image.resizable().scaledToFill() } placeholder: {
                                            Image(systemName: "person.crop.circle.fill").resizable().scaledToFit()
                                        }
                                    } else {
                                        Image(systemName: "person.crop.circle.fill").resizable().scaledToFit()
                                            .foregroundStyle(Color(red: 0.55, green: 0.52, blue: 0.44))
                                    }
                                }
                                .frame(width: 104, height: 104).clipShape(Circle())
                            }
                            Text(name).font(.system(size: 27, design: .serif))
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
                            Button {
                                Task { await saveProfile() }
                            } label: {
                                HStack {
                                    if isSaving { ProgressView() }
                                    Text("Save profile")
                                }
                                .frame(maxWidth: .infinity).padding(.vertical, 12)
                                .background(Color(red: 0.18, green: 0.20, blue: 0.17))
                                .foregroundStyle(Color(red: 0.96, green: 0.94, blue: 0.89))
                                .clipShape(Capsule())
                            }
                            .disabled(isSaving)
                            if let profileMessage { Text(profileMessage).font(.system(size: 11)).foregroundStyle(.secondary) }
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
            .task(id: auth.user?.uid) { await loadProfile() }
            .onChange(of: photo) { _, item in
                Task { if let data = try? await item?.loadTransferable(type: Data.self) { avatarBase64 = data.base64EncodedString(); avatarNeedsUpload = true } }
            }
        }
    }

    @MainActor
    private func loadProfile() async {
        guard let user = auth.user else { return }
        do {
            if let profile = try await CommunityService().loadProfile(userID: user.uid) {
                if !profile.name.isEmpty { name = profile.name }
                bio = profile.bio
                if let url = profile.avatarURL, !url.isEmpty { avatarURLString = url }
            }
        } catch {
            profileMessage = "Your profile is saved on this device. Cloud sync is unavailable."
        }
    }

    @MainActor
    private func saveProfile() async {
        guard let user = auth.user else {
            profileMessage = "Saved on this device. Sign in to sync your profile."
            return
        }
        isSaving = true
        defer { isSaving = false }
        do {
            var cloudAvatarURL: String? = avatarURLString.isEmpty ? nil : avatarURLString
            if avatarNeedsUpload, let data = Data(base64Encoded: avatarBase64) {
                let url = try await CommunityService().uploadAvatar(data, userID: user.uid)
                cloudAvatarURL = url.absoluteString
                avatarURLString = url.absoluteString
                avatarNeedsUpload = false
            }
            try await CommunityService().saveProfile(name: name, bio: bio, avatarURL: cloudAvatarURL, userID: user.uid)
            profileMessage = "Your reader profile is saved."
        } catch {
            profileMessage = "Couldn't sync your profile. Please try again."
        }
    }
}
