# dzgui.flake
A nix flake providing [`dzgui`](https://github.com/aclist/dztui)
- a better way of launching DayZ on Linux.

## Why a flake?

With how quickly `dzgui` can introduce patches it'd probably be
quite a chore to update it in `nixpkgs` all the time.

This way I can adopt new updates faster and I can even update
the package without messing around with hashes and revisions.
I can just `nix flake update dzgui` and if there patches don't
break I am up to date.

## Why `dzgui`?

Because, as of now, I find other launchers for DayZ inferior.

I've tried other launchers but when I'm joining a server with hundreds
of mods it's a real chore to subscribe to every single one manually.

`dzgui` implemented a system that manages the mods without you needing to
manually subscribe to them. It's still considered experimental,

> [Link](https://aclist.github.io/dzgui/dzgui.html#_options), see `Options > Toggle release branch`
>
> This feature is experimental. It attempts to queue the mods requested for
> download automatically, rather than prompting the user to subscribe to each one.

but it's a real life saver if you like playing on modded servers.

It, of course, can do other things as well

> [Link](https://aclist.github.io/dzgui/dzgui.html#_what_this_is)
>
> Used to list official and community server details and quick connect
> to preferred servers by staging mods and concatenating launch options
> automatically.

## Usage

> [!Important]
> This flake provides both the `stable` and the `testing` branches of `dzgui`
> with `stable` being the default.
>
> This applies for everything apart from the dev shell.
>
> If you want to use the `testing` branch append `#dzgui-testing` to the
> flake path:
> Eg. `nix run "github:jiriks74/dzgui.flake#dzgui-testing"`

### Running `dzgui` directly

To run `dzgui` without installing it run

```bash
nix run "github:jiriks74/dzgui.flake"
```

### Including it as a package:

To include this flake as a package use `packages.x86_64-linux.dzgui`.

If don't have flake enabled nix [see wiki](https://wiki.nixos.org/wiki/Flakes#Using_flakes_with_stable_Nix).

[NixOS Flakes Wiki](https://wiki.nixos.org/wiki/Flakes)

### Dev shell

This flake also provides a dev shell for easier development of the packages.
You probably won't need it unless you want to modify the flake.

## Flake outputs

```
├───apps
│   └───x86_64-linux
│       ├───default: app
│       ├───dzgui: app
│       └───dzgui-testing: app
└───packages
    └───x86_64-linux
        ├───default: package 'DZGUI-bae6a57e1ee5660a07e3a3c326ec68617b831d31-1.0.0'
        ├───dzgui: package 'DZGUI-bae6a57e1ee5660a07e3a3c326ec68617b831d31-1.0.0'
        └───dzgui-testing: package 'DZGUI-testing-885c3bc7e78f79392ce1ad561d75596be0253424-1.0.0'
```
