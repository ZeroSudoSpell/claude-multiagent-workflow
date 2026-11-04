#!/usr/bin/env python3
"""Sanity-check the .claude/ setup so a broken agent or skill fails CI, not a teammate.

Checks:
  * every agent in .claude/agents/*.md has frontmatter with name + description,
    its name matches the file name, and its fields and model are recognised;
  * every skill in .claude/skills/*/SKILL.md has a description, and any
    `agent:` it forks into exists;
  * .claude/settings.json is valid JSON and every hook script it runs exists
    and is executable;
  * every `.claude/...` path mentioned in an agent or skill exists.

Standard library only. Usage: python3 scripts/validate.py [repo-root]
"""

from __future__ import annotations

import json
import os
import re
import sys
from pathlib import Path

AGENT_FIELDS = {
    "name", "description", "tools", "disallowedTools", "model", "permissionMode",
    "maxTurns", "autoCompactWindow", "skills", "mcpServers", "hooks", "memory",
    "background", "omitClaudeMd", "effort", "isolation", "color", "initialPrompt",
}
SKILL_FIELDS = {
    "name", "description", "when_to_use", "argument-hint", "arguments",
    "disable-model-invocation", "user-invocable", "allowed-tools",
    "disallowed-tools", "model", "effort", "context", "agent", "background",
    "hooks", "paths", "shell", "metadata",
}
MODEL_ALIASES = {"sonnet", "opus", "haiku", "fable", "inherit"}
BUILTIN_AGENTS = {"general-purpose", "Explore", "Plan"}
PATH_REF = re.compile(r"`(\.claude/[\w./-]+?)`")


def parse_frontmatter(path: Path) -> tuple[dict[str, str], str]:
    """Return (top-level fields, body). Nested YAML values are kept as raw text."""
    text = path.read_text(encoding="utf-8")
    if not text.startswith("---\n"):
        raise ValueError("missing YAML frontmatter (file must start with '---')")
    end = text.find("\n---", 4)
    if end == -1:
        raise ValueError("frontmatter is not closed with '---'")
    fields: dict[str, str] = {}
    for line in text[4:end].splitlines():
        if not line.strip() or line.startswith((" ", "\t", "#", "-")):
            continue
        key, sep, value = line.partition(":")
        if not sep:
            raise ValueError(f"cannot parse frontmatter line: {line!r}")
        fields[key.strip()] = value.strip().strip("\"'")
    return fields, text[end + 4 :]


class Checker:
    def __init__(self, root: Path) -> None:
        self.root = root
        self.errors: list[str] = []
        self.warnings: list[str] = []

    def err(self, where: Path | str, msg: str) -> None:
        self.errors.append(f"{self._rel(where)}: {msg}")

    def warn(self, where: Path | str, msg: str) -> None:
        self.warnings.append(f"{self._rel(where)}: {msg}")

    def _rel(self, p: Path | str) -> str:
        p = Path(p)
        return str(p.relative_to(self.root)) if p.is_absolute() else str(p)

    def check_refs(self, path: Path, body: str) -> None:
        for ref in PATH_REF.findall(body):
            if "<" in ref or "*" in ref:
                continue
            if not (self.root / ref).exists():
                self.err(path, f"references {ref}, which does not exist")

    def agents(self) -> set[str]:
        names: set[str] = set()
        for path in sorted((self.root / ".claude/agents").glob("*.md")):
            try:
                fm, body = parse_frontmatter(path)
            except ValueError as e:
                self.err(path, str(e))
                continue
            for req in ("name", "description"):
                if not fm.get(req):
                    self.err(path, f"missing required field '{req}'")
            name = fm.get("name", "")
            if name and name != path.stem:
                self.err(path, f"name '{name}' does not match file name '{path.stem}'")
            if name and not re.fullmatch(r"[a-z0-9][a-z0-9-]*", name):
                self.err(path, f"name '{name}' should be lowercase letters, digits and hyphens")
            for key in fm.keys() - AGENT_FIELDS:
                self.warn(path, f"unknown field '{key}' (Claude Code ignores unknown fields)")
            model = fm.get("model")
            if model and model not in MODEL_ALIASES and not model.startswith("claude-"):
                self.err(path, f"model '{model}' is not an alias or a claude-* model ID")
            if fm.get("isolation") not in (None, "worktree"):
                self.err(path, f"isolation '{fm['isolation']}' is not supported (use 'worktree')")
            self.check_refs(path, body)
            names.add(name)
        if not names:
            self.err(".claude/agents", "no agents found")
        return names

    def skills(self, agents: set[str]) -> None:
        found = False
        for path in sorted((self.root / ".claude/skills").glob("*/SKILL.md")):
            found = True
            try:
                fm, body = parse_frontmatter(path)
            except ValueError as e:
                self.err(path, str(e))
                continue
            if not fm.get("description"):
                self.err(path, "missing 'description' (Claude uses it to decide when the skill applies)")
            if fm.get("name") and fm["name"] != path.parent.name:
                self.err(path, f"name '{fm['name']}' does not match directory '{path.parent.name}'")
            for key in fm.keys() - SKILL_FIELDS:
                self.warn(path, f"unknown field '{key}'")
            agent = fm.get("agent")
            if agent and agent not in agents | BUILTIN_AGENTS:
                self.err(path, f"agent '{agent}' is not defined in .claude/agents/")
            if agent and fm.get("context") != "fork":
                self.warn(path, "'agent' only takes effect with 'context: fork'")
            self.check_refs(path, body)
        if not found:
            self.err(".claude/skills", "no skills found")

    def settings(self) -> None:
        path = self.root / ".claude/settings.json"
        try:
            settings = json.loads(path.read_text(encoding="utf-8"))
        except FileNotFoundError:
            self.err(path, "missing")
            return
        except json.JSONDecodeError as e:
            self.err(path, f"invalid JSON: {e}")
            return
        for event, groups in settings.get("hooks", {}).items():
            for group in groups:
                for hook in group.get("hooks", []):
                    cmd = hook.get("command", "")
                    m = re.search(r"\$\{?CLAUDE_PROJECT_DIR\}?\"?(/[^\s\"']+)", cmd)
                    if not m:
                        continue
                    script = self.root / m.group(1).lstrip("/")
                    if not script.is_file():
                        self.err(path, f"{event} hook runs {m.group(1)}, which does not exist")
                    elif not os.access(script, os.X_OK):
                        self.err(path, f"{event} hook script {m.group(1)} is not executable (chmod +x)")


def main() -> int:
    root = Path(sys.argv[1] if len(sys.argv) > 1 else Path(__file__).resolve().parent.parent).resolve()
    c = Checker(root)
    c.skills(c.agents())
    c.settings()
    for w in c.warnings:
        print(f"warning: {w}")
    for e in c.errors:
        print(f"error: {e}")
    print(f"validate: {len(c.errors)} error(s), {len(c.warnings)} warning(s)")
    return 1 if c.errors else 0


if __name__ == "__main__":
    sys.exit(main())
