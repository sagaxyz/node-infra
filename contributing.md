# Contributing guidelines

- [Contributing guidelines](#contributing-guidelines)
  - [Providing Feedback](#providing-feedback)
  - [Opening pull requests (PRs)](#opening-pull-requests-prs)
    - [Choose a good PR title](#choose-a-good-pr-title)
    - [Review your own code](#review-your-own-code)
    - [Do not rebase commits in your branch](#do-not-rebase-commits-in-your-branch)
  - [Contributing to documentation](#contributing-to-documentation)
    - [Ask for help](#ask-for-help)

Before you create a new PR on the Saga Security Chain repo, make sure that you read and comply with this document.

To prepare for success, see [Run a SAGA validator cluster](https://github.com/sagaxyz/node-infra/blob/main/README.md).

Thank you for your contribution!

## Providing Feedback

* Before you open an issue, do a web search, and check
  for [existing open and closed GitHub Issues](https://github.com/sagaxyz/node-infra/issues) to see if your question has already
  been asked and answered. If you find a relevant topic, you can comment on that issue.

* To provide feedback or ask a question, create a [GitHub issue](https://github.com/sagaxyz/node-infra/issues/new). Be
  sure to provide the relevant information, case study, or informative links as suggested by the Pull Request template.


## Opening pull requests (PRs)

Review the issues and discussions before you open a PR.

### Choose a good PR title

Avoid long names in your PR titles. Make sure your title has fewer than 60 characters.

Follow [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0) guidelines and keywords to find the best
title.

Use parentheses to identify the package or feature that you worked on. For example:  `feat(services/chain)`
, `fix(scaffolding)`, `docs(migration)`.

### Review your own code

Make sure that you manually tested the changes you're introducing before creating a PR or pushing another commit.

Monitor your PR to make sure that all CI checks pass and the PR shows **All checks have passed** (the checkmark is
green).

### Do not rebase commits in your branch

Avoid rebasing after you open your PRs to reviews. Instead, add more commits to your PR. It's OK to do force pushes if
the PR is still in draft mode and was never opened to reviews before.

A reviewer likes to see a linear commit history while reviewing. If you tend to force push from an older commit, a
reviewer might lose track in your recent changes and will have to start reviewing from scratch.

Don't worry about adding too many commits. The commits are squashed into a single commit while merging. Your PR title is
used as the commit message.

## Contributing to documentation

When you open a PR for the node-infra codebase, you must also update the relevant documentation. For changes to:

* [Saga Docs](https://docs.saga.xyz/) ensure you have access to our Github Docs portal ([request access to the docs portal]()) and update the relevant documentation. Then submit a pull request in Github Docs.

### Ask for help

If you started a PR but couldn't finish it for whatever reason, don't give up. Instead, just ask for help. Someone else
can take over and assume the ownership.

We appreciate your contribution!