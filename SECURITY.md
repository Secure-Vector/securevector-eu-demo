# Security

## Reporting a vulnerability

Please report security issues privately via GitHub's [Private Security Advisory](https://github.com/Secure-Vector/securevector-eu-demo/security/advisories/new) or by emailing **security@securevector.io**. Do **not** file public issues for security vulnerabilities.

We aim to acknowledge reports within 2 business days and provide a fix or mitigation timeline within 14 days for high-severity issues.

## Scope — this is a test harness, not a production template

By design this repo runs **deploy → validate → destroy**. The default posture is an
**internet-facing HTTP** ALB in the **default VPC**, and a token-less `terraform apply`
leaves the `/analyze` endpoint open (see the README warning). That posture is
**intentional and documented** for a short-lived, self-destroying test — it is not a
vulnerability. For anything long-lived, front the ALB with TLS (ACM/HTTPS) or an
internal ALB / PrivateLink, deploy into a private VPC, and always set an ingress token.

Reports we DO want: committed secrets, weak/leaked token handling, an unpinned or
tamperable module source, or anything in the harness scripts that could harm a user
who runs it as documented.
