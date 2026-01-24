# Release Process

This document describes the release process for OCX.

## Branching Strategy

OCX follows a **trunk-based development** workflow:

- **`master`** is the main development branch
  - Contains the latest merged features and fixes
  - All pull requests merge here
  - May be ahead of the latest release
  - **Not recommended for production use** - users should pin to version tags

- **Version tags** mark stable releases
  - Format: `vX.Y.Z` or `vX.Y.Z-alpha.N` (following [Semantic Versioning](https://semver.org/))
  - These are the canonical releases users should install
  - Each tag points to a tested, stable commit

- **Feature branches** for development
  - Branch from `master`
  - Merge back to `master` via pull request
  - Deleted after merge

## Versioning Scheme

OCX uses [Semantic Versioning](https://semver.org/):

- **MAJOR** version (X.0.0): Breaking changes
- **MINOR** version (0.X.0): New features, backwards compatible
- **PATCH** version (0.0.X): Bug fixes, backwards compatible

### Pre-release versions:
- **Alpha**: `vX.Y.Z-alpha.N` - Early development, unstable API
- **Beta**: `vX.Y.Z-beta.N` - Feature complete, testing phase
- **RC**: `vX.Y.Z-rc.N` - Release candidate, final testing

## Creating a Release

### 1. Prepare the Release

Ensure `master` is in a releasable state:

```bash
# Pull latest changes
git checkout master
git pull origin master

# Run tests if available
nix build

# Test the package
nix run . -- --version
```

### 2. Update Version Files

Update the version in `src/VERSION`:

```bash
echo "X.Y.Z" > src/VERSION
# Or for pre-release:
echo "X.Y.Z-alpha.N" > src/VERSION
```

Verify the flake picks up the new version:

```bash
nix eval .#packages.x86_64-linux.default.version
```

### 3. Commit Version Bump

```bash
git add src/VERSION
git commit -m "chore: bump version to vX.Y.Z"
git push origin master
```

### 4. Create and Push Tag

```bash
# Create annotated tag
git tag -a vX.Y.Z -m "Release vX.Y.Z"

# Push the tag
git push origin vX.Y.Z
```

### 5. Create GitHub Release

Go to https://github.com/palekiwi-labs/ocx/releases/new

- Select the tag you just created
- Title: `vX.Y.Z` or `vX.Y.Z-alpha.N`
- Description: Add release notes (see template below)
- Mark as pre-release if it's an alpha/beta/rc
- Publish release

### Release Notes Template

```markdown
## What's Changed

### Features
- Feature description (#PR-number)

### Bug Fixes
- Fix description (#PR-number)

### Documentation
- Documentation improvements (#PR-number)

### Internal
- Internal changes (#PR-number)

**Full Changelog**: https://github.com/palekiwi-labs/ocx/compare/vOLD...vNEW
```

### 6. Announce the Release

Consider announcing in:
- Project README (update badge if needed)
- Discussions/Discord/etc if applicable

## Post-Release

After creating a release, development continues on `master`:

- `master` will be ahead of the latest tag
- This is expected and correct for trunk-based development
- Users tracking `master` get unreleased features (at their own risk)
- Users tracking tags get stable releases

## Hotfix Process

For urgent fixes to a released version:

1. Create hotfix branch from the tag:
   ```bash
   git checkout -b hotfix/X.Y.Z+1 vX.Y.Z
   ```

2. Make the fix and commit:
   ```bash
   # Make changes
   git commit -m "fix: critical bug description"
   ```

3. Update version:
   ```bash
   echo "X.Y.Z+1" > src/VERSION
   git commit -am "chore: bump version to vX.Y.Z+1"
   ```

4. Merge to master:
   ```bash
   git checkout master
   git merge hotfix/X.Y.Z+1
   git push origin master
   ```

5. Create tag and release (follow steps 4-6 above)

6. Delete hotfix branch:
   ```bash
   git branch -d hotfix/X.Y.Z+1
   ```

## Version Check

To verify the current state:

```bash
# Check current version in source
cat src/VERSION

# Check latest tag
git describe --tags --abbrev=0

# Check if master is ahead of latest tag
git log $(git describe --tags --abbrev=0)..HEAD --oneline
```

## Troubleshooting

**Q: I tagged the wrong commit, how do I fix it?**

```bash
# Delete local tag
git tag -d vX.Y.Z

# Delete remote tag (if already pushed)
git push --delete origin vX.Y.Z

# Recreate on correct commit
git tag -a vX.Y.Z -m "Release vX.Y.Z" <commit-hash>
git push origin vX.Y.Z
```

**Q: Should I delete the GitHub Release too?**

Yes, if you delete a tag, also delete the corresponding GitHub Release from the web UI.

**Q: When should I bump the version in src/VERSION?**

Only when creating a new release. The VERSION file should match the latest tag, even if `master` is ahead.
