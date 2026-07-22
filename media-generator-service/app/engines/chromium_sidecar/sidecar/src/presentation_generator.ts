import pptxgen from 'pptxgenjs';

export interface Theme {
  primary_color: string;
  secondary_color: string;
  bg_color: string;
  text_color: string;
  font_heading: string;
  font_body: string;
}

export interface Meta {
  title: string;
  theme: Theme;
}

export interface SlideContent {
  heading?: string;
  body: string;
}

export interface SlideInput {
  slide_number: number;
  layout_type: string;
  title: string;
  subtitle?: string;
  content: SlideContent[];
}

export interface PresentationInput {
  meta: Meta;
  slides: SlideInput[];
}

/**
 * Estimate height of a text block in inches.
 */
function estimateTextHeight(text: string, fontSize: number, widthInches: number): number {
  if (!text) return 0;
  // Heuristic: standard font chars average about 0.045 to 0.05 inches per pt of size
  const avgCharWidth = (fontSize * 0.045) / 10;
  const charsPerLine = Math.max(1, Math.floor(widthInches / avgCharWidth));
  const paragraphs = text.split('\n');
  let totalLines = 0;
  for (const para of paragraphs) {
    const cleanPara = para.replace(/^[-*•]\s+/, '').trim();
    if (cleanPara.length === 0) continue;
    const lines = Math.ceil(cleanPara.length / charsPerLine);
    totalLines += Math.max(1, lines);
  }
  const lineHeight = (fontSize * 1.35) / 72; // in inches
  return totalLines * lineHeight;
}

/**
 * Parses body text into bullet lines or single paragraphs.
 */
function parseBodyToLines(body: string): string[] {
  return body
    .split('\n')
    .map(line => line.trim())
    .filter(line => line.length > 0)
    .map(line => line.replace(/^[-*•]\s+/, ''));
}

/**
 * Utility to sanitize colors (strip # if present).
 */
function cleanColor(hex: string): string {
  return hex.replace('#', '').trim();
}

export async function generatePresentation(input: PresentationInput): Promise<Buffer> {
  const pptx = new (pptxgen as any)();
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
      // ── Title Hero Slide Layout ──
      const titleFontSize = 44;
      const subtitleFontSize = 20;
      const contentWidth = 11.733; // 13.333 - 2 * 0.8

      const titleHeight = estimateTextHeight(slideData.title, titleFontSize, contentWidth);
      const subtitleHeight = slideData.subtitle
        ? estimateTextHeight(slideData.subtitle, subtitleFontSize, contentWidth)
        : 0;

      const totalHeight = titleHeight + (slideData.subtitle ? subtitleHeight + 0.4 : 0);
      const yStart = (7.5 - totalHeight) / 2;

      // Draw aesthetic accent line above title
      slide.addShape(pptx.shapes.RECTANGLE, {
        x: (13.333 - 1.5) / 2,
        y: yStart - 0.35,
        w: 1.5,
        h: 0.06,
        fill: { color: theme.secondary_color },
        line: { width: 0 }
      });

      // Title
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

      // Subtitle
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
    } else {
      // ── Standard Content / Column / Metric Slides Layout ──
      // Calculate dynamic header size
      const headerWidth = 11.733;
      const titleFontSize = 28;
      const subtitleFontSize = 15;

      const titleHeight = estimateTextHeight(slideData.title, titleFontSize, headerWidth);
      const subtitleHeight = slideData.subtitle
        ? estimateTextHeight(slideData.subtitle, subtitleFontSize, headerWidth)
        : 0;

      // Title
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

      // Subtitle
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
      const availableHeight = 7.5 - yContentStart - 0.7;

      const cards = slideData.content || [];
      const N = cards.length;

      if (N > 0) {
        if (slideData.layout_type === 'metric_highlight') {
          // ── Metric Highlight Layout ──
          const gap = 0.45;
          const colWidth = (11.733 - (N - 1) * gap) / N;

          for (let i = 0; i < N; i++) {
            const card = cards[i];
            const colX = 0.8 + i * (colWidth + gap);

            // Background Card
            slide.addShape(pptx.shapes.ROUNDED_RECTANGLE, {
              x: colX,
              y: yContentStart,
              w: colWidth,
              h: availableHeight,
              fill: { color: cardFillColor },
              line: { color: cardBorderColor, width: 1 },
              rectRadius: 0.05,
            });

            // Prominent Metric Heading
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

            // Metric Description Label
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
        } else {
          // ── Multi-Column / Grid Layout ──
          // Determine grid configuration:
          // If N <= 3: single row with N columns.
          // If N >= 4: 2 rows of columns to avoid horizontal cramp.
          const useGrid = N >= 4;
          const cols = useGrid ? Math.ceil(N / 2) : N;
          const rows = useGrid ? 2 : 1;

          const gapX = 0.45;
          const gapY = 0.35;
          const colWidth = useGrid
            ? (11.733 - (cols - 1) * gapX) / cols
            : (N === 1 ? 7.5 : (11.733 - (N - 1) * gapX) / N); // Center single column with custom width
          
          const startX = N === 1 ? (13.333 - colWidth) / 2 : 0.8;
          const rowHeight = (availableHeight - (rows - 1) * gapY) / rows;

          for (let i = 0; i < N; i++) {
            const card = cards[i];
            const r = useGrid ? Math.floor(i / cols) : 0;
            const c = useGrid ? i % cols : i;

            const colX = startX + c * (colWidth + gapX);
            const colY = yContentStart + r * (rowHeight + gapY);

            // Background Card Shape
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
              } else {
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
    }
  }

  // Generate buffer and return
  const buffer = await pptx.write({ outputType: 'nodebuffer' }) as Buffer;
  return buffer;
}
