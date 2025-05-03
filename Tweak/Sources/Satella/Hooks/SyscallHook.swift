import Foundation
import Jinx

/// SyscallHook intercepts system calls that are commonly used for jailbreak detection
/// This implementation specifically targets iOS 16-18 detection mechanisms
@available(iOS 16.0, *)
struct SyscallHook: Hook {
    // Hook a common function that many syscall wrappers use internally
    let cls: AnyClass? = NSFileManager.self
    let sel: Selector = #selector(NSFileManager.contentsOfDirectory(atPath:))
    
    typealias T = @convention(c) (NSFileManager, Selector, String) -> [String]
    let replace: T = { obj, sel, path in
        // If this is checking a sensitive directory, filter the results
        let sensitiveDirectories = ["/", "/bin", "/usr/bin", "/usr/libexec", "/var", "/etc", "/private", "/tmp"]
        
        if sensitiveDirectories.contains(path) {
            // Get original results
            let results = orig(obj, sel, path)
            
            // Filter out suspicious binaries and directories
            return results.filter { !SyscallHook.isSuspiciousFile($0) }
        }
        
        return orig(obj, sel, path)
    }
    
    /// Hook syscall-related functions that are commonly used for jailbreak detection
    func hook() {
        // First hook our basic implementation
        Jinx.hook(self)
        
        // Hook specific syscalls commonly used for jailbreak detection
        hookSysctl()
        hookStat()
        hookDlsym()
        hookFork()
        hookExecve()
        hookAccess()
        hookOpen()
        hookSyscall()
    }
    
    /// Hooks sysctl which is commonly used to detect jailbreak
    private func hookSysctl() {
        // Find the sysctl function
        guard let sysctlPtr = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "sysctl") else {
            return
        }
        
        typealias SysctlFunc = @convention(c) (UnsafeMutablePointer<Int32>?, u_int, UnsafeMutableRawPointer?, UnsafeMutablePointer<size_t>?, UnsafeMutableRawPointer?, size_t) -> Int32
        
        let replacementSysctl: SysctlFunc = { name, namelen, oldp, oldlenp, newp, newlen in
            // Check if this is a process-related sysctl call
            if name != nil && namelen >= 2 {
                // Check for CTL_KERN / KERN_PROC combinations which are used to detect jailbreaks
                if name![0] == CTL_KERN {
                    if name![1] == KERN_PROC {
                        if namelen >= 4 && name![2] == KERN_PROC_ALL {
                            // This is enumerating all processes, which is a common jailbreak detection technique
                            
                            // Call original function
                            let result = unsafeBitCast(sysctlPtr, to: SysctlFunc.self)(name, namelen, oldp, oldlenp, newp, newlen)
                            
                            // If successful, sanitize the results
                            if result == 0 && oldp != nil && oldlenp != nil {
                                SyscallHook.sanitizeProcessList(oldp!, oldlenp!)
                            }
                            
                            return result
                        }
                    }
                    
                    // KERN_OSVERSION often used to check iOS version for compatibility issues
                    if name![1] == KERN_OSVERSION {
                        // Let this pass through normally
                        return unsafeBitCast(sysctlPtr, to: SysctlFunc.self)(name, namelen, oldp, oldlenp, newp, newlen)
                    }
                    
                    // KERN_OSTYPE is safe
                    if name![1] == KERN_OSTYPE {
                        return unsafeBitCast(sysctlPtr, to: SysctlFunc.self)(name, namelen, oldp, oldlenp, newp, newlen)
                    }
                    
                    // Other KERN_* calls might be used for detection
                    if namelen >= 3 && name![2] == 3 /* commonly used for checking specific processes */ {
                        // If checking specific processes, still sanitize
                        let result = unsafeBitCast(sysctlPtr, to: SysctlFunc.self)(name, namelen, oldp, oldlenp, newp, newlen)
                        
                        if result == 0 && oldp != nil && oldlenp != nil {
                            SyscallHook.sanitizeProcessList(oldp!, oldlenp!)
                        }
                        
                        return result
                    }
                }
                
                // CTL_HW queries are generally safe hardware queries
                if name![0] == CTL_HW {
                    return unsafeBitCast(sysctlPtr, to: SysctlFunc.self)(name, namelen, oldp, oldlenp, newp, newlen)
                }
            }
            
            // Call original function for everything else
            return unsafeBitCast(sysctlPtr, to: SysctlFunc.self)(name, namelen, oldp, oldlenp, newp, newlen)
        }
        
        let replacement = unsafeBitCast(replacementSysctl, to: UnsafeMutableRawPointer.self)
        Jinx.replaceFunction(sysctlPtr, with: replacement)
    }
    
    /// Hooks stat/lstat functions used to check file existence
    private func hookStat() {
        // Hook stat
        guard let statPtr = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "stat") else {
            return
        }
        
        typealias StatFunc = @convention(c) (UnsafePointer<Int8>?, UnsafeMutablePointer<stat>?) -> Int32
        
        let replacementStat: StatFunc = { path, buf in
            if let pathStr = path.map({ String(cString: $0) }) {
                if SyscallHook.isJailbreakPath(pathStr) {
                    errno = ENOENT // No such file or directory
                    return -1
                }
            }
            
            return unsafeBitCast(statPtr, to: StatFunc.self)(path, buf)
        }
        
        let replacementStatPtr = unsafeBitCast(replacementStat, to: UnsafeMutableRawPointer.self)
        Jinx.replaceFunction(statPtr, with: replacementStatPtr)
        
        // Hook lstat
        guard let lstatPtr = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "lstat") else {
            return
        }
        
        typealias LstatFunc = @convention(c) (UnsafePointer<Int8>?, UnsafeMutablePointer<stat>?) -> Int32
        
        let replacementLstat: LstatFunc = { path, buf in
            if let pathStr = path.map({ String(cString: $0) }) {
                if SyscallHook.isJailbreakPath(pathStr) {
                    errno = ENOENT // No such file or directory
                    return -1
                }
            }
            
            return unsafeBitCast(lstatPtr, to: LstatFunc.self)(path, buf)
        }
        
        let replacementLstatPtr = unsafeBitCast(replacementLstat, to: UnsafeMutableRawPointer.self)
        Jinx.replaceFunction(lstatPtr, with: replacementLstatPtr)
    }
    
    /// Hooks dlsym to prevent discovery of suspicious symbols
    private func hookDlsym() {
        guard let dlsymPtr = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "dlsym") else {
            return
        }
        
        typealias DlsymFunc = @convention(c) (UnsafeMutableRawPointer?, UnsafePointer<Int8>?) -> UnsafeMutableRawPointer?
        
        let replacementDlsym: DlsymFunc = { handle, symbol in
            if let sym = symbol.map({ String(cString: $0) }) {
                // Hide suspicious symbols that might be used for jailbreak detection
                let suspiciousSymbols = [
                    "MSHookFunction",
                    "MSHookMessage",
                    "MSGetImageByName",
                    "TFP0",
                    "task_for_pid",
                    "host_get_special_port"
                ]
                
                if suspiciousSymbols.contains(sym) {
                    return nil
                }
            }
            
            return unsafeBitCast(dlsymPtr, to: DlsymFunc.self)(handle, symbol)
        }
        
        let replacement = unsafeBitCast(replacementDlsym, to: UnsafeMutableRawPointer.self)
        Jinx.replaceFunction(dlsymPtr, with: replacement)
    }
    
    /// Hooks fork() to prevent fork detection
    private func hookFork() {
        guard let forkPtr = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "fork") else {
            return
        }
        
        typealias ForkFunc = @convention(c) () -> pid_t
        
        let replacementFork: ForkFunc = {
            // Most iOS apps should never call fork - it's often used in jailbreak detection
            // Return error (fork failed)
            errno = EPERM // Operation not permitted
            return -1
        }
        
        let replacement = unsafeBitCast(replacementFork, to: UnsafeMutableRawPointer.self)
        Jinx.replaceFunction(forkPtr, with: replacement)
    }
    
    /// Hooks execve to prevent executing suspicious programs
    private func hookExecve() {
        guard let execvePtr = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "execve") else {
            return
        }
        
        typealias ExecveFunc = @convention(c) (UnsafePointer<Int8>?, UnsafePointer<UnsafePointer<Int8>?>?, UnsafePointer<UnsafePointer<Int8>?>?) -> Int32
        
        let replacementExecve: ExecveFunc = { path, argv, envp in
            if let pathStr = path.map({ String(cString: $0) }) {
                // Block execution of suspicious binaries
                if pathStr.contains("/bin/sh") || 
                   pathStr.contains("/bin/bash") || 
                   pathStr.contains("/usr/sbin/sshd") {
                    errno = ENOENT // No such file or directory
                    return -1
                }
            }
            
            return unsafeBitCast(execvePtr, to: ExecveFunc.self)(path, argv, envp)
        }
        
        let replacement = unsafeBitCast(replacementExecve, to: UnsafeMutableRawPointer.self)
        Jinx.replaceFunction(execvePtr, with: replacement)
    }
    
    /// Hooks access() to hide suspicious files
    private func hookAccess() {
        guard let accessPtr = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "access") else {
            return
        }
        
        typealias AccessFunc = @convention(c) (UnsafePointer<Int8>?, Int32) -> Int32
        
        let replacementAccess: AccessFunc = { path, mode in
            if let pathStr = path.map({ String(cString: $0) }) {
                if SyscallHook.isJailbreakPath(pathStr) {
                    errno = ENOENT // No such file or directory
                    return -1
                }
            }
            
            return unsafeBitCast(accessPtr, to: AccessFunc.self)(path, mode)
        }
        
        let replacement = unsafeBitCast(replacementAccess, to: UnsafeMutableRawPointer.self)
        Jinx.replaceFunction(accessPtr, with: replacement)
    }
    
    /// Hooks open() to prevent opening suspicious files
    private func hookOpen() {
        guard let openPtr = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "open") else {
            return
        }
        
        typealias OpenFunc = @convention(c) (UnsafePointer<Int8>?, Int32, mode_t) -> Int32
        
        let replacementOpen: OpenFunc = { path, flags, mode in
            if let pathStr = path.map({ String(cString: $0) }) {
                if SyscallHook.isJailbreakPath(pathStr) {
                    errno = ENOENT // No such file or directory
                    return -1
                }
            }
            
            return unsafeBitCast(openPtr, to: OpenFunc.self)(path, flags, mode)
        }
        
        let replacement = unsafeBitCast(replacementOpen, to: UnsafeMutableRawPointer.self)
        Jinx.replaceFunction(openPtr, with: replacement)
    }
    
    /// Hooks syscall directly
    private func hookSyscall() {
        guard let syscallPtr = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "syscall") else {
            return
        }
        
        typealias SyscallFunc = @convention(c) (Int32, UInt, UInt, UInt, UInt, UInt, UInt) -> Int
        
        let replacementSyscall: SyscallFunc = { number, arg1, arg2, arg3, arg4, arg5, arg6 in
            // SYS_stat is 188, SYS_stat64 is 338, SYS_lstat is 190, SYS_lstat64 is 340
            if number == 188 || number == 338 || number == 190 || number == 340 {
                // Check if this is attempting to stat a jailbreak path
                if let path = UnsafePointer<Int8>(bitPattern: Int(arg1)) {
                    let pathStr = String(cString: path)
                    if SyscallHook.isJailbreakPath(pathStr) {
                        errno = ENOENT
                        return -1
                    }
                }
            }
            
            // SYS_open is 5
            if number == 5 {
                if let path = UnsafePointer<Int8>(bitPattern: Int(arg1)) {
                    let pathStr = String(cString: path)
                    if SyscallHook.isJailbreakPath(pathStr) {
                        errno = ENOENT
                        return -1
                    }
                }
            }
            
            // SYS_access is 33
            if number == 33 {
                if let path = UnsafePointer<Int8>(bitPattern: Int(arg1)) {
                    let pathStr = String(cString: path)
                    if SyscallHook.isJailbreakPath(pathStr) {
                        errno = ENOENT
                        return -1
                    }
                }
            }
            
            // SYS_fork is 2
            if number == 2 {
                errno = EPERM
                return -1
            }
            
            // Call original for everything else
            return unsafeBitCast(syscallPtr, to: SyscallFunc.self)(number, arg1, arg2, arg3, arg4, arg5, arg6)
        }
        
        let replacement = unsafeBitCast(replacementSyscall, to: UnsafeMutableRawPointer.self)
        Jinx.replaceFunction(syscallPtr, with: replacement)
    }
    
    /// Returns true if the given file is suspicious
    static func isSuspiciousFile(_ filename: String) -> Bool {
        let suspiciousFiles = [
            "cydia",
            "Cydia",
            "substrate",
            "substitute",
            "SBSettings",
            "MobileSubstrate",
            "jailbreak",
            "Sileo",
            "Zebra",
            "Filza",
            "apt",
            "dpkg",
            "ssh",
            "sshd",
            "bash",
            "zsh",
            "libhooker",
            "trollstore",
            "checkra1n",
            "palera1n",
            "NewTerm",
            "Terminal"
        ]
        
        return suspiciousFiles.contains { filename.lowercased().contains($0.lowercased()) }
    }
    
    /// Returns true if the given path is a jailbreak-related path
    static func isJailbreakPath(_ path: String) -> Bool {
        let jailbreakPaths = [
            "/Applications/Cydia.app",
            "/Library/MobileSubstrate",
            "/usr/lib/libsubstrate.dylib",
            "/usr/lib/libsubstitute.dylib",
            "/var/lib/cydia",
            "/var/cache/apt",
            "/var/lib/apt",
            "/etc/apt",
            "/private/var/lib/apt",
            "/usr/sbin/sshd",
            "/usr/bin/ssh",
            "/bin/bash",
            "/etc/ssh",
            "/.bootstrapped",
            "/usr/lib/libjailbreak.dylib",
            "/var/jb",
            "/private/var/jb",
            "/var/mobile/Library/SBSettings",
            "/usr/bin/cycript",
            "/var/mobile/Library/Cydia",
            "/usr/libexec/cydia",
            "/var/log/syslog",
            "/private/var/stash",
            "/usr/libexec/ssh-keysign",
            "/Applications/FakeCarrier.app",
            "/Applications/Sileo.app",
            "/Applications/Zebra.app",
            "/Applications/Filza.app",
            "/Applications/NewTerm.app",
            "/Applications/Terminal.app",
            "/Library/PreferenceLoader",
            "/Library/PreferenceBundles",
            "/usr/lib/TweakInject",
            "/var/checkra1n.dmg",
            "/var/binpack",
            "/.file", // Common root-level hidden file
            "/.installed_unc0ver",
            "/.installed_odyssey",
            "/usr/bin/frida-server",
            "/etc/alternatives",
            "/chimera",
            "/usr/lib/TweakInject.dylib"
        ]
        
        return jailbreakPaths.contains { path.hasPrefix($0) }
    }
    
    /// Sanitizes the process list to remove suspicious processes
    static func sanitizeProcessList(_ buffer: UnsafeMutableRawPointer, _ size: UnsafeMutablePointer<size_t>) {
        // This is a complex operation that would require parsing kinfo_proc structures
        // For iOS 16-18 compatibility, we need a robust implementation
        
        // Get the size of a kinfo_proc structure
        let procSize = MemoryLayout<kinfo_proc>.size
        
        // Calculate how many proc structures we have
        let count = size.pointee / procSize
        
        // Create a mutable buffer we can work with
        let procBuf = buffer.bindMemory(to: kinfo_proc.self, capacity: Int(count))
        
        // Sanitize suspicious processes
        var writeIndex = 0
        
        for i in 0..<Int(count) {
            let proc = procBuf[i]
            let procName = withUnsafePointer(to: proc.kp_proc.p_comm) { ptr in
                let bytes = UnsafeRawPointer(ptr).assumingMemoryBound(to: CChar.self)
                return String(cString: bytes)
            }
            
            // Skip suspicious processes
            if isSuspiciousFile(procName) {
                continue
            }
            
            // Keep legitimate processes
            if writeIndex != i {
                procBuf[writeIndex] = proc
            }
            writeIndex += 1
        }
        
        // Update the output buffer size
        size.pointee = size_t(writeIndex * procSize)
    }
}
