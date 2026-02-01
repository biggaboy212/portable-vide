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

> [!NOTE]
> By default, vide.luau is minified for performance and fetch times. If you need specific features, you can fetch these variants instead:
>
> `vide-typed.luau` - Includes types
>
> `vide-unminified.luau` - Is not minified and contains types. Raw bundle output.

### Loading the latest release via HTTP

```luau
local vide = loadstring(game:HttpGet(`https://github.com/biggaboy212/portable-vide/releases/latest/download/vide.luau`))
```

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
