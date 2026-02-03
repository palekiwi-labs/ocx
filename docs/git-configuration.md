# Git Configuration in OCX

OCX containers come with pre-configured git settings to enable agents to commit code without requiring manual configuration.

## Default Git Configuration

Git is configured at the system level (`/etc/gitconfig`) during container build time with the following defaults:

| Setting | Value | Purpose |
|---------|-------|---------|
| `user.name` | `opencode` | Identity used for commits |
| `user.email` | `opencode@local` | Email used for commits |
| `init.defaultBranch` | `main` | Default branch name for new repositories |
| `commit.gpgsign` | `false` | Disable GPG signing (no keys available in container) |
| `core.autocrlf` | `input` | Consistent line endings (LF in repository) |
| `pull.rebase` | `false` | Avoid warning messages on `git pull` |

These defaults ensure that agents can create git commits immediately without encountering the error:
```
*** Please tell me who you are.
```

## Verifying Git Configuration

To verify the git configuration in your running container:

```bash
ocx shell
git config --list --show-origin
```

You should see the system-level configuration:
```
file:/etc/gitconfig    user.name=opencode
file:/etc/gitconfig    user.email=opencode@local
file:/etc/gitconfig    init.defaultbranch=main
file:/etc/gitconfig    commit.gpgsign=false
file:/etc/gitconfig    core.autocrlf=input
file:/etc/gitconfig    pull.rebase=false
```

## Testing Git Commits

Test that git commits work correctly:

```bash
ocx shell
cd /workspace

# Initialize a new repository
git init

# Create a test file
echo "test content" > test.txt

# Stage the file
git add test.txt

# Commit (should work without prompting for user info)
git commit -m "test commit"

# Verify the commit
git log --oneline
```

The commit should show as:
```
(opencode <opencode@local>) test commit
```

## Security Considerations

- **Immutable Configuration**: The system-level git config is stored in `/etc/gitconfig` which is immutable when using `read_only: true` mode
- **No Credentials**: No git credentials, SSH keys, or GPG keys are stored in the container image
- **Agent Commits**: All commits made by agents will use the `opencode` identity

## Future Customization

In future versions, OCX will support customizing git configuration through:

1. **Environment Variables**: Override defaults via `OCX_GIT_USER_NAME` and `OCX_GIT_USER_EMAIL`
2. **Configuration Files**: Mount a custom `.gitconfig` from `~/.config/opencode/.gitconfig`
3. **Project Configuration**: Specify git settings in `ocx.json`

## Troubleshooting

### "Please tell me who you are" Error

If you encounter this error, it means the system-level git config was not properly installed during the build. Rebuild the image:

```bash
ocx build --force
```

### Different Git Identity for Commits

If you need commits to use your actual identity, you have several options:

1. **Configure user-level git config** (persists in your home directory within the container):
   ```bash
   ocx shell
   git config --global user.name "Your Name"
   git config --global user.email "your.email@example.com"
   ```

2. **Pass git config as environment variables** when running commands:
   ```bash
   ocx exec git -c user.name="Your Name" -c user.email="your.email@example.com" commit -m "message"
   ```

3. **Wait for future OCX features** that will support git config customization

### Git Configuration Priority

Git configuration is applied in this order (highest to lowest priority):

1. **Command-line flags** (`-c user.name="..."`)
2. **Repository-level** (`.git/config` in your project)
3. **User-level** (`~/.gitconfig` - persists in container home directory)
4. **System-level** (`/etc/gitconfig` - configured by OCX, lowest priority)

## Related Documentation

- [Security Model](security-model.md) - How OCX secures the container environment
- [Image Management](image-management.md) - Building and managing OCX images
- [Volume Management](volume-management.md) - Persisting configuration across container restarts
