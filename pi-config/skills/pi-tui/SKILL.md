---
name: pi-tui
description: >
  Reference for customizing the pi TUI: footer, header, working indicator,
  status line, widgets, editor, themes, and tool rendering.
---

# pi-tui Skill

All visual customization is done via TypeScript **extensions** in
`pi-config/extensions/`. Deploy with `./pi-config/deploy.sh`, reload live with
`/reload`. Pass `undefined` to any setter to restore the pi default.

## Customizable surfaces

| Surface | API | Notes |
|---|---|---|
| Footer | `ctx.ui.setFooter(factory)` | `footerData` gives git branch + statuses; token stats via `ctx.sessionManager` |
| Header | `ctx.ui.setHeader(factory)` | Replaces logo + keybinding hints |
| Working spinner | `ctx.ui.setWorkingIndicator({ frames, intervalMs? })` | `frames: []` hides it; `undefined` restores default |
| Status text | `ctx.ui.setStatus(id, text)` | Injected into footer; `undefined` clears |
| Widgets | `ctx.ui.setWidget(id, lines \| factory, { placement? })` | `"aboveEditor"` (default) or `"belowEditor"` |
| Editor | `ctx.ui.setEditorComponent(factory)` | Extend `CustomEditor` from `@earendil-works/pi-coding-agent` |
| Tool rendering | `renderCall` / `renderResult` on `pi.registerTool()` | Return a `Component` |

## Themes (no code needed)

Create `pi-config/themes/my-theme.json` with `"extends": "dark"` or `"light"`,
then override only the colors you want. Switch with `/theme my-theme` or set
`"theme"` in `settings.json`.

## Theme color keys

`theme.fg(key, text)` / `theme.bg(key, text)` — key reference:

- **General:** `text`, `accent`, `muted`, `dim`
- **Status:** `success`, `error`, `warning`
- **Borders:** `border`, `borderAccent`, `borderMuted`
- **Tools:** `toolTitle`, `toolOutput`
- **Syntax:** `syntaxKeyword`, `syntaxFunction`, `syntaxString`, `syntaxComment`, `syntaxType`, `syntaxNumber`
- **Backgrounds:** `selectedBg`, `toolPendingBg`, `toolSuccessBg`, `toolErrorBg`
- **Styles:** `theme.bold()`, `theme.italic()`, `theme.strikethrough()`

## TUI component primitives

From `@earendil-works/pi-tui`: `Text`, `Box`, `Container`, `Spacer`, `Markdown`.
Utilities: `truncateToWidth`, `visibleWidth`, `wrapTextWithAnsi`, `matchesKey`, `Key`.

Every line from `render(width)` must not exceed `width`. Use `truncateToWidth(str, width)`.

## footerData (only inside setFooter)

- `footerData.getGitBranch(): string | null`
- `footerData.getExtensionStatuses(): ReadonlyMap<string, string>`
- `footerData.onBranchChange(cb): () => void` — return value goes in `dispose`

## Extension examples

Canonical reference examples ship with pi at:
`node_modules/@earendil-works/pi-coding-agent/examples/extensions/`

Relevant: `custom-footer.ts`, `custom-header.ts`, `status-line.ts`,
`working-indicator.ts`, `modal-editor.ts`, `widget-placement.ts`.
