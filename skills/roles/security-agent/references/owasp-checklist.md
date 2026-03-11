# OWASP Top 10 Security Checklist

## A01: Broken Access Control

- [ ] Authorization checks on every endpoint (not just authentication)
- [ ] No IDOR (Insecure Direct Object Reference) — users can't access other users' data by changing IDs
- [ ] Server-side enforcement (not client-side only)
- [ ] CORS configured with specific origins (not `*`)
- [ ] Directory listing disabled
- [ ] JWT claims verified server-side
- [ ] Admin endpoints protected with role checks

## A02: Cryptographic Failures

- [ ] Passwords hashed with bcrypt/argon2/scrypt (not MD5/SHA1/plaintext)
- [ ] Sensitive data encrypted at rest
- [ ] TLS enforced for data in transit
- [ ] No sensitive data in URLs or logs
- [ ] Proper key management (not hardcoded)
- [ ] Secure random number generation for tokens/IDs

## A03: Injection

- [ ] Parameterized queries / ORM (no string concatenation in SQL)
- [ ] Input sanitization for user-controlled data
- [ ] Output encoding for XSS prevention
- [ ] Command injection prevention (no `exec()` with user input)
- [ ] Path traversal prevention (validate file paths)
- [ ] NoSQL injection prevention (if MongoDB/similar)

## A04: Insecure Design

- [ ] Rate limiting on sensitive endpoints (login, registration, password reset)
- [ ] Account lockout after failed attempts
- [ ] Business logic validation (not just input validation)
- [ ] Proper error handling (no information leakage)

## A05: Security Misconfiguration

- [ ] Debug mode disabled in production config
- [ ] Default credentials changed
- [ ] Unnecessary features/endpoints removed
- [ ] Security headers set (X-Content-Type-Options, X-Frame-Options, CSP)
- [ ] Error pages don't reveal stack traces
- [ ] CORS not overly permissive

## A06: Vulnerable and Outdated Components

- [ ] `npm audit` / `pip-audit` / `govulncheck` run with no critical findings
- [ ] Dependencies pinned to specific versions
- [ ] No known-vulnerable library versions
- [ ] Unused dependencies removed

## A07: Identification and Authentication Failures

- [ ] Strong password policy enforced
- [ ] Multi-factor authentication available (if applicable)
- [ ] Session tokens invalidated on logout
- [ ] Token expiration enforced
- [ ] Brute force protection (rate limiting, CAPTCHA)
- [ ] Password reset flow is secure

## A08: Software and Data Integrity Failures

- [ ] Dependencies from trusted sources
- [ ] CI/CD pipeline secured
- [ ] No unsigned/unverified deserialization of untrusted data
- [ ] Subresource integrity for CDN resources

## A09: Security Logging and Monitoring Failures

- [ ] Authentication events logged (login, logout, failed attempts)
- [ ] Authorization failures logged
- [ ] Input validation failures logged
- [ ] Logs don't contain sensitive data (passwords, tokens, PII)

## A10: Server-Side Request Forgery (SSRF)

- [ ] URL input validated and restricted
- [ ] Internal network access blocked from user-supplied URLs
- [ ] Allowlist for external service calls (if applicable)
