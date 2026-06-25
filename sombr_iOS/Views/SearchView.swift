import SwiftUI

struct SearchView: View {

    @StateObject private var vm = SearchViewModel()

    var body: some View {
        NavigationStack {
            List {
                listContent
            }
            .listStyle(.plain)
            .navigationTitle("Sombr")
            .searchable(text: $vm.query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search music…")
            .onSubmit(of: .search) { vm.search() }
            .onChange(of: vm.query) { _, new in
                if new.isEmpty { vm.results = [] }
            }
        }
    }

    @ViewBuilder
    private var listContent: some View {
        if vm.isSearching {
            HStack {
                Spacer()
                ProgressView("Searching…")
                Spacer()
            }
            .listRowSeparator(.hidden)
            .padding(.top, 40)
        } else if let err = vm.searchError {
            ContentUnavailableView(
                "Search failed",
                systemImage: "exclamationmark.triangle",
                description: Text(err)
            )
            .listRowSeparator(.hidden)
        } else if vm.results.isEmpty && !vm.query.isEmpty {
            ContentUnavailableView.search(text: vm.query)
                .listRowSeparator(.hidden)
        } else {
            ForEach(vm.results) { result in
                SearchResultRow(
                    result: result,
                    job: vm.job(for: result),
                    onDownload: { vm.download(result: result) }
                )
                .padding(.vertical, 4)
            }
        }
    }
}

#Preview {
    SearchView()
}
