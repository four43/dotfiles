# ZSH

ZSH or ZShell is a much improved drop in replacement for bash. It has more customization options and more functionality over bash.

## Layout

Shells are differentiated between [login and interactive shells](https://stackoverflow.com/a/18187389/387851)

> For example, if you login to bash using an xterm or terminal emulator like putty, then the session is both a login shell and an interactive one. If you then type bash then you enter an interactive shell, but it is not a login shell.
> 
> If a shell script (a file containing shell commands) is run, then it is neither a login shell nor an interactive one.

 * profile is used for login shells
 * rc is for interactive

Typically we just want both.

