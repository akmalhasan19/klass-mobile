"""Font metrics for the Canvas Calculator fallback engine.

Provides text-box size estimation so the canvas layout engine can size its
rounded-rectangle cards and (optionally) sanity-check that content fits within
a given width before rendering.

Deviation from the plan's formula
---------------------------------
The plan sketches ``chars-per-line ≈ width / (0.5 * font_pt)``. That expression
mixes units: ``width`` is supplied in EMU while ``font_pt`` is in points, so
dividing them directly is meaningless. The correct comparison requires both
sides in the same unit. We convert the box width from EMU to points first
(``1 pt = 1/72 in``, ``1 EMU = 1/914400 in`` → ``EMU_PER_POINT = 12700``) and
then divide by the average glyph advance, kept at the plan's ``0.5 * font_pt``
heuristic. ``estimate_box`` therefore returns a true EMU height.
"""
from __future__ import annotations

import math
from pptx.util import Emu

EMU_PER_INCH = 914_400
EMU_PER_POINT = EMU_PER_INCH / 72  # 12700 EMU per point

# Average glyph advance as a fraction of the font size (points).  0.45 is
# slightly more conservative than the conventional 0.5 heuristic, which
# overestimates chars-per-line for Indonesian/Latin mixed text that contains
# wide glyphs (e.g. "W", "M") and CJK characters.  Using 0.45 causes
# estimate_box to predict ~11 % more wrapped lines, which better matches
# reality in PowerPoint where word-wrap follows word boundaries (not fixed
# char counts).
AVG_GLYPH_ADVANCE = 0.45

# Multiplier applied to the nominal font size to obtain the line box height.
LINE_SPACING = 1.2


def estimate_box(text: str, font_pt: float, box_w_emu: int) -> Emu:
    """Estimate the height (EMU) needed to render *text* at *font_pt*.

    The estimate accounts for explicit line breaks in *text* and for word/char
    wrapping within *box_w_emu*. The average glyph advance is approximated as
    ``AVG_GLYPH_ADVANCE * font_pt`` points; lines are computed per paragraph
    (splitting on ``"\\n"``) and wrapped to ``floor(width / glyph_advance)``
    characters per line.

    Args:
        text: Text to measure. May contain ``"\\n"`` line breaks (e.g. from
            ``TemplateInjector._format_block`` output such as ``"• item"``).
        font_pt: Font size in points.
        box_w_emu: Available text width in EMU.

    Returns:
        Required text height in EMU (as a :class:`~pptx.util.Emu`).
    """
    char_w_pt = AVG_GLYPH_ADVANCE * font_pt
    box_w_pt = box_w_emu / EMU_PER_POINT
    chars_per_line = max(1, int(box_w_pt // char_w_pt))

    line_count = 0
    for paragraph in text.split("\n"):
        if paragraph == "":
            line_count += 1
        else:
            line_count += max(1, math.ceil(len(paragraph) / chars_per_line))

    height_pt = line_count * font_pt * LINE_SPACING
    return Emu(int(round(height_pt * EMU_PER_POINT)))
