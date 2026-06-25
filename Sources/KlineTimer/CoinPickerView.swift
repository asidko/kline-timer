import SwiftUI

/// Spotlight-style coin picker shown in place of the panel. Type to autocomplete
/// by ticker or name; otherwise browse Recent (last few watched) then All coins.
/// Clicking a coin watches it and closes immediately.
struct CoinPickerView: View {
    @ObservedObject var monitor: CoinMonitor
    @ObservedObject var settings: Settings
    let onClose: () -> Void

    @State private var query = ""
    @FocusState private var searchFocused: Bool

    private var trimmed: String { query.trimmingCharacters(in: .whitespaces) }

    /// Up to three recently-watched coins, minus the ones already on the list.
    private var recent: [CoinInfo] {
        let watched = Set(monitor.coins.map(\.displayName))
        return Array(
            settings.recentSymbols
                .filter { !watched.contains($0) }
                .compactMap { CoinCatalog.info(base: $0) }
                .prefix(3)
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if trimmed.isEmpty { browse } else { searchResults }
                }
                .padding(.horizontal, 8)
                .padding(.top, 6)
                .padding(.bottom, 9)
            }
            .frame(maxHeight: 300)
        }
        .onExitCommand(perform: onClose)
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            TextField("Search symbol or name", text: $query)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .focused($searchFocused)
                .onSubmit(pickFirst)
            Button(action: onClose) {
                Image(systemName: "xmark").font(.system(size: 11, weight: .semibold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color.primary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal, 12)
        .padding(.top, 11)
        .padding(.bottom, 9)
        .onAppear { searchFocused = true }
    }

    @ViewBuilder private var browse: some View {
        let recentCoins = recent
        if !recentCoins.isEmpty {
            sectionHeader("Recent")
            ForEach(recentCoins) { row($0) }
        }
        sectionHeader("All coins")
        ForEach(CoinCatalog.all) { row($0) }
    }

    @ViewBuilder private var searchResults: some View {
        let results = Array(CoinCatalog.search(trimmed).prefix(7))
        if results.isEmpty {
            Text("No symbol matches \u{201C}\(trimmed)\u{201D}")
                .font(.system(size: 12.5))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 22)
        } else {
            ForEach(results) { row($0) }
        }
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text).tagStyle()
            .padding(.horizontal, 10)
            .padding(.top, 6)
            .padding(.bottom, 5)
    }

    private func row(_ coin: CoinInfo) -> some View {
        CoinOptionRow(coin: coin) { pick(coin) }
    }

    private func pick(_ coin: CoinInfo) {
        monitor.add(coin.symbol)
        onClose()
    }

    private func pickFirst() {
        if let first = CoinCatalog.search(trimmed).first { pick(first) }
    }
}

/// One coin in the picker: avatar monogram, ticker, full name, and a `+` that
/// fades in on hover; the whole row is the click target.
private struct CoinOptionRow: View {
    let coin: CoinInfo
    let pick: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: pick) {
            HStack(spacing: 10) {
                Text(coin.monogram)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 26, height: 26)
                    .background(Color.primary.opacity(0.07))
                    .clipShape(Circle())
                VStack(alignment: .leading, spacing: 1) {
                    Text(coin.symbol).font(.system(size: 12.5, weight: .semibold)).foregroundStyle(.primary)
                    Text(coin.name).font(.system(size: 11)).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                    .opacity(hover ? 1 : 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(hover ? 0.05 : 0)))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
    }
}
