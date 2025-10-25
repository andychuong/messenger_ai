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
    private let encryptionService = EncryptionService.shared
    
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
        
        // Phase 6: Generate RSA key pair for encryption
        let publicKeyData = try encryptionService.generateRSAKeyPair(userId: result.user.uid)
        let publicKeyBase64 = publicKeyData.base64EncodedString()
        
        let user = User(id: result.user.uid, email: email, displayName: displayName)
        var userDict = user.toDictionary()
        userDict["publicKey"] = publicKeyBase64  // Store public key for key exchange
        
        try await db.collection(User.collectionName)
            .document(result.user.uid)
            .setData(userDict)
        
        try await updateUserStatus(userId: result.user.uid, status: .online)
        await fetchUserData(userId: result.user.uid)
        await setupNotifications(userId: result.user.uid)
        PresenceService.shared.startMonitoring()
        
        print("🔐 Phase 6: Generated encryption keys for new user")
    }
    
    func login(email: String, password: String) async throws {
        let result = try await auth.signIn(withEmail: email, password: password)
        
        // Phase 6: Ensure user has encryption keys
        await ensureEncryptionKeys(userId: result.user.uid)
        
        try await updateUserStatus(userId: result.user.uid, status: .online)
        await fetchUserData(userId: result.user.uid)
        await setupNotifications(userId: result.user.uid)
        PresenceService.shared.startMonitoring()
    }
    
    // Phase 6: Ensure user has RSA key pair
    private func ensureEncryptionKeys(userId: String) async {
        // Check if keys exist in keychain
        if encryptionService.getPublicKey(userId: userId) == nil {
            print("🔐 Phase 6: Generating encryption keys for existing user")
            do {
                // Generate new keys
                let publicKeyData = try encryptionService.generateRSAKeyPair(userId: userId)
                let publicKeyBase64 = publicKeyData.base64EncodedString()
                
                // Store public key in Firestore
                try await db.collection(User.collectionName)
                    .document(userId)
                    .updateData(["publicKey": publicKeyBase64])
                
                print("🔐 Phase 6: Encryption keys generated and stored")
            } catch {
                print("❌ Failed to generate encryption keys: \(error.localizedDescription)")
            }
        } else {
            print("🔐 Phase 6: Encryption keys already exist")
        }
    }
    
    func logout() async throws {
        if let userId = currentUser?.id {
            PresenceService.shared.stopMonitoring()
            try? await updateUserStatus(userId: userId, status: .offline)
            await NotificationService.shared.removeTokenFromFirestore(userId: userId)
            
            // Phase 6: Delete all encryption keys from keychain
            encryptionService.deleteAllUserKeys(userId: userId)
            print("🔐 Phase 6: Deleted all encryption keys on logout")
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
    
    func updatePreferredLanguage(_ language: String?) async throws {
        guard let userId = currentUser?.id else { return }
        
        let updates: [String: Any] = [
            "preferredLanguage": language as Any
        ]
        
        try await db.collection(User.collectionName)
            .document(userId)
            .updateData(updates)
        
        await fetchUserData(userId: userId)
        print("✅ Updated preferred language to: \(language ?? "none")")
    }
    
    func resetPassword(email: String) async throws {
        try await auth.sendPasswordReset(withEmail: email)
    }
    
    private func setupNotifications(userId: String) async {
        // DISABLED FOR TESTING: Push notifications disabled for device testing without APNs
        print("⚠️ Push notifications disabled - skipping setup")
        
        // let granted = await NotificationService.shared.requestPermission()
        // if granted {
        //     try? await Task.sleep(nanoseconds: 1_000_000_000)
        //     await NotificationService.shared.saveTokenToFirestore(userId: userId)
        // }
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

