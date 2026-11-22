import SwiftUI
import PhotosUI

struct ProfileView: View {
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
                                        Image(systemName: "person.crop.circle.fill")
                                            .resizable().scaledToFit().foregroundStyle(Color(red: 0.55, green: 0.52, blue: 0.44))
                                    }
                                }
                                .frame(width: 104, height: 104).clipShape(Circle())
                            }
                            Text(name).font(.system(size: 27, design: .serif))
                            Text("@your.pages").font(.system(size: 11)).tracking(1.2).foregroundStyle(.secondary)
                        }
                        .padding(.top, 28)

                        VStack(alignment: .leading, spacing: 14) {
                            Text("A LITTLE ABOUT YOU").font(.system(size: 10, weight: .semibold)).tracking(1.6)
                            TextField("Your name", text: $name)
                                .textFieldStyle(.roundedBorder)
                            TextField("A line or two about your reading life", text: $bio, axis: .vertical)
                                .lineLimit(2...4).textFieldStyle(.roundedBorder)
                        }
                        .padding(18).background(.white.opacity(0.58)).clipShape(RoundedRectangle(cornerRadius: 5))
                        VStack(alignment: .leading, spacing: 8) {
                            Text("ACCOUNT").font(.system(size: 10, weight: .semibold)).tracking(1.6)
                            Label("Sign-in providers will appear here when connected", systemImage: "lock.shield")
                                .font(.system(size: 12, design: .serif)).foregroundStyle(.secondary)
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
