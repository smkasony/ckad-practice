# Contributing to CKAD Practice Questions

Thanks for your interest in contributing! This repo aims to help others prepare for the CKAD exam.

## How to Contribute

### Adding New Questions

1. Fork the repository
2. Add your question to `README.md` following the existing format:
   - Question number and title
   - Clear task description
   - Solution with step-by-step commands
   - Link to relevant Kubernetes docs

### Question Format

```markdown
<a id="question-X"></a>
## Question X – Descriptive Title

Brief scenario description.

Your task:
1. Step one
2. Step two
3. Step three

### Solution

**Step 1 – Description**

\```bash
kubectl command here
\```

**Docs**

- Relevant Doc: https://kubernetes.io/docs/...
```

### Fixing Errors

If you find any errors in the existing questions or solutions:

1. Open an issue describing the error
2. Or submit a pull request with the fix

### Guidelines

- Keep solutions exam-focused (use `kubectl` commands, not just YAML files)
- Include verification steps where possible
- Add links to official Kubernetes documentation
- Test your solutions before submitting

### Topics Welcome

- Pod design patterns
- Multi-container pods
- Jobs and CronJobs
- ConfigMaps and Secrets
- RBAC
- Network Policies
- Services and Ingress
- Helm basics
- Resource management
- Probes (liveness, readiness, startup)

## Pull Request Process

1. Ensure your question follows the existing format
2. Test your solution in a real Kubernetes cluster
3. Submit a PR with a clear description of what you're adding

## Questions?

Feel free to open an issue if you have any questions about contributing.

Thanks for helping others pass the CKAD exam!
