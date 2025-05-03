# Satella Repository Codebase Upgrade Instructions

## Overview

This document outlines the requirements and guidelines for upgrading the Satella repository codebase to ensure it is production-grade, robust, reliable, and fully compatible with iOS 16 to 18 and above, including non-jailbroken devices. The goal is to enhance the dynamic library (dylib) while maintaining compatibility, improving performance, and adhering to best practices for production-level code.

## Repository Context

The Satella repository is assumed to be a dynamic library (dylib) project targeting iOS applications, likely for in-app purchase (IAP) emulation or related functionality. The codebase must be analyzed thoroughly to understand its structure, dependencies, and logic before making improvements. All changes must enhance the existing functionality without breaking compatibility or introducing regressions.

## General Guidelines

The following rules must be strictly adhered to for all code-related tasks:

1. **Production-Level Code**: Provide complete, robust, production-level code for all additions or modifications. Do not include stub code, partial implementations, or simplified code. Ensure all code adheres to real-world logic and best practices.
2. **Real Files Only**: Use only real, existing files from the repository. Do not create stub files, placeholder files, or simplified files. Download or access any missing files necessary to ensure the code compiles and runs successfully.
3. **Avoid Simplified Code**: Never include simplified code or files. Remove any previously added simplified code or files and replace them with complete, production-ready implementations that reflect real logic and functionality.
4. **Issue Resolution**: Address each issue provided one at a time, in the order specified. Do not skip any issues. Provide a complete, robust, production-ready fix for each issue before moving to the next.
5. **Repository Analysis**: When analyzing the codebase, thoroughly examine every file in the repository. Ensure all changes or suggestions are based on a comprehensive understanding of the full codebase.
6. **Rule Adherence**: Store these rules for reference and apply them consistently across all tasks.

## Specific Requirements

### 1. Codebase Analysis
- **Task**: Perform a comprehensive analysis of the Satella repository to identify its purpose, structure, and functionality.
- **Steps**:
  - Clone the Satella repository from GitHub (ensure the latest commit is used).
  - Analyze all files, including source code (`.m`, `.h`, `.c`, `.cpp`), build scripts (e.g., `Makefile`), configuration files (e.g., `plist`), and documentation.
  - Identify the core components, such as the dylib's entry points, hooks, or patches applied to iOS applications.
  - Document the dependencies, including any third-party libraries or frameworks.
  - Understand the logic for IAP emulation or other functionality, focusing on how it interacts with iOS APIs and non-jailbroken environments.
- **Output**: Provide a summary of the codebase, including:
  - Purpose (e.g., IAP emulation, payment processing bypass).
  - Key components and their roles.
  - Current iOS compatibility (e.g., SDK versions, deployment targets).
  - Existing dependencies and their versions.
  - Potential areas for improvement (e.g., outdated APIs, missing error handling).

### 2. Compatibility with iOS 16 to 18 and Above
- **Task**: Ensure the codebase is fully compatible with iOS 16, 17, 18, and future versions, including non-jailbroken devices.
- **Steps**:
  - Update the deployment target to iOS 16.0 or higher in the build configuration (e.g., `Info.plist` or Xcode project settings).
  - Replace deprecated APIs with modern equivalents (e.g., use `StoreKit 2` if applicable for IAP-related functionality).
  - Ensure compatibility with non-jailbroken environments by avoiding jailbreak-specific techniques (e.g., `substrate` hooks, `libhooker`) unless they are conditionally supported.
  - Test for compatibility with ARM64 and ARM64e architectures.
  - Add runtime checks for iOS version-specific features to prevent crashes on newer or older systems.
- **Best Practices**:
  - Use `#available` checks in Objective-C/Swift for version-specific code.
  - Implement fallback mechanisms for older iOS versions where necessary.
  - Ensure the dylib is signed correctly for non-jailbroken devices (e.g., via entitlements or developer certificates).

### 3. Production-Grade Enhancements
- **Task**: Improve the codebase to meet production-grade standards, enhancing reliability, robustness, and performance.
- **Steps**:
  - **Code Quality**:
    - Refactor code to follow modern Objective-C or Swift best practices (e.g., use `@property` for safer access, adopt ARC fully if not already done).
    - Add comprehensive error handling for all API calls, network requests, and file operations.
    - make sure that this works for any and all apps or atleast try to make this work for any and all apps. make sure we the dylib dont get spotted by jailbreak detection or anything else tbat would block this from working make sure you make this work completely.
  - **Security**:
    - Harden the dylib against reverse engineering (e.g., obfuscate sensitive strings, use runtime encryption for critical data).
    - Validate all inputs to prevent crashes or exploits (e.g., sanitize receipt data, check for null pointers).
  - **Performance**:
    - Optimize hooks or patches to minimize runtime overhead (e.g., use efficient method swizzling techniques).
    - Cache frequently accessed data (e.g., receipt validation results) to reduce redundant computations.
    - Profile the dylib using Instruments to identify and fix performance bottlenecks.
  - **Documentation**:
    - Add inline comments for complex logic.

### 4. Dependency Management
- **Task**: Add or update dependencies to support new features or improve reliability.
- **Steps**:
  - Identify outdated dependencies in the codebase (e.g., check versions in `Podfile`, `Cartfile`, or manual includes).
  - Update to the latest compatible versions, ensuring iOS 16+ compatibility.
  - Consider adding new dependencies for enhanced functionality,
- **Best Practices**:
  - Pin dependency versions to avoid breaking changes.

### 5. Non-Jailbroken Compatibility
- **Task**: Ensure the dylib functions seamlessly on non-jailbroken devices.
- **Steps**:
  - Replace jailbreak-specific techniques (e.g., `Cydia Substrate`, `libhooker`) with alternative approaches, such as:
    - Runtime method swizzling using Objective-C runtime APIs.
    - Dynamic library injection via legitimate means (e.g., embedded frameworks).
  - Ensure the dylib can be loaded without requiring a jailbroken environment (e.g., via app extensions or developer-signed binaries).
  - Test the dylib in a sandboxed environment to verify compliance with App Store restrictions.
  - Add conditional logic to detect jailbroken vs. non-jailbroken environments and adjust behavior accordingly.
- **Best Practices**:
  - Avoid using private APIs or undocumented behaviors.
  - Use entitlements sparingly and only as needed for legitimate functionality.
  - Test on physical devices running iOS 16, 17, and 18 to confirm compatibility.

## Deliverables

1. **Updated Codebase**:
   - All modified or added files must be production-grade, fully implemented, and compatible with iOS 16 to 18 and above.
   - Include new dependencies, build scripts, and documentation as needed.

## Constraints

- **Compatibility**: Must support iOS 16 to 18 and above, including non-jailbroken devices.
- **No Breaking Changes**: All enhancements must preserve existing functionality unless explicitly requested.
- **Production-Grade**: All code must be robust, secure, and optimized for real-world use.
- **No Simplified Code**: Avoid placeholders, stubs, or incomplete implementations.
- **Repository Integrity**: Only use real files from the Satella repository or necessary external dependencies.