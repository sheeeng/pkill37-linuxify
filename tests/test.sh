#!/bin/bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
TEMP=$(mktemp -d)
trap 'rm -rf "$TEMP"' EXIT
export TEST_ROOT=$ROOT TEST_TEMP=$TEMP
export HOME="$TEMP/home" HOMEBREW_PREFIX="$TEMP/brew prefix"
export BREW_LOG="$TEMP/brew.log" BREW_STATE="$TEMP/state"
mkdir -p "$HOME" "$BREW_STATE" "$HOMEBREW_PREFIX/bin" "$HOMEBREW_PREFIX/sbin"
cat > "$HOMEBREW_PREFIX/bin/brew" <<'BREW'
#!/bin/bash
printf '%s\n' "$*" >> "$BREW_LOG"
case "$1" in
    --prefix) printf '%s\n' "$TEST_PREFIX" ;;
    list) [ -f "$BREW_STATE/$3" ] ;;
    install)
        [ "${FAIL_FORMULA-}" != "$2" ] || exit 42
        touch "$BREW_STATE/$2" ;;
    info) exit 0 ;;
    *) exit 99 ;;
esac
BREW
chmod +x "$HOMEBREW_PREFIX/bin/brew"
export TEST_PREFIX=$HOMEBREW_PREFIX
for formula in coreutils make gawk gpatch; do
    mkdir -p "$HOMEBREW_PREFIX/opt/$formula/libexec/gnubin" "$HOMEBREW_PREFIX/opt/$formula/libexec/gnuman"
done
for formula in flex bison libressl; do
    mkdir -p "$HOMEBREW_PREFIX/opt/$formula/bin" "$HOMEBREW_PREFIX/opt/$formula/lib" "$HOMEBREW_PREFIX/opt/$formula/include"
done
mkdir -p "$HOMEBREW_PREFIX/opt/python/libexec/bin" "$HOMEBREW_PREFIX/share/man" "$HOMEBREW_PREFIX/share/info" "$HOMEBREW_PREFIX/opt/libressl/lib/pkgconfig"
printf '#!/bin/sh\nexit 0\n' > "$HOMEBREW_PREFIX/opt/coreutils/libexec/gnubin/ls"
chmod +x "$HOMEBREW_PREFIX/opt/coreutils/libexec/gnubin/ls"

for shell in /bin/bash /bin/zsh; do
    [ -x "$shell" ] || continue
    "$shell" -n "$ROOT/.linuxify"
    [ "$("$shell" -f "$ROOT/.linuxify")" = "$("$shell" -f "$ROOT/.linuxify" --help)" ]
    "$shell" -f -c '
        set -eu
        PATH="/usr/bin:/bin:$HOMEBREW_PREFIX/opt/coreutils/libexec/gnubin"
        MANPATH=""; INFOPATH=""; LDFLAGS="-L/custom"; CPPFLAGS="-DUSER"; PKG_CONFIG_PATH="/custom/pkg"
        before_options=$(set +o)
        . "$TEST_ROOT/.linuxify" install
        [ "$(set +o)" = "$before_options" ]
        [ "$(command -v ls)" = "$HOMEBREW_PREFIX/opt/coreutils/libexec/gnubin/ls" ]
        case "$PATH" in "$HOMEBREW_PREFIX/opt/coreutils/libexec/gnubin:"*) ;; *) exit 1;; esac
        case "$MANPATH" in *:) ;; *) exit 1;; esac
        case "$INFOPATH" in *:) ;; *) exit 1;; esac
        case "$LDFLAGS" in *"-L/custom"*) ;; *) exit 1;; esac
        case "$CPPFLAGS" in *"-DUSER"*) ;; *) exit 1;; esac
        case "$PKG_CONFIG_PATH" in *:/custom/pkg) ;; *) exit 1;; esac
        before="$PATH|$MANPATH|$INFOPATH|$LDFLAGS|$CPPFLAGS|$PKG_CONFIG_PATH"
        . "$TEST_ROOT/.linuxify"
        [ "$before" = "$PATH|$MANPATH|$INFOPATH|$LDFLAGS|$CPPFLAGS|$PKG_CONFIG_PATH" ]
        ! command -v _linuxify_main >/dev/null
        unset PATH MANPATH INFOPATH LDFLAGS CPPFLAGS PKG_CONFIG_PATH
        . "$TEST_ROOT/.linuxify"
        [ -n "$PATH" ] && [ -n "$MANPATH" ] && [ -n "$LDFLAGS" ]
        activate() { . "$TEST_ROOT/.linuxify"; }
        activate
        unset -f activate
        HOMEBREW_PREFIX="$TEST_TEMP/missing"
        before=$PATH
        . "$TEST_ROOT/.linuxify"
        [ "$PATH" = "$before" ]
        printf "Sourcing checks passed\n"
    '
done
[ ! -f "$BREW_LOG" ] # Sourcing uses the prefix without calling brew.
# Check brew-based prefix discovery and command lookup.
PATH="$HOMEBREW_PREFIX/bin:/usr/bin:/bin" /bin/bash -c '
    unset HOMEBREW_PREFIX
    . "$TEST_ROOT/.linuxify"
    [ "$(command -v ls)" = "$TEST_PREFIX/opt/coreutils/libexec/gnubin/ls" ]
'
# Exercise standard prefix layouts without touching actual Homebrew installs.
for layout in opt/homebrew usr/local; do
    HOMEBREW_PREFIX="$TEMP/$layout"
    mkdir -p "$HOMEBREW_PREFIX/bin"
    export HOMEBREW_PREFIX
    /bin/bash -c '
        . "$TEST_ROOT/.linuxify"
        case "$PATH" in "$HOMEBREW_PREFIX/bin:"*) ;; *) exit 1;; esac
        case "$PATH" in *"$HOMEBREW_PREFIX/opt/coreutils/"*) exit 1;; esac
    '
done
export HOMEBREW_PREFIX=$TEST_PREFIX
# Mock architecture detection for both Apple Silicon and Intel installation.
mkdir -p "$TEMP/system"
cat > "$TEMP/system/uname" <<'UNAME'
#!/bin/sh
printf '%s\n' "${MOCK_ARCH:-arm64}"
UNAME
chmod +x "$TEMP/system/uname"
export PATH="$TEMP/system:$PATH"
# Installation works from elsewhere, copies itself, and is repeatable.
(cd "$TEMP" && "$ROOT/.linuxify" install > /dev/null)
cmp "$ROOT/.linuxify" "$HOME/.linuxify"
[ ! -f "$BREW_STATE/gdb" ]
count=$(grep -c '^install ' "$BREW_LOG")
"$HOME/.linuxify" install >/dev/null
[ "$count" = "$(grep -c '^install ' "$BREW_LOG")" ]
MOCK_ARCH=x86_64 "$HOME/.linuxify" install >/dev/null
[ -f "$BREW_STATE/gdb" ]
/bin/zsh -f "$HOME/.linuxify" install >/dev/null
[ ! -e "$HOME/.gdbinit" ] && [ ! -e "$HOME/.bashrc" ] && [ ! -e "$HOME/.zshrc" ]
"$ROOT/.linuxify" info >/dev/null
if "$ROOT/.linuxify" invalid 2>/dev/null; then exit 1; fi
if "$ROOT/.linuxify" install extra 2>/dev/null; then exit 1; fi
HOMEBREW_PREFIX="$TEMP/missing" "$HOME/.linuxify" uninstall >/dev/null
[ ! -e "$HOME/.linuxify" ]
[ -f "$BREW_STATE/coreutils" ]
rm "$BREW_STATE/watch"
if FAIL_FORMULA=watch "$ROOT/.linuxify" install >/dev/null; then exit 1; fi
[ ! -e "$HOME/.linuxify" ]
printf 'All linuxify tests passed.\n'
