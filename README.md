# Secrets encryption for Git

[//]: # "SPDX-License-Identifier: MIT"

## Abstract

Automatically encrypt and decrypt secrets in git repository on clone, commit and pull/merge. Files which you choose to protect are encrypted when committed, and decrypted when checked out. Developers without the secret key can still clone and commit to a repository with encrypted files.

## Prerequisites

1. [git v2.9.0+](https://git-scm.com/downloads)
2. [sops v3.0.0+](https://github.com/getsops/sops)
3. [yq](https://pypi.org/project/yq/)

If something is missing, installation will abort with apropriate message.

## Installation

`$ curl -sS https://raw.githubusercontent.com/timaliev/git-secrets-encryption/master/secretsencryption.sh | /bin/bash`

This will install Git hooks from `.githooks` to your home directory and set global `core.hooksPath` to it (supported by Git v2.9.0 and later). If you have existing Git hooks directory with the same name it will be backed up and you will be informed during installation.

For now setup is working only with `sops` assisted encryption. See `sops --help` or [sops project documentation](https://github.com/getsops/sops) for further information.

## Usage

Basically, the process for developers is the same as usual: clone, commit, pull, and push. Some (or all, depending on your configuration) files are transparently encrypted when committed and decrypted when pulled or merged. The only special thing to note is the Git status. Encrypted files will always be marked as "modified" because they are stored encrypted in Git and decrypted after checkout.

Also it's not possible to get meaninful diff for protected files. But since `sops` is used it's not that important for INI, YAML and JSON files as it's possible to protect only some fields.

The result is that all secrets in Git, and therefore in the remote repository, are encrypted and only accessible to developers who have the encryption key.

## Configuration

There are few `git config` parameters and one configuration file: `.secretsencryption-sops.yaml`. Configuration parameters are set via `git config` (see `git-config(1)`)

### Parameters description

- hooks.secretsencrypton -- enable or disable secrets encryption per repository or globally. For now only "none" and "sops-inline" are supported. If you want secrets decryption during clone operations this must be set globally. Presence of `.secretsencryption-sops.yaml` configuration file in the repository root in conjunction with not "none" value of this flag is needed to turn secrets encryption/decryption on for this repository. This flag will be configured to "sops-inline" by installation script. If it's empty, warning message will be shown on git clone/pull/commit operations but encryption wont be enabled.
- hooks.strictencryption -- allow unencrypted commits (if encryption process is failed for some or all files). By default flag is unset which is equivalent to `true`. If you want to be able to commit unencrypted files because encryption failed, set it to `false`. Warning: this may lead to unencrypted secrets in Git repositories.
- hooks.secretsencryption-debug -- turn on verbosity for hooks during execution. By default flag is not present and it is equivalent to `false` (verbosity is turned off). You can turn it on based on repository or globally.

Note, that configuration flags are checked in code without `--global` option for Git, so local configuration of repository is having precidence over global.

In case of any problematic situation for scripts there will be indicative message during execution.

### Configuration file description

The `.secretsencryption-sops.yaml` file is needed in order to specify a pattern for files that should be encrypted (independently of the `.sops.yaml` configuration). This is because specifying a path regex in `.sops.yaml` would encrypt the whole matching file, rather than just the chosen JSON/YAML/INI keys. If `.secretsencryption-sops.yaml` file is not present or misconfigured, encryption is disabled for this repository and apropriate message is displayed during commit and merge git operations.

The only YAML key used in `.secretsencryption-sops.yaml` is `path_regex`, which can be seen in the example file `example.secretseencryption-sops.yaml`.

`sops` would work normally, using the rules from the `.sops.yaml` for all files in the repository that match the specified patterns. Note that the sops configuration is outside the scope of this document and hooks setup. For more information, see the [sops documentation](https://github.com/getops/sops).

Note also that for every file in the working tree that matches the `path_regex` pattern in the `.secretsencryption-sops.yaml` file, `sops` will be run from the corresponding directory that contains this file. This allows for custom `sops` configurations to be defined in the `.sops.yaml` file for each directory.

You can see example of such setup in the testing example repository (available in the "Testing" section). There are three similar YAML files with users information (users.yaml, sub/more-users.yaml, and sub/secrets/users.yaml) and they are all encrypted differently according to the `.sops.yaml` settings in their respective directories.

## Testing

You can safely test this Git hooks on [test repository](https://github.com/timaliev/test-git-secrets-encryption).

## Credits

Inspired by this post [Zev Averbach: Oops, I Did It Again: Automatically Encrypting Secrets](https://zev.averba.ch/oops)
