#!/usr/bin/env python3
"""Generate the fixed-function feature matrix (T1.8).

The renderer seam (T1.7) and the future Vulkan backend (T5.2) need a complete,
*generated* list of the D3D9 fixed-function state the client actually touches:

  * render states      (D3DRS_*)
  * texture-stage states (D3DTSS_*)
  * sampler states     (D3DSAMP_*)
  * transforms         (D3DTS_*)
  * FVF layouts        (SetFVF expressions, expanded to a D3DFVF value)
  * lights and materials
  * the shader calls that are no-ops on the GL path (D13)

It is generated, never hand-written: comments and string literals are stripped
first, the platform implementation (`include/Platform/`, `EterBase/src/`) and
the test trees are excluded, and every section is sorted so `--check` is a
stable diff.

Usage:
    feature-matrix.py --root <repo> [--output FILE]
"""

from __future__ import annotations

import argparse
import os
import re
import sys
from collections import defaultdict

SOURCE_SUFFIXES = {".cpp", ".c", ".cc", ".h", ".hpp", ".inl"}

# Implementation-side files: they *consume* the state (switch statements in the
# compat device / GL backend) rather than declare the app's feature usage.
EXCLUDED_DIR_PARTS = ("tests",)
EXCLUDED_PATH_PREFIXES = ("src/EterBase/src/",)
# Every package vendors the platform shim under include/Platform/.
EXCLUDED_PATH_MARKERS = ("/include/Platform/",)

# Declarations of the API (`void SetFVF(DWORD FVF);`) are not call sites.
DECL_TOKENS = {
    "void", "HRESULT", "bool", "DWORD", "UINT", "INT", "int", "unsigned",
    "float", "double", "long", "short", "char", "static", "virtual", "inline",
    "const", "constexpr", "extern", "class", "struct", "typename",
    "LPDIRECT3DDEVICE9", "LPDIRECT3DVERTEXSHADER9", "LPDIRECT3DPIXELSHADER9",
    "LPDIRECT3DVERTEXBUFFER9", "LPDIRECT3DINDEXBUFFER9", "LPDIRECT3DTEXTURE9",
    "CStateManager", "CGraphicDevice",
}

# Ordered longest-first so `SetVertexShaderConstant` is not cut to `SetVertexShader`.
CALL_NAMES = [
    "SetVertexShaderConstantF",
    "SetVertexShaderConstantI",
    "SetVertexShaderConstantB",
    "SetVertexShaderConstant",
    "SetPixelShaderConstantF",
    "SetPixelShaderConstantI",
    "SetPixelShaderConstantB",
    "SetPixelShaderConstant",
    "D3DXAssembleShaderFromFileA",
    "D3DXAssembleShaderFromFile",
    "SetTextureStageState",
    "SetRenderState",
    "SetSamplerState",
    "SetTransform",
    "SetVertexShader",
    "SetPixelShader",
    "CreateVertexShader",
    "CreatePixelShader",
    "SetMaterial",
    "SetLight",
    "SetFVF",
]

CALL_RE = re.compile(r"\b(" + "|".join(CALL_NAMES) + r")\s*\(")

STATE_RE = re.compile(r"\bD3DRS_[A-Z0-9_]+\b")
STAGE_STATE_RE = re.compile(r"\bD3DTSS_[A-Z0-9_]+\b")
SAMPLER_STATE_RE = re.compile(r"\bD3DSAMP_[A-Z0-9_]+\b")
TRANSFORM_RE = re.compile(r"\bD3DTS_[A-Z0-9_]+\b")
FVF_TOKEN_RE = re.compile(r"\bD3DFVF_[A-Z0-9_]+\b")
DEFINE_RE = re.compile(r"^\s*#\s*define\s+(D3DFVF_[A-Z0-9_]+)\s+([^\n]+)$", re.M)
STATIC_FVF_RE = re.compile(
    r"\b(?:static\s+)?(?:const\s+)?DWORD\s+(D3DFVF_[A-Z0-9_]+)\s*=\s*([^;]+);")
TEXCOORD_SIZE_RE = re.compile(r"D3DFVF_TEXCOORDSIZE([1-4])\s*\(\s*(\d+)\s*\)")

# D3DFVF_* values (d3d9types.h). Only used to expand literal SetFVF arguments.
D3DFVF_VALUES = {
    "D3DFVF_RESERVED0": 0x001,
    "D3DFVF_POSITION_MASK": 0x00E,
    "D3DFVF_XYZ": 0x002,
    "D3DFVF_XYZRHW": 0x004,
    "D3DFVF_XYZB1": 0x006,
    "D3DFVF_XYZB2": 0x008,
    "D3DFVF_XYZB3": 0x00A,
    "D3DFVF_XYZB4": 0x00C,
    "D3DFVF_XYZB5": 0x00E,
    "D3DFVF_XYZW": 0x4002,
    "D3DFVF_NORMAL": 0x010,
    "D3DFVF_PSIZE": 0x020,
    "D3DFVF_DIFFUSE": 0x040,
    "D3DFVF_SPECULAR": 0x080,
    "D3DFVF_TEXCOUNT_MASK": 0xF00,
    "D3DFVF_TEXCOUNT_SHIFT": 8,
    "D3DFVF_TEX0": 0x000,
    "D3DFVF_TEX1": 0x100,
    "D3DFVF_TEX2": 0x200,
    "D3DFVF_TEX3": 0x300,
    "D3DFVF_TEX4": 0x400,
    "D3DFVF_TEX5": 0x500,
    "D3DFVF_TEX6": 0x600,
    "D3DFVF_TEX7": 0x700,
    "D3DFVF_TEX8": 0x800,
    "D3DFVF_TEXTUREFORMAT1": 0,
    "D3DFVF_TEXTUREFORMAT2": 1,
    "D3DFVF_TEXTUREFORMAT3": 2,
    "D3DFVF_TEXTUREFORMAT4": 3,
}


def strip_comments_and_strings(text: str) -> str:
    """Blank out comments and literals but keep offsets and newlines intact."""
    out = []
    i = 0
    n = len(text)
    state = "code"
    quote = ""
    while i < n:
        c = text[i]
        if state == "code":
            if c == "/" and i + 1 < n and text[i + 1] == "/":
                state, i = "line", i + 2
                out.append("  ")
                continue
            if c == "/" and i + 1 < n and text[i + 1] == "*":
                state, i = "block", i + 2
                out.append("  ")
                continue
            if c in ("'", '"'):
                state, quote, i = "string", c, i + 1
                out.append(" ")
                continue
            out.append(c)
            i += 1
        elif state == "line":
            out.append("\n" if c == "\n" else " ")
            if c == "\n":
                state = "code"
            i += 1
        elif state == "block":
            if c == "*" and i + 1 < n and text[i + 1] == "/":
                state, i = "code", i + 2
                out.append("  ")
                continue
            out.append("\n" if c == "\n" else " ")
            i += 1
        else:  # string / char literal
            if c == "\\" and i + 1 < n:
                out.append("  ")
                i += 2
                continue
            out.append("\n" if c == "\n" else " ")
            if c == quote:
                state = "code"
            i += 1
    return "".join(out)


def parse_calls(code: str):
    """Yield (name, args, offset) for every tracked call in stripped code."""
    pos = 0
    while True:
        match = CALL_RE.search(code, pos)
        if not match:
            return
        name = match.group(1)
        start = match.end()
        depth = 1
        i = start
        while i < len(code) and depth:
            if code[i] == "(":
                depth += 1
            elif code[i] == ")":
                depth -= 1
            i += 1
        args = code[start:i - 1] if depth == 0 else code[start:]
        yield name, args, match.start()
        pos = i


def is_declaration(code: str, start: int) -> bool:
    """True when the match is an API declaration/definition, not a call."""
    prefix = code[max(0, start - 80):start].rstrip()
    if not prefix:
        return False
    if prefix.endswith("::"):
        # `void CStateManager::SetRenderState(...)` — the shim definition.
        return True
    if prefix[-1] in ".*&>":
        # `obj.Method(`, `ptr->Method(`, `Type* Method(`.
        return prefix[-1] in "*&"
    word = re.search(r"([A-Za-z_][A-Za-z0-9_]*)$", prefix)
    if word and word.group(1) in DECL_TOKENS:
        return True
    return False


def is_excluded(rel_path: str) -> bool:
    if os.path.splitext(rel_path)[1] not in SOURCE_SUFFIXES:
        return True
    if any(part in EXCLUDED_DIR_PARTS for part in rel_path.split("/")):
        return True
    if any(rel_path.startswith(prefix) for prefix in EXCLUDED_PATH_PREFIXES):
        return True
    return any(marker in rel_path for marker in EXCLUDED_PATH_MARKERS)


def collect(root: str):
    """Return (calls, fvf_macros): per-file calls and #define'd FVF macros."""
    result = {}
    macros = {}
    for dirpath, dirnames, filenames in os.walk(os.path.join(root, "src")):
        dirnames.sort()
        for filename in sorted(filenames):
            full = os.path.join(dirpath, filename)
            rel = os.path.relpath(full, root).replace(os.sep, "/")
            if is_excluded(rel):
                continue
            with open(full, "r", encoding="utf-8", errors="replace") as handle:
                code = strip_comments_and_strings(handle.read())
            for match in DEFINE_RE.finditer(code):
                macros.setdefault(match.group(1), match.group(2).strip())
            for match in STATIC_FVF_RE.finditer(code):
                macros.setdefault(match.group(1), match.group(2).strip())
            calls = []
            for name, args, offset in parse_calls(code):
                if is_declaration(code, offset):
                    continue
                line = code.count("\n", 0, offset) + 1
                calls.append((name, args, line))
            if calls:
                result[rel] = calls
    return result, macros


def normalize(text: str) -> str:
    return re.sub(r"\s+", " ", text).strip()


def fvf_expansion(args: str, macros=None):
    """Expand a literal SetFVF argument to a hex value, or None if dynamic."""
    macros = macros or {}
    expr = normalize(args)
    if expr == "0":
        return "0x000"
    tokens = [t.strip("()") for t in re.split(r"[|+\s]+", expr) if t.strip("()")]
    if not tokens:
        return None

    def resolve(token: str, seen):
        if token in D3DFVF_VALUES:
            return D3DFVF_VALUES[token]
        if token in macros and token not in seen:
            return expand(macros[token], seen | {token})
        return None

    def expand(text: str, seen):
        # `D3DFVF_TEXCOORDSIZE2(0)` packs the coordinate size above bit 16.
        def texcoord(match):
            fmt = int(match.group(1)) - 1
            index = int(match.group(2))
            return str(fmt << (index * 2 + 16))

        value = 0
        expanded_text = TEXCOORD_SIZE_RE.sub(texcoord, normalize(text))
        for raw in re.split(r"[|+\s]+", expanded_text):
            token = raw.strip("()")
            if not token:
                continue
            if token.lstrip("-").isdigit():
                value |= int(token) & 0xFFFFFFFF
                continue
            part = resolve(token, seen)
            if part is None:
                return None
            value |= part
        return value

    value = expand(expr, frozenset())
    if value is None:
        return None
    return "0x%03X" % value


def add_sites(table, symbol, rel_path, line):
    table[symbol].append((rel_path, line))


def symbol_table(calls, call_names, pattern):
    table = defaultdict(list)
    for rel_path, entries in calls.items():
        for name, args, line in entries:
            if name not in call_names:
                continue
            for symbol in sorted(set(pattern.findall(args))):
                add_sites(table, symbol, rel_path, line)
    return table


def format_symbol_table(lines, table, symbol_header="Symbol"):
    if not table:
        lines.append("_No call sites._")
        lines.append("")
        return
    lines.append("| %s | Sites | Files |" % symbol_header)
    lines.append("|---|---:|---|")
    for symbol in sorted(table):
        sites = table[symbol]
        files = sorted({path for path, _ in sites})
        lines.append("| `%s` | %d | %s |" % (symbol, len(sites), "<br>".join("`%s`" % f for f in files)))
    lines.append("")


def format_value_table(lines, table, value_header, value_fn):
    if not table:
        lines.append("_No call sites._")
        lines.append("")
        return
    lines.append("| %s | Value | Sites | Files |" % value_header)
    lines.append("|---|---|---:|---|")
    for expr in sorted(table):
        sites = table[expr]
        files = sorted({path for path, _ in sites})
        value = value_fn(expr) if value_fn else ""
        lines.append("| `%s` | `%s` | %d | %s |" % (
            expr, value if value else "—", len(sites), "<br>".join("`%s`" % f for f in files)))
    lines.append("")


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", default=".", help="repository root (default: .)")
    parser.add_argument("--output", default="-", help="write to FILE instead of stdout")
    args = parser.parse_args(argv)

    root = os.path.abspath(args.root)
    calls, fvf_macros = collect(root)

    render_states = symbol_table(calls, {"SetRenderState"}, STATE_RE)
    stage_states = symbol_table(calls, {"SetTextureStageState"}, STAGE_STATE_RE)
    sampler_states = symbol_table(calls, {"SetSamplerState"}, SAMPLER_STATE_RE)
    transforms = symbol_table(calls, {"SetTransform"}, TRANSFORM_RE)

    fvf = defaultdict(list)
    shader_calls = defaultdict(list)
    lights = defaultdict(int)
    materials = defaultdict(int)
    stage_indices = defaultdict(lambda: [0, 0])
    for rel_path, entries in calls.items():
        for name, native_args, line in entries:
            if name == "SetFVF":
                fvf[normalize(native_args)].append((rel_path, line))
            elif name in {"SetLight", "SetMaterial"}:
                (lights if name == "SetLight" else materials)[rel_path] += 1
            elif name in {"SetVertexShader", "SetPixelShader",
                          "SetVertexShaderConstant", "SetPixelShaderConstant",
                          "SetVertexShaderConstantF", "SetVertexShaderConstantI",
                          "SetVertexShaderConstantB", "SetPixelShaderConstantF",
                          "SetPixelShaderConstantI", "SetPixelShaderConstantB",
                          "CreateVertexShader", "CreatePixelShader",
                          "D3DXAssembleShaderFromFile", "D3DXAssembleShaderFromFileA"}:
                shader_calls[name].append((rel_path, line))
            elif name in {"SetTextureStageState", "SetSamplerState"}:
                stage = normalize(native_args.split(",")[0]) if native_args else "?"
                stage_indices[stage][0 if name == "SetTextureStageState" else 1] += 1

    total_symbols = len(render_states) + len(stage_states) + len(sampler_states) + len(transforms)
    total_sites = sum(len(v) for v in render_states.values())
    total_sites += sum(len(v) for v in stage_states.values())
    total_sites += sum(len(v) for v in sampler_states.values())
    total_sites += sum(len(v) for v in transforms.values())

    lines = []
    lines.append("# Fixed-function feature matrix")
    lines.append("")
    lines.append("> **Generated — do not edit by hand.** `scripts/feature-matrix.sh --write`;")
    lines.append("> verify with `scripts/feature-matrix.sh --check` (also run by `ctest`/CI).")
    lines.append(">")
    lines.append("> Source: `src/**/*.{cpp,c,h,hpp,inl}` with comments and string literals")
    lines.append("> removed, excluding `tests/` and the renderer/platform implementation")
    lines.append("> (`src/EterBase/include/`, `src/EterBase/src/`). Those directories consume")
    lines.append("> the state; this file lists what the game and engine *ask for*.")
    lines.append("")
    lines.append("This is the contract the renderer backend must satisfy (plan §4.4): the GL")
    lines.append("backend passes it through to OpenGL 2.1, and a Vulkan backend has to")
    lines.append("synthesise programs from it (D11/D12, T5.2).")
    lines.append("")
    lines.append("## Summary")
    lines.append("")
    lines.append("| Item | Distinct | Call sites |")
    lines.append("|---|---:|---:|")
    lines.append("| Render states (`D3DRS_*`) | %d | %d |" % (len(render_states), sum(len(v) for v in render_states.values())))
    lines.append("| Texture-stage states (`D3DTSS_*`) | %d | %d |" % (len(stage_states), sum(len(v) for v in stage_states.values())))
    lines.append("| Sampler states (`D3DSAMP_*`) | %d | %d |" % (len(sampler_states), sum(len(v) for v in sampler_states.values())))
    lines.append("| Transform states (`D3DTS_*`) | %d | %d |" % (len(transforms), sum(len(v) for v in transforms.values())))
    lines.append("| FVF layouts | %d | %d |" % (len(fvf), sum(len(v) for v in fvf.values())))
    lines.append("| Shader calls (no-op on GL, D13) | %d | %d |" % (len(shader_calls), sum(len(v) for v in shader_calls.values())))
    lines.append("| **Total fixed-function state** | **%d** | **%d** |" % (total_symbols, total_sites))
    lines.append("")

    lines.append("## Render states (`D3DRS_*`)")
    lines.append("")
    format_symbol_table(lines, render_states, "State")

    lines.append("## Texture-stage states (`D3DTSS_*`)")
    lines.append("")
    format_symbol_table(lines, stage_states, "State")

    lines.append("## Sampler states (`D3DSAMP_*`)")
    lines.append("")
    format_symbol_table(lines, sampler_states, "State")

    lines.append("## Transforms (`D3DTS_*`)")
    lines.append("")
    format_symbol_table(lines, transforms, "Transform")

    lines.append("## Texture stages")
    lines.append("")
    lines.append("| Stage argument | `SetTextureStageState` | `SetSamplerState` |")
    lines.append("|---|---:|---:|")
    for stage in sorted(stage_indices):
        counts = stage_indices[stage]
        lines.append("| `%s` | %d | %d |" % (stage, counts[0], counts[1]))
    lines.append("")

    lines.append("## FVF layouts")
    lines.append("")
    lines.append("Literal `SetFVF` expressions are expanded to their `D3DFVF_*` value; rows")
    lines.append("without a value are dynamic (`SetFVF(variable)`), and the backend must track")
    lines.append("them through the stream declarations instead.")
    lines.append("")
    format_value_table(lines, fvf, "FVF expression", lambda expr: fvf_expansion(expr, fvf_macros))

    lines.append("## Lights and materials")
    lines.append("")
    lines.append("| File | `SetLight` | `SetMaterial` |")
    lines.append("|---|---:|---:|")
    for rel_path in sorted(set(lights) | set(materials)):
        lines.append("| `%s` | %d | %d |" % (rel_path, lights.get(rel_path, 0), materials.get(rel_path, 0)))
    lines.append("")

    lines.append("## Shader no-op delta (D13)")
    lines.append("")
    lines.append("`CreateVertexShader`/`CreatePixelShader` return dummy objects on the GL")
    lines.append("path, `SetVertexShader*`/`SetPixelShader*` discard their arguments, and")
    lines.append("`D3DXAssembleShaderFromFile*` returns an empty buffer. The calls below are")
    lines.append("therefore inert today; T5.2 has to make them real or prove the effect is")
    lines.append("fixed-function equivalent.")
    lines.append("")
    lines.append("| Call | Sites | Files |")
    lines.append("|---|---:|---|")
    for name in sorted(shader_calls):
        sites = shader_calls[name]
        files = sorted({path for path, _ in sites})
        lines.append("| `%s` | %d | %s |" % (name, len(sites), "<br>".join("`%s`" % f for f in files)))
    lines.append("")
    lines.append("Runtime counters are exposed by `CShaderStats` (`EterLib`): shader files")
    lines.append("created, shader binds and constant uploads, so the delta can be measured")
    lines.append("in a real frame instead of only counted statically.")
    lines.append("")

    text = "\n".join(lines)
    if args.output == "-":
        sys.stdout.write(text)
    else:
        with open(args.output, "w", encoding="utf-8") as handle:
            handle.write(text)
    return 0


if __name__ == "__main__":
    sys.exit(main())
