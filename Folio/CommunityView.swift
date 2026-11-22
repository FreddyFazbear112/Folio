import SwiftUI

struct CommunityPost: Identifiable {
    let id: String
    let name: String
    let handle: String
    let title: String
    let book: String
    let body: String
    let likes: Int
    let mark: String
}

struct CommunityView: View {
    @EnvironmentObject private var auth: AuthManager
    @State private var liked: Set<String> = []
    @State private var draft = ""
    @State private var isReview = false
    @State private var reviewBook = ""
    @State private var rating = 5
    @State private var showingComposer = false
    @State private var selectedForComments: CommunityPost?
    @State private var isPublishing = false
    @State private var notice: String?
    @State private var posts = [
        CommunityPost(id: "sample-1", name: "Mara Ellis", handle: "@mara.reads", title: "A book that stayed with me", book: "Piranesi · Susanna Clarke", body: "Finished this in two quiet evenings. It feels like finding a note from another world tucked inside a familiar book.", likes: 28, mark: "M"),
        CommunityPost(id: "sample-2", name: "Theo Park", handle: "@theopark", title: "The Sunday reading club", book: "The Secret History · Donna Tartt", body: "Do you think the atmosphere is the real narrator here? I keep thinking about the first chapter.", likes: 16, mark: "T"),
        CommunityPost(id: "sample-3", name: "June Rivera", handle: "@junepages", title: "A small recommendation", book: "Small Things Like These · Claire Keegan", body: "For anyone who wants a short book that somehow makes the whole room feel different.", likes: 41, mark: "J")
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.96, green: 0.94, blue: 0.89).ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("THE READING ROOM").font(.system(size: 10, weight: .semibold)).tracking(2.2)
                            Text("Stories are better\nwhen shared.").font(.system(size: 32, design: .serif))
                        }
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("A thoughtful corner for readers.").font(.system(size: 13, design: .serif).italic())
                                if let notice { Text(notice).font(.system(size: 10)).foregroundStyle(.secondary) }
                            }
                            Spacer()
                            Button { showingComposer = true } label: {
                                Image(systemName: "square.and.pencil").padding(12)
                                    .background(Color(red: 0.18, green: 0.20, blue: 0.17))
                                    .foregroundStyle(.white).clipShape(Circle())
                            }
                        }
                        ForEach(posts) { post in postCard(post) }
                    }
                    .foregroundStyle(Color(red: 0.18, green: 0.20, blue: 0.17))
                    .padding(22)
                }
            }
            .navigationBarHidden(true)
            .task { await refreshFeed() }
            .sheet(isPresented: $showingComposer) {
                NavigationStack {
                    Form {
                        Section("WHAT WOULD YOU LIKE TO SHARE?") {
                            Picker("Post type", selection: $isReview) {
                                Text("Reading note").tag(false)
                                Text("Book review").tag(true)
                            }
                            .pickerStyle(.segmented)
                            if isReview {
                                TextField("Book title and author", text: $reviewBook)
                                Picker("Your rating", selection: $rating) {
                                    ForEach(1...5, id: \\.self) { value in
                                        Text(String(repeating: "★", count: value)).tag(value)
                                    }
                                }
                                .pickerStyle(.segmented)
                            }
                            TextEditor(text: $draft).frame(minHeight: 140)
                                .overlay(alignment: .topLeading) {
                                    if draft.isEmpty {
                                        Text(isReview ? "What did this book make you feel?" : "What's on your reading mind?")
                                            .font(.system(size: 13, design: .serif)).foregroundStyle(.tertiary)
                                            .padding(.top, 8).padding(.leading, 5).allowsHitTesting(false)
                                    }
                                }
                        }
                        Section {
                            Button {
                                Task { await publishPost() }
                            } label: {
                                HStack {
                                    if isPublishing { ProgressView() }
                                    Text("Share with the reading room")
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isPublishing || auth.user == nil)
                            if auth.user == nil {
                                Text("Connect Google in your profile to publish and join discussions.")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                    .navigationTitle("Write a note")
                    .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Close") { showingComposer = false } } }
                }
            }
            .sheet(item: $selectedForComments) { post in
                CommentSheet(post: post).environmentObject(auth)
                    .presentationDetents([.medium, .large])
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
                Button { selectedForComments = post } label: {
                    Label("Discuss", systemImage: "bubble.right")
                }
                .foregroundStyle(.secondary)
            }
            .font(.system(size: 11, weight: .medium))
        }
        .padding(17).background(Color.white.opacity(0.54)).clipShape(RoundedRectangle(cornerRadius: 5))
    }

    @MainActor
    private func refreshFeed() async {
        guard auth.user != nil, auth.isConfigured else { return }
        do {
            let remote = try await CommunityService().fetchPosts()
            if !remote.isEmpty { posts = remote }
        } catch {
            notice = "The community feed is temporarily unavailable."
        }
    }

    @MainActor
    private func publishPost() async {
        guard let user = auth.user else { return }
        isPublishing = true
        defer { isPublishing = false }
        let clean = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        let displayName = user.displayName ?? "A Folio reader"
        let post = CommunityPost(id: UUID().uuidString, name: displayName, handle: "@reader", title: isReview ? "A reader’s review · \\(rating)/5" : "A note from my reading journal", book: isReview ? reviewBook : "Currently reading", body: clean, likes: 0, mark: String(displayName.prefix(1)))
        do {
            try await CommunityService().publish(post, userID: user.uid)
            draft = ""
            reviewBook = ""
            isReview = false
            showingComposer = false
            notice = "Your note has been shared."
            await refreshFeed()
        } catch {
            notice = "Couldn't publish just now. Please try again."
        }
    }
}

private struct CommentSheet: View {
    @EnvironmentObject private var auth: AuthManager
    let post: CommunityPost
    @State private var comment = ""
    @State private var comments: [String] = []
    @State private var message: String?

    var body: some View {
        NavigationStack {
            List {
                Section(post.title) {
                    Text(post.body).font(.system(size: 14, design: .serif))
                }
                Section("COMMENTS") {
                    if comments.isEmpty { Text("Be the first to add a thoughtful note.").foregroundStyle(.secondary) }
                    ForEach(Array(comments.enumerated()), id: \.offset) { item in
                        Text(item.element).font(.system(size: 13, design: .serif))
                    }
                }
                Section {
                    TextField("Write a comment…", text: $comment, axis: .vertical)
                    Button("Post comment") { Task { await sendComment() } }
                        .disabled(auth.user == nil || comment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    if let message { Text(message).font(.caption).foregroundStyle(.secondary) }
                    if auth.user == nil { Text("Sign in to join the conversation.").font(.caption).foregroundStyle(.secondary) }
                }
            }
            .navigationTitle("Conversation")
            .navigationBarTitleDisplayMode(.inline)
            .task { await loadComments() }
        }
    }

    @MainActor
    private func loadComments() async {
        guard auth.user != nil else { return }
        comments = (try? await CommunityService().fetchComments(postID: post.id)) ?? []
    }

    @MainActor
    private func sendComment() async {
        guard let user = auth.user else { return }
        do {
            try await CommunityService().addComment(comment, postID: post.id, userID: user.uid, displayName: user.displayName ?? "Reader")
            comment = ""
            await loadComments()
        } catch {
            message = "Couldn't send your comment. Try again."
        }
    }
}
