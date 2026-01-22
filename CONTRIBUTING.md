# Contributing to FutureFlux

Thank you for your interest in contributing to FutureFlux! This document provides guidelines and instructions for contributing to the project.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [How to Contribute](#how-to-contribute)
- [Development Workflow](#development-workflow)
- [Coding Standards](#coding-standards)
- [Testing Guidelines](#testing-guidelines)
- [Documentation](#documentation)
- [Pull Request Process](#pull-request-process)
- [Community](#community)

## Code of Conduct

### Our Pledge

We are committed to providing a welcoming and inclusive environment for all contributors, regardless of background or identity.

### Expected Behavior

- Be respectful and considerate in all interactions
- Accept constructive criticism gracefully
- Focus on what is best for the community and project
- Show empathy towards other community members

### Unacceptable Behavior

- Harassment, discrimination, or offensive comments
- Trolling, insulting, or derogatory remarks
- Publishing others' private information without permission
- Any conduct that could reasonably be considered inappropriate

## Getting Started

### Prerequisites

Before contributing, ensure you have:

- Node.js v16 or higher installed
- Git installed and configured
- A GitHub account
- Basic understanding of Ethereum and smart contracts
- Familiarity with ERC-3643 token standard (for smart contract contributions)

### Setting Up Your Development Environment

1. Fork the repository on GitHub
2. Clone your fork locally:
   ```bash
   git clone https://github.com/YOUR_USERNAME/Future-Flux.git
   cd Future-Flux
   ```
3. Add the upstream repository:
   ```bash
   git remote add upstream https://github.com/victorweichen/Future-Flux.git
   ```
4. Install dependencies (when available):
   ```bash
   npm install
   ```

## How to Contribute

### Types of Contributions

We welcome various types of contributions:

#### 1. Bug Reports

If you find a bug, please create an issue with:
- Clear, descriptive title
- Detailed description of the issue
- Steps to reproduce
- Expected vs actual behavior
- Environment details (OS, Node version, etc.)
- Screenshots or error messages if applicable

#### 2. Feature Requests

For new features:
- Check existing issues to avoid duplicates
- Describe the feature and its use case
- Explain why it would be beneficial
- Provide examples or mockups if possible

#### 3. Code Contributions

Areas where code contributions are welcome:
- Smart contract development
- Frontend/UI improvements
- Testing and test coverage
- Documentation improvements
- Bug fixes
- Performance optimizations

#### 4. Documentation

Help improve:
- README and setup instructions
- Code comments and inline documentation
- Whitepapers and technical documentation
- API documentation
- Tutorials and guides
- Translations

## Development Workflow

### Branch Naming Convention

Use descriptive branch names following this pattern:
- `feature/description` - New features
- `fix/description` - Bug fixes
- `docs/description` - Documentation updates
- `test/description` - Test improvements
- `refactor/description` - Code refactoring

Example: `feature/add-identity-registry-validation`

### Commit Messages

Write clear, concise commit messages:

```
type: Brief description (50 chars or less)

More detailed explanation if necessary. Wrap at 72 characters.
Explain what changed and why, not how.

- Bullet points for multiple changes
- Reference issues: Fixes #123, Relates to #456
```

Types:
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `test`: Test additions or changes
- `refactor`: Code refactoring
- `style`: Code style changes (formatting, etc.)
- `chore`: Maintenance tasks

## Coding Standards

### Solidity (Smart Contracts)

- Follow the [Solidity Style Guide](https://docs.soliditylang.org/en/latest/style-guide.html)
- Use Solidity 0.8.x or higher
- Include comprehensive NatSpec comments
- Implement security best practices
- Gas optimization where reasonable
- Include tests for all contract functionality

Example:
```solidity
/// @title Identity Registry Contract
/// @notice Manages KYC/AML verified investor identities
/// @dev Implements ERC-3643 compliance requirements
contract IdentityRegistry {
    /// @notice Verifies if an investor is eligible
    /// @param investor The address to check
    /// @return bool True if investor is verified
    function isVerified(address investor) public view returns (bool) {
        // Implementation
    }
}
```

### JavaScript/TypeScript

- Use ESLint and Prettier for code formatting
- Follow Airbnb JavaScript Style Guide
- Use TypeScript for type safety
- Write clear, self-documenting code
- Add JSDoc comments for public functions

### General Guidelines

- Keep functions small and focused
- Use meaningful variable and function names
- Avoid magic numbers - use named constants
- Handle errors appropriately
- Write defensive code
- Optimize for readability over cleverness

## Testing Guidelines

### Smart Contract Testing

- Write comprehensive unit tests using Hardhat or Foundry
- Test all functions, including edge cases
- Test access control and permissions
- Test failure scenarios
- Aim for >90% code coverage

Example test structure:
```javascript
describe("IdentityRegistry", function () {
  describe("isVerified", function () {
    it("should return true for verified investor", async function () {
      // Test implementation
    });
    
    it("should return false for unverified investor", async function () {
      // Test implementation
    });
  });
});
```

### Test Coverage

- Run tests before submitting PR: `npm test`
- Check coverage: `npm run coverage`
- Ensure new code is adequately tested

## Documentation

### Code Documentation

- Document all public functions and contracts
- Explain complex logic with inline comments
- Keep comments up-to-date with code changes

### External Documentation

When updating documentation:
- Use clear, concise language
- Include code examples where helpful
- Update table of contents if adding sections
- Check for broken links
- Ensure formatting is consistent

## Pull Request Process

### Before Submitting

1. Update your fork:
   ```bash
   git fetch upstream
   git rebase upstream/main
   ```

2. Run all tests:
   ```bash
   npm test
   ```

3. Check code style:
   ```bash
   npm run lint
   ```

4. Update documentation if needed

### Submitting Your PR

1. Push to your fork:
   ```bash
   git push origin your-branch-name
   ```

2. Create a Pull Request on GitHub

3. Fill out the PR template completely:
   - Clear title describing the change
   - Detailed description of what changed and why
   - Reference related issues
   - List any breaking changes
   - Include screenshots for UI changes
   - Add testing notes

### PR Review Process

- Maintainers will review your PR
- Address any requested changes
- Keep the PR focused on a single concern
- Be responsive to feedback
- PRs require at least one approval to merge

### After Your PR is Merged

- Delete your branch:
  ```bash
  git branch -d your-branch-name
  git push origin --delete your-branch-name
  ```

- Update your fork:
  ```bash
  git checkout main
  git pull upstream main
  git push origin main
  ```

## Community

### Getting Help

- **GitHub Discussions**: https://github.com/victorweichen/Future-Flux/discussions
- **Discord**: Coming soon
- **Issues**: For bug reports and feature requests

### Staying Updated

- Watch the repository for notifications
- Join GitHub Discussions for announcements
- Follow the project roadmap

### Recognition

Contributors will be:
- Listed in the project contributors
- Acknowledged in release notes for significant contributions
- Invited to join the core team for consistent, high-quality contributions

## Questions?

If you have questions about contributing, please:
1. Check existing documentation
2. Search GitHub Discussions
3. Open a new discussion thread
4. Tag maintainers if urgent

Thank you for contributing to FutureFlux! Your efforts help build a more transparent, compliant, and accessible RWA ecosystem.
