import Foundation
import Jinx
import StoreKit

/// SideloadHelper provides mechanisms for sideloading Satella into apps without a jailbreak
/// This helper handles loading, initialization, and runtime patching for sideloaded environments
final class SideloadHelper {
    /// Shared instance
    static let shared = SideloadHelper()
    
    /// Indicates if running in a sideloaded environment
    private(set) var isSideloaded = false
    
    /// Array of frameworks to inject into when they load
    private let frameworksToInject = [
        "StoreKit.framework",
        "AppleAccount.framework",
        "PassKit.framework"
    ]
    
    /// Initialize the sideload helper
    func initialize() {
        // Detect if we're running in a sideloaded environment
        isSideloaded = detectSideloadedEnvironment()
        
        if isSideloaded {
            print("Satella: Running in sideloaded mode")
            setupSideloadHooks()
        }
    }
    
    /// Detects if we're running in a sideloaded environment
    private func detectSideloadedEnvironment() -> Bool {
        // Check if we're in an app bundle
        guard let executablePath = Bundle.main.executablePath else {
            return false
        }
        
        // Check if we're sideloaded (not in App Store path or developer path)
        let isAppStore = executablePath.contains("/var/containers/Bundle/Application/")
        let isDeveloper = executablePath.contains("/private/var/mobile/Containers/Bundle/Application/")
        
        // Check for entitlements that indicate sideloading
        let hasSideloadEntitlements = checkForSideloadEntitlements()
        
        // Check for absence of jailbreak
        let notJailbroken = !FileManager.default.fileExists(atPath: "/var/lib/dpkg") &&
                            !FileManager.default.fileExists(atPath: "/var/jb") &&
                            !FileManager.default.fileExists(atPath: "/usr/lib/libsubstrate.dylib")
        
        return (isAppStore || isDeveloper) && hasSideloadEntitlements && notJailbroken
    }
    
    /// Checks for sideload-specific entitlements
    private func checkForSideloadEntitlements() -> Bool {
        // Get the main bundle's entitlements
        guard let executableURL = Bundle.main.executableURL else {
            return false
        }
        
        // Load the binary to check its code signature
        guard let task = Process.init() else {
            return false
        }
        
        // Use codesign to check entitlements
        task.launchPath = "/usr/bin/codesign"
        task.arguments = ["-d", "--entitlements", ":-", executableURL.path]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        
        do {
            try task.launch()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                // Check for specific entitlements that indicate sideloading
                let hasSideloadIndicators = output.contains("get-task-allow") || 
                                            output.contains("com.apple.developer.team-identifier") ||
                                            !output.contains("com.apple.developer.receipt-validation")
                
                return hasSideloadIndicators
            }
        } catch {
            // Default to false on error
            return false
        }
        
        return false
    }
    
    /// Sets up hooks for sideloaded environment
    private func setupSideloadHooks() {
        // Set up framework load detection
        setupFrameworkLoadDetection()
        
        // Set up app launch handling
        setupAppLaunchHandling()
        
        // Apply basic StoreKit hooks that work in sideloaded environment
        applySideloadStoreKitHooks()
    }
    
    /// Sets up detection for framework loading to inject our code
    private func setupFrameworkLoadDetection() {
        // Hook dlopen to intercept framework loading
        if let dlsymPtr = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "dlsym"),
           let dlopenPtr = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "dlopen") {
            
            typealias DlopenFunc = @convention(c) (UnsafePointer<CChar>?, Int32) -> UnsafeMutableRawPointer?
            
            let replacementDlopen: DlopenFunc = { path, mode in
                // Call original dlopen
                let handle = unsafeBitCast(dlopenPtr, to: DlopenFunc.self)(path, mode)
                
                // If we loaded a framework we're interested in, inject our hooks
                if let pathStr = path.map({ String(cString: $0) }) {
                    if self.frameworksToInject.contains(where: { pathStr.contains($0) }) {
                        print("Satella: Intercepted loading of \(pathStr)")
                        
                        // Schedule hook injection on the next run loop to avoid potential locks
                        DispatchQueue.main.async {
                            // Apply our hooks to the newly loaded framework
                            self.injectIntoLoadedFramework(pathStr)
                        }
                    }
                }
                
                return handle
            }
            
            let replacement = unsafeBitCast(replacementDlopen, to: UnsafeMutableRawPointer.self)
            Jinx.replaceFunction(dlopenPtr, with: replacement)
        }
    }
    
    /// Sets up handling for app launch to initialize our tweak
    private func setupAppLaunchHandling() {
        // Swizzle UIApplication initialization to inject our code early
        if let uiApplicationClass = objc_getClass("UIApplication") as? AnyClass {
            let originalSelector = #selector(UIApplication.shared)
            let swizzledSelector = #selector(UIApplication.appDidFinishLaunching(_:))
            
            guard let originalMethod = class_getClassMethod(uiApplicationClass, originalSelector),
                  let swizzledMethod = class_getClassMethod(UIApplication.self, swizzledSelector) else {
                return
            }
            
            // Swap implementations
            method_exchangeImplementations(originalMethod, swizzledMethod)
        }
    }
    
    /// Injects our hooks into a loaded framework
    private func injectIntoLoadedFramework(_ frameworkPath: String) {
        // Apply appropriate hooks based on the framework
        if frameworkPath.contains("StoreKit.framework") {
            print("Satella: Injecting into StoreKit framework")
            
            // Initialize the tweak for StoreKit
            DispatchQueue.main.async {
                Tweak.ctor()
            }
        }
    }
    
    /// Applies StoreKit hooks that are compatible with sideloaded environments
    private func applySideloadStoreKitHooks() {
        // These hooks are specifically designed to work in sideloaded environments
        // without requiring substrate or substitute
        
        // Apply basic StoreKit 1 hooks via method swizzling
        applySideloadStoreKit1Hooks()
        
        // Apply StoreKit 2 hooks if available
        if #available(iOS 15.0, *) {
            applySideloadStoreKit2Hooks()
        }
    }
    
    /// Applies StoreKit 1 hooks via method swizzling for sideloaded environment
    private func applySideloadStoreKit1Hooks() {
        // Hook SKPaymentQueue's canMakePayments method
        if let skPaymentQueueClass = objc_getClass("SKPaymentQueue") as? AnyClass {
            let originalSelector = #selector(SKPaymentQueue.canMakePayments)
            
            // Create a new method implementation
            let newImplementation: @convention(block) (AnyObject) -> Bool = { _ in
                return true
            }
            
            // Replace the method with our implementation
            let method = class_getClassMethod(skPaymentQueueClass, originalSelector)
            let imp = imp_implementationWithBlock(newImplementation)
            
            if let method = method {
                method_setImplementation(method, imp)
            }
        }
        
        // Hook SKPaymentTransaction's transactionState property
        if let skPaymentTransactionClass = objc_getClass("SKPaymentTransaction") as? AnyClass {
            let originalSelector = #selector(getter: SKPaymentTransaction.transactionState)
            
            // Create a new method implementation that always returns purchased
            let newImplementation: @convention(block) (AnyObject) -> SKPaymentTransactionState = { _ in
                return .purchased
            }
            
            // Replace the method with our implementation
            let method = class_getInstanceMethod(skPaymentTransactionClass, originalSelector)
            let imp = imp_implementationWithBlock(newImplementation)
            
            if let method = method {
                method_setImplementation(method, imp)
            }
        }
    }
    
    /// Applies StoreKit 2 hooks for sideloaded environment
    @available(iOS 15.0, *)
    private func applySideloadStoreKit2Hooks() {
        // Here we would implement StoreKit 2 hooks
        // This is more complex and would require runtime modification of StoreKit 2 classes
        
        // Initialize the StoreKit 2 helper
        StoreKit2Helper.shared.initialize()
    }
}

// MARK: - UIApplication Extensions

extension UIApplication {
    /// Swizzled method that gets called when the app is initialized
    @objc class func appDidFinishLaunching(_ application: UIApplication) {
        // Call original implementation
        appDidFinishLaunching(application)
        
        // Initialize our tweak
        DispatchQueue.main.async {
            SideloadHelper.shared.initialize()
        }
    }
}
