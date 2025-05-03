import Foundation
import Jinx

/// URLHook intercepts App Store receipt validation requests
/// This hook is enhanced to support both StoreKit 1 and StoreKit 2 validation endpoints
/// and works with the latest iOS 16-18 validation mechanisms
struct URLHook: Hook {
    typealias URLHandler = @Sendable (Data?, URLResponse?, Error?) -> Void
    typealias T = @convention(c) (URLSession, Selector, URLRequest, @escaping (URLHandler)) -> URLSessionDataTask

    let cls: AnyClass? = URLSession.self
    let sel: Selector = sel_registerName("dataTaskWithRequest:completionHandler:")
    let replace: T = { obj, sel, request, handler in
        // Check for any validation endpoint
        if let url = request.url?.absoluteString,
           (url.contains("/verifyReceipt") || 
            url.contains("/validate") || 
            url.contains("appStoreReceiptValidation") ||
            url.contains("/receipts/")) {
            
            // Create a new handler that intercepts the response
            let newHandler: URLHandler = { (_, response, error) in
                // Use the enhanced receipt generator to handle the validation
                // based on the request format and iOS version
                let validationResponse = ReceiptGenerator.handleValidationRequest(request)
                    ?? ReceiptGenerator.response(for: SatellaDelegate.shared.products.last?.productIdentifier ?? "")
                
                handler(validationResponse, response, error)
            }

            return orig(obj, sel, request, newHandler)
        }

        return orig(obj, sel, request, handler)
    }
}
