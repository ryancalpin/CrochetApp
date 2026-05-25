import SwiftUI
import StoreKit

// MARK: - Pro plan constants

enum Pro {
    /// Non-consumable unlock. Must match the product configured in App Store Connect
    /// (and Looplet.storekit for local testing).
    static let productID = "looplet_pro001"

    /// Free tier may keep this many patterns in the library at once (concurrent).
    /// Deleting a pattern frees a slot.
    static let freeImportLimit = 3

    /// Themes available without Pro. Everything else is Pro-only.
    /// Plum + Amber are free so the default palette coordinates with the app icon.
    static let freeThemes: Set<AppTheme> = [.plum, .amber]

    /// Nonisolated, thread-safe mirror of the entitlement (kept in sync by `ProStore`).
    /// Use this from non-main-actor code (e.g. `PatternLibrary`); SwiftUI views should
    /// observe `ProStore.shared.isPro` for live updates instead.
    static let cachedKey = "crochet.isProCached"
    static var isUnlocked: Bool { UserDefaults.standard.bool(forKey: cachedKey) }
}

// MARK: - Store (StoreKit 2)

/// Owns the Pro entitlement and the purchase/restore flow. Observe via
/// `@ObservedObject var store = ProStore.shared`. All entitlement reads degrade to
/// "not purchased" when StoreKit is unavailable, so the app is fully usable unsigned.
@MainActor
final class ProStore: ObservableObject {
    static let shared = ProStore()

    @Published private(set) var isPro = false
    @Published private(set) var product: Product?
    @Published private(set) var purchasing = false

    private var updatesTask: Task<Void, Never>?

    private init() {
        updatesTask = listenForTransactions()
        Task {
            await loadProduct()
            await refreshEntitlement()
        }
    }

    deinit { updatesTask?.cancel() }

    /// Localized price string, or a sensible fallback before the product loads.
    var priceText: String { product?.displayPrice ?? "—" }

    func loadProduct() async {
        product = try? await Product.products(for: [Pro.productID]).first
    }

    func refreshEntitlement() async {
        #if DEBUG
        // Dev/screenshot only: force-unlock Pro when the off-by-default debug flag is set.
        // Never compiled into Release builds, so it can't bypass the paywall in production.
        if UserDefaults.standard.bool(forKey: "debug.forceProUnlock") {
            isPro = true
            UserDefaults.standard.set(true, forKey: Pro.cachedKey)
            return
        }
        #endif
        var entitled = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.productID == Pro.productID,
               transaction.revocationDate == nil {
                entitled = true
            }
        }
        isPro = entitled
        // Mirror to a nonisolated flag for non-main-actor readers (e.g. PatternLibrary).
        UserDefaults.standard.set(entitled, forKey: Pro.cachedKey)
    }

    /// Returns true if the purchase completed and Pro is now unlocked.
    @discardableResult
    func purchase() async -> Bool {
        guard let product else { return false }
        purchasing = true
        defer { purchasing = false }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    await transaction.finish()
                    await refreshEntitlement()
                    return isPro
                }
                return false
            case .userCancelled, .pending:
                return false
            @unknown default:
                return false
            }
        } catch {
            return false
        }
    }

    func restore() async {
        try? await AppStore.sync()
        await refreshEntitlement()
    }

    private func listenForTransactions() -> Task<Void, Never> {
        Task(priority: .background) { [weak self] in
            for await result in Transaction.updates {
                guard case .verified(let transaction) = result else { continue }
                await transaction.finish()
                await self?.refreshEntitlement()
            }
        }
    }
}

// MARK: - Locked AI panel (free tier)

/// Shown in place of the AI panel for free users — previews the feature and invites unlock.
struct AILockedPanel: View {
    let onUnlock: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles").foregroundColor(Color.appAccent)
                Text("AI Assistant").font(.system(.headline))
                Spacer()
                Button { onClose() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.textSecondary).font(.title3)
                }
                .buttonStyle(.plain).help("Close")
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
            .background(Color.surface)
            Divider()
            Spacer()
            VStack(spacing: 14) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 34))
                    .foregroundColor(Color.appAccent)
                Text("AI insights are a Pro feature")
                    .font(.headline).multilineTextAlignment(.center)
                Text("Get a summary, abbreviations, materials, difficulty, time, and a Q&A — powered by Apple Intelligence.")
                    .font(.callout).foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
                Button("Unlock Looplet Pro") { onUnlock() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
            }
            .padding(.horizontal, 24)
            Spacer()
        }
        .background(Color.surface)
        .tint(Color.appAccent)
    }
}

// MARK: - Paywall

struct PaywallView: View {
    @ObservedObject private var store = ProStore.shared
    @Environment(\.dismiss) private var dismiss

    /// Optional context line explaining what the user just tried to do.
    var reason: String? = nil

    private let benefits: [(icon: String, title: String, detail: String, color: Color)] = [
        ("sparkles", "AI Pattern Insights", "Summary, abbreviations, materials, difficulty, time, and Q&A — powered by Apple Intelligence.", Color.appAccent),
        ("icloud.fill", "iCloud Sync", "Keep your patterns and yarn stash in sync across all your devices.", Color(hex: "#5A96C7") ?? .blue),
        ("square.stack.3d.up.fill", "Unlimited Patterns", "Import as many patterns as you like — the free tier stops at \(Pro.freeImportLimit).", Color(hex: "#5DA882") ?? .green),
        ("paintpalette.fill", "All Themes & Colors", "Unlock all 8 themes plus custom counter-pill colors.", Color(hex: "#C87AB0") ?? .pink)
    ]

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let reason {
                        Text(reason)
                            .font(.callout)
                            .foregroundColor(.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    ForEach(benefits, id: \.title) { benefit in
                        HStack(alignment: .top, spacing: 14) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 11, style: .continuous)
                                    .fill(benefit.color.opacity(0.12))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                                            .strokeBorder(benefit.color.opacity(0.25), lineWidth: 1)
                                    )
                                    .frame(width: 38, height: 38)
                                Image(systemName: benefit.icon)
                                    .font(.system(size: 16))
                                    .foregroundColor(benefit.color)
                            }
                            VStack(alignment: .leading, spacing: 3) {
                                Text(benefit.title).font(.system(size: 15, weight: .semibold))
                                Text(benefit.detail)
                                    .font(.system(size: 13)).foregroundColor(.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
                .padding(20)
            }
            Divider()
            footer
        }
        #if os(macOS)
        .frame(width: 440, height: 520)
        #endif
        .background(Color.surface)
        .tint(Color.appAccent)
    }

    private var accentGradient: LinearGradient {
        LinearGradient(
            colors: [Color.appAccent.lightened(by: 0.08), Color.appAccent.darkened(by: 0.10)],
            startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    private var header: some View {
        VStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 19, style: .continuous)
                    .fill(accentGradient)
                    .frame(width: 58, height: 58)
                    .shadow(color: Color.appAccent.opacity(0.5), radius: 18, x: 0, y: 10)
                Image(systemName: "lock.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.white)
            }
            VStack(spacing: 5) {
                Text("Looplet Pro").font(.system(size: 24, weight: .bold))
                Text("A one-time unlock — no subscription.")
                    .font(.callout).foregroundColor(.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 22)
        .background(
            LinearGradient(colors: [Color.appAccent.opacity(0.14), .clear],
                           startPoint: .top, endPoint: .bottom)
        )
    }

    private var footer: some View {
        VStack(spacing: 10) {
            Button {
                Task {
                    let ok = await store.purchase()
                    if ok { dismiss() }
                }
            } label: {
                HStack(spacing: 8) {
                    if store.purchasing { ProgressView().controlSize(.small).tint(.white) }
                    Text(store.purchasing ? "Processing…"
                         : (store.product != nil ? "Unlock Pro — \(store.priceText)" : "Unlock Pro"))
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(accentGradient, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: Color.appAccent.opacity(0.45), radius: 16, x: 0, y: 8)
                .opacity(store.purchasing ? 0.7 : 1)
            }
            .buttonStyle(.plain)
            .disabled(store.purchasing || store.product == nil)

            HStack {
                Button("Restore Purchase") { Task { await store.restore(); if store.isPro { dismiss() } } }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.appAccent)
                Spacer()
                Button("Maybe Later") { dismiss() }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
            }
            .font(.callout)
        }
        .padding(20)
        .background(Color.surfaceRaised)
    }
}
