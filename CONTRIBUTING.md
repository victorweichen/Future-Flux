# Contributing to Future Flux

Thank you for your interest in contributing to Future Flux! This document provides guidelines for contributing to the project.

## Code of Conduct

- Be respectful and inclusive
- Welcome newcomers and help them get started
- Focus on constructive feedback
- Respect differing viewpoints and experiences

## Getting Started

1. Fork the repository
2. Clone your fork: `git clone https://github.com/YOUR_USERNAME/Future-Flux.git`
3. Create a branch: `git checkout -b feature/your-feature-name`
4. Make your changes
5. Test your changes thoroughly
6. Commit with clear messages
7. Push to your fork
8. Submit a pull request

## Development Setup

See the [README.md](README.md) for detailed setup instructions.

## Pull Request Process

1. **Before Creating a PR:**
   - Ensure your code follows the project's coding standards
   - Run all tests and ensure they pass
   - Update documentation if needed
   - Rebase your branch on the latest main

2. **PR Description:**
   - Clearly describe what changes you made and why
   - Reference any related issues
   - Include screenshots for UI changes
   - List any breaking changes

3. **Code Review:**
   - Address reviewer feedback promptly
   - Keep discussions focused and professional
   - Be open to suggestions

## Coding Standards

### Smart Contracts

- Use Solidity 0.8.20+
- Follow OpenZeppelin patterns
- Add comprehensive NatSpec comments
- Include tests for all functions
- Use SafeMath patterns (or built-in checks in 0.8+)

### JavaScript/TypeScript

- Use ESLint configuration
- Follow Airbnb style guide
- Use meaningful variable names
- Add JSDoc comments for functions
- Keep functions small and focused

### Git Commits

- Use conventional commits format
- Examples:
  - `feat: add liquidity pool analytics`
  - `fix: resolve swap calculation bug`
  - `docs: update API documentation`
  - `test: add tests for DEX contract`

## Testing

- Write tests for all new features
- Maintain or improve test coverage
- Test edge cases
- Run the full test suite before submitting

### Smart Contract Tests

```bash
cd packages/contracts
npm test
```

### Frontend Tests

```bash
cd packages/frontend
npm test
```

## Documentation

- Update README.md for major changes
- Update relevant docs in `/docs` directory
- Add inline code comments for complex logic
- Document API changes

## Reporting Bugs

Use GitHub Issues and include:
- Clear description of the bug
- Steps to reproduce
- Expected vs actual behavior
- Environment details (OS, Node version, etc.)
- Screenshots if applicable

## Feature Requests

- Use GitHub Issues with "enhancement" label
- Clearly describe the feature and its benefits
- Discuss implementation approach if possible
- Be open to feedback and alternatives

## Security Issues

**Do not open public issues for security vulnerabilities!**

Instead:
1. Email security@future-flux.io (when available)
2. Provide detailed description
3. Wait for response before public disclosure

## License

By contributing, you agree that your contributions will be licensed under the MIT License.

## Questions?

Feel free to open a discussion or reach out to the maintainers.

Thank you for contributing to Future Flux! 🚀
