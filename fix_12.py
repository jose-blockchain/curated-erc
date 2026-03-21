# Security Policy

## Supported Versions

The following contracts are considered **production-ready** and receive active security support:

| Contract          | Status          |
| ----------------- | --------------- |
| Core ERC-20/721/1155 implementations | ✅ Supported |
| Utility libraries (SafeERC20, Address, etc.) | ✅ Supported |
| Extensions (e.g., ERC20Votes, ERC721Enumerable) | ✅ Supported |

Contracts in the `src/experimental/` directory or marked with `// @dev experimental` are **not** covered by this policy.

## Reporting a Vulnerability

If you believe you have found a security vulnerability in a supported contract, please report it responsibly.

**Do not** open a public GitHub issue for security vulnerabilities.

Instead, please email us at:

**security@jose-blockchain.dev**

Include the following in your report:

1. **Description** of the vulnerability
2. **Affected contract(s)** and function(s)
3. **Steps to reproduce** (PoC, Foundry test, or similar)
4. **Potential impact** if exploited
5. **Suggested fix** (optional but appreciated)

You may also report via GitHub's [private vulnerability reporting](../../security) feature.

## Response Timeline

| Milestone               | Timeframe |
| ----------------------- | --------- |
| Initial acknowledgement  | Within **48 hours** |
| Triage & severity assessment | Within **5 business days** |
| Fix development         | Depends on severity (see below) |
| Disclosure / advisory published | After fix is verified & deployed |

### Severity Handling

- **Critical / High**: Work begins immediately. We aim for a patch within 7 days of triage.
- **Medium**: Addressed in the next scheduled release cycle (typically within 30 days).
- **Low / Informational**: Best-effort; included in a future release.

## Bug Bounty

We are evaluating a formal bug bounty program and plan to launch one on a platform such as [Immunefi](https://immunefi.com/) in the near future. In the meantime, we commit to crediting responsible reporters in our changelog (with their consent) and working with them on coordinated disclosure.

## Security Advisories

We use GitHub's built-in [Security Advisories](../../security) feature to track and publish vulnerabilities. Published advisories are linked to Dependabot alerts so downstream users receive automatic notifications.

## Code of Conduct

We will treat all security reporters with respect and handle reports confidentially. We do not tolerate threats, demands, or attempts to exploit a vulnerability before a patch is available.