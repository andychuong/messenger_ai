import Foundation
import Combine
import FirebaseAuth
import FirebaseFirestore

@MainActor
class AuthService: ObservableObject {
    @Published var currentUser: User?
    @Published var isAuthenticated = false
    @Published var isLoading = true  // Start as loading
    
    private let auth = Auth.auth()
    private let db = Firestore.firestore()
    private var authStateHandle: AuthStateDidChangeListenerHandle?
    
    static var shared: AuthService?
    
    init() {
        Self.shared = self
        
        authStateHandle = auth.addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                if let user = user {
                    await self?.fetchUserData(userId: user.uid)
                    PresenceService.shared.startMonitoring()
                } else {
                    self?.currentUser = nil
                    self?.isAuthenticated = false
                    self?.isLoading = false
                    PresenceService.shared.stopMonitoring()
                }
            }
        }
    }
    
    deinit {
        if let handle = authStateHandle {
            auth.removeStateDidChangeListener(handle)
        }
    }
    
    func signUp(email: String, password: String, displayName: String) async throws {
        let result = try await auth.createUser(withEmail: email, password: password)
        
        let user = User(id: result.user.uid, email: email, displayName: displayName)
        try await db.collection(User.collectionName)
            .document(result.user.uid)
            .setData(user.toDictionary())
        
        try await updateUserStatus(userId: result.user.uid, status: .online)
        await fetchUserData(userId: result.user.uid)
        await setupNotifications(userId: result.user.uid)
        PresenceService.shared.startMonitoring()
    }
    
    func login(email: String, password: String) async throws {
        let result = try await auth.signIn(withEmail: email, password: password)
        try await updateUserStatus(userId: result.user.uid, status: .online)
        await fetchUserData(userId: result.user.uid)
        await setupNotifications(userId: result.user.uid)
        PresenceService.shared.startMonitoring()
    }
    
    func logout() async throws {
        if let userId = currentUser?.id {
            PresenceService.shared.stopMonitoring()
            try? await updateUserStatus(userId: userId, status: .offline)
            await NotificationService.shared.removeTokenFromFirestore(userId: userId)
        }
        
        try auth.signOut()
        currentUser = nil
        isAuthenticated = false
    }
    
    private func fetchUserData(userId: String) async {
        do {
            let document = try await db.collection(User.collectionName)
                .document(userId)
                .getDocument()
            
            if let user = try? document.data(as: User.self) {
                self.currentUser = user
                self.isAuthenticated = true
                self.isLoading = false
                print("✅ User data loaded: \(user.displayName)")
            } else {
                self.isLoading = false
            }
        } catch {
            print("❌ Error fetching user data: \(error.localizedDescription)")
            self.isLoading = false
        }
    }
    
    func updateProfile(displayName: String? = nil, photoURL: String? = nil) async throws {
        guard let userId = currentUser?.id else { return }
        
        var updates: [String: Any] = [:]
        if let displayName = displayName {
            updates["displayName"] = displayName
        }
        if let photoURL = photoURL {
            updates["photoURL"] = photoURL
        }
        
        try await db.collection(User.collectionName)
            .document(userId)
            .updateData(updates)
        
        await fetchUserData(userId: userId)
    }
    
    func resetPassword(email: String) async throws {
        try await auth.sendPasswordReset(withEmail: email)
    }
    
    private func setupNotifications(userId: String) async {
        let granted = await NotificationService.shared.requestPermission()
        
        if granted {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            await NotificationService.shared.saveTokenToFirestore(userId: userId)
        }
    }
    
    private func updateUserStatus(userId: String, status: User.UserStatus) async throws {
        print("🔵 Updating user status to: \(status.rawValue) for user: \(userId)")
        try await db.collection(User.collectionName)
            .document(userId)
            .updateData([
                "status": status.rawValue,
                "lastSeen": Timestamp(date: Date())
            ])
        print("✅ User status updated successfully to: \(status.rawValue)")
    }
}

