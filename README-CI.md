# Satella CI/CD Setup

This repository includes GitHub Actions workflows to automatically build and release the Satella tweak. These workflows simplify the development process by automating builds and releases.

## Available Workflows

### 1. Build Workflow

**File:** `.github/workflows/build.yml`

This workflow builds the Satella dylib whenever changes are pushed to the main branches (`emt`, `main`, or `master`) or when manually triggered.

**Features:**
- Automatically builds on every push
- Uploads the compiled .deb as a GitHub artifact
- Can be manually triggered from the GitHub Actions tab

**To manually trigger a build:**
1. Go to the "Actions" tab in your GitHub repository
2. Select "Build Satella Dylib" from the workflows list
3. Click "Run workflow" button
4. Select the branch you want to build from
5. Click "Run workflow" again

**To download the build artifact:**
1. Go to the completed workflow run
2. Scroll down to the "Artifacts" section
3. Click on the artifact name (e.g., "Satella-2.0.0")
4. The artifact will download as a zip file containing the .deb

### 2. Release Workflow

**File:** `.github/workflows/release.yml`

This workflow creates a formal GitHub Release whenever a version tag is pushed or when manually triggered.

**Features:**
- Automatically creates a GitHub Release when a version tag is pushed
- Generates a simple changelog
- Attaches the compiled .deb to the release
- Can be manually triggered from the GitHub Actions tab

**To create a release with a tag:**
1. Create and push a tag following the pattern `v*` (e.g., `v2.0.0`)
   ```
   git tag v2.0.0
   git push origin v2.0.0
   ```
2. The workflow will automatically run and create a release

**To manually trigger a release:**
1. Go to the "Actions" tab in your GitHub repository
2. Select "Create Release" from the workflows list
3. Click "Run workflow" button
4. Select the branch you want to build from
5. Click "Run workflow" again

## Customizing the Workflows

You can customize these workflows by editing the corresponding YAML files:

- **Change the build targets:** Edit the `on:` section to change which branches trigger builds
- **Add custom build steps:** Add additional steps in the `steps:` section
- **Modify the build environment:** Change the `runs-on:` value to use a different runner

## Troubleshooting

If the workflows fail, check the following common issues:

1. **Missing dependencies:** Ensure all dependencies are correctly specified
2. **SDK issues:** Make sure the iOS SDK is available and accessible
3. **Repository access:** Ensure the workflow has proper access to all required repositories

For specific errors, check the workflow logs by clicking on the failed job in the GitHub Actions tab.

## Additional Resources

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Theos Documentation](https://theos.dev/docs/)
- [ldid Documentation](https://github.com/ProcursusTeam/ldid)
