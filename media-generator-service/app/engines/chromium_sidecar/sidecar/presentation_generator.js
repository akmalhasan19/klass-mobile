import pptxgen from 'pptxgenjs';
/**
 * Estimate height of a text block in inches.
 */
function estimateTextHeight(text, fontSize, widthInches) {
    if (!text)
        return 0;
    const avgCharWidth = (fontSize * 0.045) / 10;
    const charsPerLine = Math.max(1, Math.floor(widthInches / avgCharWidth));
    const paragraphs = text.split('\n');
    let totalLines = 0;
    for (const para of paragraphs) {
        const cleanPara = para.replace(/^[-*•]\s+/, '').trim();
        if (cleanPara.length === 0)
            continue;
        const lines = Math.ceil(cleanPara.length / charsPerLine);
        totalLines += Math.max(1, lines);
    }
    const lineHeight = (fontSize * 1.35) / 72;
    return totalLines * lineHeight;
}
/**
 * Parses body text into bullet lines or single paragraphs.
 */
function parseBodyToLines(body) {
    return body
        .split('\n')
        .map(line => line.trim())
        .filter(line => line.length > 0)
        .map(line => line.replace(/^[-*•]\s+/, ''));
}
/**
 * Utility to sanitize colors (strip # if present).
 */
function cleanColor(hex) {
    return hex.replace('#', '').trim();
}
export async function generatePresentation(input) {
    const pptx = new pptxgen();
    pptx.layout = 'LAYOUT_16x9'; // Widescreen 13.33 x 7.5 inches
    const theme = {
        primary_color: cleanColor(input.meta.theme?.primary_color || '0B1F33'),
        secondary_color: cleanColor(input.meta.theme?.secondary_color || '0F4C5C'),
        bg_color: cleanColor(input.meta.theme?.bg_color || 'F8FAFC'),
        text_color: cleanColor(input.meta.theme?.text_color || '1F2933'),
        font_heading: input.meta.theme?.font_heading || 'Helvetica',
        font_body: input.meta.theme?.font_body || 'Arial',
    };
    // Determine light or dark mode theme colors
    const isDarkBg = ['0f172a', '1e293b', '000000', '0b1f33'].includes(theme.bg_color.toLowerCase());
    const cardFillColor = isDarkBg ? '1E293B' : 'FFFFFF';
    const cardBorderColor = isDarkBg ? '334155' : 'E2E8F0';
    for (const slideData of input.slides) {
        const slide = pptx.addSlide();
        slide.background = { fill: theme.bg_color };
        if (slideData.layout_type === 'title_hero') {
            renderTitleHero(pptx, slide, slideData, theme);
        }
        else if (slideData.layout_type === 'section_header') {
            renderSectionHeader(pptx, slide, slideData, theme);
        }
        else if (slideData.layout_type === 'bullet_list_icon') {
            renderBulletListIcon(pptx, slide, slideData, theme, isDarkBg);
        }
        else if (slideData.layout_type === 'two_columns_card') {
            renderColumnsCard(pptx, slide, slideData, theme, cardFillColor, cardBorderColor, 2);
        }
        else if (slideData.layout_type === 'three_columns_card') {
            renderColumnsCard(pptx, slide, slideData, theme, cardFillColor, cardBorderColor, 3);
        }
        else if (slideData.layout_type === 'metric_highlight') {
            renderMetricHighlight(pptx, slide, slideData, theme, cardFillColor, cardBorderColor);
        }
        else if (slideData.layout_type === 'timeline_process') {
            renderTimelineProcess(pptx, slide, slideData, theme, isDarkBg);
        }
        else if (slideData.layout_type === 'quote_callout') {
            renderQuoteCallout(pptx, slide, slideData, theme);
        }
        else {
            renderGenericContent(pptx, slide, slideData, theme, cardFillColor, cardBorderColor);
        }
    }
    const buffer = await pptx.write({ outputType: 'nodebuffer' });
    return buffer;
}
// ═══════════════════════════════════════════════════════════════════════════
// Layout Renderers
// ═══════════════════════════════════════════════════════════════════════════
function renderTitleHero(pptx, slide, slideData, theme) {
    const titleFontSize = 44;
    const subtitleFontSize = 20;
    const contentWidth = 11.733;
    const titleHeight = estimateTextHeight(slideData.title, titleFontSize, contentWidth);
    const subtitleHeight = slideData.subtitle
        ? estimateTextHeight(slideData.subtitle, subtitleFontSize, contentWidth)
        : 0;
    const totalHeight = titleHeight + (slideData.subtitle ? subtitleHeight + 0.4 : 0);
    const yStart = (7.5 - totalHeight) / 2;
    // Aesthetic accent line above title
    slide.addShape(pptx.shapes.RECTANGLE, {
        x: (13.333 - 1.5) / 2,
        y: yStart - 0.35,
        w: 1.5,
        h: 0.06,
        fill: { color: theme.secondary_color },
        line: { width: 0 }
    });
    slide.addText(slideData.title, {
        x: 0.8,
        y: yStart,
        w: contentWidth,
        h: titleHeight + 0.1,
        fontName: theme.font_heading,
        fontSize: titleFontSize,
        color: theme.primary_color,
        bold: true,
        align: 'center',
    });
    if (slideData.subtitle) {
        slide.addText(slideData.subtitle, {
            x: 0.8,
            y: yStart + titleHeight + 0.3,
            w: contentWidth,
            h: subtitleHeight + 0.1,
            fontName: theme.font_body,
            fontSize: subtitleFontSize,
            color: theme.secondary_color,
            align: 'center',
        });
    }
}
function renderSectionHeader(pptx, slide, slideData, theme) {
    // Full-bleed colored background with high-contrast text
    slide.background = { fill: theme.secondary_color };
    const titleFontSize = 40;
    const subtitleFontSize = 18;
    const contentWidth = 10;
    const titleHeight = estimateTextHeight(slideData.title, titleFontSize, contentWidth);
    const subtitleHeight = slideData.subtitle
        ? estimateTextHeight(slideData.subtitle, subtitleFontSize, contentWidth)
        : 0;
    const totalHeight = titleHeight + (slideData.subtitle ? subtitleHeight + 0.5 : 0);
    const yStart = (7.5 - totalHeight) / 2;
    // Decorative line
    slide.addShape(pptx.shapes.RECTANGLE, {
        x: (13.333 - 2) / 2,
        y: yStart - 0.4,
        w: 2,
        h: 0.05,
        fill: { color: 'FFFFFF' },
        line: { width: 0 }
    });
    slide.addText(slideData.title, {
        x: (13.333 - contentWidth) / 2,
        y: yStart,
        w: contentWidth,
        h: titleHeight + 0.1,
        fontName: theme.font_heading,
        fontSize: titleFontSize,
        color: 'FFFFFF',
        bold: true,
        align: 'center',
    });
    if (slideData.subtitle) {
        slide.addText(slideData.subtitle, {
            x: (13.333 - contentWidth) / 2,
            y: yStart + titleHeight + 0.3,
            w: contentWidth,
            h: subtitleHeight + 0.1,
            fontName: theme.font_body,
            fontSize: subtitleFontSize,
            color: 'E0E0E0',
            align: 'center',
        });
    }
}
function renderBulletListIcon(pptx, slide, slideData, theme, isDarkBg) {
    const { yContentStart } = renderSlideHeader(pptx, slide, slideData, theme);
    const availableHeight = 7.5 - yContentStart - 0.5;
    const cards = slideData.content || [];
    const N = cards.length;
    if (N === 0)
        return;
    const rowHeight = Math.min(availableHeight / N, 1.0);
    const iconSize = 0.5;
    const gapY = 0.15;
    for (let i = 0; i < N; i++) {
        const card = cards[i];
        const rowY = yContentStart + i * (rowHeight + gapY);
        // Numbered circle icon
        slide.addShape(pptx.shapes.OVAL, {
            x: 0.8,
            y: rowY + (rowHeight - iconSize) / 2,
            w: iconSize,
            h: iconSize,
            fill: { color: theme.secondary_color },
            line: { width: 0 },
        });
        slide.addText(String(i + 1), {
            x: 0.8,
            y: rowY + (rowHeight - iconSize) / 2,
            w: iconSize,
            h: iconSize,
            fontName: theme.font_heading,
            fontSize: 16,
            color: isDarkBg ? '0F172A' : 'FFFFFF',
            bold: true,
            align: 'center',
            valign: 'middle',
        });
        // Heading + body
        const textX = 0.8 + iconSize + 0.3;
        const textW = 13.333 - textX - 0.8;
        if (card.heading) {
            const headingHeight = estimateTextHeight(card.heading, 15, textW);
            slide.addText(card.heading, {
                x: textX,
                y: rowY,
                w: textW,
                h: headingHeight + 0.05,
                fontName: theme.font_heading,
                fontSize: 15,
                color: theme.primary_color,
                bold: true,
            });
            if (card.body && card.body !== card.heading) {
                slide.addText(card.body, {
                    x: textX,
                    y: rowY + headingHeight + 0.05,
                    w: textW,
                    h: rowHeight - headingHeight - 0.1,
                    fontName: theme.font_body,
                    fontSize: 12,
                    color: theme.text_color,
                    valign: 'top',
                });
            }
        }
        else if (card.body) {
            slide.addText(card.body, {
                x: textX,
                y: rowY,
                w: textW,
                h: rowHeight,
                fontName: theme.font_body,
                fontSize: 13,
                color: theme.text_color,
                valign: 'middle',
            });
        }
    }
}
function renderColumnsCard(pptx, slide, slideData, theme, cardFillColor, cardBorderColor, targetCols) {
    const { yContentStart } = renderSlideHeader(pptx, slide, slideData, theme);
    const availableHeight = 7.5 - yContentStart - 0.7;
    const cards = slideData.content || [];
    const N = Math.min(cards.length, targetCols);
    if (N === 0)
        return;
    const gap = 0.45;
    const colWidth = (11.733 - (N - 1) * gap) / N;
    for (let i = 0; i < N; i++) {
        const card = cards[i];
        const colX = 0.8 + i * (colWidth + gap);
        slide.addShape(pptx.shapes.ROUNDED_RECTANGLE, {
            x: colX,
            y: yContentStart,
            w: colWidth,
            h: availableHeight,
            fill: { color: cardFillColor },
            line: { color: cardBorderColor, width: 1 },
            rectRadius: 0.05,
        });
        let currentY = yContentStart + 0.3;
        const paddingX = 0.3;
        const contentW = colWidth - 2 * paddingX;
        if (card.heading) {
            const headingFontSize = 16;
            const headingHeight = estimateTextHeight(card.heading, headingFontSize, contentW);
            slide.addText(card.heading, {
                x: colX + paddingX,
                y: currentY,
                w: contentW,
                h: headingHeight + 0.05,
                fontName: theme.font_heading,
                fontSize: headingFontSize,
                color: theme.primary_color,
                bold: true,
            });
            currentY += headingHeight + 0.2;
        }
        if (card.body) {
            const bodyFontSize = 12;
            const bodyLines = parseBodyToLines(card.body);
            const isBullets = card.body.trim().startsWith('-') || card.body.trim().startsWith('*') || bodyLines.length > 1;
            if (isBullets) {
                const textObjects = bodyLines.map(line => ({
                    text: line,
                    options: {
                        bullet: true,
                        color: theme.text_color,
                        fontSize: bodyFontSize,
                        fontName: theme.font_body,
                    },
                }));
                slide.addText(textObjects, {
                    x: colX + paddingX,
                    y: currentY,
                    w: contentW,
                    h: availableHeight - (currentY - yContentStart) - 0.3,
                    valign: 'top',
                });
            }
            else {
                slide.addText(card.body, {
                    x: colX + paddingX,
                    y: currentY,
                    w: contentW,
                    h: availableHeight - (currentY - yContentStart) - 0.3,
                    fontName: theme.font_body,
                    fontSize: bodyFontSize,
                    color: theme.text_color,
                    valign: 'top',
                });
            }
        }
    }
}
function renderMetricHighlight(pptx, slide, slideData, theme, cardFillColor, cardBorderColor) {
    const { yContentStart } = renderSlideHeader(pptx, slide, slideData, theme);
    const availableHeight = 7.5 - yContentStart - 0.7;
    const cards = slideData.content || [];
    const N = cards.length;
    if (N === 0)
        return;
    const gap = 0.45;
    const colWidth = (11.733 - (N - 1) * gap) / N;
    for (let i = 0; i < N; i++) {
        const card = cards[i];
        const colX = 0.8 + i * (colWidth + gap);
        slide.addShape(pptx.shapes.ROUNDED_RECTANGLE, {
            x: colX,
            y: yContentStart,
            w: colWidth,
            h: availableHeight,
            fill: { color: cardFillColor },
            line: { color: cardBorderColor, width: 1 },
            rectRadius: 0.05,
        });
        const metricFontSize = N >= 4 ? 36 : 48;
        const headingText = card.heading || '';
        const headingHeight = estimateTextHeight(headingText, metricFontSize, colWidth - 0.4);
        slide.addText(headingText, {
            x: colX + 0.2,
            y: yContentStart + 0.4,
            w: colWidth - 0.4,
            h: headingHeight + 0.1,
            fontName: theme.font_heading,
            fontSize: metricFontSize,
            color: theme.secondary_color,
            bold: true,
            align: 'center',
        });
        const labelText = card.body || '';
        const labelFontSize = 13;
        const labelHeight = estimateTextHeight(labelText, labelFontSize, colWidth - 0.4);
        slide.addText(labelText, {
            x: colX + 0.2,
            y: yContentStart + 0.4 + headingHeight + 0.2,
            w: colWidth - 0.4,
            h: Math.min(availableHeight - headingHeight - 0.8, labelHeight + 0.1),
            fontName: theme.font_body,
            fontSize: labelFontSize,
            color: theme.text_color,
            align: 'center',
            valign: 'top',
        });
    }
}
function renderTimelineProcess(pptx, slide, slideData, theme, isDarkBg) {
    const { yContentStart } = renderSlideHeader(pptx, slide, slideData, theme);
    const availableHeight = 7.5 - yContentStart - 0.5;
    const cards = slideData.content || [];
    const N = cards.length;
    if (N === 0)
        return;
    const gap = 0.3;
    const totalWidth = 11.733;
    const stepWidth = (totalWidth - (N - 1) * gap) / N;
    const circleSize = 0.6;
    const lineY = yContentStart + availableHeight * 0.25;
    // Connecting horizontal line
    if (N > 1) {
        slide.addShape(pptx.shapes.RECTANGLE, {
            x: 0.8 + circleSize / 2,
            y: lineY + circleSize / 2 - 0.03,
            w: totalWidth - circleSize,
            h: 0.06,
            fill: { color: theme.secondary_color },
            line: { width: 0 },
        });
    }
    for (let i = 0; i < N; i++) {
        const card = cards[i];
        const stepX = 0.8 + i * (stepWidth + gap);
        const circleX = stepX + (stepWidth - circleSize) / 2;
        // Step circle
        slide.addShape(pptx.shapes.OVAL, {
            x: circleX,
            y: lineY,
            w: circleSize,
            h: circleSize,
            fill: { color: theme.secondary_color },
            line: { width: 0 },
        });
        // Step number
        slide.addText(String(i + 1), {
            x: circleX,
            y: lineY,
            w: circleSize,
            h: circleSize,
            fontName: theme.font_heading,
            fontSize: 18,
            color: isDarkBg ? '0F172A' : 'FFFFFF',
            bold: true,
            align: 'center',
            valign: 'middle',
        });
        // Step heading below circle
        const textY = lineY + circleSize + 0.25;
        if (card.heading) {
            const headingHeight = estimateTextHeight(card.heading, 13, stepWidth);
            slide.addText(card.heading, {
                x: stepX,
                y: textY,
                w: stepWidth,
                h: headingHeight + 0.05,
                fontName: theme.font_heading,
                fontSize: 13,
                color: theme.primary_color,
                bold: true,
                align: 'center',
            });
            if (card.body && card.body !== card.heading) {
                slide.addText(card.body, {
                    x: stepX,
                    y: textY + headingHeight + 0.1,
                    w: stepWidth,
                    h: availableHeight - (textY + headingHeight + 0.1 - yContentStart) - 0.2,
                    fontName: theme.font_body,
                    fontSize: 11,
                    color: theme.text_color,
                    align: 'center',
                    valign: 'top',
                });
            }
        }
        else if (card.body) {
            slide.addText(card.body, {
                x: stepX,
                y: textY,
                w: stepWidth,
                h: availableHeight - (textY - yContentStart) - 0.2,
                fontName: theme.font_body,
                fontSize: 12,
                color: theme.text_color,
                align: 'center',
                valign: 'top',
            });
        }
    }
}
function renderQuoteCallout(pptx, slide, slideData, theme) {
    const contentWidth = 10;
    const quoteText = slideData.content?.[0]?.body || slideData.subtitle || '';
    const quoteFontSize = 24;
    const quoteHeight = estimateTextHeight(quoteText, quoteFontSize, contentWidth);
    const totalHeight = quoteHeight + 1.2;
    const yStart = (7.5 - totalHeight) / 2;
    // Decorative opening quote mark
    slide.addText('\u201C', {
        x: (13.333 - contentWidth) / 2 - 0.3,
        y: yStart - 0.3,
        w: 1,
        h: 1,
        fontName: 'Georgia',
        fontSize: 80,
        color: theme.secondary_color,
        bold: true,
        transparency: 40,
    });
    // Quote text
    slide.addText(quoteText, {
        x: (13.333 - contentWidth) / 2,
        y: yStart + 0.5,
        w: contentWidth,
        h: quoteHeight + 0.2,
        fontName: theme.font_body,
        fontSize: quoteFontSize,
        color: theme.primary_color,
        italic: true,
        align: 'center',
        valign: 'middle',
    });
    // Slide title as attribution below
    if (slideData.title) {
        slide.addText(`\u2014 ${slideData.title}`, {
            x: (13.333 - contentWidth) / 2,
            y: yStart + 0.5 + quoteHeight + 0.4,
            w: contentWidth,
            h: 0.4,
            fontName: theme.font_heading,
            fontSize: 14,
            color: theme.secondary_color,
            align: 'center',
        });
    }
}
function renderGenericContent(pptx, slide, slideData, theme, cardFillColor, cardBorderColor) {
    const { yContentStart } = renderSlideHeader(pptx, slide, slideData, theme);
    const availableHeight = 7.5 - yContentStart - 0.7;
    const cards = slideData.content || [];
    const N = cards.length;
    if (N > 0) {
        const useGrid = N >= 4;
        const cols = useGrid ? Math.ceil(N / 2) : N;
        const rows = useGrid ? 2 : 1;
        const gapX = 0.45;
        const gapY = 0.35;
        const colWidth = useGrid
            ? (11.733 - (cols - 1) * gapX) / cols
            : (N === 1 ? 7.5 : (11.733 - (N - 1) * gapX) / N);
        const startX = N === 1 ? (13.333 - colWidth) / 2 : 0.8;
        const rowHeight = (availableHeight - (rows - 1) * gapY) / rows;
        for (let i = 0; i < N; i++) {
            const card = cards[i];
            const r = useGrid ? Math.floor(i / cols) : 0;
            const c = useGrid ? i % cols : i;
            const colX = startX + c * (colWidth + gapX);
            const colY = yContentStart + r * (rowHeight + gapY);
            slide.addShape(pptx.shapes.ROUNDED_RECTANGLE, {
                x: colX,
                y: colY,
                w: colWidth,
                h: rowHeight,
                fill: { color: cardFillColor },
                line: { color: cardBorderColor, width: 1 },
                rectRadius: 0.04,
            });
            let currentY = colY + 0.25;
            const paddingX = 0.25;
            const contentW = colWidth - 2 * paddingX;
            if (card.heading) {
                const headingFontSize = 16;
                const cardHeadingHeight = estimateTextHeight(card.heading, headingFontSize, contentW);
                slide.addText(card.heading, {
                    x: colX + paddingX,
                    y: currentY,
                    w: contentW,
                    h: cardHeadingHeight + 0.05,
                    fontName: theme.font_heading,
                    fontSize: headingFontSize,
                    color: theme.primary_color,
                    bold: true,
                });
                currentY += cardHeadingHeight + 0.15;
            }
            if (card.body) {
                const bodyFontSize = 12;
                const bodyLines = parseBodyToLines(card.body);
                const isBullets = card.body.trim().startsWith('-') || card.body.trim().startsWith('*') || bodyLines.length > 1;
                if (isBullets) {
                    const textObjects = bodyLines.map(line => ({
                        text: line,
                        options: {
                            bullet: true,
                            color: theme.text_color,
                            fontSize: bodyFontSize,
                            fontName: theme.font_body,
                        },
                    }));
                    slide.addText(textObjects, {
                        x: colX + paddingX,
                        y: currentY,
                        w: contentW,
                        h: rowHeight - (currentY - colY) - 0.2,
                        valign: 'top',
                    });
                }
                else {
                    slide.addText(card.body, {
                        x: colX + paddingX,
                        y: currentY,
                        w: contentW,
                        h: rowHeight - (currentY - colY) - 0.2,
                        fontName: theme.font_body,
                        fontSize: bodyFontSize,
                        color: theme.text_color,
                        valign: 'top',
                    });
                }
            }
        }
    }
}
// ═══════════════════════════════════════════════════════════════════════════
// Shared helpers
// ═══════════════════════════════════════════════════════════════════════════
/**
 * Render the standard slide header (title + optional subtitle).
 * Returns the Y position where content should start.
 */
function renderSlideHeader(pptx, slide, slideData, theme) {
    const headerWidth = 11.733;
    const titleFontSize = 28;
    const subtitleFontSize = 15;
    const titleHeight = estimateTextHeight(slideData.title, titleFontSize, headerWidth);
    const subtitleHeight = slideData.subtitle
        ? estimateTextHeight(slideData.subtitle, subtitleFontSize, headerWidth)
        : 0;
    slide.addText(slideData.title, {
        x: 0.8,
        y: 0.6,
        w: headerWidth,
        h: titleHeight + 0.1,
        fontName: theme.font_heading,
        fontSize: titleFontSize,
        color: theme.primary_color,
        bold: true,
    });
    if (slideData.subtitle) {
        slide.addText(slideData.subtitle, {
            x: 0.8,
            y: 0.6 + titleHeight + 0.1,
            w: headerWidth,
            h: subtitleHeight + 0.1,
            fontName: theme.font_body,
            fontSize: subtitleFontSize,
            color: theme.secondary_color,
        });
    }
    const yContentStart = Math.max(1.8, 0.6 + titleHeight + (slideData.subtitle ? subtitleHeight + 0.15 : 0) + 0.4);
    return { yContentStart };
}
