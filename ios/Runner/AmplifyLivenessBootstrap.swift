import Amplify
import AWSCognitoAuthPlugin
import AWSPluginsCore
import Foundation

/// Configures Amplify Auth once for AWS Face Liveness (iOS).
enum AmplifyLivenessBootstrap {
  private static var didConfigure = false

  static var isConfigured: Bool { didConfigure }

  static func configureIfNeeded() {
    guard !didConfigure else { return }

    do {
      try Amplify.add(plugin: AWSCognitoAuthPlugin())
      try Amplify.configure()
      didConfigure = true
      print("✅ Amplify configured for Face Liveness")
      verifyGuestCredentials()
    } catch {
      print("❌ Amplify configure failed: \(error)")
      print(
        "   Check ios/Runner/amplifyconfiguration.json — PoolId format: ap-south-1:uuid"
      )
    }
  }

  private static func verifyGuestCredentials() {
    Task {
      do {
        let session = try await Amplify.Auth.fetchAuthSession()
        print("✅ Amplify auth session fetched isSignedIn=\(session.isSignedIn)")

        guard let awsSession = session as? AuthAWSCredentialsProvider else {
          print("❌ Auth session is not AuthAWSCredentialsProvider — check amplifyconfiguration.json")
          return
        }

        let credsResult = await awsSession.getAWSCredentials()
        switch credsResult {
        case .success(let creds):
          let prefix = String(creds.accessKeyId.prefix(4))
          print("✅ Cognito guest AWS credentials OK (access key \(prefix)…)")
        case .failure(let err):
          print("❌ Cognito getAWSCredentials failed: \(err)")
          print("   Fix Identity Pool ID (ap-south-1:uuid) and enable guest access")
        }
      } catch {
        print("❌ Cognito guest credentials failed: \(error)")
        print("   Fix Identity Pool ID or unauth role StartFaceLivenessSession policy")
      }
    }
  }
}
