import { useCallback, useMemo, useState, type CSSProperties } from "react";
import { Button, mergeClasses, ToggleButton, Tooltip } from "@fluentui/react-components";
import {
    Checkmark20Regular,
    ChevronDown12Regular,
    ChevronRight12Regular,
    Copy20Regular,
    FullScreenMaximize20Regular,
    FullScreenMinimize20Regular,
} from "@fluentui/react-icons";
import { useXmlFormatterStyles } from "../../../styles";
import { tokenizeXml, type XmlToken } from "./xmlTokenizer";
import { collectFoldRegions, formatXml, parseXmlDocument, type XmlFoldRegion } from "./xmlParser";
import { resolveXmlTheme, type XmlTheme, type XmlThemeName } from "./xmlTheme";
import { diffLines, type DiffLineStatus } from "./xmlDiff";

/** Props for {@link XmlFormatter}. */
export interface IXmlFormatterProps {
    /** Raw XML to display. */
    xml: string;
    /** Built-in palette name, or a fully custom palette. @default "dark" */
    theme?: XmlThemeName | XmlTheme;
    /** Show a line-number gutter. @default false */
    showLineNumbers?: boolean;
    /** Show fold chevrons on elements whose content spans more than one line. @default true */
    collapsible?: boolean;
    /** Re-indent the input via an internal structural formatter instead of showing it as-is. @default false */
    prettyPrint?: boolean;
    /** Indent unit used when `prettyPrint` is on. @default "  " (two spaces) */
    indent?: string;
    /** Show a floating copy-to-clipboard button in the top-right corner. @default true */
    showCopyButton?: boolean;
    /** Tag names (not paths) that should start folded on first render. */
    initiallyCollapsedTags?: string[];
    /** Message shown in place of the content when `xml` is empty. */
    placeholder?: string;
    /** When non-empty, every case-insensitive occurrence of this substring is highlighted. */
    highlightQuery?: string;
    /** The other side's raw XML to diff this instance's lines against. Omit to disable diffing. */
    compareXml?: string;
    /** Whether lines that differ from `compareXml` represent additions (green) or removals (red). */
    diffHighlight?: "added" | "removed";
    /** Whether the parent layout is currently showing this instance maximized. Controls the
     * maximize toggle button's pressed state and icon. */
    maximized?: boolean;
    /** Called when the user toggles the maximize button, with the new desired state. Omit to hide
     * the button — this component doesn't control its own container's size, so without a parent
     * to act on it there's nothing the button could meaningfully do. */
    onMaximizedChange?: (maximized: boolean) => void;
    /** Additional class applied to the root element. */
    className?: string;
    /** Additional inline styles applied to the root element, merged after the theme's CSS custom properties. */
    style?: CSSProperties;
}

/**
 * Read-only, syntax-highlighted display of an XML string: tags, attribute names/values, and
 * comments colored separately, with an optional line-number gutter, per-element fold/collapse,
 * structural re-indenting, and a floating copy button.
 *
 * @remarks
 * Folding and pretty-printing rely on a small structural parser ({@link parseXmlDocument}) that
 * only understands elements, attributes, text, and comments (no processing instructions, CDATA,
 * or DOCTYPE) — sufficient for Dataverse form XML but not arbitrary XML. If parsing fails, this
 * falls back to coloring the raw text as a single block with no line numbers or folding, so
 * malformed input still renders something instead of crashing. Kept dependency-free deliberately:
 * PPTB bundles this tool to a single IIFE, so a full syntax-highlighting library would add real
 * weight for what's otherwise a small amount of text.
 *
 * `compareXml`/`diffHighlight` add a GitHub-style diff mode: lines with no counterpart on the
 * other side (per a line-level LCS diff, see {@link diffLines}) get a full-row green or red
 * background. Each instance only knows its own role (`"added"` or `"removed"`) — pass the two
 * instances' `xml` to each other's `compareXml` to diff a before/after pair.
 *
 * `maximized`/`onMaximizedChange` make the maximize button a controlled toggle: this component has
 * no notion of its own container size, so it only reports the user's intent — the parent decides
 * what "maximized" actually means (e.g. hiding a sibling column) and feeds `maximized` back in.
 */
export function XmlFormatter({
    xml,
    theme,
    showLineNumbers = false,
    collapsible = true,
    prettyPrint = false,
    indent = "  ",
    showCopyButton = true,
    initiallyCollapsedTags,
    placeholder,
    highlightQuery = "",
    compareXml,
    diffHighlight,
    maximized,
    onMaximizedChange,
    className,
    style,
}: IXmlFormatterProps) {
    const styles = useXmlFormatterStyles();
    const resolvedTheme = resolveXmlTheme(theme);

    const parsedOriginal = useMemo(() => parseXmlDocument(xml), [xml]);

    const displayText = useMemo(() => {
        if (prettyPrint && parsedOriginal) return formatXml(parsedOriginal, indent);
        return xml;
    }, [xml, prettyPrint, indent, parsedOriginal]);

    // Formatted the same way as `displayText` so the two sides' lines line up 1:1 for diffing,
    // regardless of how the source XML happened to be indented originally.
    const compareDisplayText = useMemo(() => {
        if (!compareXml) return null;
        const compareParsed = parseXmlDocument(compareXml);
        if (prettyPrint && compareParsed) return formatXml(compareParsed, indent);
        return compareXml;
    }, [compareXml, prettyPrint, indent]);

    const lineDiffStatuses = useMemo<DiffLineStatus[] | null>(() => {
        if (!diffHighlight || compareDisplayText === null) return null;
        return diffLines(displayText.split("\n"), compareDisplayText.split("\n")).a;
    }, [diffHighlight, displayText, compareDisplayText]);

    // Re-parse after pretty-printing so fold regions point at lines in `displayText`, not `xml`.
    // Element ids are still comparable across the two parses since both assign them in document
    // order and re-indenting never reorders elements.
    const parsedForDisplay = useMemo(() => {
        if (prettyPrint && parsedOriginal) return parseXmlDocument(displayText);
        return parsedOriginal;
    }, [displayText, prettyPrint, parsedOriginal]);

    const foldRegions = useMemo(
        () => (collapsible && parsedForDisplay ? collectFoldRegions(parsedForDisplay) : []),
        [collapsible, parsedForDisplay],
    );

    const foldByStartLine = useMemo(() => {
        const map = new Map<number, XmlFoldRegion>();
        for (const region of foldRegions) map.set(region.startLine, region);
        return map;
    }, [foldRegions]);

    const [collapsedIds, setCollapsedIds] = useState<Set<number>>(() => {
        if (!collapsible || !initiallyCollapsedTags?.length || !parsedOriginal) return new Set();
        const initialRegions = collectFoldRegions(parsedOriginal);
        return new Set(initialRegions.filter((r) => initiallyCollapsedTags.includes(r.name)).map((r) => r.id));
    });

    const toggleFold = useCallback((id: number) => {
        setCollapsedIds((prev) => {
            const next = new Set(prev);
            if (next.has(id)) next.delete(id);
            else next.add(id);
            return next;
        });
    }, []);

    const [copied, setCopied] = useState(false);
    const handleCopy = useCallback(() => {
        void (async () => {
            try {
                await window.toolboxAPI.utils.copyToClipboard(displayText);
                setCopied(true);
                setTimeout(() => setCopied(false), 1500);
            } catch (error) {
                console.error("Copy error:", error);
            }
        })();
    }, [displayText]);

    const cssVars: CSSProperties = {
        // Custom properties consumed by useXmlFormatterStyles' classes.
        ["--xml-background" as string]: resolvedTheme.background,
        ["--xml-text" as string]: resolvedTheme.text,
        ["--xml-tag" as string]: resolvedTheme.tag,
        ["--xml-attr-name" as string]: resolvedTheme.attrName,
        ["--xml-attr-value" as string]: resolvedTheme.attrValue,
        ["--xml-comment" as string]: resolvedTheme.comment,
        ["--xml-punctuation" as string]: resolvedTheme.punctuation,
        ["--xml-placeholder" as string]: resolvedTheme.placeholder,
        ["--xml-line-number" as string]: resolvedTheme.lineNumber,
        ["--xml-border" as string]: resolvedTheme.border,
        ["--xml-highlight" as string]: resolvedTheme.highlight,
        ["--xml-diff-added" as string]: resolvedTheme.diffAddedBackground,
        ["--xml-diff-removed" as string]: resolvedTheme.diffRemovedBackground,
        ...style,
    };

    const diffRowClass = diffHighlight === "added" ? styles.lineRowAdded : styles.lineRowRemoved;
    // `endIdxExclusive` lets a collapsed region's summary row pick up the highlight if any line it
    // hides changed, not just its (always-visible) opening tag.
    const diffClassForLines = (startIdx: number, endIdxExclusive: number): string | undefined => {
        if (!lineDiffStatuses) return undefined;
        for (let i = startIdx; i < endIdxExclusive; i++) {
            if (lineDiffStatuses[i] === "changed") return diffRowClass;
        }
        return undefined;
    };

    if (!xml) {
        return (
            <div className={mergeClasses(styles.root, className)} style={cssVars}>
                <span className={styles.placeholder}>{placeholder ?? ""}</span>
            </div>
        );
    }

    const rows: React.ReactNode[] = [];

    if (parsedForDisplay) {
        const lines = displayText.split("\n");
        let displayLineNumber = 0;
        let lineIndex = 0;

        while (lineIndex < lines.length) {
            const lineNumber1Based = lineIndex + 1;
            const region = foldByStartLine.get(lineNumber1Based);
            displayLineNumber++;

            if (region && collapsedIds.has(region.id)) {
                const headerTokens = tokenizeXml(lines[lineIndex]);
                const closingLine = lines[region.endLine - 1]?.trim() ?? `</${region.name}>`;
                rows.push(
                    <div key={lineIndex} className={mergeClasses(styles.lineRow, diffClassForLines(lineIndex, region.endLine))}>
                        {showLineNumbers && <span className={styles.lineNumber}>{displayLineNumber}</span>}
                        <button
                            type="button"
                            className={styles.chevron}
                            onClick={() => toggleFold(region.id)}
                            aria-label={`Expand <${region.name}>`}
                        >
                            <ChevronRight12Regular />
                        </button>
                        <span className={styles.lineContent}>
                            {renderTokens(headerTokens, styles, highlightQuery)}
                            <span className={styles.punctuation}> … </span>
                            {renderTokens(tokenizeXml(closingLine), styles, highlightQuery)}
                        </span>
                    </div>,
                );
                lineIndex = region.endLine;
                continue;
            }

            const tokens = tokenizeXml(lines[lineIndex]);
            rows.push(
                <div key={lineIndex} className={mergeClasses(styles.lineRow, diffClassForLines(lineIndex, lineIndex + 1))}>
                    {showLineNumbers && <span className={styles.lineNumber}>{displayLineNumber}</span>}
                    {collapsible ? (
                        region ? (
                            <button
                                type="button"
                                className={styles.chevron}
                                onClick={() => toggleFold(region.id)}
                                aria-label={`Collapse <${region.name}>`}
                            >
                                <ChevronDown12Regular />
                            </button>
                        ) : (
                            <span className={styles.chevronPlaceholder} />
                        )
                    ) : null}
                    <span className={styles.lineContent}>{renderTokens(tokens, styles, highlightQuery)}</span>
                </div>,
            );
            lineIndex++;
        }
    } else {
        // Parsing failed: fall back to a single colorized block, no line numbers or folding.
        rows.push(
            <div key="fallback" className={styles.lineRow}>
                <span className={styles.lineContent}>{renderTokens(tokenizeXml(displayText), styles, highlightQuery)}</span>
            </div>,
        );
    }

    return (
        <div className={mergeClasses(styles.root, className)} style={cssVars}>
            <div className={styles.cornerActionsAnchor}>
                <div className={styles.cornerActions}>
                    {showCopyButton && (
                        <Tooltip content={copied ? "Copied" : "Copy"} relationship="label">
                            <Button
                                appearance="subtle"
                                size="small"
                                icon={copied ? <Checkmark20Regular /> : <Copy20Regular />}
                                onClick={handleCopy}
                            />
                        </Tooltip>
                    )}
                    {onMaximizedChange && (
                        <Tooltip content={maximized ? "Restore" : "Maximize"} relationship="label">
                            <ToggleButton
                                appearance="subtle"
                                size="small"
                                checked={maximized}
                                icon={maximized ? <FullScreenMinimize20Regular /> : <FullScreenMaximize20Regular />}
                                onClick={() => onMaximizedChange(!maximized)}
                            />
                        </Tooltip>
                    )}
                </div>
            </div>
            {rows}
        </div>
    );
}

function splitByQuery(text: string, query: string): Array<{ text: string; matched: boolean }> {
    if (!query) return [{ text, matched: false }];
    const lowerText = text.toLowerCase();
    const lowerQuery = query.toLowerCase();
    const segments: Array<{ text: string; matched: boolean }> = [];
    let cursor = 0;
    let index = lowerText.indexOf(lowerQuery, cursor);
    while (index !== -1) {
        if (index > cursor) segments.push({ text: text.slice(cursor, index), matched: false });
        segments.push({ text: text.slice(index, index + query.length), matched: true });
        cursor = index + query.length;
        index = lowerText.indexOf(lowerQuery, cursor);
    }
    if (cursor < text.length) segments.push({ text: text.slice(cursor), matched: false });
    return segments;
}

function renderTokens(tokens: XmlToken[], styles: Record<string, string>, query: string) {
    return tokens.map((token, tokenIndex) => (
        <span key={tokenIndex} className={styles[token.type]}>
            {splitByQuery(token.value, query).map((segment, segIndex) =>
                segment.matched ? (
                    <mark key={segIndex} className={styles.highlight}>
                        {segment.text}
                    </mark>
                ) : (
                    segment.text
                ),
            )}
        </span>
    ));
}
