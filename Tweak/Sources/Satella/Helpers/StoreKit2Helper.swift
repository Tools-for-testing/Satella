import Foundation
import StoreKit
import Jinx

/// StoreKit2Helper provides compatibility with newer StoreKit 2 APIs introduced in iOS 15+
/// while maintaining backward compatibility with older iOS versions
@available(iOS 15.0, *)
final class StoreKit2Helper {
    static let shared = StoreKit2Helper()
    
    /// Tracks if we've set up StoreKit 2 transaction listener
    private var hasSetupTransactionListener = false
    
    /// Cached products for StoreKit 2
    private var sk2Products: [Product] = []
    
    /// Maps StoreKit 1 product identifiers to StoreKit 2 products
    private var productIdToSK2Product: [String: Product] = [:]
    
    /// Initialize the StoreKit 2 helper and set up transaction listeners if needed
    func initialize() {
        if !hasSetupTransactionListener {
            setupTransactionListener()
            hasSetupTransactionListener = true
        }
    }
    
    /// Set up StoreKit 2 transaction listener to handle transactions in real-time
    private func setupTransactionListener() {
        // Listen for transactions updates
        Task {
            for await verificationResult in Transaction.updates {
                // For each transaction update, handle it by creating a fake verified transaction
                await handleTransactionUpdate(verificationResult)
            }
        }
    }
    
    /// Handle a transaction update from StoreKit 2
    private func handleTransactionUpdate(_ verificationResult: VerificationResult<Transaction>) async {
        // We ignore the verification result and create a "verified" transaction
        switch verificationResult {
        case .verified(let transaction):
            // Already verified, just finish it
            await transaction.finish()
        case .unverified:
            // Create a fake verified transaction for unverified ones
            if let transaction = try? verificationResult.payloadValue {
                await transaction.finish()
            }
        }
    }
    
    /// Get StoreKit 2 products for given identifiers
    func products(for identifiers: Set<String>) async -> [Product] {
        // Return cached products if we already have them
        if !sk2Products.isEmpty {
            return sk2Products
        }
        
        // Try to load real products first
        do {
            let realProducts = try await Product.products(for: identifiers)
            if !realProducts.isEmpty {
                sk2Products = realProducts
                
                // Update mapping
                for product in realProducts {
                    productIdToSK2Product[product.id] = product
                }
                
                return realProducts
            }
        } catch {
            // Failed to load real products, fall back to fake ones
            print("StoreKit2Helper: Failed to load real products, creating fake ones")
        }
        
        // Create fake products when real ones can't be loaded
        var fakeProducts: [Product] = []
        for identifier in identifiers {
            if let fakeProduct = await createFakeProduct(for: identifier) {
                fakeProducts.append(fakeProduct)
                productIdToSK2Product[identifier] = fakeProduct
            }
        }
        
        sk2Products = fakeProducts
        return fakeProducts
    }
    
    /// Create a fake Product for StoreKit 2
    private func createFakeProduct(for id: String) async -> Product? {
        // We use private API to create a fake Product since there's no public initializer
        // This is necessary to provide a seamless experience for apps expecting StoreKit 2
        let productClass: AnyClass = Product.self
        
        guard let product = object_getClass(productClass)?.alloc() as? Product else {
            return nil
        }
        
        let fakeProductDict: [String: Any] = [
            "id": id,
            "type": Product.ProductType.nonConsumable.rawValue,
            "displayName": id,
            "description": id,
            "price": 0.01,
            "displayPrice": "$0.01"
        ]
        
        // Use KVC to set private properties (this is why we're in a tweak)
        for (key, value) in fakeProductDict {
            product.setValue(value, forKey: key)
        }
        
        return product
    }
    
    /// Purchase a product using StoreKit 2
    func purchase(productId: String) async -> Transaction? {
        guard let product = productIdToSK2Product[productId] else {
            // If we don't have the product yet, try to load it
            let newProducts = await products(for: [productId])
            guard let product = newProducts.first else {
                return nil
            }
            
            // Store the product for future reference
            productIdToSK2Product[productId] = product
        }
        
        do {
            // Create a fake successful purchase result
            let purchaseResult = try await createFakePurchaseResult(for: product)
            
            // Return the transaction from our fake purchase result
            let transaction = try purchaseResult.payloadValue
            // Mark it as finished in the system
            await transaction.finish()
            
            return transaction
        } catch {
            return nil
        }
    }
    
    /// Create a fake purchase result with a verified transaction
    private func createFakePurchaseResult(for product: Product) async throws -> VerificationResult<Transaction> {
        // Use private APIs to create a fake transaction
        let transactionClass: AnyClass = Transaction.self
        
        guard let transaction = object_getClass(transactionClass)?.alloc() as? Transaction else {
            throw NSError(domain: "StoreKit2Helper", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create transaction"])
        }
        
        let now = Date()
        let transactionId = UUID().uuidString
        
        // Set the private properties on the transaction
        let transactionDict: [String: Any] = [
            "productID": product.id,
            "productType": product.type.rawValue,
            "purchaseDate": now,
            "expirationDate": Date(timeIntervalSinceNow: 365 * 24 * 60 * 60), // 1 year from now
            "webOrderLineItemID": transactionId,
            "revocationDate": nil,
            "revocationReason": nil,
            "originalID": transactionId,
            "originalPurchaseDate": now,
            "purchasedQuantity": 1,
            "appAccountToken": UUID()
        ]
        
        // Set the values using KVC
        for (key, value) in transactionDict {
            transaction.setValue(value, forKey: key)
        }
        
        // Create a verified result using private initializer
        // Since we can't actually use the private initializer, we'll just return the transaction
        // and handle it as if it was verified
        let selectorName = "initWithPayloadValue:verificationState:"
        let selector = NSSelectorFromString(selectorName)
        
        if let verificationResult = VerificationResult<Transaction>.perform(selector, with: [transaction, 0]) as? VerificationResult<Transaction> {
            return verificationResult
        }
        
        // Fallback to creating our own verification result representation
        let verificationResultClass: AnyClass = object_getClass(VerificationResult<Transaction>.self)!
        let verificationResult = verificationResultClass.alloc() as! VerificationResult<Transaction>
        
        // Set the private properties for verification result
        verificationResult.setValue(transaction, forKey: "payloadValue")
        verificationResult.setValue(0, forKey: "verificationState") // 0 represents verified
        
        return verificationResult
    }
    
    /// Get a StoreKit 2 receipt for the given product
    func generateReceipt(for productId: String) -> Data? {
        // Generate a JWS receipt format used by StoreKit 2
        let receiptGenerator = ReceiptGenerator()
        return receiptGenerator.generateJWSReceipt(for: productId)
    }
}
