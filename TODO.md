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
    - Implement logging with a configurable verbosity level (e.g., using `os_log` or a third-party library like `CocoaLumberjack`).
    - Add unit tests using XCTest to cover critical functionality (e.g., IAP transaction handling).
  - **Security**:
    - Harden the dylib against reverse engineering (e.g., obfuscate sensitive strings, use runtime encryption for critical data).
    - Validate all inputs to prevent crashes or exploits (e.g., sanitize receipt data, check for null pointers).
    - Ensure compliance with App Store guidelines for non-jailbroken use (e.g., avoid private APIs).
  - **Performance**:
    - Optimize hooks or patches to minimize runtime overhead (e.g., use efficient method swizzling techniques).
    - Cache frequently accessed data (e.g., receipt validation results) to reduce redundant computations.
    - Profile the dylib using Instruments to identify and fix performance bottlenecks.
  - **Documentation**:
    - Add inline comments for complex logic.
    - Update or create a `README.md` with clear setup instructions, dependencies, and usage examples.
    - Generate API documentation using tools like `jazzy` or `appledoc` if Swift or Objective-C is used.

### 4. Dependency Management
- **Task**: Add or update dependencies to support new features or improve reliability.
- **Steps**:
  - Identify outdated dependencies in the codebase (e.g., check versions in `Podfile`, `Cartfile`, or manual includes).
  - Update to the latest compatible versions, ensuring iOS 16+ compatibility.
  - Consider adding new dependencies for enhanced functionality, such as:
    - `CocoaLumberjack` for advanced logging.
    - `Alamofire` for network requests (if applicable).
    - `CryptoSwift` for encryption tasks.
  - Use a dependency manager (e.g., CocoaPods, Swift Package Manager) to streamline integration.
  - Document all dependencies in the `README.md`, including installation instructions.
- **Best Practices**:
  - Pin dependency versions to avoid breaking changes.
  - Test dependencies in non-jailbroken environments to ensure compatibility.

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

### 6. Build and Deployment
- **Task**: Enhance the build process to ensure reliability and ease of deployment.
- **Steps**:
  - Update the `Makefile` or Xcode project to support modern build tools (e.g., `xcodebuild`, `cmake`).
  - Add scripts for automated building, testing, and signing (e.g., `fastlane` integration).
  - Ensure the dylib is compiled with optimizations enabled (`-O2` or equivalent).
  - Create a CI/CD pipeline configuration (e.g., GitHub Actions) to run tests and build the dylib on each commit.
  - Package the dylib with clear versioning (e.g., semantic versioning) and distribution instructions.
- **Best Practices**:
  - Include build-time checks for missing dependencies or misconfigurations.
  - Provide a release checklist in the `README.md` for developers.

### 7. Testing and Validation
- **Task**: Implement comprehensive testing to ensure reliability and compatibility.
- **Steps**:
  - Write unit tests for all critical components (e.g., IAP transaction processing, receipt validation).
  - Create integration tests to simulate real-world usage (e.g., mock StoreKit transactions).
  - Test on multiple iOS versions (16, 17, 18) and device types (iPhone, iPad).
  - Use tools like `XCUITest` for UI-related testing if the dylib interacts with app interfaces.
  - Validate non-jailbroken compatibility by running tests in a clean, sandboxed environment.
- **Best Practices**:
  - Aim for at least 80% code coverage in unit tests.
  - Automate test execution via CI/CD.
  - Document test setup and execution instructions in the `README.md`.

## Deliverables

1. **Updated Codebase**:
   - All modified or added files must be production-grade, fully implemented, and compatible with iOS 16 to 18 and above.
   - Include new dependencies, build scripts, and documentation as needed.

2. **Analysis Report**:
   - A detailed summary of the codebase analysis, including purpose, structure, and identified improvements.
   - List of dependencies and their roles.

3. **Changelog**:
   - A `CHANGELOG.md` file documenting all changes, including fixes, enhancements, and new features.
   - Follow semantic versioning for releases.

4. **Documentation**:
   - Updated `README.md` with setup, build, and usage instructions.
   - API documentation for public interfaces (if applicable).
   - Inline comments for complex logic.

## Constraints

- **Compatibility**: Must support iOS 16 to 18 and above, including non-jailbroken devices.
- **No Breaking Changes**: All enhancements must preserve existing functionality unless explicitly requested.
- **Production-Grade**: All code must be robust, secure, and optimized for real-world use.
- **No Simplified Code**: Avoid placeholders, stubs, or incomplete implementations.
- **Repository Integrity**: Only use real files from the Satella repository or necessary external dependencies.

## Notes

- If the Satella repository involves ethically or legally sensitive functionality (e.g., bypassing IAP protections), ensure all changes comply with applicable laws and App Store guidelines.
- If access to the repository is restricted, provide instructions for cloning or accessing the codebase.
- For any ambiguities in the codebase or requirements, seek clarification before proceeding.

## References

- [Satella GitHub Repository](https://github.com/username/satella) (replace with actual URL).
- [iOS Developer Documentation](https://developer.apple.com/documentation/).
- [CocoaPods](https://cocoapods.org/) or [Swift Package Manager](https://swift.org/package-manager/) for dependency management.
- [Apple StoreKit Documentation](https://developer.apple.com/documentation/storekit).

---

*Last Updated: May 03, 2025*