# Upgrading OpenCode

OCX includes an upgrade system to keep OpenCode up to date. This guide covers the upgrade process, version management, and troubleshooting.

## Upgrade Commands

### Check for Updates

Check if a newer version of OpenCode is available:

```bash
ocx upgrade --check
```

**What it does:**
- Queries the GitHub Releases API
- Compares with current installed version
- Shows available update (if any)
- Does not perform any changes

**Sample Output:**
```
Current version: 1.1.23
Latest version: 1.1.24
A newer version is available! Run 'ocx upgrade' to upgrade.
```

### Perform Upgrade

Upgrade to the latest version of OpenCode:

```bash
ocx upgrade
```

**What it does:**
1. Fetches latest version information from GitHub
2. Downloads new OpenCode binary
3. Updates global configuration with new version
4. Rebuilds OCX images with new version
5. Displays release notes

**Sample Output:**
```
Checking for updates...
Current version: 1.1.23
Latest version: 1.1.24

Upgrading OpenCode to 1.1.24...
Downloading OpenCode 1.1.24...
[████████████████████████████] 100%

Update complete!

Release Notes:
- Fixed bug with file permissions
- Improved performance on large projects
- Added new features for debugging

Images will be rebuilt on next run, or run 'ocx build --force' to rebuild now.
```

## Version Management

### Understanding Versioning

OpenCode uses semantic versioning: `MAJOR.MINOR.PATCH`

- **MAJOR:** Breaking changes
- **MINOR:** New features, backward compatible
- **PATCH:** Bug fixes, backward compatible

Example: `1.2.3` → `1.2.4` (patch), `1.3.0` (minor), `2.0.0` (major)

### Current Version

Check your current OpenCode version:

```bash
ocx config | grep opencode_version
```

Or view full configuration:

```bash
ocx config
```

### Version Caching

OCX caches version information for 24 hours to reduce API calls:

**Cache Location:** `~/.cache/ocx/version-cache.json`

**Cache Contents:**
- Latest version number
- Timestamp of last check
- Release notes (cached)

**Force Cache Refresh:**
```bash
ocx upgrade --check
```

This bypasses the cache and queries GitHub directly.

## Automatic vs Manual Updates

### Using "latest"

By default, OCX uses `latest` as the version:

```json
{
  "opencode_version": "latest"
}
```

**Behavior:**
- Always checks for the latest version on GitHub
- Upgrades automatically when you run `ocx upgrade`
- Recommended for most users

**Advantages:**
- Always have latest features and bug fixes
- Security patches automatically applied

**Disadvantages:**
- Potential breaking changes with major versions
- Less predictable development environment

### Version Pinning

Pin to a specific version:

```json
{
  "opencode_version": "1.2.3"
}
```

Or via environment variable:
```bash
export OCX_OPENCODE_VERSION=1.2.3
```

**Behavior:**
- Always uses the specified version
- `ocx upgrade` will skip version checks
- Manual update requires changing the version

**Advantages:**
- Predictable development environment
- Team members use identical versions
- Avoids unexpected breaking changes
- Reproducible builds

**Disadvantages:**
- Manual updates required
- Miss out on bug fixes and security patches

### When to Pin Versions

**Pin to specific version when:**
- Working in a team environment
- CI/CD pipelines requiring reproducibility
- Production deployments
- Testing specific features or bugs
- Compliance requirements

**Use "latest" when:**
- Solo development
- Personal projects
- Early-stage development
- Want latest features and fixes

## Upgrade Workflow

### Standard Upgrade

1. **Check what's new:**
   ```bash
   ocx upgrade --check
   ```

2. **Review release notes:**
   - Visit GitHub releases page
   - Check for breaking changes
   - Review bug fixes and new features

3. **Perform upgrade:**
   ```bash
   ocx upgrade
   ```

4. **Rebuild images (optional):**
   ```bash
   ocx build --force
   ```

5. **Test your project:**
   ```bash
   ocx opencode
   # Run your tests
   ocx exec npm test  # or whatever your test command is
   ```

### Team Upgrade Workflow

1. **Coordinate with team:**
   - Schedule upgrade time
   - Inform team members of version change

2. **Update version in config:**
   ```json
   {
     "opencode_version": "1.2.3"
   }
   ```

3. **Commit to version control:**
   ```bash
   git add ocx.json
   git commit -m "Upgrade OpenCode to 1.2.3"
   git push
   ```

4. **Team members update:**
   ```bash
   git pull
   ocx build --force
   ocx opencode
   ```

5. **Verify:**
   ```bash
   ocx config | grep opencode_version
   # Should show 1.2.3
   ```

### Rollback Workflow

If a new version has issues:

1. **Revert version in config:**
   ```json
   {
     "opencode_version": "1.2.2"  # Previous version
   }
   ```

2. **Rebuild with old version:**
   ```bash
   ocx build --force
   ```

3. **Verify rollback:**
   ```bash
   ocx config | grep opencode_version
   ocx opencode
   ```

4. **Report issue:**
   - File bug report on GitHub
   - Include version numbers
   - Describe the issue

## Network and API

### GitHub API

OCX queries the GitHub Releases API:
```
https://api.github.com/repos/anomalyco/opencode/releases/latest
```

**Rate Limits:**
- Authenticated: 5,000 requests/hour
- Unauthenticated: 60 requests/hour
- OCX uses unauthenticated requests

**Cache Benefits:**
- Reduces API calls
- Avoids rate limiting
- Faster checks (no network delay)

### Network Errors

If you encounter network errors during upgrade:

**"Failed to fetch version information"**

**Possible causes:**
- No internet connection
- GitHub API rate limit exceeded
- Firewall blocking GitHub

**Solutions:**
1. Check internet connection:
   ```bash
   curl -I https://api.github.com
   ```

2. Check cache fallback:
   - OCX will use cached version if available
   - Or fallback to currently installed version

3. Wait for rate limit reset (60 minutes for unauthenticated)

4. Use GitHub token (advanced):
   ```bash
   export GITHUB_TOKEN=your_token_here
   ```

**"Download failed"**

**Possible causes:**
- Network interruption
- Invalid version
- Download URL changed

**Solutions:**
1. Check version exists on GitHub releases page
2. Retry upgrade:
   ```bash
   ocx upgrade
   ```
3. Clear cache and retry:
   ```bash
   rm ~/.cache/ocx/version-cache.json
   ocx upgrade --check
   ```

### Timeout Handling

OCX includes timeout protection:
- API request timeout: 30 seconds
- Download timeout: 5 minutes

If timeouts occur:
1. Check network speed
2. Try again (temporary network issue)
3. Use manual download (advanced)

## Manual Upgrade

If automatic upgrade fails, you can manually upgrade:

### 1. Download Binary Manually

Visit GitHub releases:
```
https://github.com/anomalyco/opencode/releases
```

Download the appropriate binary for your system.

### 2. Place Binary

Move binary to OCX cache location:
```bash
mkdir -p ~/.cache/ocx/binaries
mv opencode-1.2.3-linux-amd64 ~/.cache/ocx/binaries/opencode-1.2.3
chmod +x ~/.cache/ocx/binaries/opencode-1.2.3
```

### 3. Update Configuration

Edit your `ocx.json`:
```json
{
  "opencode_version": "1.2.3"
}
```

### 4. Rebuild Images

```bash
ocx build --force
```

## Release Notes

### Viewing Release Notes

Release notes are shown during upgrade. To view without upgrading:

```bash
ocx upgrade --check
```

Or visit GitHub:
```
https://github.com/anomalyco/opencode/releases
```

### Understanding Release Notes

Release notes typically include:
- **Added:** New features
- **Fixed:** Bug fixes
- **Changed:** Modifications to existing features
- **Deprecated:** Features to be removed
- **Removed:** Removed features
- **Security:** Security fixes

### Breaking Changes

Pay attention to breaking changes (major version bumps):

**Example:**
```
Breaking Changes:
- File system mounting changed from /workspace to /project
- Old configuration format no longer supported
```

**Action Required:**
- Review migration guide
- Update configuration
- Test thoroughly

## Configuration After Upgrade

### Image Rebuilding

After upgrade, images will be rebuilt automatically on next `ocx opencode` run.

To rebuild immediately:

```bash
ocx build --force
```

**What gets rebuilt:**
- Base image with new OpenCode binary
- Final image with new version

**What doesn't change:**
- Your custom base Dockerfile
- Project configuration
- Workspace contents

### Configuration Compatibility

Most upgrades are backward compatible. However:

**Check these after upgrade:**
1. Version-specific features
2. Configuration options (new or deprecated)
3. Environment variables
4. Plugin compatibility (if using editor plugins)

**Test thoroughly:**
- Run your project
- Execute tests
- Verify all features work

## Troubleshooting

### Upgrade Fails

**Symptom:** `ocx upgrade` fails with error

**Solutions:**

1. **Check for conflicting process:**
   ```bash
   ocx ps
   ocx stop
   ocx upgrade
   ```

2. **Clear cache and retry:**
   ```bash
   rm -rf ~/.cache/ocx/version-cache.json
   ocx upgrade
   ```

3. **Check disk space:**
   ```bash
   df -h
   # If low, prune images
   ocx image prune
   ```

4. **Check Docker daemon:**
   ```bash
   docker ps
   ```

### Version Doesn't Change

**Symptom:** Running `ocx upgrade` but version remains old

**Solutions:**

1. **Check for pinned version:**
   ```bash
   ocx config | grep opencode_version
   ```
   If it's pinned (not "latest"), the version won't update.

2. **Update configuration:**
   ```bash
   # Change to "latest" in ocx.json or environment
   export OCX_OPENCODE_VERSION=latest
   ```

3. **Rebuild images:**
   ```bash
   ocx build --force
   ```

### Images Not Updating

**Symptom:** OpenCode updated but container still uses old version

**Solutions:**

1. **Force rebuild:**
   ```bash
   ocx build --base --force
   ocx build --force
   ```

2. **Remove and restart container:**
   ```bash
   ocx stop
   ocx opencode
   ```

3. **Check image list:**
   ```bash
   ocx image list
   # Verify new version exists
   ```

### Cache Issues

**Symptom:** Upgrade shows outdated information

**Solutions:**

1. **Clear version cache:**
   ```bash
   rm ~/.cache/ocx/version-cache.json
   ocx upgrade --check
   ```

2. **Clear binary cache (if needed):**
   ```bash
   rm ~/.cache/ocx/binaries/*
   ocx upgrade
   ```

3. **Bypass cache entirely:**
   ```bash
   ocx upgrade --check
   # Always queries GitHub
   ```

## Best Practices

### 1. Regular Updates

Update regularly to get bug fixes and security patches:
- Monthly updates recommended
- Check `ocx upgrade --check` weekly
- Read release notes before major upgrades

### 2. Test Before Team Upgrade

For team environments:
1. One person tests new version first
2. Verify all features work
3. Document any changes needed
4. Coordinate team upgrade

### 3. Pin Versions for Production

Use pinned versions in production:
```json
{
  "opencode_version": "1.2.3"
}
```

Update only after testing:
1. Test in development/staging
2. Review release notes
3. Plan upgrade window
4. Update version and deploy

### 4. Keep Documentation Updated

Update project documentation when upgrading:
- Note version in README
- Document any breaking changes
- Update installation instructions if needed
- Record upgrade date in changelog

### 5. Backup Before Major Upgrades

Before major version upgrades:
```bash
# Backup configuration
cp ~/.config/ocx/ocx.json ~/.config/ocx/ocx.json.backup

# Export current images (optional)
docker save localhost/ocx:1.1.23 -o backup.tar

# Then upgrade
ocx upgrade
```

### 6. Monitor for Issues

After upgrade:
- Run your tests
- Check for new warnings or errors
- Verify performance is acceptable
- Test all critical features

### 7. Stay Informed

- Star the repository on GitHub
- Watch releases for updates
- Join discussions for community feedback
- Report issues if you encounter bugs

## Advanced Topics

### Custom Binary Sources

By default, OCX downloads from GitHub releases. You can override this (advanced):

```bash
export OCX_OPENCODE_DOWNLOAD_URL=https://your-server.com/opencode.tar.gz
```

**Use cases:**
- Air-gapped environments
- Corporate firewalls
- Custom build systems
- Internal releases

### Pre-release Versions

To use pre-release/alpha/beta versions:

1. Manually download from GitHub releases (prerelease tab)
2. Place in binary cache
3. Pin to specific version

**Warning:** Pre-releases may be unstable. Use with caution.

### Multiple Versions

You can run different OpenCode versions in different projects by setting project-specific `ocx.json`:

**Project A:**
```json
{
  "opencode_version": "1.2.3"
}
```

**Project B:**
```json
{
  "opencode_version": "1.3.0"
}
```

OCX will build separate images for each version.

### Automated Upgrades

For automated environments (CI/CD), create a script:

```bash
#!/bin/bash
# upgrade-check.sh

CURRENT=$(ocx config | grep opencode_version | awk '{print $2}')
LATEST=$(curl -s https://api.github.com/repos/anomalyco/opencode/releases/latest | grep tag_name | cut -d'"' -f4)

if [ "$CURRENT" != "$LATEST" ]; then
  echo "New version available: $LATEST"
  # Optional: auto-upgrade
  ocx upgrade
  ocx build --force
fi
```

Add to cron or CI pipeline for automatic checks.
