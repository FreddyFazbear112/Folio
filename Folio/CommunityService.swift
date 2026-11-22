import Foundation
import FirebaseFirestore

struct CommunityService {
    private let db = Firestore.firestore()

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
