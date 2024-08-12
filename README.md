[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://github.com/timaliev/git-secrets-encryption/blob/master/README.md)

# Secrets encryption for Git

[//]: # "SPDX-License-Identifier: MIT"

## Abstract

Automatically encrypt and decrypt secrets in git repository on clone, commit and pull/merge. Files which you choose to protect are encrypted when committed, and decrypted when checked out. Developers without the secret key can still clone and commit to a repository with encrypted files.

## WARNING: WORK IN PROGRESS

This is work in progress. Current version has this known limitations:

1. All encrypted files has status 'modified' right after commit. This is because files are normally encrypted only in git repository. You can change this manually encrypting them in working tree, but they will be unencrypted on next `git pull` or `git checkout`. There is an issue [#26](https://github.com/timaliev/git-secrets-encryption/issues/26) to workaround this bug.
1. Overall, in `git status` output it is not possible to differentiate between files you have changed and all encrypted files. Current workaround is to keep secret files in particular directory, for instance `/secrets`, so it would be easer to visually find encrypted files.
1. Many git operations or variants of operations, for instance complex diff-based like `git-merge(1)`, are not tested and may be not working.

## Prerequisites

1. [git v2.9.0+](https://git-scm.com/downloads)
2. [sops v3.0.0+](https://github.com/getsops/sops)
3. [yq](https://pypi.org/project/yq/)

If something is missing, installation will abort with appropriate message.

## Installation

`curl -sS https://raw.githubusercontent.com/timaliev/git-secrets-encryption/master/secretsencryption.sh | /bin/bash`

This will install Git hooks from `.githooks` to your home directory and set global `core.hooksPath` to it (supported by Git v2.9.0 and later). If you have existing Git hooks directory with the same name it will be backed up and you will be informed during installation.

For now setup is working only with `sops` assisted encryption. See `sops --help` or [sops project documentation](https://github.com/getsops/sops) for further information.

## Usage

Basically, the process for developers is the same as usual: clone, commit, pull, and push. Some (or all, depending on your configuration) files are transparently encrypted when committed and decrypted when pulled or merged. The only special thing to note is the Git status. Encrypted files will always be marked as "modified" because they are stored encrypted in Git and decrypted after checkout.

Also it's not possible to get meaningful diff for protected files. But since `sops` is used it's not that important for INI, YAML and JSON files as it's possible to protect only some fields.

The result is that all secrets in Git, and therefore in the remote repository, are encrypted and only accessible to developers who have the encryption key.

## Configuration

There are few `git config` parameters and one configuration file: `.secretsencryption-sops.yaml`. Configuration parameters are set via `git config` (see `git-config(1)`)

### Parameters description

- hooks.secretsencrypton -- enable or disable secrets encryption per repository or globally. For now only "none" and "sops-inline" are supported. If you want secrets decryption during clone operations this must be set globally. Presence of `.secretsencryption-sops.yaml` configuration file in the repository root in conjunction with not "none" value of this flag is needed to turn secrets encryption/decryption on for this repository. This flag will be configured globally to "sops-inline" by installation script. If flag is empty, warning message will be shown on git clone/pull/commit operations but encryption wont be enabled.
- hooks.strictencryption -- allow unencrypted commits (if encryption process is failed for some or all files). By default flag is unset which is equivalent to `true`. If you want to be able to commit unencrypted files (because encryption failed), set it to `false`. Warning: this may lead to unencrypted secrets in Git repositories.
- hooks.secretsencryption-debug -- turn on verbosity for hooks during execution. By default flag is not present and it is equivalent to `false` (verbosity is turned off). You can turn it on based on repository or globally.
- diff.sops.command -- this must be set to the the name of diff script (or absolute path to this script) that will be used in `git diff` command for encrypted files. This option will be configured globally to `"${HOME}/.githooks/sops-inline"` by installation script. Functionality is explained below in section [Git diff](#git-diff).

Note, that configuration flags are checked in code without `--global` option for Git, so local configuration of repository is having precedence over global.

In case of any problematic situation for scripts there will be indicative message during execution.

### Configuration file description

The `.secretsencryption-sops.yaml` file is needed in order to specify a pattern for files that should be encrypted (independently of the `.sops.yaml` configuration). This is because specifying a path regex in `.sops.yaml` would encrypt the whole matching file, rather than just the chosen JSON/YAML/INI keys. If `.secretsencryption-sops.yaml` file is not present or misconfigured, encryption is disabled for this repository and appropriate message is displayed during commit and merge git operations.

The only YAML key used in `.secretsencryption-sops.yaml` is `path_regex`, which can be seen in the example file `example.secretseencryption-sops.yaml`.

`sops` would work normally, using the rules from the `.sops.yaml` for all files in the repository that match the specified patterns. Note that the sops configuration is outside the scope of this document and hooks setup. For more information, see the [sops documentation](https://github.com/getops/sops).

Note also that for every file in the working tree that matches the `path_regex` pattern in the `.secretsencryption-sops.yaml` file, `sops` will be run from the corresponding directory that contains this file. This allows for custom `sops` configurations to be defined in the `.sops.yaml` file for each directory.

You can see example of such setup in the testing example repository (available in the "Testing" section). There are three similar YAML files with users information (users.yaml, sub/more-users.yaml, and sub/secrets/users.yaml) and they are all encrypted differently according to the `.sops.yaml` settings in their respective directories.

## Git diff

Git diff works for Git programs that respect the `.gitattributes` file. At the moment, it is the `git` command itself. You can also use any other `git-diff(1)` option. It will show you the difference in the decrypted file content if you are allowed to decrypt the secrets. Otherwise, the differences between encrypted files will be shown. No content is modified in the working tree during the diff, so if your files are usually encrypted, this is a safe operation.

Note that although `git diff` may work correctly (if you have access to the encryption keys), `git status` will still show you that a file with encrypted content has been modified. If you do not want this behavior, you can choose to keep the secret files encrypted in the working tree (see [[#26](https://github.com/timaliev/git-secrets-encryption/issues/26)]).

## Testing

You can safely test this Git hooks on [test repository](https://github.com/timaliev/test-git-secrets-encryption).

Automation testing is WIP (see [#22](https://github.com/timaliev/git-secrets-encryption/issues/22)).

## Support

Only latest version is supported. If you have any [issues](https://github.com/timaliev/git-secrets-encryption/issues/new/choose) or [pull requests](https://github.com/timaliev/git-secrets-encryption/compare), please file them on GitHub.

Be aware that `git` is a complex tool and it's distributed nature add even more complexity. Due to the complexity of the tool, it's not feasible to test all use cases, even though it's technically possible. Therefore, **there may be bugs** in the project that could affect even major functionality of the Git system.

## Credits

Inspired by this post [Zev Averbach: Oops, I Did It Again: Automatically Encrypting Secrets](https://zev.averba.ch/oops)
