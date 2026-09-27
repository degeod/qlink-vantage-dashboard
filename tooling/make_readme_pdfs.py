"""Build one bilingual NL+EN README PDF for Vantage-Control-source.zip in an AI console."""

from __future__ import annotations

import re
from pathlib import Path

from fpdf import FPDF

ROOT = Path(__file__).resolve().parents[1]
DOCS = ROOT / "docs"
OUT_DIRS = [
    DOCS,
    ROOT / "assets" / "docs",
    Path(r"C:\Users\User\Desktop\webpoint\android apk"),
]
PDF_NAME = "README-AI-NL-EN.pdf"

FONT_CANDIDATES = [
    Path(r"C:\Windows\Fonts\arial.ttf"),
    Path(r"C:\Windows\Fonts\calibri.ttf"),
    Path(r"C:\Windows\Fonts\segoeui.ttf"),
]


class ReadmePdf(FPDF):
    def __init__(self) -> None:
        super().__init__(format="A4")
        self.set_auto_page_break(auto=True, margin=18)
        font = next((p for p in FONT_CANDIDATES if p.exists()), None)
        if font is None:
            raise RuntimeError("No TTF font found (Arial/Calibri/Segoe UI).")
        self.add_font("Body", "", str(font))
        bold = Path(r"C:\Windows\Fonts\arialbd.ttf")
        if not bold.exists():
            bold = font
        self.add_font("Body", "B", str(bold))

    def header(self) -> None:
        self.set_font("Body", "B", 9)
        self.set_text_color(90, 90, 90)
        self.cell(0, 8, "Vantage Control — AI console / AI-console  |  NL + EN", align="L")
        self.ln(4)
        self.set_draw_color(224, 161, 74)
        self.set_line_width(0.4)
        self.line(10, self.get_y(), 200, self.get_y())
        self.ln(6)

    def footer(self) -> None:
        self.set_y(-14)
        self.set_font("Body", "", 8)
        self.set_text_color(120, 120, 120)
        self.cell(0, 8, f"{self.page_no()}", align="C")


def _clean_inline(text: str) -> str:
    text = text.replace("**", "")
    text = text.replace("`", "")
    text = text.replace("→", "->")
    text = text.replace("—", "-")
    text = text.replace("–", "-")
    text = text.replace("·", "|")
    text = text.replace("“", '"').replace("”", '"')
    text = text.replace("‘", "'").replace("’", "'")
    return text


def render_markdown(pdf: ReadmePdf, md: str) -> None:
    in_code = False
    code_lines: list[str] = []
    left = pdf.l_margin
    width = pdf.epw

    def write(h: float, text: str, *, fill: bool = False) -> None:
        pdf.set_x(left)
        pdf.multi_cell(width, h, text, fill=fill)

    def flush_code() -> None:
        nonlocal code_lines
        if not code_lines:
            return
        pdf.set_fill_color(245, 245, 247)
        pdf.set_font("Body", "", 9)
        pdf.set_text_color(30, 30, 30)
        write(4.5, "\n".join(code_lines), fill=True)
        pdf.ln(3)
        code_lines = []

    for raw in md.splitlines():
        line = raw.rstrip()

        if line.startswith("```"):
            if in_code:
                flush_code()
                in_code = False
            else:
                flush_code()
                in_code = True
            continue

        if in_code:
            code_lines.append(line if line else " ")
            continue

        if not line.strip():
            pdf.ln(2)
            continue

        if line.startswith("# "):
            pdf.set_font("Body", "B", 16)
            pdf.set_text_color(20, 20, 20)
            write(8, _clean_inline(line[2:]))
            pdf.ln(2)
            continue

        if line.startswith("## "):
            pdf.ln(2)
            pdf.set_font("Body", "B", 12)
            pdf.set_text_color(30, 30, 30)
            write(7, _clean_inline(line[3:]))
            pdf.ln(1)
            continue

        if line.startswith("### "):
            pdf.set_font("Body", "B", 11)
            pdf.set_text_color(40, 40, 40)
            write(6, _clean_inline(line[4:]))
            pdf.ln(1)
            continue

        if line.startswith("|"):
            cells = [c.strip() for c in line.strip("|").split("|")]
            if all(set(c) <= {"-", ":", " "} for c in cells):
                continue
            pdf.set_font("Body", "", 9)
            pdf.set_text_color(35, 35, 35)
            write(5, "  |  ".join(_clean_inline(c) for c in cells))
            continue

        if re.match(r"^[-*] ", line) or re.match(r"^- \[[ xX]\] ", line):
            pdf.set_font("Body", "", 10)
            pdf.set_text_color(35, 35, 35)
            bullet = re.sub(r"^- \[[ xX]\] ", "- [ ] ", line)
            bullet = re.sub(r"^[-*] ", "- ", bullet)
            write(5, _clean_inline(bullet))
            continue

        if re.match(r"^\d+\. ", line):
            pdf.set_font("Body", "", 10)
            pdf.set_text_color(35, 35, 35)
            write(5, _clean_inline(line))
            continue

        pdf.set_font("Body", "", 10)
        pdf.set_text_color(35, 35, 35)
        write(5, _clean_inline(line))

    flush_code()


def section_banner(pdf: ReadmePdf, title: str) -> None:
    pdf.set_fill_color(27, 33, 41)
    pdf.set_text_color(224, 161, 74)
    pdf.set_font("Body", "B", 13)
    pdf.set_x(pdf.l_margin)
    pdf.cell(pdf.epw, 10, f"  {title}", fill=True)
    pdf.ln(14)
    pdf.set_text_color(35, 35, 35)


def main() -> None:
    nl = (DOCS / "README-AI-NL.md").read_text(encoding="utf-8")
    en = (DOCS / "README-AI-EN.md").read_text(encoding="utf-8")

    pdf = ReadmePdf()
    pdf.add_page()
    section_banner(pdf, "Nederlands")
    render_markdown(pdf, nl)

    pdf.add_page()
    section_banner(pdf, "English")
    render_markdown(pdf, en)

    primary = DOCS / PDF_NAME
    pdf.output(str(primary))

    for out_dir in OUT_DIRS:
        out_dir.mkdir(parents=True, exist_ok=True)
        target = out_dir / PDF_NAME
        if target.resolve() != primary.resolve():
            target.write_bytes(primary.read_bytes())
        print("wrote", target)

    # Remove older split PDFs if present.
    for name in ("README-AI-NL.pdf", "README-AI-EN.pdf"):
        for folder in OUT_DIRS:
            old = folder / name
            if old.exists():
                old.unlink()
                print("removed", old)


if __name__ == "__main__":
    main()
