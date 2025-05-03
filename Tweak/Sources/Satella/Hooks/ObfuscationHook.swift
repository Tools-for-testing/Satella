import Foundation
import Jinx

/// ObfuscationHook hides the tweak from detection mechanisms by obfuscating its presence
/// This is essential for modern iOS 16-18 detection systems that scan memory and binaries
@available(iOS 16.0, *)
struct ObfuscationHook: Hook {
    // Hook NSBundle's bundleIdentifier to hide our bundle ID in callbacks
    let cls: AnyClass? = NSBundle.self
    let sel: Selector = #selector(getter: NSBundle.bundleIdentifier)
    
    typealias T = @convention(c) (NSBundle, Selector) -> String?
    let replace: T = { bundle, sel in
        // Get the real bundle ID
        let realBundleID = orig(bundle, sel)
        
        // If this is our bundle (unlikely, but possible), return a fake ID
        if let bundleID = realBundleID, bundleID.contains("emt.paisseon.satella") {
            return "com.apple.UIKit"
        }
        
        return realBundleID
    }
    
    /// Implement all the obfuscation hooks
    func hook() {
        // Apply the base hook
        Jinx.hook(self)
        
        // Apply additional obfuscation techniques
        obfuscateDylibInfo()
        obfuscateClassNames()
        obfuscateSymbols()
        obfuscateStrings()
    }
    
    /// Obfuscates dylib information
    private func obfuscateDylibInfo() {
        // Hook dyld_image_path_containing_address to hide our dylib from address lookups
        guard let dyldPathForAddr = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "dyld_image_path_containing_address") else {
            return
        }
        
        typealias DyldPathFunc = @convention(c) (UnsafeRawPointer) -> UnsafePointer<Int8>?
        
        let replacementPathFunc: DyldPathFunc = { addr in
            // Call the original function
            let path = unsafeBitCast(dyldPathForAddr, to: DyldPathFunc.self)(addr)
            
            // If this is our dylib, return a fake system path
            if let pathStr = path.map({ String(cString: $0) }),
               pathStr.contains("Satella.dylib") {
                return "/System/Library/Frameworks/UIKit.framework/UIKit".withCString { $0 }
            }
            
            return path
        }
        
        let replacement = unsafeBitCast(replacementPathFunc, to: UnsafeMutableRawPointer.self)
        Jinx.replaceFunction(dyldPathForAddr, with: replacement)
        
        // Hook dladdr to hide our dylib's symbols
        guard let dladdrPtr = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "dladdr") else {
            return
        }
        
        typealias DladdrFunc = @convention(c) (UnsafeRawPointer, UnsafeMutablePointer<Dl_info>) -> Int32
        
        let replacementDladdr: DladdrFunc = { addr, info in
            // Call the original function
            let result = unsafeBitCast(dladdrPtr, to: DladdrFunc.self)(addr, info)
            
            // If this is our dylib, modify the info
            if result != 0,
               let fname = info.pointee.dli_fname,
               String(cString: fname).contains("Satella.dylib") {
                
                // Set fake values for the Dl_info structure
                info.pointee.dli_fname = "/System/Library/Frameworks/UIKit.framework/UIKit".withCString { strdup($0) }
                
                // For the symbol name, replace our symbols with UIKit ones
                if let sname = info.pointee.dli_sname,
                   String(cString: sname).contains("Satella") || String(cString: sname).contains("jinxEntry") {
                    info.pointee.dli_sname = "_UIApplicationMain".withCString { strdup($0) }
                }
            }
            
            return result
        }
        
        let replacementDladdrPtr = unsafeBitCast(replacementDladdr, to: UnsafeMutableRawPointer.self)
        Jinx.replaceFunction(dladdrPtr, with: replacementDladdrPtr)
    }
    
    /// Obfuscates our class names
    private func obfuscateClassNames() {
        // Hook objc_getClass to hide our class names
        guard let objcGetClassPtr = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "objc_getClass") else {
            return
        }
        
        typealias ObjcGetClassFunc = @convention(c) (UnsafePointer<Int8>?) -> AnyClass?
        
        let replacementGetClass: ObjcGetClassFunc = { name in
            // If trying to look up our classes, return nil
            if let nameStr = name.map({ String(cString: $0) }),
               nameStr.contains("Satella") || nameStr.contains("Jinx") {
                return nil
            }
            
            // Otherwise call the original function
            return unsafeBitCast(objcGetClassPtr, to: ObjcGetClassFunc.self)(name)
        }
        
        let replacement = unsafeBitCast(replacementGetClass, to: UnsafeMutableRawPointer.self)
        Jinx.replaceFunction(objcGetClassPtr, with: replacement)
        
        // Hook objc_copyClassNamesForImage to hide our classes
        guard let objcCopyClassNamesPtr = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "objc_copyClassNamesForImage") else {
            return
        }
        
        typealias ObjcCopyClassNamesFunc = @convention(c) (UnsafePointer<Int8>?, UnsafeMutablePointer<UInt32>?) -> UnsafeMutablePointer<UnsafePointer<Int8>?>?
        
        let replacementCopyNames: ObjcCopyClassNamesFunc = { image, outCount in
            // If requesting class names for our image, return empty
            if let imageStr = image.map({ String(cString: $0) }),
               imageStr.contains("Satella.dylib") {
                
                if let outCount = outCount {
                    outCount.pointee = 0
                }
                
                return nil
            }
            
            // For other images, filter out our classes from the results
            let classes = unsafeBitCast(objcCopyClassNamesPtr, to: ObjcCopyClassNamesFunc.self)(image, outCount)
            
            // If no classes, just return
            if classes == nil || outCount == nil || outCount!.pointee == 0 {
                return classes
            }
            
            // Filter the classes
            let count = Int(outCount!.pointee)
            var filteredCount = 0
            
            // Create a new buffer for filtered classes
            let buffer = UnsafeMutablePointer<UnsafePointer<Int8>?>.allocate(capacity: count)
            
            // Copy non-suspicious classes
            for i in 0..<count {
                guard let className = classes?[i] else { continue }
                let name = String(cString: className)
                
                // Skip our classes
                if name.contains("Satella") || name.contains("Jinx") {
                    continue
                }
                
                // Keep other classes
                buffer[filteredCount] = className
                filteredCount += 1
            }
            
            // Update the count
            outCount!.pointee = UInt32(filteredCount)
            
            return buffer
        }
        
        let replacementNames = unsafeBitCast(replacementCopyNames, to: UnsafeMutableRawPointer.self)
        Jinx.replaceFunction(objcCopyClassNamesPtr, with: replacementNames)
    }
    
    /// Obfuscates symbols
    private func obfuscateSymbols() {
        // Hook functions that might be used to discover symbols
        guard let dlsymPtr = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "dlsym") else {
            return
        }
        
        typealias DlsymFunc = @convention(c) (UnsafeMutableRawPointer?, UnsafePointer<Int8>?) -> UnsafeMutableRawPointer?
        
        let replacementDlsym: DlsymFunc = { handle, symbol in
            // If looking for our symbols, return nil
            if let symbolStr = symbol.map({ String(cString: $0) }) {
                let ourSymbols = [
                    "jinxEntry",
                    "Satella",
                    "StoreKit2Helper",
                    "NonJailbrokenLoader",
                    "SideloadHelper"
                ]
                
                if ourSymbols.contains(where: { symbolStr.contains($0) }) {
                    return nil
                }
            }
            
            // Call original for other symbols
            return unsafeBitCast(dlsymPtr, to: DlsymFunc.self)(handle, symbol)
        }
        
        let replacement = unsafeBitCast(replacementDlsym, to: UnsafeMutableRawPointer.self)
        Jinx.replaceFunction(dlsymPtr, with: replacement)
    }
    
    /// Obfuscates strings in memory
    private func obfuscateStrings() {
        // Hook string functions that might be used to search for suspicious strings
        guard let strcmpPtr = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "strcmp") else {
            return
        }
        
        typealias StrcmpFunc = @convention(c) (UnsafePointer<Int8>?, UnsafePointer<Int8>?) -> Int32
        
        let replacementStrcmp: StrcmpFunc = { str1, str2 in
            // If comparing with a suspicious string, make it not match
            if let string1 = str1.map({ String(cString: $0) }),
               let string2 = str2.map({ String(cString: $0) }) {
                
                // If comparing against jailbreak detection strings
                let jailbreakStrings = [
                    "MobileSubstrate",
                    "Substrate",
                    "Substitute",
                    "TweakInject",
                    "cynject",
                    "libhooker",
                    "Satella",
                    "Cydia",
                    "Sileo"
                ]
                
                // If either string contains suspicious content
                if jailbreakStrings.contains(where: { string1.contains($0) || string2.contains($0) }) {
                    // Make sure they don't match
                    return 1
                }
            }
            
            // Call original for other comparisons
            return unsafeBitCast(strcmpPtr, to: StrcmpFunc.self)(str1, str2)
        }
        
        let replacementCmp = unsafeBitCast(replacementStrcmp, to: UnsafeMutableRawPointer.self)
        Jinx.replaceFunction(strcmpPtr, with: replacementCmp)
        
        // Also hook strstr which is used to search for substrings
        guard let strstrPtr = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "strstr") else {
            return
        }
        
        typealias StrstrFunc = @convention(c) (UnsafePointer<Int8>?, UnsafePointer<Int8>?) -> UnsafePointer<Int8>?
        
        let replacementStrstr: StrstrFunc = { haystack, needle in
            // If searching for a suspicious string, return nil (not found)
            if let needleStr = needle.map({ String(cString: $0) }) {
                let suspiciousStrings = [
                    "Cydia",
                    "substrate",
                    "substitute",
                    "Satella",
                    "Jinx",
                    "dylib",
                    "jailbreak",
                    "tweak"
                ]
                
                if suspiciousStrings.contains(where: { needleStr.contains($0) }) {
                    return nil
                }
            }
            
            // Call original for other searches
            return unsafeBitCast(strstrPtr, to: StrstrFunc.self)(haystack, needle)
        }
        
        let replacementStr = unsafeBitCast(replacementStrstr, to: UnsafeMutableRawPointer.self)
        Jinx.replaceFunction(strstrPtr, with: replacementStr)
    }
}
