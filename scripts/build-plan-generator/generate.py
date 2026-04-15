#!/usr/bin/env python3
"""
Build Plan PDF Generator
========================
Reads data.json, renders page1.html + page2.html with injected data,
and outputs a two-page PDF named RIG-Build-Plan-YYYY-MM-DD.pdf.

Usage:
    python generate.py              # outputs to parent directory
    python generate.py --out ./     # outputs to current directory

Requirements:
    pip install playwright pypdf
    python -m playwright install chromium
"""

import asyncio
import json
import io
import os
import re
import sys
from datetime import date
from pathlib import Path

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
HERE = Path(__file__).resolve().parent
DATA_PATH = HERE / "data.json"
PAGE1_PATH = HERE / "page1.html"
PAGE2_PATH = HERE / "page2.html"

# ---------------------------------------------------------------------------
# Status helpers
# ---------------------------------------------------------------------------
STATUS_LABELS = {
    "built": "Built",
    "scaffolded": "Scaffolded",
    "next": "Up Next",
    "later": "Later",
    "tbd": "TBD",
}


def count_statuses(data, include_convergence=True):
    """Count statuses across all items."""
    counts = {"built": len(data["builtCards"]), "scaffolded": 0, "next": 0, "later": 0, "tbd": 0}
    for track in data["tracks"].values():
        for item in track["items"]:
            counts[item["status"]] += 1
    if include_convergence:
        for item in data["convergence"]:
            counts[item["status"]] += 1
    return counts


# ---------------------------------------------------------------------------
# HTML injection (simple string replacement, no deps needed)
# ---------------------------------------------------------------------------
def build_page1_html(data):
    """Read page1.html template and inject data."""
    template = PAGE1_PATH.read_text()

    counts = count_statuses(data, include_convergence=False)

    # Replace date
    template = template.replace("{{DATE}}", data["date"])

    # Already built items as mini-cards
    cards_html = ""
    for item in data["alreadyBuilt"]:
        cards_html += f'      <div class="built-card"><div class="gdot"></div><span>{item}</span></div>\n'
    template = template.replace("{{BUILT_CARDS}}", cards_html)

    # Newly built as chips (green=tested, amber=needs testing)
    chips_html = ""
    for item in data["newlyBuilt"]:
        if isinstance(item, str):
            # Backwards compat: plain string = tested
            chips_html += f'      <div class="new-chip tested">{item}</div>\n'
        else:
            name = item["name"]
            tested = item.get("tested", False)
            cls = "tested" if tested else "needs-testing"
            label = "Tested" if tested else "Needs Testing"
            chips_html += f'      <div class="new-chip {cls}">{name}<span class="chip-status">· {label}</span></div>\n'
    template = template.replace("{{NEW_CHIPS}}", chips_html)
    template = template.replace("{{PLATFORM_NOTE}}", data["platformNote"])

    # Tracks
    for track_id, track_class in [("data", "data"), ("outreach", "outreach"), ("intelligence", "intelligence")]:
        track = data["tracks"][track_id]
        template = template.replace(f"{{{{{track_id.upper()}_TITLE}}}}", track["title"])
        template = template.replace(f"{{{{{track_id.upper()}_DESC}}}}", track["description"])

        items_html = ""
        for item in track["items"]:
            prev = item.get("previousStatus")
            if prev:
                status_html = f'''<div class="status-transition">
            <span class="status-old {prev}">{STATUS_LABELS[prev]}</span>
            <span class="status-arrow">→</span>
            <span class="status-text {item['status']}">{STATUS_LABELS[item['status']]}</span>
          </div>'''
            else:
                s = item["status"]
                status_html = f'<span class="status-text {s}">{STATUS_LABELS[s]}</span>'
            items_html += f'''
        <div class="track-item">
          <div class="track-item-left"><span class="dot {item['status']}"></span><span class="track-item-name">{item['name']}</span></div>
          {status_html}
        </div>'''
        template = template.replace(f"{{{{{track_id.upper()}_ITEMS}}}}", items_html)

    # Legend counts
    for status, label in STATUS_LABELS.items():
        template = template.replace(f"{{{{{status.upper()}_COUNT}}}}", str(counts[status]))

    return template


def build_page2_html(data):
    """Read page2.html template and inject data."""
    template = PAGE2_PATH.read_text()

    counts = count_statuses(data)
    template = template.replace("{{DATE}}", data["date"])

    # Pain points
    pains_html = ""
    for p in data["painPoints"]:
        pains_html += f'''<div class="pain-item"><div class="pain-dot"></div><div class="pain-text">{p['text']}</div><div class="pain-tag">{p['tag']}</div></div>\n'''
    template = template.replace("{{PAIN_POINTS}}", pains_html)

    # Tool landscape
    tools_html = ""
    for t in data["toolLandscape"]:
        tools_html += f'''<div class="tool-row"><div class="tool-badge {t['badge']}">{t['approach']}</div><div class="tool-name">{t['tool']}</div><div class="tool-desc">{t['desc']}</div></div>\n'''
    template = template.replace("{{TOOL_ROWS}}", tools_html)

    # Built cards
    cards_html = ""
    for c in data["builtCards"]:
        cards_html += f'''<div class="built-card"><div class="built-card-header"><div class="gdot"></div><span>{c['name']}</span></div><div class="built-card-desc">{c['detail']}</div></div>\n'''
    template = template.replace("{{BUILT_CARDS}}", cards_html)
    template = template.replace("{{PLATFORM_NOTE}}", data["platformNote"])

    # Tracks (detailed)
    for track_id in ["data", "outreach", "intelligence"]:
        track = data["tracks"][track_id]
        template = template.replace(f"{{{{{track_id.upper()}_TITLE}}}}", track["title"])
        template = template.replace(f"{{{{{track_id.upper()}_DESC}}}}", track["description"])
        template = template.replace(f"{{{{{track_id.upper()}_FOOT}}}}", track["footnote"])

        items_html = ""
        for item in track["items"]:
            prev = item.get("previousStatus")
            if prev:
                badge_html = f'<div class="status-transition"><span class="sbadge-old {prev}">{STATUS_LABELS[prev]}</span><span class="status-arrow-sm">→</span><span class="sbadge {item["status"]}">{STATUS_LABELS[item["status"]]}</span></div>'
            else:
                badge_html = f'<span class="sbadge {item["status"]}">{STATUS_LABELS[item["status"]]}</span>'
            items_html += f'<div class="track-card"><div class="track-card-top"><span class="track-card-name">{item["name"]}</span>{badge_html}</div><div class="track-card-desc">{item["detail"]}</div></div>\n'
        template = template.replace(f"{{{{{track_id.upper()}_ITEMS}}}}", items_html)

    # Convergence
    conv_html = ""
    for c in data["convergence"]:
        conv_html += f'''<div class="conv-card">
      <div class="conv-top"><span class="conv-name">{c['name']}</span><span class="sbadge {c['status']}">{STATUS_LABELS[c['status']]}</span></div>
      <div class="conv-desc">{c['detail']}</div>
      <div class="conv-req">Requires: {c['requires']}</div>
    </div>\n'''
    template = template.replace("{{CONVERGENCE}}", conv_html)

    # Counts
    for status, label in STATUS_LABELS.items():
        template = template.replace(f"{{{{{status.upper()}_COUNT}}}}", str(counts[status]))

    return template


# ---------------------------------------------------------------------------
# PDF rendering
# ---------------------------------------------------------------------------
async def render_to_pdf(html_content, fixed_height=None):
    """Render HTML string to PDF bytes via Playwright."""
    from playwright.async_api import async_playwright

    async with async_playwright() as p:
        browser = await p.chromium.launch(headless=True)
        page = await browser.new_page()
        await page.set_content(html_content, wait_until="networkidle")

        height = fixed_height or await page.evaluate("document.body.scrollHeight")
        pdf_bytes = await page.pdf(
            width="816px",
            height=f"{height}px",
            print_background=True,
            margin={"top": "0px", "right": "0px", "bottom": "0px", "left": "0px"},
        )
        await browser.close()
        return pdf_bytes


async def generate_pdf(output_dir):
    """Main generation pipeline."""
    from pypdf import PdfReader, PdfWriter

    # Load data
    data = json.loads(DATA_PATH.read_text())

    # Build HTML
    page1_html = build_page1_html(data)
    page2_html = build_page2_html(data)

    # Render to PDF
    print("Rendering page 1...")
    pdf1 = await render_to_pdf(page1_html, fixed_height=1056)
    print("Rendering page 2...")
    pdf2 = await render_to_pdf(page2_html)

    # Merge
    writer = PdfWriter()
    for pdf_bytes in [pdf1, pdf2]:
        reader = PdfReader(io.BytesIO(pdf_bytes))
        for pg in reader.pages:
            writer.add_page(pg)

    # Output
    today = date.today().isoformat()
    filename = f"RIG-Build-Plan-{today}.pdf"
    out_path = Path(output_dir) / filename
    with open(out_path, "wb") as f:
        writer.write(f)

    print(f"Done! Saved to {out_path}")
    return out_path


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------
def main():
    output_dir = HERE.parent  # default: project root
    if "--out" in sys.argv:
        idx = sys.argv.index("--out")
        if idx + 1 < len(sys.argv):
            output_dir = sys.argv[idx + 1]

    asyncio.run(generate_pdf(output_dir))


if __name__ == "__main__":
    main()
