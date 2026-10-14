import AuthenticationServices
import SwiftUI

/// Sign in with Apple tugmasi — matn ilova tilida (tizim `SignInWithAppleButton`
/// matni qurilma tiliga bog'langan, ilova tiliga emas). Dizayn Apple HIG'ga
/// mos: qora fon, oq Apple logotipi va matn.
struct LocalizedAppleButton: View {
    let title: String
    var scopes: [ASAuthorization.Scope] = [.fullName, .email]
    var height: CGFloat = 44
    var compact = false
    let onCompletion: (Result<ASAuthorization, Error>) -> Void

    @StateObject private var coordinator = AppleSignInCoordinator()

    var body: some View {
        Button {
            coordinator.start(scopes: scopes, completion: onCompletion)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "apple.logo")
                Text(title).lineLimit(1).minimumScaleFactor(0.8)
            }
            .font(.system(size: compact ? 12 : 17, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, compact ? 12 : 0)
            .frame(maxWidth: compact ? nil : .infinity)
            .frame(height: height)
            .background(Color.black, in: RoundedRectangle(cornerRadius: compact ? height / 2 : 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}

final class AppleSignInCoordinator: NSObject, ObservableObject,
    ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding
{
    private var completion: ((Result<ASAuthorization, Error>) -> Void)?
    private var controller: ASAuthorizationController?

    func start(scopes: [ASAuthorization.Scope], completion: @escaping (Result<ASAuthorization, Error>) -> Void) {
        self.completion = completion
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = scopes
        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        self.controller = controller
        controller.performRequests()
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        completion?(.success(authorization))
        completion = nil
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        completion?(.failure(error))
        completion = nil
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        return scene?.windows.first(where: { $0.isKeyWindow }) ?? ASPresentationAnchor()
    }
}
