import Jinx
import StoreKit

/// Main Tweak structure - handles initialization and setup of all components
/// This upgraded version works on iOS 16-18+ and supports both jailbroken and non-jailbroken devices
struct Tweak {
    /// Flag to track if the tweak has been initialized
    private static var isInitialized = false
    
    /// Operating environment of the tweak
    enum Environment {
        case jailbroken       // Normal jailbreak environment
        case nonJailbroken    // Non-jailbroken device
        case sideloaded       // Sideloaded app without jailbreak
        case unknown          // Environment not yet detected
    }
    
    /// Current detected environment
    static var environment: Environment = .unknown
    
    /// Version information
    static let version = "2.0.0"
    static let compatibleiOSVersions = "iOS 16.0 - 18.x+"
    
    /// Initialize the tweak
    static func ctor() {
        // Avoid double initialization
        guard !isInitialized else { return }
        
        print("Satella \(version): Initializing for \(compatibleiOSVersions)")
        
        // Only inject into apps, not system processes
        guard CommandLine.arguments[0].hasPrefix("/var/containers/Bundle/Application"),
              Preferences.shouldInject()
        else {
            print("Satella: Skipping injection - not an app or not in preferences")
            return
        }
        
        // Detect and initialize for the appropriate environment
        detectAndInitializeEnvironment()
        
        // Apply the appropriate hooks based on environment
        applyHooks()
        
        isInitialized = true
        print("Satella \(version): Initialized successfully for \(compatibleiOSVersions) in \(environment) environment")
    }
    
    /// Detects the environment and initializes the appropriate components
    private static func detectAndInitializeEnvironment() {
        // Initialize all environment helpers to determine which one applies
        NonJailbrokenLoader.shared.initialize()
        SideloadHelper.shared.initialize()
        
        // Determine the environment based on helper detection
        if NonJailbrokenLoader.shared.isNonJailbroken {
            environment = .nonJailbroken
            print("Satella: Detected non-jailbroken environment")
        } else if SideloadHelper.shared.isSideloaded {
            environment = .sideloaded
            print("Satella: Detected sideloaded environment")
        } else {
            environment = .jailbroken
            print("Satella: Detected jailbroken environment")
        }
    }
    
    /// Applies the appropriate hooks based on environment and preferences
    private static func applyHooks() {
        // Apply hooks based on environment
        switch environment {
        case .jailbroken:
            applyJailbrokenHooks()
        case .nonJailbroken:
            applyNonJailbrokenHooks()
        case .sideloaded:
            applySideloadedHooks()
        case .unknown:
            // Fall back to basic hooks that should work in any environment
            applyBasicHooks()
        }
        
        // Always apply stealth mechanisms for iOS 16-18 compatibility
        applyStealthMechanisms()
        
        // Initialize StoreKit 2 support for iOS 15+
        initializeStoreKit2()
    }
    
    /// Applies hooks for jailbroken environment
    private static func applyJailbrokenHooks() {
        print("Satella: Applying jailbroken hooks")
        
        // Core StoreKit hooks
        CanPayHook().hook()
        TransactionHook().hook()
        
        // Optional hooks based on preferences
        if Preferences.isPriceZero { ProductHook().hook() }
        if Preferences.isObserver { ObserverHook().hook() }
        if Preferences.isSideloaded { DelegateHook().hook() }
        
        // Receipt validation hooks
        if Preferences.isReceipt {
            ReceiptHook().hook()
            URLHook().hook()
        }
    }
    
    /// Applies hooks for non-jailbroken environment
    private static func applyNonJailbrokenHooks() {
        print("Satella: Applying non-jailbroken hooks")
        
        // Core StoreKit hooks using alternative hooking methods
        // These avoid using substrate/substitute which aren't available on non-jailbroken devices
        CanPayHook().hook() // Still works with Jinx's alternative hooking mode
        
        // Use method swizzling for essential functionality
        swizzleStoreKitMethods()
        
        // Receipt validation hooks - also work with Jinx's alternative hooking
        if Preferences.isReceipt {
            ReceiptHook().hook()
            URLHook().hook()
        }
    }
    
    /// Applies hooks for sideloaded environment
    private static func applySideloadedHooks() {
        print("Satella: Applying sideloaded hooks")
        
        // Delegate to the SideloadHelper for sideload-specific hooks
        // It handles its own hooking strategy optimized for sideloaded apps
        SideloadHelper.shared.applySideloadStoreKitHooks()
        
        // We still apply some basic hooks that work in sideloaded environment
        CanPayHook().hook() // Works with Jinx's lightweight mode
        
        // Receipt validation hooks
        if Preferences.isReceipt {
            URLHook().hook()
        }
    }
    
    /// Applies basic hooks that should work in any environment
    private static func applyBasicHooks() {
        print("Satella: Applying basic hooks")
        
        // Apply minimal set of hooks that should work anywhere
        CanPayHook().hook()
        
        // Use method swizzling for essential functionality
        swizzleStoreKitMethods()
    }
    
    /// Method swizzling for StoreKit - used when substrate/substitute isn't available
    private static func swizzleStoreKitMethods() {
        // Swizzle SKPaymentTransaction.transactionState to always return purchased
        if let transactionClass = objc_getClass("SKPaymentTransaction") as? AnyClass {
            let origSel = #selector(getter: SKPaymentTransaction.transactionState)
            let swizzledSel = #selector(SKPaymentTransaction.swizzled_transactionState)
            
            guard let origMethod = class_getInstanceMethod(transactionClass, origSel),
                  let swizzledMethod = class_getInstanceMethod(SKPaymentTransaction.self, swizzledSel) else {
                return
            }
            
            method_exchangeImplementations(origMethod, swizzledMethod)
        }
        
        // Other StoreKit swizzling as needed
    }
    
    /// Applies stealth mechanisms for all environments
    private static func applyStealthMechanisms() {
        // Basic jailbreak hiding for all environments
        if Preferences.isStealth || environment != .jailbroken {
            // Apply stealth mechanisms appropriate for the environment
            applyCoreStealth()
            
            // Apply advanced stealth for iOS 16+
            if #available(iOS 16.0, *) {
                applyAdvancedStealth()
            }
        }
    }
    
    /// Applies core stealth mechanisms for all environments
    private static func applyCoreStealth() {
        // Basic hiding of dylib presence
        DyldHook().hook()
        
        // Hide jailbreak file paths
        FileExistenceHook().hook()
    }
    
    /// Applies advanced stealth mechanisms for iOS 16+
    @available(iOS 16.0, *)
    private static func applyAdvancedStealth() {
        // Advanced process hiding
        ProcessListingHook().hook()
        
        // Memory protection
        MemoryScanHook().hook()
        
        // Syscall hooks for advanced jailbreak detection prevention
        SyscallHook().hook()
    }
    
    /// Initializes StoreKit 2 support for iOS 15+
    private static func initializeStoreKit2() {
        if #available(iOS 15.0, *) {
            // Initialize the StoreKit 2 helper
            Task {
                StoreKit2Helper.shared.initialize()
                
                // Set up StoreKit 2 transaction listener
                await setupStoreKit2TransactionListener()
            }
        }
    }
    
    /// Sets up the StoreKit 2 transaction listener for iOS 15+
    @available(iOS 15.0, *)
    private static func setupStoreKit2TransactionListener() async {
        // Start listening for transaction updates in the background
        Task.detached {
            for await verificationResult in Transaction.updates {
                // For each transaction update, create a verified transaction
                switch verificationResult {
                case .verified(let transaction):
                    print("StoreKit 2: Got verified transaction for product \(transaction.productID)")
                    await transaction.finish()
                    
                case .unverified:
                    if let transaction = try? verificationResult.payloadValue {
                        print("StoreKit 2: Got unverified transaction for product \(transaction.productID)")
                        await transaction.finish()
                    }
                }
            }
        }
    }
}

/// Simple implementation of FileExistenceHook (other hooks are implemented in their own files)
struct FileExistenceHook: Hook {
    let cls: AnyClass? = NSFileManager.self
    let sel: Selector = #selector(NSFileManager.fileExists(atPath:))
    
    typealias T = @convention(c) (NSFileManager, Selector, String) -> Bool
    let replace: T = { obj, sel, path in
        // Hide common jailbreak detection paths
        let jailbreakPaths = [
            "/Applications/Cydia.app",
            "/Library/MobileSubstrate",
            "/usr/lib/libsubstrate.dylib",
            "/var/lib/cydia",
            "/var/cache/apt",
            "/private/var/lib/apt",
            "/usr/sbin/sshd",
            "/usr/bin/ssh",
            "/etc/apt",
            "/etc/ssh",
            "/.bootstrapped",
            "/usr/lib/libjailbreak.dylib",
            "/var/jb",
            "/private/var/jb",
            "/var/mobile/Library/Cydia"
        ]
        
        // If checking for a jailbreak path, return false
        if jailbreakPaths.contains(where: { path.contains($0) }) {
            return false
        }
        
        // Otherwise, return the original result
        return orig(obj, sel, path)
    }
}

/// Add a category on SKPaymentTransaction for method swizzling
extension SKPaymentTransaction {
    @objc dynamic func swizzled_transactionState() -> SKPaymentTransactionState {
        // Always return purchased to simulate successful purchases
        return .purchased
    }
}

/// Entry point for the tweak
@_cdecl("jinx_entry")
func jinxEntry() {
    Tweak.ctor()
}
