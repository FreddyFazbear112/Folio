import Foundation
import FirebaseFirestore
import FirebaseStorage
import FirebaseAuth

/// Community data is served by Folio's own API when FOLIO_API_BASE_URL is
/// configured in the app's Info.plist. Firestore remains a migration fallback.
struct CommunityService {
    private let db = Firestore.firestore()
    private var apiBaseURL: URL? {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "FOLIO_API_BASE_URL") as? String,
              !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let url = URL(string: raw), url.scheme == "https" else { return nil }
        return url
    }

    private struct FeedResponse: Decodable { let posts: [APIPost] }
    private struct APIPost: Decodable {
        let id: String
        let title: String
        let book: String
        let body: String
        let name: String
        let handle: String
        let likes: Int
        let mark: String
        var communityPost: CommunityPost {
            CommunityPost(id: id, name: name, handle: handle, title: title, book: book,
                          body: body, likes: likes, mark: mark)
        }
    }
    private struct CommentsResponse: Decodable { let comments: [APIComment] }
    private struct APIComment: Decodable { let displayName: String; let body: String }
    private struct ProfileResponse: Decodable { let profile: APIProfile }
    private struct APIProfile: Decodable { let name: String; let bio: String; let avatarURL: String? }

    private func request(_ path: String, method: String = "GET", body: [String: Any]? = nil, authenticated: Bool = false) async throws -> Data {
        guard let base = apiBaseURL else { throw URLError(.unsupportedURL) }
        let url = base.appendingPathComponent(path)
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        if authenticated {
            guard let user = Auth.auth().currentUser else { throw CommunityAPIError.signInRequired }
            let token = try await user.getIDToken()
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        guard (200...299).contains(http.statusCode) else {
            let message = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["error"] as? String
            throw CommunityAPIError.server(message ?? "The Reading Room couldn't complete that request.")
        }
        return data
    }

    func saveProfile(name: String, bio: String, avatarURL: String?, userID: String) async throws {
        if apiBaseURL != nil {
            _ = try await request("v1/me/profile", method: "PUT",
                                  body: ["name": name, "bio": bio], authenticated: true)
            return
        }
        try await db.collection("profiles").document(userID).setData([
            "name": name, "bio": bio, "avatarURL": avatarURL ?? "",
            "updatedAt": FieldValue.serverTimestamp()
        ], merge: true)
    }

    func loadProfile(userID: String) async throws -> (name: String, bio: String, avatarURL: String?)? {
        if apiBaseURL != nil {
            let data = try await request("v1/profiles/\(userID)")
            let response = try JSONDecoder().decode(ProfileResponse.self, from: data)
            return (response.profile.name, response.profile.bio, response.profile.avatarURL)
        }
        let snapshot = try await db.collection("profiles").document(userID).getDocument()
        guard snapshot.exists, let data = snapshot.data() else { return nil }
        return (data["name"] as? String ?? "", data["bio"] as? String ?? "", data["avatarURL"] as? String)
    }

    func uploadAvatar(_ data: Data, userID: String) async throws -> URL {
        let reference = Storage.storage().reference().child("profile-images/\(userID).jpg")
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        _ = try await reference.putDataAsync(data, metadata: metadata)
        return try await reference.downloadURL()
    }

    func fetchPosts() async throws -> [CommunityPost] {
        if apiBaseURL != nil {
            let data = try await request("v1/posts")
            return try JSONDecoder().decode(FeedResponse.self, from: data).posts.map(\.communityPost)
        }
        let snapshot = try await db.collection("posts").order(by: "createdAt", descending: true).limit(to: 60).getDocuments()
        return snapshot.documents.compactMap { document in
            let data = document.data()
            guard let name = data["name"] as? String, let handle = data["handle"] as? String,
                  let title = data["title"] as? String, let book = data["book"] as? String,
                  let body = data["body"] as? String else { return nil }
            return CommunityPost(id: document.documentID, name: name, handle: handle, title: title,
                                 book: book, body: body, likes: data["likes"] as? Int ?? 0,
                                 mark: data["mark"] as? String ?? String(name.prefix(1)))
        }
    }

    func publish(_ post: CommunityPost, userID: String) async throws {
        if apiBaseURL != nil {
            _ = try await request("v1/posts", method: "POST",
                body: ["title": post.title, "book": post.book, "body": post.body,
                       "postType": post.title.contains("review") ? "review" : "note",
                       "rating": 5], authenticated: true)
            return
        }
        try await db.collection("posts").addDocument(data: [
            "authorID": userID, "name": post.name, "handle": post.handle, "title": post.title,
            "book": post.book, "body": post.body, "likes": 0, "mark": post.mark,
            "createdAt": FieldValue.serverTimestamp()
        ])
    }

    func addComment(_ text: String, postID: String, userID: String, displayName: String) async throws {
        if apiBaseURL != nil {
            _ = try await request("v1/posts/\(postID)/comments", method: "POST",
                                  body: ["body": text], authenticated: true)
            return
        }
        try await db.collection("posts").document(postID).collection("comments").addDocument(data: [
            "authorID": userID, "displayName": displayName, "body": text,
            "createdAt": FieldValue.serverTimestamp()
        ])
    }

    func fetchComments(postID: String) async throws -> [String] {
        if apiBaseURL != nil {
            let data = try await request("v1/posts/\(postID)/comments")
            return try JSONDecoder().decode(CommentsResponse.self, from: data).comments.map { "\($0.displayName): \($0.body)" }
        }
        let snapshot = try await db.collection("posts").document(postID).collection("comments")
            .order(by: "createdAt").limit(to: 100).getDocuments()
        return snapshot.documents.compactMap { doc in
            guard let name = doc.data()["displayName"] as? String,
                  let body = doc.data()["body"] as? String else { return nil }
            return "\(name): \(body)"
        }
    }

    func setLiked(_ liked: Bool, postID: String) async throws {
        if apiBaseURL != nil {
            _ = try await request("v1/posts/\(postID)/like", method: liked ? "PUT" : "DELETE", authenticated: true)
            return
        }
        guard let uid = Auth.auth().currentUser?.uid else { throw CommunityAPIError.signInRequired }
        let ref = db.collection("posts").document(postID)
        if liked {
            try await ref.collection("likes").document(uid).setData(["createdAt": FieldValue.serverTimestamp()])
        } else {
            try await ref.collection("likes").document(uid).delete()
        }
    }
}

enum CommunityAPIError: LocalizedError {
    case signInRequired
    case server(String)
    var errorDescription: String? {
        switch self {
        case .signInRequired: return "Sign in to use the Reading Room."
        case .server(let message): return message
        }
    }
}
