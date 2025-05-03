import Foundation
import Jinx

/// MemoryScanHook protects against sophisticated memory scanning techniques
/// used by modern iOS 16-18 apps to detect tweaks and jailbreaks
@available(iOS 16.0, *)
struct MemoryScanHook: Hook {
    // Hook the basic vm_region function used for memory scans
    let cls: AnyClass? = NSObject.self
    let sel: Selector = #selector(NSObject.description)
    
    typealias T = @convention(c) (AnyObject, Selector) -> String
    let replace: T = { obj, sel in
        // Default implementation simply passes through
        return orig(obj, sel)
    }
    
    /// Implement all the memory protection hooks
    func hook() {
        // Hook vm_* functions used to scan memory regions
        hookVMFunctions()
        
        // Hook memory mapping functions
        hookMemoryMappingFunctions()
        
        // Hook memory reading functions
        hookMemoryReadingFunctions()
        
        // Hook dyld lookup functions
        hookDyldLookupFunctions()
    }
    
    /// Hooks vm_* functions used to scan memory regions
    private func hookVMFunctions() {
        // Hook vm_region_64 which is commonly used to scan memory regions
        guard let vmRegionPtr = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "vm_region_64") else {
            return
        }
        
        typealias VMRegionFunc = @convention(c) (
            vm_map_t,
            UnsafeMutablePointer<mach_vm_address_t>,
            UnsafeMutablePointer<mach_vm_size_t>,
            vm_region_flavor_t,
            UnsafeMutableRawPointer?,
            UnsafeMutablePointer<mach_msg_type_number_t>,
            UnsafeMutablePointer<mach_port_t>?
        ) -> kern_return_t
        
        let replacementVMRegion: VMRegionFunc = { task, address, size, flavor, info, infoCnt, object_name in
            // Call original function
            let result = unsafeBitCast(vmRegionPtr, to: VMRegionFunc.self)(
                task, address, size, flavor, info, infoCnt, object_name
            )
            
            // If successful and this is our dylib's memory region, hide it
            if result == KERN_SUCCESS && info != nil {
                // Cast info pointer to correct type based on flavor
                if flavor == VM_REGION_BASIC_INFO_64 || flavor == VM_REGION_BASIC_INFO {
                    let regionInfo = info!.bindMemory(
                        to: vm_region_basic_info_64_t.self,
                        capacity: 1
                    )
                    
                    // Check if this memory region belongs to our dylib
                    if isSatellaDylibRegion(address.pointee, size.pointee) {
                        // Modify protection bits to look like a system library
                        regionInfo.pointee.protection = VM_PROT_READ
                        regionInfo.pointee.max_protection = VM_PROT_READ
                        regionInfo.pointee.inheritance = 0
                        regionInfo.pointee.shared = 1
                        regionInfo.pointee.reserved = 0
                    }
                }
            }
            
            return result
        }
        
        let replacement = unsafeBitCast(replacementVMRegion, to: UnsafeMutableRawPointer.self)
        Jinx.replaceFunction(vmRegionPtr, with: replacement)
    }
    
    /// Hooks memory mapping functions to hide our dylib
    private func hookMemoryMappingFunctions() {
        // Hook mach_vm_read which is used to read memory
        guard let machVMReadPtr = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "mach_vm_read") else {
            return
        }
        
        typealias MachVMReadFunc = @convention(c) (
            vm_map_t,
            mach_vm_address_t,
            mach_vm_size_t,
            UnsafeMutablePointer<mach_vm_address_t>?,
            UnsafeMutablePointer<mach_msg_type_number_t>?
        ) -> kern_return_t
        
        let replacementMachVMRead: MachVMReadFunc = { task, address, size, data, dataCnt in
            // If trying to read our dylib's memory, return an error
            if isSatellaDylibRegion(address, size) {
                return KERN_INVALID_ADDRESS
            }
            
            // Otherwise, call original function
            return unsafeBitCast(machVMReadPtr, to: MachVMReadFunc.self)(
                task, address, size, data, dataCnt
            )
        }
        
        let replacement = unsafeBitCast(replacementMachVMRead, to: UnsafeMutableRawPointer.self)
        Jinx.replaceFunction(machVMReadPtr, with: replacement)
    }
    
    /// Hooks memory reading functions to protect against direct memory access
    private func hookMemoryReadingFunctions() {
        // Hook task_for_pid which is commonly used for memory access
        guard let taskForPidPtr = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "task_for_pid") else {
            return
        }
        
        typealias TaskForPidFunc = @convention(c) (
            mach_port_t,
            Int32,
            UnsafeMutablePointer<mach_port_t>?
        ) -> kern_return_t
        
        let replacementTaskForPid: TaskForPidFunc = { host, pid, task in
            // If trying to get task port for our own process, return error
            if pid == getpid() {
                return KERN_FAILURE
            }
            
            // Otherwise, call original function
            return unsafeBitCast(taskForPidPtr, to: TaskForPidFunc.self)(
                host, pid, task
            )
        }
        
        let replacement = unsafeBitCast(replacementTaskForPid, to: UnsafeMutableRawPointer.self)
        Jinx.replaceFunction(taskForPidPtr, with: replacement)
    }
    
    /// Hooks dyld lookup functions to hide our dylib
    private func hookDyldLookupFunctions() {
        // Hook _dyld_get_image_name which returns dylib paths
        guard let dyldGetImageNamePtr = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "_dyld_get_image_name") else {
            return
        }
        
        typealias DyldGetImageNameFunc = @convention(c) (UInt32) -> UnsafePointer<Int8>?
        
        let replacementDyldGetImageName: DyldGetImageNameFunc = { index in
            // Call original function
            let result = unsafeBitCast(dyldGetImageNamePtr, to: DyldGetImageNameFunc.self)(index)
            
            // If this is our dylib, return a fake system library path
            if let path = result.map({ String(cString: $0) }),
               path.contains("Satella.dylib") {
                return "/usr/lib/system/libdyld.dylib".withCString { $0 }
            }
            
            return result
        }
        
        let replacement = unsafeBitCast(replacementDyldGetImageName, to: UnsafeMutableRawPointer.self)
        Jinx.replaceFunction(dyldGetImageNamePtr, with: replacement)
        
        // Also hook _dyld_image_count to hide our dylib from image count
        guard let dyldImageCountPtr = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "_dyld_image_count") else {
            return
        }
        
        typealias DyldImageCountFunc = @convention(c) () -> UInt32
        
        let replacementDyldImageCount: DyldImageCountFunc = {
            // Call original function
            let count = unsafeBitCast(dyldImageCountPtr, to: DyldImageCountFunc.self)()
            
            // Return one less if our dylib is loaded
            // This makes our dylib "invisible" to dyld enumeration
            if isSatellaLoaded() {
                return count - 1
            }
            
            return count
        }
        
        let replacementCount = unsafeBitCast(replacementDyldImageCount, to: UnsafeMutableRawPointer.self)
        Jinx.replaceFunction(dyldImageCountPtr, with: replacementCount)
    }
    
    /// Checks if the given memory region belongs to our dylib
    private func isSatellaDylibRegion(_ address: mach_vm_address_t, _ size: mach_vm_size_t) -> Bool {
        // Get information about all loaded dylibs
        let imageCount = _dyld_image_count()
        
        for i in 0..<imageCount {
            // Get header of this image
            guard let header = _dyld_get_image_header(i) else {
                continue
            }
            
            // Get name of this image
            guard let imageName = _dyld_get_image_name(i) else {
                continue
            }
            
            let name = String(cString: imageName)
            
            // If this is our dylib
            if name.contains("Satella.dylib") {
                // Calculate start and end address of image
                let startAddr = UInt64(UInt(bitPattern: header))
                let endAddr = startAddr + dyldGetImageSize(header)
                
                // Check if the requested region overlaps with our dylib
                let regionEnd = address + UInt64(size)
                if (address >= startAddr && address < endAddr) ||
                   (regionEnd > startAddr && regionEnd <= endAddr) ||
                   (address <= startAddr && regionEnd >= endAddr) {
                    return true
                }
            }
        }
        
        return false
    }
    
    /// Checks if Satella is loaded in the process
    private func isSatellaLoaded() -> Bool {
        let imageCount = _dyld_image_count()
        
        for i in 0..<imageCount {
            guard let imageName = _dyld_get_image_name(i) else {
                continue
            }
            
            let name = String(cString: imageName)
            if name.contains("Satella.dylib") {
                return true
            }
        }
        
        return false
    }
    
    /// Get the size of a dylib image from its header
    private func dyldGetImageSize(_ header: UnsafePointer<mach_header>?) -> UInt64 {
        guard let header = header else {
            return 0
        }
        
        // Start after the header
        var cursor = UnsafeRawPointer(header)
            .advanced(by: header.pointee.magic == MH_MAGIC_64 ? MemoryLayout<mach_header_64>.size : MemoryLayout<mach_header>.size)
        
        // Enumerate load commands to find segments
        var size: UInt64 = 0
        
        for _ in 0..<header.pointee.ncmds {
            let loadCommand = cursor.assumingMemoryBound(to: load_command.self)
            
            // Check if this is a segment command
            if loadCommand.pointee.cmd == LC_SEGMENT_64 {
                let segmentCommand = cursor.assumingMemoryBound(to: segment_command_64.self)
                size = max(size, UInt64(segmentCommand.pointee.vmaddr + segmentCommand.pointee.vmsize))
            } else if loadCommand.pointee.cmd == LC_SEGMENT {
                let segmentCommand = cursor.assumingMemoryBound(to: segment_command.self)
                size = max(size, UInt64(segmentCommand.pointee.vmaddr + segmentCommand.pointee.vmsize))
            }
            
            // Move to next command
            cursor = cursor.advanced(by: Int(loadCommand.pointee.cmdsize))
        }
        
        return size
    }
}
