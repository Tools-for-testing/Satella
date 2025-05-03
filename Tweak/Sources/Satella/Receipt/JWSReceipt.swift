import Foundation

/// JWSReceipt provides structures and helpers for generating StoreKit 2 style receipts
/// StoreKit 2 (iOS 15+) uses JWS (JSON Web Signature) format for receipts
struct JWSReceipt: Encodable {
    /// Header for the JWS
    struct Header: Encodable {
        let alg: String
        let kid: String
        let typ: String
    }
    
    /// Payload for the JWS - contains actual receipt data
    struct Payload: Encodable {
        let bundleId: String
        let transactionId: String
        let productId: String
        let purchaseDate: Int64
        let originalPurchaseDate: Int64
        let expiresDate: Int64?
        let quantity: Int
        let type: String
        let inAppOwnershipType: String
        let signedDate: Int64
        let environment: String
        let deviceVerification: String
        let deviceVerificationNonce: String
        let appAccountToken: String?
        
        enum CodingKeys: String, CodingKey {
            case bundleId = "bundleId"
            case transactionId = "transactionId"
            case productId = "productId"
            case purchaseDate = "purchaseDate"
            case originalPurchaseDate = "originalPurchaseDate"
            case expiresDate = "expiresDate"
            case quantity = "quantity"
            case type = "type"
            case inAppOwnershipType = "inAppOwnershipType"
            case signedDate = "signedDate"
            case environment = "environment"
            case deviceVerification = "deviceVerification"
            case deviceVerificationNonce = "deviceVerificationNonce"
            case appAccountToken = "appAccountToken"
        }
    }
    
    /// Generate a JWS format receipt string
    static func generateJWSString(for productId: String) -> String {
        let header = Header(
            alg: "ES256",
            kid: "W98C7HK6S6",
            typ: "JWT"
        )
        
        let bundleId = Bundle.main.bundleIdentifier ?? "com.example.app"
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        let oneYearFromNow = now + (365 * 24 * 60 * 60 * 1000)
        let transactionId = UUID().uuidString.replacingOccurrences(of: "-", with: "")
        
        let payload = Payload(
            bundleId: bundleId,
            transactionId: transactionId,
            productId: productId,
            purchaseDate: now,
            originalPurchaseDate: now,
            expiresDate: oneYearFromNow,
            quantity: 1,
            type: "Non-Consumable",
            inAppOwnershipType: "PURCHASED",
            signedDate: now,
            environment: "Production",
            deviceVerification: UUID().uuidString,
            deviceVerificationNonce: UUID().uuidString,
            appAccountToken: UUID().uuidString
        )
        
        // Encode header and payload as base64
        let headerData = try! JSONEncoder().encode(header)
        let payloadData = try! JSONEncoder().encode(payload)
        
        let headerBase64 = headerData.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        
        let payloadBase64 = payloadData.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        
        // Generate a fake signature (we need a valid signature format for JWS)
        let fakeSignatureBytes = [UInt8](repeating: 0, count: 64)
        let fakeSignatureData = Data(fakeSignatureBytes)
        let signatureBase64 = fakeSignatureData.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        
        // Combine to create the JWS format string
        return "\(headerBase64).\(payloadBase64).\(signatureBase64)"
    }
}
