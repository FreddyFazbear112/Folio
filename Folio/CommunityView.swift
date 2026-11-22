import SwiftUI

struct CommunityPost: Identifiable {
    let id = UUID()
    let name: String
    let handle: String
    let title: String
    let book: String
    let body: String
    let likes: Int
    let mark: String
}

struct CommunityView: View {
    @State private var liked: Set<UUID> = []
    @State private var draft = ""
    @State private var showingComposer = false
    @State private var posts = [
        CommunityPost(name: "Mara Ellis", handle: "@mara.reads", title: "A book that stayed with me", book: "Piranesi · Susanna Clarke", body: "Finished this in two quiet evenings. It feels like finding a note from another world tucked inside a familiar book.", likes: 28, mark: "M"),
        CommunityPost(name: "Theo Park", handle: "@theopark", title: "The Sunday reading club", book: "The Secret History · Donna Tartt", body: "Do you think the atmosphere is the real narrator here? I keep thinking about the first chapter.", likes: 16, mark: "T"),
        CommunityPost(name: "June Rivera", handle: "@junepages", title: "A small recommendation", book: "Small Things Like These · Claire Keegan", body: "For anyone who wants a short book that somehow makes the whole room feel different.", likes: 41, mark: "J")
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.96, green: 0.94, blue: 0.89).ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("THE READING ROOM")
                                .font(.system(size: 10, weight: .semibold)).tracking(2.2)
                            Text("Stories are better
when shared.")
                                .font(.system(size: 32, design: .serif))
                        }
                        HStack {
                            Text("A thoughtful corner for readers.")
                                .font(.system(size: 13, design: .serif).italic())
                            Spacer()
                            Button { showingComposer = true } label: {
                                Image(systemName: "square.and.pencil")
                                    .padding(12).background(Color(red: 0.18, green: 0.20, blue: 0.17))
                                    .foregroundStyle(.white).clipShape(Circle())
                            }
                        }
                        ForEach(posts) { post in
                            postCard(post)
                        }
                    }
                    .foregroundStyle(Color(red: 0.18, green: 0.20, blue: 0.17))
                    .padding(22)
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showingComposer) {
                NavigationStack {
                    Form {
                        Section("YOUR THOUGHTS") {
                            TextEditor(text: $draft).frame(minHeight: 140)
                        }
                        Button("Share with the reading room") {
                            let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
                            if !text.isEmpty {
                                posts.insert(CommunityPost(name: "You", handle: "@your.pages", title: "A note from my reading journal", book: "Currently reading", body: text, likes: 0, mark: "Y"), at: 0)
                                draft = ""
                                showingComposer = false
                            }
                        }
                    }
                    .navigationTitle("Write a note")
                    .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Close") { showingComposer = false } } }
                }
            }
        }
    }

    private func postCard(_ post: CommunityPost) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(spacing: 10) {
                Text(post.mark).font(.system(size: 15, design: .serif))
                    .frame(width: 34, height: 34).background(Color(red: 0.87, green: 0.84, blue: 0.77)).clipShape(Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(post.name).font(.system(size: 12, weight: .semibold))
                    Text(post.handle).font(.system(size: 10)).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "ellipsis").foregroundStyle(.secondary)
            }
            Text(post.title).font(.system(size: 20, design: .serif))
            Text(post.book.uppercased()).font(.system(size: 9, weight: .medium)).tracking(1.2).foregroundStyle(.secondary)
            Text(post.body).font(.system(size: 14, design: .serif)).lineSpacing(4)
            Divider().overlay(Color.black.opacity(0.08))
            HStack {
                Button {
                    if liked.contains(post.id) { liked.remove(post.id) } else { liked.insert(post.id) }
                    SoundEffects.softTap()
                } label: {
                    Label("\(post.likes + (liked.contains(post.id) ? 1 : 0))", systemImage: liked.contains(post.id) ? "heart.fill" : "heart")
                }
                .tint(liked.contains(post.id) ? .red : .secondary)
                Spacer()
                Label("Discuss", systemImage: "bubble.right")
                    .foregroundStyle(.secondary)
            }
            .font(.system(size: 11, weight: .medium))
        }
        .padding(17)
        .background(Color.white.opacity(0.54))
        .clipShape(RoundedRectangle(cornerRadius: 5))
    }
}
