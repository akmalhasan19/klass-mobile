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
    let titleFontSize = 44;
    let subtitleFontSize = 20;
    const contentWidth = 11.733;
    let titleHeight = estimateTextHeight(slideData.title, titleFontSize, contentWidth);
    let subtitleHeight = slideData.subtitle
        ? estimateTextHeight(slideData.subtitle, subtitleFontSize, contentWidth)
        : 0;
    let totalHeight = titleHeight + (slideData.subtitle ? subtitleHeight + 0.4 : 0);
    
    // Scale down fonts dynamically if the content overflows the slide height
    while (totalHeight > 5.5 && titleFontSize > 24) {
        titleFontSize -= 2;
        if (subtitleFontSize > 14)
            subtitleFontSize -= 1;
        titleHeight = estimateTextHeight(slideData.title, titleFontSize, contentWidth);
        subtitleHeight = slideData.subtitle
            ? estimateTextHeight(slideData.subtitle, subtitleFontSize, contentWidth)
            : 0;
        totalHeight = titleHeight + (slideData.subtitle ? subtitleHeight + 0.4 : 0);
    }
    
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
        fit: 'shrink',
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
            fit: 'shrink',
        });
    }
}
function renderSectionHeader(pptx, slide, slideData, theme) {
    // Full-bleed colored background with high-contrast text
    slide.background = { fill: theme.secondary_color };
    let titleFontSize = 40;
    let subtitleFontSize = 18;
    const contentWidth = 10;
    let titleHeight = estimateTextHeight(slideData.title, titleFontSize, contentWidth);
    let subtitleHeight = slideData.subtitle
        ? estimateTextHeight(slideData.subtitle, subtitleFontSize, contentWidth)
        : 0;
    let totalHeight = titleHeight + (slideData.subtitle ? subtitleHeight + 0.5 : 0);
    
    // Scale down fonts dynamically if the content overflows the slide height
    while (totalHeight > 5.5 && titleFontSize > 20) {
        titleFontSize -= 2;
        if (subtitleFontSize > 12)
            subtitleFontSize -= 1;
        titleHeight = estimateTextHeight(slideData.title, titleFontSize, contentWidth);
        subtitleHeight = slideData.subtitle
            ? estimateTextHeight(slideData.subtitle, subtitleFontSize, contentWidth)
            : 0;
        totalHeight = titleHeight + (slideData.subtitle ? subtitleHeight + 0.5 : 0);
    }
    
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
        fit: 'shrink',
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
            fit: 'shrink',
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
    const iconSize = 0.5;
    const textX = 0.8 + iconSize + 0.3;
    const textW = 13.333 - textX - 0.8;
    
    let headingFontSize = 15;
    let bodyFontSize = 12;
    let gapY = N > 4 ? 0.08 : 0.15;
    
    let attempts = 0;
    while (attempts < 5) {
        let totalRequiredHeight = 0;
        for (let i = 0; i < N; i++) {
            const card = cards[i];
            let cardH = 0;
            if (card.heading) {
                const headingHeight = estimateTextHeight(card.heading, headingFontSize, textW);
                cardH += headingHeight + 0.05;
                if (card.body && card.body !== card.heading) {
                    const bodyHeight = estimateTextHeight(card.body, bodyFontSize, textW);
                    cardH += bodyHeight + 0.1;
                }
            }
            else if (card.body) {
                cardH += estimateTextHeight(card.body, bodyFontSize + 1, textW);
            }
            totalRequiredHeight += Math.max(iconSize, cardH);
        }
        totalRequiredHeight += (N - 1) * gapY;
        
        if (totalRequiredHeight <= availableHeight || headingFontSize <= 11) {
            break;
        }
        
        headingFontSize -= 1;
        bodyFontSize = Math.max(9, bodyFontSize - 1);
        gapY = Math.max(0.04, gapY - 0.02);
        attempts++;
    }
    
    let currentY = yContentStart;
    for (let i = 0; i < N; i++) {
        const card = cards[i];
        let cardH = 0;
        let headingHeight = 0;
        let bodyHeight = 0;
        if (card.heading) {
            headingHeight = estimateTextHeight(card.heading, headingFontSize, textW);
            cardH += headingHeight + 0.05;
            if (card.body && card.body !== card.heading) {
                bodyHeight = estimateTextHeight(card.body, bodyFontSize, textW);
                cardH += bodyHeight + 0.1;
            }
        }
        else if (card.body) {
            bodyHeight = estimateTextHeight(card.body, bodyFontSize + 1, textW);
            cardH += bodyHeight;
        }
        const rowHeight = Math.max(iconSize, cardH);
        const rowY = currentY;
        
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
            fontSize: Math.min(16, headingFontSize + 1),
            color: isDarkBg ? '0F172A' : 'FFFFFF',
            bold: true,
            align: 'center',
            valign: 'middle',
        });
        
        // Heading + body
        if (card.heading) {
            slide.addText(card.heading, {
                x: textX,
                y: rowY,
                w: textW,
                h: headingHeight + 0.05,
                fontName: theme.font_heading,
                fontSize: headingFontSize,
                color: theme.primary_color,
                bold: true,
                fit: 'shrink',
            });
            if (card.body && card.body !== card.heading) {
                slide.addText(card.body, {
                    x: textX,
                    y: rowY + headingHeight + 0.05,
                    w: textW,
                    h: bodyHeight + 0.05,
                    fontName: theme.font_body,
                    fontSize: bodyFontSize,
                    color: theme.text_color,
                    valign: 'top',
                    fit: 'shrink',
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
                fontSize: bodyFontSize + 1,
                color: theme.text_color,
                valign: 'middle',
                fit: 'shrink',
            });
        }
        currentY += rowHeight + gapY;
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
    
    let headingFontSize = 16;
    let bodyFontSize = 12;
    const paddingX = 0.3;
    const contentW = colWidth - 2 * paddingX;
    
    let attempts = 0;
    while (attempts < 5) {
        let maxRequiredHeight = 0;
        for (let i = 0; i < N; i++) {
            const card = cards[i];
            let cardH = 0.6; // top and bottom padding
            if (card.heading) {
                cardH += estimateTextHeight(card.heading, headingFontSize, contentW) + 0.2;
            }
            if (card.body) {
                cardH += estimateTextHeight(card.body, bodyFontSize, contentW);
            }
            if (cardH > maxRequiredHeight) {
                maxRequiredHeight = cardH;
            }
        }
        
        if (maxRequiredHeight <= availableHeight || headingFontSize <= 12) {
            break;
        }
        
        headingFontSize -= 1;
        bodyFontSize = Math.max(9, bodyFontSize - 1);
        attempts++;
    }
    
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
        if (card.heading) {
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
                fit: 'shrink',
            });
            currentY += headingHeight + 0.2;
        }
        if (card.body) {
            const bodyLines = parseBodyToLines(card.body);
            const isBullets = card.body.trim().startsWith('-') || card.body.trim().startsWith('*') || bodyLines.length > 1;
            const remainingHeight = availableHeight - (currentY - yContentStart) - 0.3;
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
                    h: remainingHeight,
                    valign: 'top',
                    fit: 'shrink',
                });
            }
            else {
                slide.addText(card.body, {
                    x: colX + paddingX,
                    y: currentY,
                    w: contentW,
                    h: remainingHeight,
                    fontName: theme.font_body,
                    fontSize: bodyFontSize,
                    color: theme.text_color,
                    valign: 'top',
                    fit: 'shrink',
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
    
    let metricFontSize = N >= 4 ? 36 : 48;
    let labelFontSize = 13;
    const contentW = colWidth - 0.4;
    
    let attempts = 0;
    while (attempts < 5) {
        let maxRequiredHeight = 0;
        for (let i = 0; i < N; i++) {
            const card = cards[i];
            const headingText = card.heading || '';
            const labelText = card.body || '';
            const headingHeight = estimateTextHeight(headingText, metricFontSize, contentW);
            const labelHeight = estimateTextHeight(labelText, labelFontSize, contentW);
            const cardH = 0.4 + headingHeight + 0.2 + labelHeight + 0.4;
            if (cardH > maxRequiredHeight) {
                maxRequiredHeight = cardH;
            }
        }
        
        if (maxRequiredHeight <= availableHeight || metricFontSize <= 24) {
            break;
        }
        
        metricFontSize -= 4;
        labelFontSize = Math.max(9, labelFontSize - 1);
        attempts++;
    }
    
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
        const headingText = card.heading || '';
        const headingHeight = estimateTextHeight(headingText, metricFontSize, contentW);
        slide.addText(headingText, {
            x: colX + 0.2,
            y: yContentStart + 0.4,
            w: contentW,
            h: headingHeight + 0.05,
            fontName: theme.font_heading,
            fontSize: metricFontSize,
            color: theme.secondary_color,
            bold: true,
            align: 'center',
            fit: 'shrink',
        });
        const labelText = card.body || '';
        const remainingHeight = availableHeight - headingHeight - 0.8;
        slide.addText(labelText, {
            x: colX + 0.2,
            y: yContentStart + 0.4 + headingHeight + 0.2,
            w: contentW,
            h: remainingHeight,
            fontName: theme.font_body,
            fontSize: labelFontSize,
            color: theme.text_color,
            align: 'center',
            valign: 'top',
            fit: 'shrink',
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
    
    let headingFontSize = 13;
    let bodyFontSize = 11;
    let attempts = 0;
    while (attempts < 5) {
        let maxRequiredTextHeight = 0;
        for (let i = 0; i < N; i++) {
            const card = cards[i];
            let textH = 0;
            if (card.heading) {
                textH += estimateTextHeight(card.heading, headingFontSize, stepWidth) + 0.05;
                if (card.body && card.body !== card.heading) {
                    textH += estimateTextHeight(card.body, bodyFontSize, stepWidth) + 0.1;
                }
            }
            else if (card.body) {
                textH += estimateTextHeight(card.body, bodyFontSize + 1, stepWidth);
            }
            if (textH > maxRequiredTextHeight) {
                maxRequiredTextHeight = textH;
            }
        }
        
        const remainingHeight = availableHeight * 0.75 - circleSize - 0.3;
        if (maxRequiredTextHeight <= remainingHeight || headingFontSize <= 10) {
            break;
        }
        
        headingFontSize -= 1;
        bodyFontSize = Math.max(8, bodyFontSize - 1);
        attempts++;
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
        const remainingTextHeight = availableHeight - (textY - yContentStart) - 0.1;
        if (card.heading) {
            const headingHeight = estimateTextHeight(card.heading, headingFontSize, stepWidth);
            slide.addText(card.heading, {
                x: stepX,
                y: textY,
                w: stepWidth,
                h: headingHeight + 0.05,
                fontName: theme.font_heading,
                fontSize: headingFontSize,
                color: theme.primary_color,
                bold: true,
                align: 'center',
                fit: 'shrink',
            });
            if (card.body && card.body !== card.heading) {
                slide.addText(card.body, {
                    x: stepX,
                    y: textY + headingHeight + 0.1,
                    w: stepWidth,
                    h: remainingTextHeight - headingHeight - 0.1,
                    fontName: theme.font_body,
                    fontSize: bodyFontSize,
                    color: theme.text_color,
                    align: 'center',
                    valign: 'top',
                    fit: 'shrink',
                });
            }
        }
        else if (card.body) {
            slide.addText(card.body, {
                x: stepX,
                y: textY,
                w: stepWidth,
                h: remainingTextHeight,
                fontName: theme.font_body,
                fontSize: bodyFontSize + 1,
                color: theme.text_color,
                align: 'center',
                valign: 'top',
                fit: 'shrink',
            });
        }
    }
}
function renderQuoteCallout(pptx, slide, slideData, theme) {
    const contentWidth = 10;
    const quoteText = slideData.content?.[0]?.body || slideData.subtitle || '';
    let quoteFontSize = 24;
    let quoteHeight = estimateTextHeight(quoteText, quoteFontSize, contentWidth);
    let totalHeight = quoteHeight + 1.2;
    
    while (totalHeight > 6.0 && quoteFontSize > 14) {
        quoteFontSize -= 2;
        quoteHeight = estimateTextHeight(quoteText, quoteFontSize, contentWidth);
        totalHeight = quoteHeight + 1.2;
    }
    
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
        fit: 'shrink',
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
            fit: 'shrink',
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
        
        let headingFontSize = 16;
        let bodyFontSize = 12;
        const paddingX = 0.25;
        const contentW = colWidth - 2 * paddingX;
        
        let attempts = 0;
        while (attempts < 5) {
            let maxRequiredHeight = 0;
            for (let i = 0; i < N; i++) {
                const card = cards[i];
                let cardH = 0.55; // top margin (0.25) + bottom margin (0.3)
                if (card.heading) {
                    cardH += estimateTextHeight(card.heading, headingFontSize, contentW) + 0.15;
                }
                if (card.body) {
                    cardH += estimateTextHeight(card.body, bodyFontSize, contentW);
                }
                if (cardH > maxRequiredHeight) {
                    maxRequiredHeight = cardH;
                }
            }
            
            if (maxRequiredHeight <= rowHeight || headingFontSize <= 11) {
                break;
            }
            
            headingFontSize -= 1;
            bodyFontSize = Math.max(9, bodyFontSize - 1);
            attempts++;
        }
        
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
            if (card.heading) {
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
                    fit: 'shrink',
                });
                currentY += cardHeadingHeight + 0.15;
            }
            if (card.body) {
                const bodyLines = parseBodyToLines(card.body);
                const isBullets = card.body.trim().startsWith('-') || card.body.trim().startsWith('*') || bodyLines.length > 1;
                const remainingBodyHeight = rowHeight - (currentY - colY) - 0.2;
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
                        h: remainingBodyHeight,
                        valign: 'top',
                        fit: 'shrink',
                    });
                }
                else {
                    slide.addText(card.body, {
                        x: colX + paddingX,
                        y: currentY,
                        w: contentW,
                        h: remainingBodyHeight,
                        fontName: theme.font_body,
                        fontSize: bodyFontSize,
                        color: theme.text_color,
                        valign: 'top',
                        fit: 'shrink',
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
    let titleFontSize = 28;
    let subtitleFontSize = 15;
    let titleHeight = estimateTextHeight(slideData.title, titleFontSize, headerWidth);
    let subtitleHeight = slideData.subtitle
        ? estimateTextHeight(slideData.subtitle, subtitleFontSize, headerWidth)
        : 0;
        
    while (titleHeight + (slideData.subtitle ? subtitleHeight + 0.15 : 0) > 1.4 && titleFontSize > 18) {
        titleFontSize -= 1;
        if (subtitleFontSize > 11) {
            subtitleFontSize -= 1;
        }
        titleHeight = estimateTextHeight(slideData.title, titleFontSize, headerWidth);
        subtitleHeight = slideData.subtitle
            ? estimateTextHeight(slideData.subtitle, subtitleFontSize, headerWidth)
            : 0;
    }
    
    slide.addText(slideData.title, {
        x: 0.8,
        y: 0.6,
        w: headerWidth,
        h: titleHeight + 0.1,
        fontName: theme.font_heading,
        fontSize: titleFontSize,
        color: theme.primary_color,
        bold: true,
        fit: 'shrink',
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
            fit: 'shrink',
        });
    }
    const yContentStart = Math.max(1.8, 0.6 + titleHeight + (slideData.subtitle ? subtitleHeight + 0.15 : 0) + 0.4);
    return { yContentStart };
}
