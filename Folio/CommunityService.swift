import Foundation
import FirebaseFirestore
import FirebaseStorage

struct CommunityService {
    private let db = Firestore.firestore()

    func saveProfile(name: String, bio: String, avatarURL: String?, userID: String) async throws {
        try await db.collection("profiles").document(userID).setData([
            "name": name,
            "bio": bio,
            "avatarURL": avatarURL as Any? ?? NSNull(),
            "updatedAt": FieldValue.serverTimestamp()
        ], merge: true)
    }

    func loadProfile(userID: String) async throws -> (name: String, bio: String, avatarURL: String?)? {
        let snapshot = try await db.collection("profiles").document(userID).getDocument()
        guard snapshot.exists, let data = snapshot.data() else { return nil }
        return (data["name"] as? String ?? "", data["bio"] as? String ?? "", data["avatarURL"] as? String)
    }

    func uploadAvatar(_ data: Data, userID: String) async throws -> URL {
        let reference = Storage.storage().reference().child("profile-images/\\(userID).jpg")
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        _ = try await reference.putDataAsync(data, metadata: metadata)
        return try await reference.downloadURL()
    }

    func fetchPosts() async throws -> [CommunityPost] {
        let snapshot = try await db.collection("posts")
            .order(by: "createdAt", descending: true)
            .limit(to: 60)
            .getDocuments()
        return snapshot.documents.compactMap { document in
            let data = document.data()
            guard let name = data["name"] as? String,
                  let handle = data["handle"] as? String,
                  let title = data["title"] as? String,
                  let book = data["book"] as? String,
                  let body = data["body"] as? String else { return nil }
            return CommunityPost(
                id: document.documentID,
                name: name,
                handle: handle,
                title: title,
                book: book,
                body: body,
                likes: data["likes"] as? Int ?? 0,
                mark: data["mark"] as? String ?? String(name.prefix(1))
            )
        }
    }

    func publish(_ post: CommunityPost, userID: String) async throws {
        try await db.collection("posts").addDocument(data: [
            "authorID": userID,
            "name": post.name,
            "handle": post.handle,
            "title": post.title,
            "book": post.book,
            "body": post.body,
            "likes": 0,
            "mark": post.mark,
            "createdAt": FieldValue.serverTimestamp()
        ])
    }

    func addComment(_ text: String, postID: String, userID: String, displayName: String) async throws {
        try await db.collection("posts").document(postID).collection("comments").addDocument(data: [
            "authorID": userID,
            "displayName": displayName,
            "body": text,
            "createdAt": FieldValue.serverTimestamp()
        ])
    }

    func fetchComments(postID: String) async throws -> [String] {
        let snapshot = try await db.collection("posts").document(postID)
            .collection("comments").order(by: "createdAt").limit(to: 100).getDocuments()
        return snapshot.documents.compactMap { doc in
            guard let name = doc.data()["displayName"] as? String,
                  let body = doc.data()["body"] as? String else { return nil }
            return "\(name): \(body)"
        }
    }
}
