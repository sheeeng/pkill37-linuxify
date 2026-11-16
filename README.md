# linuxify

Prefer Homebrew's GNU alternatives to macOS command-line tools, without typing
`g` prefixes. All installation logic and environment setup live in one file:
`.linuxify`.

Requires macOS, [Homebrew](https://brew.sh), and Bash 3.2+ or Zsh. Fish and other
shells are not supported.

## Install

```bash
git clone https://github.com/pkill37/linuxify.git
cd linuxify
./.linuxify install
```

Installation adds missing packages and copies the executable dotfile to
`~/.linuxify`. Existing packages are not upgraded. The command works from any
working directory, and `~/.linuxify install` can be run again safely.

Add this line to `~/.zshrc` or `~/.bashrc`, after other PATH settings:

```bash
[ ! -f "$HOME/.linuxify" ] || . "$HOME/.linuxify"
```

For Bash login shells, ensure `~/.bash_profile` sources `~/.bashrc`. Open a new
terminal or source `~/.linuxify` to activate it. Sourcing only configures the
environment; arguments supplied to `source` never run installation commands.

Already have the packages? Source the repository's `.linuxify` directly, or copy
it to your home directory. No installation command is required for activation.

## Environment

Activation discovers Homebrew using `HOMEBREW_PREFIX`, `brew --prefix`, or the
standard `/opt/homebrew` and `/usr/local` installations. Set `HOMEBREW_PREFIX`
before sourcing to select a custom installation. Paths containing spaces are
supported. An explicitly configured prefix takes priority over `brew` on PATH.

Only existing directories are added, in this command search order:

1. Each listed formula's `libexec/gnubin` (including coreutils, gawk and gpatch).
2. Python's `libexec/bin`, for unversioned Python commands.
3. Each listed formula's `bin`, including keg-only tools.
4. Homebrew's `bin` and `sbin`, followed by your existing PATH.

The package list in `.linuxify` controls both installation and activation.
Matching manual/info directories are added to `MANPATH` and `INFOPATH`, preserving
system documentation lookup when those variables are empty or unset. Activation
also adds flex, bison and LibreSSL library flags to `LDFLAGS`, flex and LibreSSL
headers to `CPPFLAGS`, and LibreSSL metadata to `PKG_CONFIG_PATH`. Existing values
are preserved; repeated sourcing does not duplicate linuxify entries.

Activation does not change shell options or leave helper functions behind. If
macOS or Homebrew is unavailable, it prints a diagnostic and leaves the environment
unchanged, returning success so shell startup under `set -e` can continue.

## Commands

```bash
~/.linuxify --help
~/.linuxify info
~/.linuxify install
~/.linuxify uninstall
```

`info` shows Homebrew information for the package list. Installation includes GDB
on Intel Macs only; GDB permissions and signing must be configured separately.
Linuxify does not change your login shell, `/etc/shells`, `.gdbinit`, or shell
startup files.

`uninstall` removes only `~/.linuxify` and does not require Homebrew. Packages stay
installed. Remove the source line from your shell config if desired, then open a
new shell to clear the activated environment. It does not undo environment changes
in the current shell.

## Migrating

The former `./linuxify` entrypoint has been removed. Use `./.linuxify` in a checkout
or `~/.linuxify` after installation. Existing `. ~/.linuxify` startup lines still
work; the guarded line above also works after uninstalling. Installation replaces
the previous `~/.linuxify`, so save any custom changes before reinstalling.

## Development

```bash
bash tests/test.sh
```

Tests check Bash/Zsh syntax, activation, precedence, repeatability, and command
behavior using temporary homes and mocked Homebrew. They do not install packages
or modify your shell configuration. CI runs the same checks on macOS.
