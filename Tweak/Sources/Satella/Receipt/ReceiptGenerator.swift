import UIKit

struct ReceiptGenerator {
    // MARK: - Types and Constants
    
    enum ReceiptFormat {
        case legacy          // Original format for iOS 7-14
        case modern          // Modern format for iOS 15-16
        case storeKit2       // JWS format for StoreKit 2 (iOS 15+)
    }
    
    // MARK: - Legacy API Methods (for backwards compatibility)
    
    static func old(for productID: String?) -> OldReceipt {
        let bundleID: String = Bundle.main.bundleIdentifier ?? "emt.paisseon.satella"
        let now: Int64 = .init(Date().timeIntervalSince1970) * 1000
        let nowDate: String = "\(Date()) Europe/Copenhagen"
        let receiptID: Int = .random(in: 1 ... 0x07151129)
        let vendorID: String = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        let version: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        
        let info: OldReceiptInfo = .init(
            appItemID: receiptID.description,
            bundleID: bundleID,
            bundleVersion: version,
            externalVersion: version,
            itemID: receiptID.description,
            originalPurchaseDate: nowDate,
            originalPurchaseDateMs: now.description,
            originalPurchaseDatePst: nowDate,
            originalTransactionID: receiptID.description,
            productID: productID ?? "emt.paisseon.satella.product",
            purchaseDate: nowDate,
            purchaseDateMs: now.description,
            purchaseDatePst: nowDate,
            quantity: "1",
            transactionID: receiptID.description,
            uniqueID: receiptID.description,
            uniqueVendorID: vendorID
        )
        
        return .init(signature: Data(signature).base64EncodedString(), purchaseInfo: info, pod: "44", signingStatus: "0")
    }
    
    static func new(for productID: String?) -> Receipt {
        let bundleID: String = Bundle.main.bundleIdentifier ?? "emt.paisseon.satella"
        let now: Int64 = .init(Date().timeIntervalSince1970) * 1000
        let nowDate: String = "\(Date()) Europe/Copenhagen"
        let receiptID: Int64 = .random(in: 1 ... 0x07151129)
        let version: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        
        // Set expiration date to 10 years from now for iOS 16-18 compatibility
        let oneDecadeFromNow = Int64(Date().timeIntervalSince1970 + 10 * 365 * 24 * 60 * 60)
        let expDate: String = "\(Date(timeIntervalSince1970: TimeInterval(oneDecadeFromNow))) Europe/Copenhagen"
        let expNow: Int64 = oneDecadeFromNow * 1000
        
        let info: ReceiptInfo = .init(
            quantity: "1",
            productID: productID ?? bundleID,
            transactionID: receiptID.description,
            originalTransactionID: receiptID.description,
            purchaseDate: nowDate,
            purchaseDateMs: now.description,
            purchaseDatePst: nowDate,
            originalPurchaseDate: nowDate,
            originalPurchaseDateMs: now.description,
            originalPurchaseDatePst: nowDate,
            expiresDate: expDate,
            expiresDateMs: expNow.description,
            expiresDatePst: expDate,
            isTrialPeriod: "false",
            isInIntroOfferPeriod: "false"
        )
        
        let receipt: Receipt = .init(
            receiptType: "Production",
            adamID: receiptID,
            appItemID: receiptID,
            bundleID: bundleID,
            applicationVersion: version,
            downloadID: Int(receiptID),
            versionExternalIDentifier: 0,
            receiptCreationDate: nowDate,
            receiptCreationDateMs: now.description,
            receiptCreationDatePst: nowDate,
            requestDate: nowDate,
            requestDateMs: now.description,
            requestDatePst: nowDate,
            originalPurchaseDate: nowDate,
            originalPurchaseDateMs: now.description,
            originalPurchaseDatePst: nowDate,
            originalApplicationVersion: version,
            inApp: [info]
        )
        
        return receipt
    }
    
    static func response(for productID: String) -> Data? {
        let receipt: Receipt = new(for: productID)
        let encoder: JSONEncoder = .init()
        var base64: String = ""
        
        do {
            let receiptData: Data = try encoder.encode(receipt)
            base64 = receiptData.base64EncodedString()
        } catch {
            return nil
        }
        
        let renewal: RenewalInfo = .init(
            autoRenewProductID: productID,
            originalTransactionID: UUID().uuidString,
            productID: productID,
            autoRenewStatus: "1"
        )
        
        let response: ReceiptResponse = .init(
            status: 0,
            environment: "Production",
            receipt: receipt,
            latestReceiptInfo: receipt.inApp,
            lastReceipt: base64,
            pendingRenewalInfo: [renewal]
        )
        
        do {
            let responseData: Data = try encoder.encode(response)
            return responseData
        } catch {
            return nil
        }
    }
    
    // MARK: - Modern API Methods (for iOS 16-18 compatibility)
    
    /// Generate a JWS receipt for StoreKit 2 (iOS 15+)
    static func generateJWSReceipt(for productId: String) -> Data? {
        let jwsString = JWSReceipt.generateJWSString(for: productId)
        return jwsString.data(using: .utf8)
    }
    
    /// Detect the appropriate receipt format based on iOS version and app
    static func detectFormat() -> ReceiptFormat {
        if #available(iOS 15.0, *) {
            // Check for StoreKit 2 usage
            if NSClassFromString("StoreKit.Product") != nil {
                return .storeKit2
            }
            return .modern
        }
        
        return .legacy
    }
    
    /// Generate a receipt in the appropriate format for the app
    static func generateReceipt(for productId: String, format: ReceiptFormat? = nil) -> Data? {
        let receiptFormat = format ?? detectFormat()
        
        switch receiptFormat {
        case .legacy:
            // For older iOS versions, use the legacy format
            let oldReceipt = old(for: productId)
            return try? JSONEncoder().encode(oldReceipt)
            
        case .modern:
            // For iOS 15-16 using StoreKit 1
            let newReceipt = new(for: productId)
            return try? JSONEncoder().encode(newReceipt)
            
        case .storeKit2:
            // For iOS 15+ using StoreKit 2
            if #available(iOS 15.0, *) {
                return generateJWSReceipt(for: productId)
            } else {
                // Fall back if needed
                let newReceipt = new(for: productId)
                return try? JSONEncoder().encode(newReceipt)
            }
        }
    }
    
    /// Enhanced method to validate receipts for both StoreKit 1 and 2
    /// This is used to intercept validation requests and provide fake validation responses
    static func handleValidationRequest(_ request: URLRequest) -> Data? {
        // Check if this is a receipt validation request
        guard let url = request.url?.absoluteString else {
            return nil
        }
        
        // Extract product ID from the request if possible
        var productId = "com.default.product"
        
        if let bodyData = request.httpBody,
           let bodyDict = try? JSONSerialization.jsonObject(with: bodyData) as? [String: Any],
           let receiptData = bodyDict["receipt-data"] as? String {
            // Try to extract product ID from the receipt data
            if let decodedData = Data(base64Encoded: receiptData),
               let receipt = try? JSONDecoder().decode(Receipt.self, from: decodedData) {
                if let inAppPurchase = receipt.inApp.first {
                    productId = inAppPurchase.productID
                }
            }
        }
        
        // Generate different response types based on URL and iOS version
        if url.contains("verifyReceipt") || url.contains("validate") {
            if #available(iOS 15.0, *) {
                // For StoreKit 2-based apps on iOS 15+
                if detectFormat() == .storeKit2 {
                    // Create a StoreKit 2 JWS validation response
                    let jwsReceipt = generateJWSReceipt(for: productId)
                    let validationResponse: [String: Any] = [
                        "status": 0,
                        "environment": "Production",
                        "receipt": ["in_app": [["product_id": productId]]],
                        "latest_receipt": jwsReceipt?.base64EncodedString() ?? "",
                        "is_retryable": false
                    ]
                    return try? JSONSerialization.data(withJSONObject: validationResponse)
                }
            }
            
            // For StoreKit 1 or older iOS
            return response(for: productId)
        }
        
        return nil
    }

    // MARK: - Private
    
    private static let signature: [UInt8] = [
        0x03, 0x42, 0xFB, 0x17, 0x13, 0xCE, 0x78, 0xFD, 0x08, 0x3D, 0xA8, 0x30, 0x13, 0xE0, 0xAE, 0xC6, 0x6D, 0x4C,
        0xA5, 0x57, 0xFC, 0x32, 0x34, 0xED, 0xA3, 0xEE, 0xC5, 0x0D, 0xB4, 0xCD, 0x03, 0xD1, 0xF1, 0x39, 0x25, 0x54,
        0xF9, 0x7C, 0xD0, 0x42, 0x4A, 0x6E, 0xAB, 0x04, 0xC8, 0x0B, 0xDB, 0x1D, 0x24, 0xB0, 0x9A, 0xBC, 0xAC, 0x33,
        0x3E, 0x37, 0xD8, 0x23, 0xFF, 0x1F, 0x58, 0x46, 0xD1, 0x7D, 0x66, 0xD3, 0x3C, 0x63, 0xF3, 0x1D, 0xD5, 0x4C,
        0xB6, 0xEE, 0x6B, 0x5D, 0x9F, 0x0E, 0x20, 0x9B, 0x10, 0xFB, 0xFA, 0xC7, 0x90, 0xB1, 0x98, 0x38, 0xEC, 0x37,
        0xBE, 0x37, 0x2F, 0x8F, 0xB5, 0x4C, 0x9C, 0x55, 0x4D, 0x09, 0xE6, 0x85, 0x8D, 0xCF, 0xBF, 0x53, 0x27, 0x4F,
        0x5B, 0x6A, 0xA6, 0x22, 0xAF, 0x2B, 0x81, 0x1A, 0x3E, 0xE7, 0xF1, 0xDD, 0x7D, 0x82, 0xD7, 0x49, 0x9F, 0xF6,
        0xC1, 0x27, 0xAA, 0xC5, 0xE1, 0x53, 0xC5, 0x84, 0x63, 0x0F, 0xCB, 0x6B, 0x1A, 0x4D, 0xBD, 0x8E, 0x3F, 0x43
    ]
}
