import SwiftUI
import MapKit
import Combine
import Contacts
import Network
import UIKit
import MediaPlayer
import CoreLocation
import EventKit

// =====================================================
// MARK: - App Entry
// =====================================================
@main
struct MotoPlayApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

// =====================================================
// MARK: - Panel enum
// =====================================================
enum Panel { case map, music, contacts, home }

// =====================================================
// MARK: - UI Tokens (CarPlay-like)
// =====================================================
private enum CarPlayUI {
    static let sidebarWidth: CGFloat = 84
    static let panelCorner: CGFloat = 26
    static let sidebarCorner: CGFloat = 28
    static let rightColumnWidth: CGFloat = 325

    static let homeRows: CGFloat = 2
    static let homeGridSpacing: CGFloat = 12
    static let homeTileMinHeight: CGFloat = 70
}

// =====================================================
// MARK: - ContentView
// =====================================================
struct ContentView: View {
    @State private var selectedPanel: Panel = .home

    @StateObject private var contactsManager = ContactsManager()
    @StateObject private var calendarManager = AppCalendarManager()
    @StateObject private var locationManager = AppLocationManager()
    @StateObject private var nowPlaying = NowPlayingManager()

    @Environment(\.colorScheme) private var systemScheme
    @AppStorage("appTheme") private var appTheme: String = "system"

    @State private var mapStyle: MapStyle = .standard
    @State private var mapExpanded: Bool = false
    @State private var isFollowingUser: Bool = true

    @FocusState private var searchFocused: Bool
    @State private var searchFullscreen: Bool = false
    @State private var showSiriHelp = false

    @State private var keepScreenOn: Bool = false
    private func setIdleTimer(_ disabled: Bool) {
        UIApplication.shared.isIdleTimerDisabled = disabled
    }

    // Map state
    @State private var position: MapCameraPosition = .userLocation(fallback: .automatic)

    private var effectiveScheme: ColorScheme {
        switch appTheme {
        case "dark": return .dark
        case "light": return .light
        default: return systemScheme
        }
    }

    var body: some View {
        GeometryReader { geo in
            let targetHeight = geo.size.height * 0.93
            let homeHeight   = geo.size.height * 0.84

            ZStack {
                backgroundView

                VStack {
                    Spacer(minLength: 0)
                        .frame(height: geo.size.height * 0.012)

                    HStack(alignment: .top, spacing: 16) {

                        if !searchFullscreen {
                            sidebar(height: targetHeight)
                        }

                        ZStack {
                            switch selectedPanel {
                            case .home:
                                HomePanel(hasSidebar: !searchFullscreen, keepScreenOn: $keepScreenOn)

                            case .map:
                                mapPanel
                                    .padding(.leading, 25)
                                    .padding(.trailing, 5)

                            case .contacts:
                                contactsPanel
                                    .padding(.leading, 25)
                                    .padding(.trailing, 5)

                            case .music:
                                // Panel central de música “tipo CarPlay”
                                chromeCard(padding: 18) {
                                    CarPlayNowPlayingPanel(np: nowPlaying)
                                }
                                .padding(.leading, 25)
                                .padding(.trailing, 5)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: selectedPanel == .home ? homeHeight : targetHeight, alignment: .top)

                        // Right column (no home, no fullscreen)
                        if !mapExpanded && !searchFullscreen && selectedPanel != .home {
                            rightColumn(height: targetHeight)
                        }
                    }
                    .padding(.horizontal, searchFullscreen ? 0 : 18)
                    .padding(.vertical, searchFullscreen ? 0 : 18)

                    Spacer(minLength: 0)
                }
            }
            .ignoresSafeArea(.keyboard)
            .preferredColorScheme(appTheme == "system" ? nil : effectiveScheme)
            .onAppear {
                setIdleTimer(true)
                calendarManager.requestAccessAndFetch()
                contactsManager.requestAccessAndFetch()
                locationManager.requestPermission()
                nowPlaying.start()
            }
            .onDisappear {
                setIdleTimer(false)
                nowPlaying.stop()
            }
            .onChange(of: keepScreenOn) { _, v in
                setIdleTimer(v)
            }
            .alert("Siri", isPresented: $showSiriHelp) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("iOS no permite abrir Siri directamente desde una app. Usa el botón lateral o di “Oye Siri”.")
            }
        }
    }

    // =====================================================
    // MARK: - Sidebar
    // =====================================================
    private func sidebar(height: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: CarPlayUI.sidebarCorner, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: CarPlayUI.sidebarCorner, style: .continuous)
                        .stroke(Color.primary.opacity(0.10), lineWidth: 1)
                )

            VStack(spacing: 10) {
                SideStatusBar()

                SideButton(icon: "map.fill", title: "Mapa", selected: selectedPanel == .map, showTitle: false) {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        selectedPanel = .map
                        mapExpanded = false
                    }
                }

                SideButton(icon: "music.note", title: "Música", selected: selectedPanel == .music, showTitle: false) {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        selectedPanel = .music
                        mapExpanded = false
                    }
                }

                SideButton(icon: "person.crop.circle.fill", title: "Contactos", selected: selectedPanel == .contacts, showTitle: false) {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        selectedPanel = .contacts
                        mapExpanded = false
                    }
                }

                SideButton(icon: "waveform.circle.fill", title: "Siri", selected: false, showTitle: false) {
                    showSiriHelp = true
                }

                Spacer(minLength: 0)

                SideButton(icon: "square.grid.2x2.fill", title: "Inicio", selected: selectedPanel == .home, showTitle: false) {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        selectedPanel = .home
                        mapExpanded = false
                        searchFullscreen = false
                    }
                }
            }
            .padding(.top, 8)
            .padding(.horizontal, 10)
            .padding(.bottom, 10)
        }
        .frame(width: CarPlayUI.sidebarWidth, height: height, alignment: .top)
        .shadow(color: Color.black.opacity(effectiveScheme == .dark ? 0.25 : 0.12), radius: 14, x: 0, y: 10)
    }

    // =====================================================
    // MARK: - Right column
    // =====================================================
    private func rightColumn(height: CGFloat) -> some View {
        VStack(spacing: 10) {
            chromeCard(padding: 16) {
                RightNowPlayingCompactCard(np: nowPlaying)
            }
            .frame(height: 220, alignment: .top)

            chromeCard(padding: 16) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Eventos para hoy")
                        .font(.system(size: 16, weight: .semibold))

                    CalendarWidget(calendarManager: calendarManager)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        .padding(.bottom, 2)
                }
            }
            .frame(height: 199, alignment: .top)

            Spacer(minLength: 0)
        }
        .frame(width: CarPlayUI.rightColumnWidth, height: height, alignment: .top)
    }

    // =====================================================
    // MARK: - Map Panel (simple y estable)
    // =====================================================
    private var mapPanel: some View {
        ZStack(alignment: .top) {
            Map(position: $position, interactionModes: [.pan, .zoom, .rotate]) {
                // En iOS 17+ esto funciona:
                UserAnnotation()
            }
            .mapStyle(mapStyle)
            .clipShape(RoundedRectangle(cornerRadius: CarPlayUI.panelCorner, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: CarPlayUI.panelCorner, style: .continuous)
                    .stroke(Color.primary.opacity(0.12), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(effectiveScheme == .dark ? 0.20 : 0.10), radius: 14, x: 0, y: 10)
            .onReceive(locationManager.$coordinate.compactMap { $0 }) { coord in
                guard isFollowingUser else { return }
                withAnimation(.easeInOut(duration: 0.25)) {
                    position = .region(
                        MKCoordinateRegion(
                            center: coord,
                            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                        )
                    )
                }
            }

            // Controles flotantes (derecha)
            VStack {
                HStack {
                    Spacer()
                    VStack(spacing: 10) {
                        controlButton(isFollowingUser ? "location.fill" : "location") {
                            isFollowingUser.toggle()
                        }

                        Menu {
                            Button("Estándar") { mapStyle = .standard }
                            Button("Híbrido") { mapStyle = .hybrid }
                            Button("Satélite") { mapStyle = .imagery }
                        } label: {
                            Image(systemName: "map")
                                .font(.system(size: 18, weight: .semibold))
                                .frame(width: 44, height: 44)
                                .background(.ultraThinMaterial)
                                .overlay(Circle().stroke(Color.primary.opacity(0.10), lineWidth: 1))
                                .clipShape(Circle())
                        }

                        controlButton(mapExpanded ? "arrow.left.to.line" : "arrow.right.to.line") {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                mapExpanded.toggle()
                            }
                        }
                    }
                }
                .padding(.trailing, 14)
                .padding(.top, 14)

                Spacer(minLength: 0)
            }
        }
    }

    // =====================================================
    // MARK: - Contacts Panel
    // =====================================================
    @State private var contactsSearchText: String = ""
    @FocusState private var contactsSearchFocused: Bool

    private var contactsPanel: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: CarPlayUI.panelCorner, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: CarPlayUI.panelCorner, style: .continuous)
                        .stroke(Color.primary.opacity(0.12), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(effectiveScheme == .dark ? 0.20 : 0.10), radius: 14, x: 0, y: 10)

            // Search bar
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").opacity(0.7)

                TextField("Buscar contacto…", text: $contactsSearchText)
                    .submitLabel(.search)
                    .focused($contactsSearchFocused)

                Button {
                    contactsSearchText = ""
                    hideKeyboard()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .opacity(0.85)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.primary.opacity(0.10), lineWidth: 1)
            )
            .padding(.top, 12)
            .padding(.horizontal, 12)

            ContactsPanel(contactsManager: contactsManager, query: $contactsSearchText)
                .padding(.top, 64)
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .clipShape(RoundedRectangle(cornerRadius: CarPlayUI.panelCorner, style: .continuous))
    }

    // =====================================================
    // MARK: - Chrome / Cards
    // =====================================================
    private func chromeCard<Content: View>(padding: CGFloat = 16, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) { content() }
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: CarPlayUI.panelCorner, style: .continuous)
                    .stroke(Color.primary.opacity(0.10), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: CarPlayUI.panelCorner, style: .continuous))
            .shadow(color: Color.black.opacity(effectiveScheme == .dark ? 0.18 : 0.08), radius: 12, x: 0, y: 10)
    }

    private var backgroundView: some View {
        LinearGradient(
            colors: [
                Color.black.opacity(effectiveScheme == .dark ? 0.75 : 0.25),
                Color.black.opacity(effectiveScheme == .dark ? 0.92 : 0.35)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    private func controlButton(_ system: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: system)
                .font(.system(size: 18, weight: .semibold))
                .frame(width: 44, height: 44)
                .background(.ultraThinMaterial)
                .overlay(Circle().stroke(Color.primary.opacity(0.10), lineWidth: 1))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }
}

// =====================================================
// MARK: - Home Panel
// =====================================================
struct HomePanel: View {
    let hasSidebar: Bool
    @Binding var keepScreenOn: Bool
    @AppStorage("appTheme") private var appTheme: String = "system"

    private let cols = [
        GridItem(.flexible(), spacing: CarPlayUI.homeGridSpacing),
        GridItem(.flexible(), spacing: CarPlayUI.homeGridSpacing),
        GridItem(.flexible(), spacing: CarPlayUI.homeGridSpacing),
        GridItem(.flexible(), spacing: CarPlayUI.homeGridSpacing)
    ]

    var body: some View {
        GeometryReader { geo in
            let available = geo.size.height
            let tileHeight = (available - CarPlayUI.homeGridSpacing) / CarPlayUI.homeRows

            ZStack {
                RoundedRectangle(cornerRadius: CarPlayUI.panelCorner, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: CarPlayUI.panelCorner, style: .continuous)
                            .stroke(Color.primary.opacity(0.10), lineWidth: 1)
                    )

                LazyVGrid(columns: cols, spacing: CarPlayUI.homeGridSpacing) {
                    HomeTile(title: "Tiempo", icon: "cloud.sun.fill", height: tileHeight) { open("weather://") }
                    HomeTile(title: "WhatsApp", icon: "message.fill", height: tileHeight) { open("whatsapp://") }
                    HomeTile(title: "Dispositivos", icon: "dot.radiowaves.left.and.right", height: tileHeight) { openBluetoothOrSettings() }
                    HomeTile(title: "Spotify", icon: "music.note", height: tileHeight) { open("spotify://") }

                    HomeTile(title: themeTitle(), icon: "circle.lefthalf.filled", height: tileHeight) { toggleTheme() }
                    HomeTile(title: "Calendario", icon: "calendar", height: tileHeight) { open("calshow:") }

                    HomeTile(
                        title: keepScreenOn ? "Pantalla ON" : "Pantalla OFF",
                        icon: keepScreenOn ? "lock.open.fill" : "lock.fill",
                        height: tileHeight
                    ) { keepScreenOn.toggle() }

                    HomeTile(title: "Ajustes", icon: "gearshape.fill", height: tileHeight) { open(UIApplication.openSettingsURLString) }
                }
                .padding(18)
            }
            .padding(.leading, hasSidebar ? 24 : 0)
            .padding(.trailing, 24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func open(_ url: String) {
        guard let u = URL(string: url) else { return }
        if UIApplication.shared.canOpenURL(u) {
            UIApplication.shared.open(u)
        } else if let s = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(s)
        }
    }

    private func openBluetoothOrSettings() {
        let candidates = [
            "App-Prefs:Bluetooth",
            "App-Prefs:root=Bluetooth",
            UIApplication.openSettingsURLString
        ]
        for c in candidates {
            if let u = URL(string: c), UIApplication.shared.canOpenURL(u) {
                UIApplication.shared.open(u)
                return
            }
        }
    }

    private func toggleTheme() {
        switch appTheme {
        case "system": appTheme = "dark"
        case "dark": appTheme = "light"
        default: appTheme = "system"
        }
    }

    private func themeTitle() -> String {
        switch appTheme {
        case "dark": return "Modo claro"
        case "light": return "Modo sistema"
        default: return "Modo oscuro"
        }
    }
}

private struct HomeTile: View {
    let title: String
    let icon: String
    let height: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 28, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)

                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .frame(maxWidth: .infinity)
            .frame(height: max(CarPlayUI.homeTileMinHeight, height))
            .background(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.primary.opacity(0.10), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 6)
        }
        .buttonStyle(.plain)
    }
}

// =====================================================
// MARK: - Side Button
// =====================================================
struct SideButton: View {
    let icon: String
    let title: String
    let selected: Bool
    var showTitle: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: showTitle ? 6 : 0) {
                AppIconGlyph(systemName: icon, selected: selected)
                    .frame(width: 64, height: 64)

                if showTitle {
                    Text(title)
                        .font(.system(size: 12, weight: .semibold))
                        .opacity(0.9)
                }
            }
            .frame(width: 67, height: showTitle ? 77 : 65)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(title))
    }
}

private struct AppIconGlyph: View {
    let systemName: String
    let selected: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.primary.opacity(selected ? 0.18 : 0.10), lineWidth: 1)
                )
                .shadow(color: .black.opacity(selected ? 0.18 : 0.10), radius: 10, x: 0, y: 6)

            Image(systemName: systemName)
                .font(.system(size: 22, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.primary)
                .opacity(selected ? 1.0 : 0.95)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.20), Color.white.opacity(0.00)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .blendMode(.softLight)
        )
    }
}

// =====================================================
// MARK: - Contacts
// =====================================================
final class ContactsManager: ObservableObject {
    @Published var contacts: [CNContact] = []
    @Published var isAuthorized: Bool = false

    private let store = CNContactStore()

    func requestAccessAndFetch() {
        let status = CNContactStore.authorizationStatus(for: .contacts)
        switch status {
        case .authorized:
            isAuthorized = true
            fetchContacts()

        case .notDetermined:
            store.requestAccess(for: .contacts) { granted, _ in
                DispatchQueue.main.async {
                    self.isAuthorized = granted
                    if granted { self.fetchContacts() } else { self.contacts = [] }
                }
            }

        default:
            DispatchQueue.main.async {
                self.isAuthorized = false
                self.contacts = []
            }
        }
    }

    private func fetchContacts() {
        let keys: [CNKeyDescriptor] = [
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
            CNContactPhoneNumbersKey as CNKeyDescriptor
        ]

        let request = CNContactFetchRequest(keysToFetch: keys)
        request.sortOrder = .userDefault

        DispatchQueue.global(qos: .userInitiated).async {
            var fetched: [CNContact] = []
            do {
                try self.store.enumerateContacts(with: request) { contact, _ in
                    if !contact.phoneNumbers.isEmpty { fetched.append(contact) }
                }
            } catch { }

            DispatchQueue.main.async {
                self.contacts = fetched
            }
        }
    }
}

struct ContactsPanel: View {
    @ObservedObject var contactsManager: ContactsManager
    @Binding var query: String

    private var filtered: [CNContact] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return contactsManager.contacts }

        return contactsManager.contacts.filter { c in
            let name = "\(c.givenName) \(c.familyName)".lowercased()
            let phone = c.phoneNumbers.first?.value.stringValue.lowercased() ?? ""
            return name.contains(q) || phone.contains(q)
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            if !contactsManager.isAuthorized {
                VStack(spacing: 12) {
                    Text("Necesito permiso para mostrar tus contactos.")
                        .font(.system(size: 16, weight: .semibold))

                    Button("Dar permiso") {
                        contactsManager.requestAccessAndFetch()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.top, 10)

                Spacer(minLength: 0)
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(filtered, id: \.identifier) { c in
                            ContactRow(contact: c)
                        }
                    }
                    .padding(.vertical, 4)
                    .padding(.bottom, 24)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onAppear { contactsManager.requestAccessAndFetch() }
    }
}

private struct ContactRow: View {
    let contact: CNContact

    private var displayName: String {
        let full = "\(contact.givenName) \(contact.familyName)".trimmingCharacters(in: .whitespaces)
        return full.isEmpty ? "Sin nombre" : full
    }

    private var rawPhone: String? {
        contact.phoneNumbers.first?.value.stringValue
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(displayName)
                        .font(.system(size: 15, weight: .semibold))

                    Text(rawPhone ?? "Sin teléfono")
                        .font(.system(size: 13))
                        .opacity(0.85)
                }

                Spacer()

                HStack(spacing: 10) {
                    actionButton("phone.fill") { call() }
                    actionButton("message.fill") { sms() }
                    actionButton("whatsapp") { whatsapp() }
                }
            }
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func actionButton(_ systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            if systemImage == "whatsapp" {
                Text("WA")
                    .font(.system(size: 12, weight: .bold))
                    .frame(width: 36, height: 36)
                    .background(Color.primary.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else {
                Image(systemName: systemImage)
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 36, height: 36)
                    .background(Color.primary.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .buttonStyle(.plain)
    }

    private func normalizedESPhone(_ input: String) -> String {
        let digits = input.replacingOccurrences(of: "+", with: "").filter { $0.isNumber }
        if digits.hasPrefix("34") { return "+\(digits)" }
        if digits.count == 9 { return "+34\(digits)" }
        return "+\(digits)"
    }

    private func call() {
        guard let rawPhone else { return }
        let phone = normalizedESPhone(rawPhone).replacingOccurrences(of: "+", with: "")
        if let url = URL(string: "tel://\(phone)") { UIApplication.shared.open(url) }
    }

    private func sms() {
        guard let rawPhone else { return }
        let phone = normalizedESPhone(rawPhone).replacingOccurrences(of: "+", with: "")
        if let url = URL(string: "sms:\(phone)") { UIApplication.shared.open(url) }
    }

    private func whatsapp() {
        guard let rawPhone else { return }
        let phone = normalizedESPhone(rawPhone).replacingOccurrences(of: "+", with: "")
        if let url = URL(string: "https://wa.me/\(phone)") { UIApplication.shared.open(url) }
    }
}

// =====================================================
// MARK: - Calendar
// =====================================================
struct AppCalendarEventRow: Identifiable {
    let id = UUID()
    let title: String
    let startDate: Date
    let isAllDay: Bool
    let location: String?
    let calendarColor: Color
}

final class AppCalendarManager: ObservableObject {
    @Published var isAuthorized: Bool = false
    @Published var upcoming: [AppCalendarEventRow] = []

    private let store = EKEventStore()
    private var isRequestingAccess: Bool = false

    func requestAccessAndFetch() {
        let status = EKEventStore.authorizationStatus(for: .event)
        switch status {
        case .authorized:
            DispatchQueue.main.async {
                self.isAuthorized = true
                self.fetchToday()
            }

        case .notDetermined:
            guard !isRequestingAccess else { return }
            isRequestingAccess = true
            store.requestFullAccessToEvents { [weak self] granted, _ in
                DispatchQueue.main.async {
                    guard let self else { return }
                    self.isRequestingAccess = false
                    self.isAuthorized = granted
                    if granted { self.fetchToday() } else { self.upcoming = [] }
                }
            }

        default:
            DispatchQueue.main.async {
                self.isAuthorized = false
                self.upcoming = []
            }
        }
    }

    private func fetchToday() {
        let cal = Calendar.current
        let start = cal.startOfDay(for: Date())
        let end = cal.date(byAdding: .day, value: 1, to: start) ?? Date().addingTimeInterval(86400)

        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        let events = store.events(matching: predicate).sorted { $0.startDate < $1.startDate }

        self.upcoming = events.prefix(10).map { ev in
            let uiColor = UIColor(cgColor: ev.calendar.cgColor)
            return AppCalendarEventRow(
                title: ev.title ?? "Evento",
                startDate: ev.startDate,
                isAllDay: ev.isAllDay,
                location: ev.location,
                calendarColor: Color(uiColor)
            )
        }
    }
}

struct CalendarWidget: View {
    @ObservedObject var calendarManager: AppCalendarManager

    private var todaysEvents: [AppCalendarEventRow] {
        calendarManager.upcoming.filter { Calendar.current.isDateInToday($0.startDate) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !calendarManager.isAuthorized {
                Text("Permite acceso al Calendario para ver tus eventos.")
                    .font(.system(size: 14))
                    .opacity(0.85)

            } else if todaysEvents.isEmpty {
                Text("No hay eventos programados para hoy")
                    .font(.system(size: 14))
                    .opacity(0.85)

            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(todaysEvents) { ev in
                            Button { openInCalendar(ev.startDate) } label: {
                                HStack(spacing: 12) {
                                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                                        .fill(ev.calendarColor)
                                        .frame(width: 4)
                                        .frame(maxHeight: .infinity)

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(ev.title)
                                            .font(.system(size: 14, weight: .semibold))
                                            .lineLimit(1)

                                        Text(eventSubtitle(ev))
                                            .font(.system(size: 12))
                                            .opacity(0.85)
                                            .lineLimit(1)
                                    }

                                    Spacer(minLength: 0)
                                }
                                .padding(10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(.ultraThinMaterial)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }
            }
        }
        .foregroundStyle(.primary)
        .onAppear { calendarManager.requestAccessAndFetch() }
    }

    private func openInCalendar(_ date: Date) {
        let interval = date.timeIntervalSinceReferenceDate
        if let url = URL(string: "calshow:\(interval)") { UIApplication.shared.open(url) }
    }

    private func eventSubtitle(_ ev: AppCalendarEventRow) -> String {
        if ev.isAllDay {
            if let loc = ev.location, !loc.isEmpty { return "Todo el día · \(loc)" }
            return "Todo el día"
        } else {
            let t = shortTime(ev.startDate)
            if let loc = ev.location, !loc.isEmpty { return "\(t) · \(loc)" }
            return t
        }
    }

    private func shortTime(_ date: Date) -> String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "es_ES")
        df.dateFormat = "HH:mm"
        return df.string(from: date)
    }
}

// =====================================================
// MARK: - Device status (wifi/battery simple)
// =====================================================
final class DeviceStatus: ObservableObject {
    @Published var isOnWiFi: Bool = false
    @Published var isOnCellular: Bool = false
    @Published var isOnline: Bool = true
    @Published var batteryLevel: Int = 100
    @Published var isCharging: Bool = false

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "DeviceStatus.NWPathMonitor")

    init() {
        startNetworkMonitoring()
        startBatteryMonitoring()
        refreshBattery()
    }

    deinit {
        monitor.cancel()
        UIDevice.current.isBatteryMonitoringEnabled = false
        NotificationCenter.default.removeObserver(self)
    }

    private func startNetworkMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isOnline = (path.status == .satisfied)
                self.isOnWiFi = path.usesInterfaceType(.wifi)
                self.isOnCellular = path.usesInterfaceType(.cellular)
            }
        }
        monitor.start(queue: queue)
    }

    private func startBatteryMonitoring() {
        UIDevice.current.isBatteryMonitoringEnabled = true
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(batteryChanged),
                                               name: UIDevice.batteryLevelDidChangeNotification,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(batteryChanged),
                                               name: UIDevice.batteryStateDidChangeNotification,
                                               object: nil)
    }

    @objc private func batteryChanged() { refreshBattery() }

    private func refreshBattery() {
        let level = UIDevice.current.batteryLevel
        if level >= 0 { batteryLevel = Int(round(level * 100)) }
        let state = UIDevice.current.batteryState
        isCharging = (state == .charging || state == .full)
    }

    func batterySymbolName() -> String {
        let lvl = batteryLevel
        let base: String
        switch lvl {
        case 0...9: base = "battery.0"
        case 10...34: base = "battery.25"
        case 35...59: base = "battery.50"
        case 60...84: base = "battery.75"
        default: base = "battery.100"
        }
        return isCharging ? "\(base).bolt" : base
    }

    func connectionSymbolName() -> String {
        if !isOnline { return "wifi.exclamationmark" }
        if isOnWiFi { return "wifi" }
        if isOnCellular { return "antenna.radiowaves.left.and.right" }
        return "network"
    }
}

struct SideStatusBar: View {
    @StateObject private var status = DeviceStatus()
    private let timer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()
    @State private var now = Date()

    var body: some View {
        VStack(spacing: 6) {
            Text(timeString(now))
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)

            HStack(spacing: 6) {
                Image(systemName: status.connectionSymbolName())
                    .font(.system(size: 13, weight: .semibold))
                    .opacity(0.95)

                Image(systemName: status.batterySymbolName())
                    .font(.system(size: 14, weight: .semibold))
            }
            .lineLimit(1)
            .minimumScaleFactor(0.8)
        }
        .foregroundStyle(.primary)
        .padding(.top, 8)
        .padding(.bottom, 4)
        .frame(maxWidth: .infinity)
        .onReceive(timer) { _ in now = Date() }
    }

    private func timeString(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "es_ES")
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }
}

// =====================================================
// MARK: - Location
// =====================================================
final class AppLocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var coordinate: CLLocationCoordinate2D? = nil

    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }

    func requestPermission() {
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        coordinate = locations.last?.coordinate
    }
}

// =====================================================
// MARK: - Now Playing
// =====================================================
final class NowPlayingManager: ObservableObject {
    @Published var title: String = "Nada reproduciéndose"
    @Published var artist: String = ""
    @Published var isPlaying: Bool = false
    @Published var artwork: UIImage? = nil
    @Published var elapsed: TimeInterval = 0
    @Published var duration: TimeInterval = 0

    private let player = MPMusicPlayerController.systemMusicPlayer
    private var timer: AnyCancellable?

    func start() {
        player.beginGeneratingPlaybackNotifications()

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(refresh),
                                               name: .MPMusicPlayerControllerNowPlayingItemDidChange,
                                               object: player)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(refresh),
                                               name: .MPMusicPlayerControllerPlaybackStateDidChange,
                                               object: player)

        timer = Timer.publish(every: 0.5, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.refresh() }

        refresh()
    }

    func stop() {
        timer?.cancel()
        timer = nil
        NotificationCenter.default.removeObserver(self)
        player.endGeneratingPlaybackNotifications()
    }

    func togglePlayPause() {
        if player.playbackState == .playing { player.pause() }
        else { player.play() }
        refresh()
    }

    func next() {
        player.skipToNextItem()
        refresh()
    }

    func previous() {
        player.skipToPreviousItem()
        refresh()
    }

    @objc func refresh() {
        if let item = player.nowPlayingItem {
            let t = item.title ?? "Reproduciendo…"
            let a = item.artist ?? item.albumTitle ?? ""
            let playing = (player.playbackState == .playing)

            let dur = max(0, item.playbackDuration)
            let el = max(0, player.currentPlaybackTime)

            DispatchQueue.main.async {
                self.title = t
                self.artist = a
                self.isPlaying = playing
                self.duration = dur
                self.elapsed = min(el, dur > 0 ? dur : el)

                if let aw = item.artwork {
                    self.artwork = aw.image(at: CGSize(width: 500, height: 500))
                } else {
                    self.artwork = nil
                }
            }
            return
        }

        if let info = MPNowPlayingInfoCenter.default().nowPlayingInfo {
            let t = (info[MPMediaItemPropertyTitle] as? String) ?? ""
            let a = (info[MPMediaItemPropertyArtist] as? String) ?? ((info[MPMediaItemPropertyAlbumTitle] as? String) ?? "")
            let playing = (info[MPNowPlayingInfoPropertyPlaybackRate] as? Double ?? 0) > 0

            let dur = max(0, info[MPMediaItemPropertyPlaybackDuration] as? TimeInterval ?? 0)
            let el = max(0, info[MPNowPlayingInfoPropertyElapsedPlaybackTime] as? TimeInterval ?? 0)

            var img: UIImage? = nil
            if let art = info[MPMediaItemPropertyArtwork] as? MPMediaItemArtwork {
                img = art.image(at: CGSize(width: 500, height: 500))
            }

            DispatchQueue.main.async {
                self.title = t.isEmpty ? (playing ? "Reproduciendo…" : "En pausa") : t
                self.artist = a
                self.isPlaying = playing
                self.duration = dur
                self.elapsed = min(el, dur > 0 ? dur : el)
                self.artwork = img
            }
            return
        }

        DispatchQueue.main.async {
            self.title = "Nada reproduciéndose"
            self.artist = "Pon música en Spotify/Apple Music"
            self.isPlaying = false
            self.artwork = nil
            self.elapsed = 0
            self.duration = 0
        }
    }
}

// =====================================================
// MARK: - Music UI
// =====================================================
struct CarPlayNowPlayingPanel: View {
    @ObservedObject var np: NowPlayingManager

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(Color.primary.opacity(0.08))
                        .frame(width: 150, height: 150)

                    if let img = np.artwork {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 150, height: 150)
                            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    } else {
                        Image(systemName: np.isPlaying ? "speaker.wave.2.fill" : "music.note")
                            .font(.system(size: 44, weight: .semibold))
                            .opacity(0.70)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(np.title)
                        .font(.system(size: 20, weight: .bold))
                        .lineLimit(2)

                    Text(np.artist.isEmpty ? (np.isPlaying ? "En reproducción" : "En pausa") : np.artist)
                        .font(.system(size: 15, weight: .semibold))
                        .opacity(0.75)
                        .lineLimit(1)

                    Spacer(minLength: 0)

                    if np.duration > 1 {
                        VStack(spacing: 8) {
                            ProgressView(value: min(max(np.elapsed, 0), np.duration), total: np.duration)
                                .progressViewStyle(.linear)
                                .tint(.primary)
                                .opacity(0.95)

                            HStack {
                                Text(timeString(np.elapsed))
                                    .font(.system(size: 12, weight: .semibold))
                                    .monospacedDigit()
                                    .opacity(0.75)

                                Spacer()

                                Text(timeString(np.duration))
                                    .font(.system(size: 12, weight: .semibold))
                                    .monospacedDigit()
                                    .opacity(0.55)
                            }
                        }
                    }
                }

                Spacer(minLength: 0)
            }

            HStack(spacing: 12) {
                musicBtn("backward.fill") { np.previous() }

                musicBtn(np.isPlaying ? "pause.fill" : "play.fill") { np.togglePlayPause() }
                    .frame(maxWidth: .infinity)

                musicBtn("forward.fill") { np.next() }
            }
        }
        .onAppear { np.refresh() }
    }

    private func musicBtn(_ system: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: system)
                .font(.system(size: 18, weight: .semibold))
                .frame(height: 52)
                .frame(maxWidth: .infinity)
                .background(Color.primary.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func timeString(_ t: TimeInterval) -> String {
        let s = max(0, Int(t.rounded()))
        let m = s / 60
        let r = s % 60
        return String(format: "%d:%02d", m, r)
    }
}

struct RightNowPlayingCompactCard: View {
    @ObservedObject var np: NowPlayingManager

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.primary.opacity(0.08))
                        .frame(width: 76, height: 76)

                    if let img = np.artwork {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 76, height: 76)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    } else {
                        Image(systemName: np.isPlaying ? "speaker.wave.2.fill" : "speaker.slash.fill")
                            .font(.system(size: 22, weight: .semibold))
                            .opacity(0.75)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(np.title)
                        .font(.system(size: 15, weight: .semibold))
                        .lineLimit(1)

                    Text(np.artist.isEmpty ? (np.isPlaying ? "En reproducción" : "En pausa") : np.artist)
                        .font(.system(size: 13))
                        .opacity(np.artist.isEmpty ? 0.6 : 0.85)
                        .lineLimit(1)
                }

                Spacer()
            }

            if np.duration > 1 {
                ProgressView(value: min(max(np.elapsed, 0), np.duration), total: np.duration)
                    .progressViewStyle(.linear)
                    .tint(.primary)
                    .opacity(0.9)
            }

            HStack(spacing: 12) {
                compactBtn("backward.fill") { np.previous() }
                compactBtn(np.isPlaying ? "pause.fill" : "play.fill") { np.togglePlayPause() }
                    .frame(maxWidth: .infinity)
                compactBtn("forward.fill") { np.next() }
            }
        }
        .onAppear { np.refresh() }
    }

    private func compactBtn(_ system: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: system)
                .font(.system(size: 16, weight: .semibold))
                .frame(height: 44)
                .frame(maxWidth: .infinity)
                .background(Color.primary.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

// =====================================================
// MARK: - Helpers
// =====================================================
private func hideKeyboard() {
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                    to: nil, from: nil, for: nil)
}
