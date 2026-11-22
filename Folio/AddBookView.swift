import SwiftUI

struct AddBookView: View {
    @EnvironmentObject private var library: LibraryStore
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var author = ""
    @State private var status: ReadingStatus = .toRead

    private let ink = Color(red: 0.18, green: 0.20, blue: 0.17)
    private let paper = Color(red: 0.96, green: 0.94, blue: 0.89)

    var body: some View {
        NavigationStack {
            Form {
                Section("THE BOOK") {
                    TextField("Title", text: $title)
                    TextField("Author", text: $author)
                }
                Section("YOUR SHELF") {
                    Picker("Reading status", selection: $status) {
                        ForEach(ReadingStatus.allCases) { item in
                            Text(item.rawValue).tag(item)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                Section {
                    Button {
                        library.add(title: title, author: author, status: status)
                        dismiss()
                    } label: {
                        Text("Add to my bookshelf")
                            .font(.system(.body, design: .serif).weight(.semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .listRowBackground(ink)
                    .foregroundStyle(paper)
                }
            }
            .scrollContentBackground(.hidden)
            .background(paper)
            .navigationTitle("A new story")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(ink)
                }
            }
        }
    }
}
