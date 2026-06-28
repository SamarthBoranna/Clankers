/**
 * tui-design — custom pi TUI extension (Nord palette, zentui-inspired)
 *
 * A clean, minimal, dark-mode footer modeled on pi-zentui's Starship-style
 * footer (https://pi.dev/packages/pi-zentui), colored with the Nord palette.
 *
 * Surfaces:
 *   Footer  — ctx.ui.setFooter(...)
 *     left  : 󰝰 dir    branch
 *     right : model | level | <ctx%>/<window> | <tokens> | $<cost>
 *
 * Requires a Nerd Font for the cwd / branch glyphs.
 *
 * Design reference:
 *   ~/.nvm/.../pi-coding-agent/docs/extensions.md   — extension API
 *   ~/.nvm/.../pi-coding-agent/examples/extensions/  — canonical examples
 */

import { basename } from "node:path";

import type { AssistantMessage } from "@earendil-works/pi-ai";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { truncateToWidth, visibleWidth } from "@earendil-works/pi-tui";

// ─── Nord palette ─────────────────────────────────────────────────────────────
// https://www.nordtheme.com/  ·  each entry: (text, bold?) => styled string
const RESET = "\x1b[0m";
const mk =
  (r: number, g: number, b: number) =>
  (t: string, bold = false) =>
    `\x1b[${bold ? "1;" : ""}38;2;${r};${g};${b}m${t}${RESET}`;

const nord = {
  text: mk(216, 222, 233), //   nord4  — primary text
  muted: mk(76, 86, 106), //    nord3  — dim / secondary
  frost: mk(136, 192, 208), //  nord8  — accent (cyan)
  purple: mk(180, 142, 173), // nord15 — branch
  green: mk(163, 190, 140), //  nord14 — cost
  yellow: mk(235, 203, 139), // nord13 — context warning
  red: mk(191, 97, 106), //     nord11 — context critical
};

// ─── Glyphs (Nerd Font) ───────────────────────────────────────────────────────
const ICON = {
  cwd: "\u{F0770}", // 󰝰  nf-md-folder
  branch: "\u{E0A0}", //   nf-pl-branch
};

const SEP = "  ";
const PIPE = nord.muted(" | ");

// ─── Formatting helpers ───────────────────────────────────────────────────────
const fmtTokens = (n: number) =>
  n < 1000 ? `${n}` : n < 1_000_000 ? `${(n / 1000).toFixed(1)}k` : `${(n / 1_000_000).toFixed(1)}M`;

// Context window, compact and without a trailing ".0" (e.g. 1000000 → "1M").
const fmtWindow = (n: number) => fmtTokens(n).replace(".0", "");

const fmtCost = (n: number) => `$${n.toFixed(3)}`;

// ─── Extension entry point ────────────────────────────────────────────────────
export default function (pi: ExtensionAPI) {
  pi.on("session_start", (_e, ctx) => {
    if (!ctx.hasUI) return;

    const cwd = ctx.cwd ?? "";

    // Lets model / thinking-level changes refresh the footer immediately.
    let requestRender: (() => void) | null = null;

    // ── Footer ────────────────────────────────────────────────────────────────
    ctx.ui.setFooter((tui, _theme, footerData) => {
      requestRender = () => tui.requestRender();

      const unsubBranch = footerData.onBranchChange(() => {
        tui.requestRender();
      });

      return {
        dispose() {
          unsubBranch();
        },
        invalidate() {},
        render(width: number): string[] {
          // Cumulative usage across the session branch.
          let input = 0;
          let output = 0;
          let cost = 0;
          for (const e of ctx.sessionManager.getBranch()) {
            if (e.type === "message" && e.message.role === "assistant") {
              const m = e.message as AssistantMessage;
              input += m.usage.input;
              output += m.usage.output;
              cost += m.usage.cost.total;
            }
          }

          // ── Left: cwd · branch ──
          const dir = basename(cwd) || cwd;
          const leftParts = [`${nord.frost(ICON.cwd)} ${nord.frost(dir, true)}`];
          const branch = footerData.getGitBranch();
          if (branch) leftParts.push(`${nord.purple(ICON.branch)} ${nord.purple(branch, true)}`);
          const left = leftParts.join(SEP);

          // ── Right: model | level | ctx%/window | tokens | cost (sleek, unbold) ──
          const model = ctx.model?.name ?? ctx.model?.id ?? "no model";
          const reasoning = ctx.model?.reasoning ?? false;
          const level = pi.getThinkingLevel();

          const usage = ctx.getContextUsage();
          const pct = usage?.percent != null ? Math.round(usage.percent) : null;
          const window = usage?.contextWindow ?? ctx.model?.contextWindow ?? 0;
          const ctxColor =
            pct == null ? nord.muted : pct >= 90 ? nord.red : pct >= 70 ? nord.yellow : nord.muted;
          const ctxStr = window ? `${pct ?? "—"}%/${fmtWindow(window)}` : `${pct ?? "—"}%`;

          const rightParts = [nord.frost(model)];
          if (reasoning && level !== "off") rightParts.push(nord.muted(level));
          rightParts.push(ctxColor(ctxStr));
          rightParts.push(nord.muted(fmtTokens(input + output)));
          rightParts.push(nord.green(fmtCost(cost)));
          const right = rightParts.join(PIPE);

          const gap = Math.max(1, width - visibleWidth(left) - visibleWidth(right));
          return [truncateToWidth(left + " ".repeat(gap) + right, width)];
        },
      };
    });

    // Model / thinking level now live in the footer; refresh it on change.
    pi.on("model_select", () => requestRender?.());
    pi.on("thinking_level_select", () => requestRender?.());
  });
}
