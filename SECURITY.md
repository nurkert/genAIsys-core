# Security Policy

## Supported Versions

| Version | Supported |
|---------|-----------|
| main branch | ✅ Active |
| 0.0.4 | ✅ Current release |
| < 0.0.4 | ❌ No longer supported |

## Reporting a Vulnerability

**Do not report security vulnerabilities through public GitHub issues.**

Send a detailed report to: **genaisys@nurkert.de**

Please include:
- A clear description of the vulnerability
- Steps to reproduce (proof-of-concept code or commands)
- Affected version(s) and environment
- Potential impact assessment

### Response Timeline

- **72 hours**: Acknowledgement of your report
- **7 days**: Initial severity assessment and triage
- **90 days**: Target for patch release (critical issues expedited)

We follow responsible disclosure: no public disclosure before a patch is available and coordinated with the reporter.

## Scope

### In scope

- Remote Code Execution (RCE) via agent runner or shell execution paths
- `safe_write` policy bypass allowing writes outside the allowed roots
- `shell_allowlist` bypass allowing execution of non-approved commands
- Privilege escalation through the orchestrator or CLI
- Credential or API key leakage via logs, run artifacts, or CLI output
- Path traversal vulnerabilities in file read/write operations

### Out of scope

- UI cosmetic issues or visual glitches
- Theoretical attacks without a working proof of concept
- Vulnerabilities in third-party dependencies not triggered by Genaisys code
- Denial-of-service attacks requiring physical or authenticated access

## Disclosure Policy

We adhere to coordinated responsible disclosure. Reporters who follow this policy in good faith will not face legal action. We credit researchers in release notes unless anonymity is requested.
