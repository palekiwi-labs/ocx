# Contributing to OCX

First off, thanks for taking the time to contribute! :tada:

The following is a set of guidelines for contributing to OCX. These are mostly guidelines, not rules. Use your best judgment, and feel free to propose changes to this document in a pull request.

## Code of Conduct

This project and everyone participating in it is governed by the [OCX Code of Conduct](CODE_OF_CONDUCT.md). By participating, you are expected to uphold this code.

## How Can I Contribute?

### Reporting Bugs

This section guides you through submitting a bug report for OCX. Following these guidelines helps maintainers and the community understand your report :pencil:, reproduce the behavior :computer:, and find related reports :mag_right:.

- **Use the Bug Report Template**: When you open an issue, please use the provided template to ensure all necessary information is captured.
- **Check for Duplicates**: Before submitting, please check if the issue has already been reported.

### Suggesting Enhancements

This section guides you through submitting an enhancement suggestion for OCX, including completely new features and minor improvements to existing functionality.

- **Use the Feature Request Template**: Please use the template to describe your suggestion.
- **Provide Context**: Explain why this enhancement would be useful to most OCX users.

### Pull Requests

1. **Fork the Repo**: Create your own fork of the code.
2. **Create a Branch**: Create a branch for your changes (`git checkout -b fix/my-fix` or `feat/my-feature`).
3. **Coding Standards**:
   - We use **Nushell** for the core logic. Please follow standard Nushell idioms.
   - Run `nix run .#check` (if available) or ensure code parses correctly.
   - Keep functions small and focused.
4. **Commit Messages**: We encourage [Conventional Commits](https://www.conventionalcommits.org/).
   - `feat: add new command`
   - `fix: resolve permission issue`
   - `docs: update readme`
   - `chore: update dependencies`
5. **Push and PR**: Push your branch and open a Pull Request.

## Development Setup

OCX is distributed as a Nix Flake. The best way to develop is using Nix.

1. **Install Nix**: [Download Nix](https://nixos.org/download.html).
2. **Enter Dev Shell**:
   ```bash
   nix develop
   ```
   This will provide you with `nu` and all necessary dependencies.
3. **Run Locally**:
   You can run the local version of OCX using:
   ```bash
   nu src/main.nu <command>
   ```

## Documentation

Documentation is a vital part of this project. If you add a new feature, please:
1. Update `README.md` if it's a user-facing command.
2. Update `docs/` with detailed usage instructions if needed.
3. Add comments to complex code blocks.

## License

By contributing, you agree that your contributions will be licensed under its MIT License.
