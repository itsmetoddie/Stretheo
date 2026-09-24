//
//  AuthManager.swift
//  Stretheo
//
//  Optional Sign in with Apple. Health and stress features do not require an account.
//  Revoke tokens at https://appleid.apple.com — local identifiers are cleared on deleteAccount().
//

import AuthenticationServices
import Foundation
import UIKit

@MainActor
final class AuthManager: NSObject {
    static let shared = AuthManager()

    private(set) var isSignedIn: Bool = false
    private(set) var displayNameFromApple: String?
    private(set) var emailFromApple: String?
    private(set) var credentialState: ASAuthorizationAppleIDProvider.CredentialState = .notFound

    private var signInDelegate: AppleSignInDelegate?

    private override init() {
        super.init()
        guard FeatureFlags.signInWithAppleEnabled else { return }
        Task { await refreshSessionState() }
    }

    func refreshSessionState() async {
        guard FeatureFlags.signInWithAppleEnabled else {
            isSignedIn = false
            credentialState = .notFound
            return
        }
        try? await KeychainManager.shared.purgeLegacyAppleIdentityToken()
        guard let userID = await KeychainManager.shared.appleUserIdentifier() else {
            isSignedIn = false
            credentialState = .notFound
            return
        }
        isSignedIn = true
        let provider = ASAuthorizationAppleIDProvider()
        credentialState = await withCheckedContinuation { continuation in
            provider.getCredentialState(forUserID: userID) { state, _ in
                continuation.resume(returning: state)
            }
        }
        if credentialState == .revoked || credentialState == .notFound {
            try? await KeychainManager.shared.deleteAppleUserIdentifier()
            isSignedIn = false
            displayNameFromApple = nil
            emailFromApple = nil
        }
    }

    func signInWithApple() async throws {
        guard FeatureFlags.signInWithAppleEnabled else {
            throw AppError.authenticationFailed("Sign in with Apple is disabled in this build")
        }
        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.fullName, .email]

        let delegate = AppleSignInDelegate()
        signInDelegate = delegate

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = delegate
        controller.presentationContextProvider = delegate
        controller.performRequests()

        let credential = try await delegate.result()
        try await applyAppleIDCredential(credential)
        signInDelegate = nil
    }

    func processAuthorization(_ authorization: ASAuthorization) async throws {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            throw AppError.authenticationFailed("Invalid credential")
        }
        try await applyAppleIDCredential(credential)
    }

    private func applyAppleIDCredential(_ credential: ASAuthorizationAppleIDCredential) async throws {
        guard credential.identityToken != nil else {
            throw AppError.authenticationFailed("Missing identity token")
        }

        try await KeychainManager.shared.saveAppleUserIdentifier(credential.user)
        try? await KeychainManager.shared.purgeLegacyAppleIdentityToken()
        // PRIVACY FIX: Identity JWT removed — not sent to any server, no reason to persist

        isSignedIn = true
        credentialState = .authorized
        displayNameFromApple = [credential.fullName?.givenName, credential.fullName?.familyName]
            .compactMap { $0 }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)
        emailFromApple = credential.email
    }

    func signOut() async throws {
        guard FeatureFlags.signInWithAppleEnabled else { return }
        try await KeychainManager.shared.wipeAll()
        isSignedIn = false
        credentialState = .notFound
        displayNameFromApple = nil
        emailFromApple = nil
    }

    /// Clears local auth state. Apple ID token revocation must be done by the user in Apple ID settings.
    func deleteAccount() async throws {
        guard FeatureFlags.signInWithAppleEnabled else { return }
        try await signOut()
    }
}

@MainActor
private final class AppleSignInDelegate: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    private var continuation: CheckedContinuation<ASAuthorizationAppleIDCredential, Error>?

    func result() async throws -> ASAuthorizationAppleIDCredential {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
        }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            continuation?.resume(throwing: AppError.authenticationFailed("Invalid credential"))
            continuation = nil
            return
        }
        continuation?.resume(returning: credential)
        continuation = nil
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        let nsError = error as NSError
        if nsError.domain == ASAuthorizationError.errorDomain,
           nsError.code == ASAuthorizationError.canceled.rawValue {
            continuation?.resume(throwing: AppError.authenticationFailed("Sign in canceled"))
        } else {
            continuation?.resume(throwing: AppError.authenticationFailed(error.localizedDescription))
        }
        continuation = nil
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let scene = scenes.first(where: { $0.activationState == .foregroundActive }) ?? scenes.first
        guard let scene else {
            preconditionFailure("No UIWindowScene available for Sign in with Apple presentation")
        }
        if let window = scene.windows.first(where: \.isKeyWindow) ?? scene.windows.first {
            return window
        }
        return ASPresentationAnchor(windowScene: scene)
    }
}
