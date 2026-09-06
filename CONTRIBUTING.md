# Contributing to FINS Agentforce Workshop

Thank you for your interest in improving the FINS Agentforce Workshop. This
guide explains how the project is governed and how to propose changes to its
Salesforce metadata, workshop instructions, sample data, scripts, and other
supporting assets.

## Governance Model

### Salesforce Sponsored

The goal of publishing this project is to make its workshop assets useful to a
broader contributor and user community. Salesforce sponsors and maintains the
project. Only Salesforce employees are granted repository administrator rights,
and Salesforce maintainers are the final arbiters of which contributions are
accepted.

## Before contributing

- Search the [existing issues](https://github.com/salesforce-misc/fins-agentforce-workshop/issues)
  before opening a new one.
- Do not include customer data, credentials, access tokens, org identifiers, or
  other confidential information in issues, commits, sample data, screenshots,
  or logs.
- Keep examples suitable for learning and demonstration. Clearly document any
  org, license, feature, or product dependencies.
- For substantial changes, open an issue before implementation so maintainers
  can confirm that the proposal fits the workshop's goals.

Security vulnerabilities must not be reported in a public issue. Follow the
instructions in [SECURITY.md](SECURITY.md).

## Reporting bugs and proposing enhancements

Use [GitHub Issues](https://github.com/salesforce-misc/fins-agentforce-workshop/issues)
for reproducible bugs, enhancement requests, and workshop-content proposals.
Include:

- A clear description of the problem or proposed outcome.
- The affected workshop track, file, Salesforce feature, and org type.
- Reproduction steps and the expected and actual behavior, when reporting a
  bug.
- Relevant error messages with sensitive information removed.

If you intend to fix an issue, comment on it before beginning substantial work.

## Creating a pull request

1. Fork and clone the repository.
2. Create a focused branch from the latest `main` branch.
3. Make a small, cohesive change and update the related workshop guidance.
4. Run the checks relevant to your change.
5. Commit with a descriptive message and reference the related issue.
6. Push your branch and open a pull request against `main`.
7. Complete the Salesforce Contributor License Agreement when prompted.

Keep unrelated changes out of the pull request. Explain any checks that could
not be run and identify Salesforce org validation that remains outstanding.

## Contribution requirements

Contributions should:

- Follow the existing project structure and naming conventions.
- Preserve valid Salesforce metadata pairings and dependencies.
- Include or update tests when behavior changes.
- Keep workshop instructions, commands, screenshots, and generated static
  resources synchronized when their source content changes.
- Avoid adding dependencies unless they are necessary and appropriately
  licensed.
- Pass peer review by a Salesforce maintainer before merge.

Depending on the files changed, useful local checks include:

```bash
npm run lint
npm run test:unit
npm run prettier:verify
```

When editing content under `src-static/`, rebuild the deployable workshop
resources and review the generated changes:

```bash
npm run build:staticresources
```

Static checks do not replace validation in a compatible Salesforce org. For
metadata changes, describe the org type and validation or deployment commands
used in the pull request.

## Contributor License Agreement

To accept a pull request, Salesforce requires contributors to complete the
[Salesforce Contributor License Agreement](https://cla.salesforce.com/sign-cla).
You generally need to complete it only once for Salesforce open-source
projects.

## Code of Conduct

All project participants must follow the [Salesforce Open Source Community Code
of Conduct](CODE_OF_CONDUCT.md).

## License

By contributing, you agree that your contribution is licensed under the terms
of the project [license](LICENSE.txt) and that you will complete the Salesforce
Contributor License Agreement.
