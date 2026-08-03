#!/usr/bin/env python3
"""Validate the skill library against the contract in AGENTS.md.

Checks: Agent Skills spec conformance, manifest agreement, content policy.
Exit code 0 = clean, 1 = violations found.
"""
from __future__ import annotations

import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SKILLS = ROOT / "skills"
AGENTS = ROOT / "agents"

NAME_RE = re.compile(r"^[a-z0-9]+(-[a-z0-9]+)*$")
# Tool-specific frontmatter that must not appear in portable skills.
FORBIDDEN_FIELDS = {
    "model", "tools", "allowed-tools", "disallowed-tools", "argument-hint",
    "arguments", "user-invocable", "disable-model-invocation", "paths",
    "context", "agent", "background", "hooks", "shell", "effort", "when_to_use",
}
MAX_BODY_LINES = 500
MAX_DESC = 1024

# Content policy: (pattern, explanation). Case-insensitive.
POLICY = [
    (r"/Users/[a-z]", "absolute local path"),
    (r"/home/[a-z]", "absolute local path"),
    (r"\b(?:\d{1,3}\.){3}\d{1,3}\b", "IP address"),
    (r"\bcat[a-z0-9]{18,}\b", "cloud resource id"),
    (r"\byc-[a-z0-9-]+-cluster\b", "real cluster context"),
    (r"(?i)\b(?:AKIA|ghp_|sk-[a-zA-Z0-9]{20,}|qmcp_)", "credential-shaped token"),
]
# Additional patterns that must never appear but are themselves private (real project
# names, namespaces, hosts) live in scripts/private-patterns.txt — git-ignored, one
# regex per line, '#' comments. The file exists only on machines that need it; CI runs
# without it and still applies every generic pattern above.
_private = ROOT / "scripts" / "private-patterns.txt"
if _private.exists():
    POLICY += [
        (line.strip(), "private pattern")
        for line in _private.read_text(encoding="utf-8").splitlines()
        if line.strip() and not line.lstrip().startswith("#")
    ]
# The changelog may name a skill version that mentions a provider in passing.
POLICY_EXEMPT = {"CHANGELOG.md"}

errors: list[str] = []
warnings: list[str] = []


def err(path: Path, msg: str) -> None:
    errors.append(f"{path.relative_to(ROOT)}: {msg}")


def parse_frontmatter(text: str, path: Path) -> tuple[dict, int]:
    """Return (fields, body_line_count). Flat YAML only, one nested level."""
    if not text.startswith("---\n"):
        err(path, "missing YAML frontmatter")
        return {}, 0
    end = text.find("\n---\n", 4)
    if end == -1:
        err(path, "unterminated frontmatter")
        return {}, 0
    fields: dict = {}
    parent = None
    for raw in text[4:end].split("\n"):
        if not raw.strip() or raw.lstrip().startswith("#"):
            continue
        indented = raw.startswith(("  ", "\t"))
        if ":" not in raw:
            continue
        key, _, value = raw.partition(":")
        key, value = key.strip(), value.strip()
        if indented and parent:
            fields.setdefault(parent, {})[key] = value
        else:
            parent = key if not value else None
            fields[key] = value if value else {}
    body_lines = text[end + 5:].count("\n")
    return fields, body_lines


def check_skill(skill_dir: Path) -> None:
    md = skill_dir / "SKILL.md"
    if not md.exists():
        err(skill_dir, "no SKILL.md")
        return
    text = md.read_text(encoding="utf-8")
    fields, body_lines = parse_frontmatter(text, md)
    if not fields:
        return

    name = fields.get("name")
    if not isinstance(name, str) or not name:
        err(md, "frontmatter missing required 'name'")
    else:
        if not NAME_RE.match(name):
            err(md, f"name '{name}' is not lowercase-kebab-case")
        if name != skill_dir.name:
            err(md, f"name '{name}' != directory '{skill_dir.name}'")

    desc = fields.get("description")
    if not isinstance(desc, str) or not desc.strip():
        err(md, "frontmatter missing required 'description'")
    elif len(desc) > MAX_DESC:
        err(md, f"description is {len(desc)} chars (max {MAX_DESC})")

    for field in fields:
        if field in FORBIDDEN_FIELDS:
            err(md, f"tool-specific frontmatter '{field}' is not portable")

    if body_lines > MAX_BODY_LINES:
        err(md, f"body is {body_lines} lines (max {MAX_BODY_LINES}) — move depth into references/")

    meta = fields.get("metadata")
    if not isinstance(meta, dict) or "version" not in meta or "source" not in meta:
        err(md, "metadata must carry 'source' and 'version'")

    # Generic skills declare what the layers below them must supply.
    pack = skill_dir.parent.name
    if pack in {"go", "infra", "database", "frontend"} and "## Project delta" not in text:
        warnings.append(f"{md.relative_to(ROOT)}: no '## Project delta' section")
    if pack == "infra" and "## Vendor delta" not in text:
        warnings.append(f"{md.relative_to(ROOT)}: no '## Vendor delta' section")

    # Vendor names must not leak into generic skills.
    if pack != "cloud":
        for vendor in ("Yandex", "AWS", "Azure", "GCP"):
            for line in text.splitlines():
                if vendor.lower() in line.lower() and "example" not in line.lower():
                    warnings.append(
                        f"{md.relative_to(ROOT)}: mentions '{vendor}' outside skills/cloud/ "
                        f"— label it as an example or move it to the vendor pack")
                    break


SKILL_REF_RE = re.compile(r"`([a-z0-9][a-z0-9-]{2,})`\s+skill\b")
LINK_RE = re.compile(r"\[[^\]]*\]\((?!https?://|#|mailto:)([^)#]+)")


def check_links(path: Path) -> None:
    """A relative link that does not resolve sends the agent to a file that isn't there."""
    text = path.read_text(encoding="utf-8")
    for m in LINK_RE.finditer(text):
        target = m.group(1).strip()
        if not (path.parent / target).exists():
            line_no = text.count("\n", 0, m.start()) + 1
            err(path, f"line {line_no}: broken relative link '{target}'")


def check_references(path: Path, known: set[str]) -> None:
    """A skill referenced by name must exist — dangling refs send agents hunting."""
    text = path.read_text(encoding="utf-8")
    for m in SKILL_REF_RE.finditer(text):
        name = m.group(1)
        if name in known or name == path.parent.name:
            continue
        line_no = text.count("\n", 0, m.start()) + 1
        err(path, f"line {line_no}: references skill '{name}', which does not exist in manifest.json")


def shipped(path: Path) -> bool:
    """Only files git would publish are subject to the content policy."""
    if not (ROOT / ".git").exists():
        return True
    return subprocess.run(
        ["git", "check-ignore", "-q", str(path)], cwd=ROOT, capture_output=True
    ).returncode != 0


def check_policy(path: Path) -> None:
    if path.name in POLICY_EXEMPT or not shipped(path):
        return
    try:
        text = path.read_text(encoding="utf-8")
    except (UnicodeDecodeError, OSError):
        return
    for pattern, why in POLICY:
        for m in re.finditer(pattern, text):
            line_no = text.count("\n", 0, m.start()) + 1
            err(path, f"line {line_no}: {why} — '{m.group()[:40]}'")


def main() -> int:
    manifest = json.loads((ROOT / "manifest.json").read_text(encoding="utf-8"))

    declared: set[Path] = set()
    for pack in manifest["packs"]:
        base = ROOT / pack["skillPath"]
        for skill in pack["skills"]:
            d = base / skill
            declared.add(d)
            if not d.is_dir():
                errors.append(f"manifest: pack '{pack['id']}' lists missing skill '{skill}' ({d.relative_to(ROOT)})")
        if pack.get("agents"):
            abase = ROOT / pack["agentPath"]
            for agent in pack["agents"]:
                if not (abase / f"{agent}.md").exists():
                    errors.append(f"manifest: pack '{pack['id']}' lists missing agent '{agent}'")

    on_disk = {p.parent for p in SKILLS.rglob("SKILL.md")}
    for d in sorted(on_disk - declared):
        errors.append(f"manifest: skill '{d.relative_to(ROOT)}' exists but no pack lists it")

    # Each pack ships a README manifest, and its plugin wiring resolves.
    for pack in manifest["packs"]:
        if not (ROOT / pack["skillPath"] / "README.md").exists():
            warnings.append(f"pack '{pack['id']}': no README.md in {pack['skillPath']}")
        plugin = ROOT / "plugins" / pack["id"]
        if not (plugin / ".claude-plugin" / "plugin.json").exists():
            errors.append(f"pack '{pack['id']}': missing plugins/{pack['id']}/.claude-plugin/plugin.json")
        link = plugin / "skills"
        if not link.is_symlink():
            errors.append(f"pack '{pack['id']}': plugins/{pack['id']}/skills is not a symlink")
        elif not link.resolve().is_dir():
            errors.append(f"pack '{pack['id']}': plugins/{pack['id']}/skills symlink is broken")

    market = ROOT / ".claude-plugin" / "marketplace.json"
    if market.exists():
        listed = {p["name"] for p in json.loads(market.read_text())["plugins"]}
        for pid in {p["id"] for p in manifest["packs"]} - listed:
            errors.append(f"marketplace.json: pack '{pid}' has no plugin entry")

    known = {s for pack in manifest["packs"] for s in pack["skills"]}
    for d in sorted(on_disk):
        check_skill(d)
        for md in sorted(d.rglob("*.md")):
            check_references(md, known)
            check_links(md)
    for a in sorted(AGENTS.rglob("*.md")) if AGENTS.exists() else []:
        check_references(a, known)

    for path in list(ROOT.rglob("*.md")) + list(ROOT.rglob("*.json")):
        if ".git/" in str(path) or "/templates/" in str(path):
            continue
        check_policy(path)

    for w in warnings:
        print(f"warning: {w}")
    for e in errors:
        print(f"ERROR: {e}")

    n_skills = len(on_disk)
    n_agents = len(list(AGENTS.rglob("*.md"))) if AGENTS.exists() else 0
    print(f"\n{n_skills} skills, {n_agents} agents, {len(manifest['packs'])} packs — "
          f"{len(errors)} errors, {len(warnings)} warnings")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
