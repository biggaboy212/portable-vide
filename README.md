<br>

<div align="center">
    <img src="docs/public/full_logo.svg" width="600" />
</div>

Vide is a reactive Luau UI library inspired by [Solid](https://www.solidjs.com/).

- Fully Luau typecheckable
- Declarative and concise syntax.
- Reactively driven.

## Getting started

Read the
[crash course](https://centau.github.io/vide/tut/crash-course/1-introduction)
for a quick introduction to the library.

## Grabbing a release

Releases are provided at: [portable-vide/releases](https://github.com/biggaboy212/portable-vide/releases)

### Loading a release via HTTP

```luau
local version = "0.4.0"
local vide = loadstring(game:HttpGet(`https://github.com/biggaboy212/Cascade/releases/download/{version}/release.luau`))
```

> We also provide typed versions of each release
>
> ```luau
> local version = "0.4.0"
> local vide = loadstring(game:HttpGet(`https://github.com/biggaboy212/Cascade/releases/download/{version}/release-typed.luau`))
> ```

## Code sample

```luau
local create = vide.create
local source = vide.source

local function Counter()
    local count = source(0)

    return create "TextButton" {
        Text = function()
            return "count: " .. count()
        end,

        Activated = function()
            count(count() + 1)
        end
    }
end
```
