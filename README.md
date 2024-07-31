# Secrets encryption for Git

[//]: # "SPDX-License-Identifier: MIT"

## Abstract

Automatically encrypt and decrypt secrets in git repository on clone, commit and pull/merge. Files which you choose to protect are encrypted when committed, and decrypted when checked out. Developers without the secret key can still clone and commit to a repository with encrypted files.

## Prerequisites

1. [git v2.9.0+](https://git-scm.com/downloads)
2. [sops v3.0.0+](https://github.com/getsops/sops)
3. [yq](https://pypi.org/project/yq/)

If something is missing, installation will abort with apropriate message (WIP [#4](https://github.com/timaliev/git-secrets-encryption/issues/4)).

## Installation

`$ curl -sS https://raw.githubusercontent.com/timaliev/git-secrets-encryption/master/secretsencryption.sh | /bin/bash`

This will install Git hooks from `.githooks` to your home directory and set global `core.hooksPath` to it (supported by Git v2.9.0 and later). If you have existing Git hooks directory with the same name it will be backed up and you will be informed during installation.

For now setup is working only with `sops` assisted encryption. See `sops --help` or [sops project documentation](https://github.com/getsops/sops) for further information.

## Usage

Basically, the process for developers is the same as usual: clone, commit, pull, and push. Some (or all, depending on your configuration) files are transparently encrypted when committed and decrypted when pulled or merged. The only special thing to note is the Git status. Encrypted files will always be marked as "modified" because they are stored encrypted in Git and decrypted after checkout.

Also it's not possible to get meaninful diff for protected files. But since `sops` is used it's not that important for INI, YAML and JSON files as it's possible to protect only some fields.

The result is that all secrets in Git, and therefore in the remote repository, are encrypted and only accessible to developers who have the encryption key.

## Configuration

There are some `git config` parameters and one configuration file: `.secretsencryption-sops.yaml`. Configuration parameters are set via `git config` (see git-config(1))

### Parameters description

- hooks.secretsencrypton -- enable or disable secrets encryption per repository or globally. For now only "none" and "sops-inline" are supported. If you want secrets decryption during clone operations this must be set globally. Presence of `.secretsencryption-sops.yaml` configuration file in the repository root in conjunction with not "none" value of this flag is needed to turn secrets encryption/decryption on for this repository. This flag will be configured to "sops-inline" by installation script. If it's empty, warning message will be shown on git clone/pull/commit operations but encryption wont be enabled.
- hooks.strictencryption -- set this flag to `false` to allow unencrypted commits (if encryption process is failed for some or all files). By default flag is unset which means `true`. If you want to be able to commit unencrypted files because encryption failed, set it to `false`.
- hooks.secretsencryption-debug -- turn on verbosity for hooks during execution. By default flag is not present and it means verbosity is turned off. You can turn it on based on repository or globally. Local git config settings (by repository) always have priority over global settings.

Note, that configuration flags are checked without `--global` option for Git, so local configuration of repository is having precidence over global.

### Configuration file description

`.secretsencryption-sops.yaml` configuration file is needed because we need some way to specify pattern for files that shoud be encrypted (independent of `sops.yaml` configuration) and indicate that secrets encryption is enabled for this particular repository at the same time. There is only one YAML key used in this file: `path_regex`. See example in `example.secretsencryption-sops.yaml`.

Otherwise, `sops` will work normally, using rules from `sops.yaml`, for all files in repository working tree matching the specified patterns in `.secretsencryption-sops.yaml`. Note, that sops configuration is out of scope of this document or hooks setup. See [sops documentation](https://github.com/getsops/sops) for more details.

In case of any problematic situation for scripts there will be indicative message during execution.

## Credits

Inspired by this post [Zev Averbach: Oops, I Did It Again: Automatically Encrypting Secrets](https://zev.averba.ch/oops)
