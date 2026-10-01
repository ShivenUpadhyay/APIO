#!/usr/bin/env python3
"""Assemble the APIO plain-English instruction format into 32-bit hex words."""

import argparse
import re
import sys
from pathlib import Path


LABEL_PATTERN = re.compile(r"^([A-Za-z_][A-Za-z0-9_]*):(?:\s*(.*))?$")
GPIO_PATTERN = re.compile(
    r"^(SET|CLEAR)\s+GPIO\[(\d+)\](?:\s*,?\s*DELAY\s+(\d+))?$",
    re.IGNORECASE,
)
JUMP_PATTERN = re.compile(r"^JUMP\s+([A-Za-z_][A-Za-z0-9_]*|0[xX][0-9A-Fa-f]+|\d+)$", re.IGNORECASE)


def assemble(source: Path) -> tuple[list[int], int, int]:
    labels: dict[str, int] = {}
    instructions: list[tuple[int, str]] = []
    program_name = None
    wrap_target = None
    wrap_address = None
    after_wrap = False

    for line_number, raw_line in enumerate(source.read_text(encoding="utf-8").splitlines(), 1):
        line = re.split(r"[#;]", raw_line, maxsplit=1)[0].strip()
        if not line:
            continue

        label_match = LABEL_PATTERN.fullmatch(line)
        if label_match:
            label = label_match.group(1).upper()
            if label in labels:
                raise ValueError(f"{source}:{line_number}: duplicate label '{label}'")
            labels[label] = len(instructions)
            line = (label_match.group(2) or "").strip()
            if not line:
                continue

        if line.startswith("."):
            directive = re.fullmatch(r"\.program\s+([A-Za-z_][A-Za-z0-9_]*)", line, re.IGNORECASE)
            if directive:
                if program_name is not None or instructions:
                    raise ValueError(f"{source}:{line_number}: .program must appear once before instructions")
                program_name = directive.group(1)
                continue
            if re.fullmatch(r"\.wrap_target", line, re.IGNORECASE):
                if wrap_target is not None or wrap_address is not None:
                    raise ValueError(f"{source}:{line_number}: misplaced or duplicate .wrap_target")
                wrap_target = len(instructions)
                continue
            if re.fullmatch(r"\.wrap", line, re.IGNORECASE):
                if wrap_target is None or wrap_address is not None or len(instructions) <= wrap_target:
                    raise ValueError(f"{source}:{line_number}: .wrap must follow at least one instruction after .wrap_target")
                wrap_address = len(instructions) - 1
                after_wrap = True
                continue
            raise ValueError(f"{source}:{line_number}: unsupported directive '{line}'")

        if after_wrap:
            raise ValueError(f"{source}:{line_number}: no instructions may follow .wrap")
        instructions.append((line_number, line))

    if program_name is None:
        raise ValueError(f"{source}: missing .program directive")
    if wrap_target is None or wrap_address is None:
        raise ValueError(f"{source}: .wrap_target and .wrap directives are required")

    words: list[int] = []
    for line_number, line in instructions:
        gpio_match = GPIO_PATTERN.fullmatch(line)
        if gpio_match:
            operation, pin_text, delay_text = gpio_match.groups()
            pin = int(pin_text)
            delay = int(delay_text or "0")
            if pin > 7:
                raise ValueError(f"{source}:{line_number}: GPIO pin must be between 0 and 7")
            if delay > 15:
                raise ValueError(f"{source}:{line_number}: delay must be between 0 and 15")
            opcode = 0x2 if operation.upper() == "SET" else 0x3
            words.append((opcode << 28) | (delay << 24) | (1 << pin))
            continue

        jump_match = JUMP_PATTERN.fullmatch(line)
        if jump_match:
            target_text = jump_match.group(1)
            try:
                target = labels[target_text.upper()] if target_text.upper() in labels else int(target_text, 0)
            except ValueError as error:
                raise ValueError(f"{source}:{line_number}: invalid jump target '{target_text}'") from error
            if not 0 <= target <= 0xFFFFFF:
                raise ValueError(f"{source}:{line_number}: jump target must fit in 24 bits")
            words.append((0x1 << 28) | target)
            continue

        raise ValueError(f"{source}:{line_number}: unsupported instruction '{line}'")

    if not words:
        raise ValueError(f"{source}: no instructions found")
    return words, wrap_target, wrap_address


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path, help="plain-English assembly source file")
    parser.add_argument("-o", "--output", type=Path, help="output hex file (default: source with .hex suffix)")
    parser.add_argument("--metadata-output", type=Path, help="write instruction count, wrap target, and wrap end")
    arguments = parser.parse_args()
    output = arguments.output or arguments.source.with_suffix(".hex")

    try:
        words, wrap_target, wrap_address = assemble(arguments.source)
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_text("".join(f"{word:08x}\n" for word in words), encoding="ascii")
        if arguments.metadata_output:
            arguments.metadata_output.parent.mkdir(parents=True, exist_ok=True)
            arguments.metadata_output.write_text(
                f"{len(words)} {wrap_target} {wrap_address}\n", encoding="ascii"
            )
    except (OSError, ValueError) as error:
        print(error, file=sys.stderr)
        return 1

    print(f"Assembled {len(words)} instructions: {output} (wrap target {wrap_target}, wrap address {wrap_address})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())