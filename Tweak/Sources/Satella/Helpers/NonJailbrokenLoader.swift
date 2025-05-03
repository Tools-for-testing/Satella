import Foundation
import Jinx

/// NonJailbrokenLoader provides mechanisms to load the tweak on non-jailbroken devices
/// It enables Satella to work with sideloaded applications without requiring a jailbreak
final class NonJailbrokenLoader {
    /// Shared instance
    static let shared = NonJailbrokenLoader()
    
    /// Indicates if we're running in a non-jailbroken environment
    private var isNonJailbroken: Bool = false
    
    /// Detects the environment and initializes loading mechanism
    func initialize() {
        // Detect if we're running on a non-jailbroken device
        isNonJailbroken = detectNonJailbrokenEnvironment()
        
        if isNonJailbroken {
            print("Satella: Running in non-jailbroken mode")
            setupNonJailbrokenHooks()
        } else {
            print("Satella: Running in jailbroken mode")
        }
    }
    
    /// Detects if we're running in a non-jailbroken environment
    private func detectNonJailbrokenEnvironment() -> Bool {
        // Check if we're injected with a sideloaded app's dylib
        if CommandLine.arguments[0].contains("Application") && !FileManager.default.fileExists(atPath: "/var/jb") && !FileManager.default.fileExists(atPath: "/var/lib/dpkg") {
            return true
        }
        
        // Check if we have substrate or substitute
        let hasMobileSubstrate = dlopen("/usr/lib/libsubstrate.dylib", RTLD_NOW) != nil
        let hasSubstitute = dlopen("/usr/lib/libsubstitute.dylib", RTLD_NOW) != nil
        
        // If we don't have either, we're probably not jailbroken
        return !(hasMobileSubstrate || hasSubstitute)
    }
    
    /// Sets up hooks for non-jailbroken environments
    private func setupNonJailbrokenHooks() {
        // On non-jailbroken devices, we need to use manual swizzling methods
        // rather than Substrate/Substitute-based hooking
        
        // Register load method for dynamic libraries
        registerDynamicLoaderHook()
        
        // Enhance stealth for non-jailbroken environment
        enhanceStealth()
    }
    
    /// Registers a hook for dynamic library loading
    private func registerDynamicLoaderHook() {
        // This is a common technique used in non-jailbroken tweaks
        // It swizzles dlopen to intercept framework loading
        
        // Store the original dlopen function
        let originalDlopen = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "dlopen")
        
        // Implement our own version that hooks into StoreKit when it's loaded
        typealias DlopenFunc = @convention(c) (UnsafePointer<Int8>?, Int32) -> UnsafeMutableRawPointer?
        
        let replacementDlopen: DlopenFunc = { path, mode in
            // Call the original dlopen
            let result = unsafeBitCast(originalDlopen, to: DlopenFunc.self)(path, mode)
            
            // If the path contains StoreKit, hook into it
            if let pathStr = path.map({ String(cString: $0) }),
               pathStr.contains("StoreKit") {
                print("Satella: Intercepted loading of StoreKit framework")
                
                // Apply our hooks to StoreKit
                DispatchQueue.main.async {
                    Tweak.ctor()
                }
            }
            
            return result
        }
        
        // Apply our dlopen hook
        let replacementDlopenPtr = unsafeBitCast(replacementDlopen, to: UnsafeMutableRawPointer.self)
        if let targetDlopen = originalDlopen {
            Jinx.replaceFunction(targetDlopen, with: replacementDlopenPtr)
        }
    }
    
    /// Enhances stealth for non-jailbroken environments
    private func enhanceStealth() {
        // Hide common jailbreak detection paths
        hideJailbreakPaths()
        
        // Hide dylib from process memory scans
        hideDylibFromMemoryScans()
    }
    
    /// Hides common jailbreak detection paths
    private func hideJailbreakPaths() {
        // Sideloaded apps still need to avoid jailbreak detection
        
        // Hook stat/lstat/access/etc. to hide common detection paths
        let pathsToHide = [
            "/Applications/Cydia.app",
            "/Library/MobileSubstrate",
            "/bin/bash",
            "/usr/sbin/sshd",
            "/etc/apt",
            "/private/var/lib/apt",
            "/private/var/lib/cydia",
            "/private/var/mobile/Library/SBSettings",
            "/private/var/stash",
            "/usr/libexec/cydia",
            "/usr/bin/cycript",
            "/usr/bin/ssh",
            "/var/cache/apt",
            "/var/lib/apt",
            "/var/lib/cydia",
            "/var/log/syslog",
            "/var/mobile/Library/Cydia",
            "/var/tmp/cydia.log",
            "/bin/sh",
            "/etc/ssh",
            "/usr/libexec/ssh-keysign"
        ]
        
        // Apply file path hooks to hide these paths
        for funcName in ["stat", "lstat", "access", "open", "__open"] {
            if let origFunc = dlsym(UnsafeMutableRawPointer(bitPattern: -2), funcName) {
                // Create a replacement function for each path checking method
                let hook: (@convention(c) (UnsafePointer<Int8>?, CInt) -> CInt) = { path, mode in
                    if let pathStr = path.map({ String(cString: $0) }),
                       pathsToHide.contains(where: { pathStr.contains($0) }) {
                        // Return ENOENT (No such file or directory) for jailbreak paths
                        errno = ENOENT
                        return -1
                    }
                    
                    // Call original function for other paths
                    let origFn = unsafeBitCast(origFunc, to: (@convention(c) (UnsafePointer<Int8>?, CInt) -> CInt).self)
                    return origFn(path, mode)
                }
                
                // Apply the hook
                let replacement = unsafeBitCast(hook, to: UnsafeMutableRawPointer.self)
                Jinx.replaceFunction(origFunc, with: replacement)
            }
        }
    }
    
    /// Hides the dylib from process memory scans
    private func hideDylibFromMemoryScans() {
        // Hide our presence from memory scanners commonly used by jailbreak detection systems
        // This is a more advanced stealth technique
        
        // Get our image name (the dylib path)
        if let imageName = _dyld_get_image_name(_dyld_image_count() - 1) {
            let imageNameStr = String(cString: imageName)
            
            // If this is our dylib, try to hide it from memory scans
            if imageNameStr.contains("Satella.dylib") {
                // Overwrite the image name in the dyld_all_image_infos
                // This is a technique that works on non-jailbroken devices
                
                // Replace our image name with something innocent
                let innocentName = "libswiftCore.dylib"
                
                if let originalDyldGetImageName = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "_dyld_get_image_name") {
                    let replacementGetImageName: (@convention(c) (UInt32) -> UnsafePointer<Int8>?) = { index in
                        let origFn = unsafeBitCast(originalDyldGetImageName, to: (@convention(c) (UInt32) -> UnsafePointer<Int8>?).self)
                        let result = origFn(index)
                        
                        if let res = result {
                            let str = String(cString: res)
                            if str.contains("Satella.dylib") {
                                return innocentName.withCString { $0 }
                            }
                        }
                        
                        return result
                    }
                    
                    let replacement = unsafeBitCast(replacementGetImageName, to: UnsafeMutableRawPointer.self)
                    Jinx.replaceFunction(originalDyldGetImageName, with: replacement)
                }
            }
        }
    }
}
