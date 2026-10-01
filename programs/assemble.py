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
RANGE_PATTERN = re.compile(r"^GPIO\[(\d+)(?::(\d+))?\]$", re.IGNORECASE)
IO_PATTERN = re.compile(
    r"^(IN|OUT)\s+(GPIO\[\d+(?::\d+)?\]|PINS)\s*,\s*(\d+)(?:\s+\[(\w+)\])?$",
    re.IGNORECASE,
)
SET_DIRECTION_PATTERN = re.compile(r"^SET\s+(GPIO\[\d+(?::\d+)?\])\s*,\s*(IN|OUT)$", re.IGNORECASE)
SET_VALUE_PATTERN = re.compile(
    r"^SET\s+(GPIO\[\d+\]|PINS)\s*,\s*([01])(?:\s+\[(\w+)\])?$",
    re.IGNORECASE,
)
WAIT_PIN_PATTERN = re.compile(r"^WAIT\s+([01])\s+(GPIO\[(\d+)\]|PINS)$", re.IGNORECASE)
NOP_PATTERN = re.compile(r"^NOP(?:\s+\[(\w+)\])?$", re.IGNORECASE)
JUMP_PATTERN = re.compile(r"^(?:JUMP|JMP)\s+([A-Za-z_][A-Za-z0-9_]*|0[xX][0-9A-Fa-f]+|\d+)$", re.IGNORECASE)


def assemble(source: Path) -> tuple[list[int], int, int]:
    labels: dict[str, int] = {}
    instructions: list[tuple[int, str]] = []
    program_name = None
    wrap_target = None
    wrap_address = None
    after_wrap = False
    definitions: dict[str, int] = {}
    default_pin = None

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
            definition = re.fullmatch(r"\.define\s+([A-Za-z_][A-Za-z0-9_]*)\s+(\d+)", line, re.IGNORECASE)
            if definition:
                name = definition.group(1).upper()
                if name in definitions:
                    raise ValueError(f"{source}:{line_number}: duplicate definition '{name}'")
                definitions[name] = int(definition.group(2))
                continue
            pin_directive = re.fullmatch(r"\.pin\s+(\d+)", line, re.IGNORECASE)
            if pin_directive:
                default_pin = int(pin_directive.group(1))
                if default_pin > 7:
                    raise ValueError(f"{source}:{line_number}: default pin must be between 0 and 7")
                continue
            raise ValueError(f"{source}:{line_number}: unsupported directive '{line}'")

        if after_wrap:
            raise ValueError(f"{source}:{line_number}: no instructions may follow .wrap")
        for name, value in definitions.items():
            line = re.sub(rf"\b{re.escape(name)}\b", str(value), line, flags=re.IGNORECASE)
        if re.search(r"\bPINS?\b", line, re.IGNORECASE):
            if default_pin is None:
                raise ValueError(f"{source}:{line_number}: PIN/PINS requires a preceding .pin directive")
            line = re.sub(r"\bPINS?\b", f"GPIO[{default_pin}]", line, flags=re.IGNORECASE)
        instructions.append((line_number, line))

    if program_name is None:
        raise ValueError(f"{source}: missing .program directive")
    if wrap_target is None or wrap_address is None:
        raise ValueError(f"{source}: .wrap_target and .wrap directives are required")

    words: list[int] = []
    for line_number, line in instructions:
        io_match = IO_PATTERN.fullmatch(line)
        if io_match:
            operation, gpio_range, cycles_text, delay_text = io_match.groups()
            base, count = parse_gpio_range(source, line_number, gpio_range)
            operation_count = int(cycles_text)
            if not 1 <= operation_count <= 15 or operation_count != count:
                raise ValueError(f"{source}:{line_number}: IN/OUT count must match the GPIO range width")
            delay = parse_symbolic_integer(source, line_number, delay_text, definitions) if delay_text else None
            if delay is not None and not 0 <= delay <= 15:
                raise ValueError(f"{source}:{line_number}: IO delay must be between 0 and 15")
            opcode = 0x4 if operation.upper() == "IN" else 0x5
            encoded_delay = delay if delay is not None else operation_count
            paced_single = delay_text is not None
            words.append(
                (opcode << 28)
                | (encoded_delay << 24)
                | (base << 20)
                | ((count - 1) << 16)
                | (0x8000 if paced_single else 0)
            )
            continue

        set_direction_match = SET_DIRECTION_PATTERN.fullmatch(line)
        if set_direction_match:
            gpio_range, direction = set_direction_match.groups()
            base, count = parse_gpio_range(source, line_number, gpio_range)
            direction_bit = 1 if direction.upper() == "OUT" else 0
            words.append((0x8 << 28) | (base << 20) | ((count - 1) << 16) | (direction_bit << 15))
            continue

        set_value_match = SET_VALUE_PATTERN.fullmatch(line)
        if set_value_match:
            gpio_name, value_text, delay_text = set_value_match.groups()
            base, count = parse_gpio_range(source, line_number, gpio_name)
            if count != 1:
                raise ValueError(f"{source}:{line_number}: SET value syntax addresses one GPIO pin")
            delay = parse_symbolic_integer(source, line_number, delay_text, definitions) if delay_text else 0
            if not 0 <= delay <= 15:
                raise ValueError(f"{source}:{line_number}: SET delay must be between 0 and 15")
            opcode = 0x2 if value_text == "1" else 0x3
            words.append((opcode << 28) | (delay << 24) | (1 << base))
            continue

        if re.fullmatch(r"PULL", line, re.IGNORECASE):
            words.append(0x6 << 28)
            continue

        if re.fullmatch(r"PUSH", line, re.IGNORECASE):
            words.append(0x7 << 28)
            continue

        wait_match = re.fullmatch(r"WAIT\s+(\d+)", line, re.IGNORECASE)
        if wait_match:
            delay = int(wait_match.group(1))
            if not 0 <= delay <= 15:
                raise ValueError(f"{source}:{line_number}: WAIT delay must be between 0 and 15")
            words.append((0x9 << 28) | (delay << 24))
            continue

        wait_pin_match = WAIT_PIN_PATTERN.fullmatch(line)
        if wait_pin_match:
            value_text, pin_name, pin_text = wait_pin_match.groups()
            if pin_text is None:
                base, count = parse_gpio_range(source, line_number, pin_name)
                if count != 1:
                    raise ValueError(f"{source}:{line_number}: WAIT PIN addresses one GPIO pin")
            else:
                base = int(pin_text)
            words.append((0xA << 28) | (base << 20) | (int(value_text) << 15))
            continue

        nop_match = NOP_PATTERN.fullmatch(line)
        if nop_match:
            delay_text = nop_match.group(1)
            delay = parse_symbolic_integer(source, line_number, delay_text, definitions) if delay_text else 0
            if not 0 <= delay <= 15:
                raise ValueError(f"{source}:{line_number}: NOP delay must be between 0 and 15")
            words.append((0x9 << 28) | (delay << 24))
            continue

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


def parse_gpio_range(source: Path, line_number: int, text: str) -> tuple[int, int]:
    range_match = RANGE_PATTERN.fullmatch(text)
    if not range_match:
        raise ValueError(f"{source}:{line_number}: invalid GPIO range '{text}'")
    base = int(range_match.group(1))
    end = int(range_match.group(2) or base)
    count = end - base + 1
    if base < 0 or end > 7 or count < 1:
        raise ValueError(f"{source}:{line_number}: GPIO range must be ascending and within GPIO[0:7]")
    return base, count


def parse_symbolic_integer(
    source: Path, line_number: int, text: str | None, definitions: dict[str, int]
) -> int:
    if text is None:
        return 0
    try:
        return int(text, 0)
    except ValueError:
        value = definitions.get(text.upper())
        if value is None:
            raise ValueError(f"{source}:{line_number}: undefined constant '{text}'")
        return value


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