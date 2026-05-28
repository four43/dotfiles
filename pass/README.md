# pass — encrypted secret store

This directory wires up a [`pass`](https://www.passwordstore.org/) password
store. **This dotfiles repo is public**, so the actual store is kept in a
**separate private repo — `four43/pass-store` — included here as a git submodule
at `store/`** (symlinked to `~/.password-store`). The encrypted `*.gpg` files
are committed to that *private* submodule; this public repo records only the
submodule pointer and URL, never the secrets.

The GPG **private key** lives only in `~/.gnupg` and is committed *nowhere* —
export/import it manually per machine (see below).

⚠️ Even in the private repo, secret *names* (the `.gpg` filenames and directory
layout) are stored in cleartext — don't encode sensitive info in entry names.

## First-time setup (new machine)

The store and its `.gpg-id` already live in the private submodule, so you do
*not* re-run `pass init`. You only need your GPG key present and the submodule
cloned.

```sh
# 1. Import your GPG private key (see "Moving the key" below) and trust it.

# 2. Clone the private submodule. Needs read access to four43/pass-store as the
#    `four43` GitHub account:
cd ~/.dotfiles && git submodule update --init pass/store

# 3. Run dotbot to create symlinks (~/.password-store -> pass/store, the
#    gpg-agent.conf, the VS Code launcher override, etc.):
./install

# 4. Verify a secret decrypts:
pass show github.com/VaisalaCorp/PAT_Non_Destructive_CLI >/dev/null && echo OK
```

## Adding / changing secrets

```sh
pass insert some/new-secret      # auto-commits to the private store repo
pass git push                    # publish to four43/pass-store
# Optionally bump the submodule pointer in dotfiles so it tracks the new commit:
git -C ~/.dotfiles add pass/store && git -C ~/.dotfiles commit -m 'bump pass-store'
```

## Moving the key to another machine

```sh
# On the machine that has the key:
gpg --export-secret-keys --armor <KEY_ID> > /tmp/key.asc   # transfer securely!
# On the new machine:
gpg --import /tmp/key.asc && shred -u /tmp/key.asc
```

## How VS Code consumes these

`~/.local/share/applications/code.desktop` (override) launches
`bin/code-with-secrets`, which decrypts the entries listed in that script and
exports them into VS Code's environment. Edit the `SECRETS` map there to add or
remove variables.
