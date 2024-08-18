[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://github.com/timaliev/git-secrets-encryption/blob/master/README.md)

# Secrets encryption for Git

[//]: # "SPDX-License-Identifier: MIT"

## Abstract

Automatically encrypt and decrypt secrets in git repository on clone, commit and pull/merge. Files which you choose to protect are encrypted when committed, and decrypted when checked out. Developers without the secret key can still clone and commit to a repository with encrypted files.

## WARNING: WORK IN PROGRESS

This is work in progress. Current version has this known limitations:

1. All encrypted files has status 'modified' even right after `git clone`. This is because files are normally encrypted only in Git index and decrypted in working tree. You can prefer to keep secret files encrypted in working tree also, see `hooks.repository-locked` flag description in [Parameters description](#parameters-description) section.
1. Best practice is to keep secret files in particular directory, for instance `<repository root>/secrets`, so it would be easer to visually skip encrypted files in `git status` output.
1. Many git operations or variants of operations, for instance complex diff-based like `git-merge(1)`, are not tested and may be not working.

## Why SOPS, why not to use git-crypt?

There is an excellent project [git-crypt](https://github.com/AGWA/git-crypt) which one definitely must check out first, for the purpose of encrypting Git repository content.

Unlike `git-crypt`, this project uses primarily [SOPS](https://getsops.io) and possibly other encryption tools. So, why SOPS?

1. SOPS is an excellent tool, actively maintained under Cloud Native Computing Foundation sandbox project.
1. SOPS allows to encrypt files partially, based on YAML/JSON/INI key.
1. SOPS can use different encryption algorithms.
1. SOPS allows to securely share encryption keys, for example using AWS secrets or GPG. So, whole development team and/or CI/CD pipeline can have access to secrets but not strangers.
1. In addition, you can recreate encryption with new key (rotate key) simply by adding files to Git's index. Therefore, only current team members who have access to the current encryption key can access the actual secret content. This process can even be automated using CI/CD tools.

## Prerequisites

1. [git v2.9.0+](https://git-scm.com/downloads)
2. [sops v3.0.0+](https://getsops.io/docs/#download)
3. [yq](https://pypi.org/project/yq/)

If something is missing, installation will abort with appropriate message.

## Installation

`curl -sS https://raw.githubusercontent.com/timaliev/git-secrets-encryption/master/secretsencryption.sh | /bin/bash`

This will install Git hooks from `.githooks` to your home directory and set global `core.hooksPath` to it (supported by Git v2.9.0 and later). If you have existing Git hooks directory with the same name it will be backed up and you will be informed during installation.

For now setup is working only with SOPS assisted encryption. See `sops --help` or [SOPS project documentation](https://getsops.io/docs/) for further information.

## Usage

Basically, the process for developers is the same as usual: clone, commit, pull, and push. Some files, depending on your configuration, are transparently encrypted when committed and decrypted when pulled or merged. As a result, all secrets stored in Git, including those in the remote repository, are protected by encryption. Only developers with the appropriate encryption key can access these secrets.

In default configuration, files chosen to be encrypted in Git will always appear as modified in `git status` output. That is why, best practice is to use separate directory in working tree to store secrets. See [Git diff](#git-diff) section for more details.

For now, there is only one encryption method: using SOPS. If it is properly configured, you can use `sops` command normally to encrypt and decrypt files in working tree in parallel with Git hooks. Note: if there is more than one `.sops.yaml` configuration file, the best practice is to operate on secret file in it's own directory. See [Configuration file description](#configuration-file-description) section.

## Configuration

There are few `git config` parameters and one configuration file: `.secretsencryption-sops.yaml`. Configuration parameters are set via `git config` (see `git-config(1)`)

### Parameters description

- hooks.secretsencrypton -- enable or disable secrets encryption per repository or globally. Only "none" and "sops-inline" options are supported. If you want secrets decryption during clone operations this parameter must be set globally. Presence of `.secretsencryption-sops.yaml` configuration file in the repository root in conjunction with not "none" value of this parameter is needed to turn secrets encryption/decryption on for this repository. This parameter will be configured globally to "sops-inline" by installation script. If parameter is empty, warning message will be shown on git clone/pull/commit operations but encryption won't be enabled.
- hooks.strictencryption -- allow unencrypted commits (if encryption process is failed for some or all files). By default flag is unset which is equivalent to `true`. If you want to be able to commit unencrypted files (because encryption failed), set it to `false`. Warning: this may lead to unencrypted secrets in Git repositories.
- hooks.secretsencryption-debug -- turn on verbosity for hooks during execution. By default flag is not present and it is equivalent to `false` (verbosity is turned off). You can turn it on based on repository or globally.
- diff.sops.command -- this must be set to the the name of diff script (or absolute path to this script) that will be used in `git diff` command for encrypted files. This option will be configured globally to `"${HOME}/.githooks/git-diff-sops-inline.sh"` by installation script. Functionality is explained below in section [Git diff](#git-diff).
- hooks.repository-locked -- status of encrypted files in working tree. If this flag is set to `true`, secret files are left encrypted in working tree (besides they are already encrypted in Git's index) even if they can be decrypted. By default flag is unset which is equivalent to `false`. To view or modify file's content they must be decrypted manually. It is convenient to use `sops exec-env` in this mode (if SOPS is used, see [SOPS Documentation](https://getsops.io/docs/) for more details).

Note, that configuration flags are checked in code without `--global` option for Git, so local configuration of repository is having precedence over global.

In case of any problematic situation for scripts there will be indicative message during execution.

### Configuration file description

The `.secretsencryption-sops.yaml` file is needed in order to specify a pattern for files that should be encrypted (independently of the `.sops.yaml` configuration). This is because specifying a path regex in `.sops.yaml` would encrypt the whole matching file, rather than just the chosen JSON/YAML/INI keys. If `.secretsencryption-sops.yaml` file is not present or misconfigured, encryption is disabled for this repository and appropriate message is displayed during commit and merge git operations.

The only YAML key used in `.secretsencryption-sops.yaml` is `creation_rules.path_regex`, as can be seen in the example file `example.secretseencryption-sops.yaml`.

SOPS would work normally, using the rules from the `.sops.yaml` for all files in the repository that match the specified patterns. SOPS configuration is outside the scope of this document and hooks setup. For more information, see the [SOPS documentation](https://getsops.io/docs/).

Note also that for every file in the working tree that matches the `path_regex` pattern in the `.secretsencryption-sops.yaml` file, `sops` will be run from the corresponding directory that contains this file. This allows for custom `sops` configurations to be defined in the `.sops.yaml` file for each directory.

You can see example of such setup in the testing example repository (available in the "Testing" section). There are three similar YAML files with users information (users.yaml, sub/more-users.yaml, and sub/secrets/users.yaml) and they are all encrypted differently according to the `.sops.yaml` settings in their respective directories.

## Git diff

Git diff works for Git programs that respect the `.gitattributes` file. At the moment, it is the `git` command itself. You can also use any other `git-diff(1)` option. It will show you the difference in the decrypted file content if you are able to decrypt the secrets. Otherwise, the differences between encrypted files will be shown. No content is modified in the working tree during the diff, so if your files are normally encrypted in working tree, this is a safe operation.

Note that although `git diff` may work correctly (if you have access to the encryption keys), `git status` will still show you that a file with encrypted content has been modified. If you do not want this behavior, you can choose to keep the secret files encrypted in the working tree (see [Parameters description](#parameters-description) section).

## Testing

You can safely test this Git hooks on [test repository](https://github.com/timaliev/test-git-secrets-encryption).

Automation testing is WIP (see [#22](https://github.com/timaliev/git-secrets-encryption/issues/22)).

Currently, all testing is done manually on macOS 14.5 Sonoma (M1).

## Support

Only latest version is supported. If you have any [issues](https://github.com/timaliev/git-secrets-encryption/issues/new/choose) or [pull requests](https://github.com/timaliev/git-secrets-encryption/compare), please file them on GitHub.

Be aware that Git is a complex tool and it's distributed nature add even more complexity. Due to the complexity of the tool, it's not feasible to test all use cases, even though it's technically possible. Therefore, be aware that **there may be bugs** in the project that could affect even major functionality of the Git system.

## Credits

Inspired by this post [Zev Averbach: Oops, I Did It Again: Automatically Encrypting Secrets](https://zev.averba.ch/oops)
