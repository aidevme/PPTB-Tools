import { useCallback, useMemo, useState, type CSSProperties } from "react";
import { Button, mergeClasses, Tooltip } from "@fluentui/react-components";
import { Checkmark20Regular, ChevronDown12Regular, ChevronRight12Regular, Copy20Regular } from "@fluentui/react-icons";
import { useXmlFormatterStyles } from "../../styles";
import { tokenizeXml, type XmlToken } from "./xmlTokenizer";
import { collectFoldRegions, formatXml, parseXmlDocument, type XmlFoldRegion } from "./xmlParser";
import { resolveXmlTheme, type XmlTheme, type XmlThemeName } from "./xmlTheme";

export interface XmlFormatterProps {
    /** Raw XML to display. */
    xml: string;
    /** Built-in palette name, or a fully custom palette. @default "dark" */
    theme?: XmlThemeName | XmlTheme;
    /** Show a line-number gutter. @default true */
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
    className?: string;
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
 */
export function XmlFormatter({
    xml,
    theme,
    showLineNumbers = true,
    collapsible = true,
    prettyPrint = false,
    indent = "  ",
    showCopyButton = true,
    initiallyCollapsedTags,
    placeholder,
    className,
    style,
}: XmlFormatterProps) {
    const styles = useXmlFormatterStyles();
    const resolvedTheme = resolveXmlTheme(theme);

    const parsedOriginal = useMemo(() => parseXmlDocument(xml), [xml]);

    const displayText = useMemo(() => {
        if (prettyPrint && parsedOriginal) return formatXml(parsedOriginal, indent);
        return xml;
    }, [xml, prettyPrint, indent, parsedOriginal]);

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
        ...style,
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
                    <div key={lineIndex} className={styles.lineRow}>
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
                            {renderTokens(headerTokens, styles)}
                            <span className={styles.punctuation}> … </span>
                            {renderTokens(tokenizeXml(closingLine), styles)}
                        </span>
                    </div>,
                );
                lineIndex = region.endLine;
                continue;
            }

            const tokens = tokenizeXml(lines[lineIndex]);
            rows.push(
                <div key={lineIndex} className={styles.lineRow}>
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
                    <span className={styles.lineContent}>{renderTokens(tokens, styles)}</span>
                </div>,
            );
            lineIndex++;
        }
    } else {
        // Parsing failed: fall back to a single colorized block, no line numbers or folding.
        rows.push(
            <div key="fallback" className={styles.lineRow}>
                <span className={styles.lineContent}>{renderTokens(tokenizeXml(displayText), styles)}</span>
            </div>,
        );
    }

    return (
        <div className={mergeClasses(styles.root, className)} style={cssVars}>
            {showCopyButton && (
                <Tooltip content={copied ? "Copied" : "Copy"} relationship="label">
                    <Button
                        className={styles.copyButton}
                        appearance="subtle"
                        size="small"
                        icon={copied ? <Checkmark20Regular /> : <Copy20Regular />}
                        onClick={handleCopy}
                    />
                </Tooltip>
            )}
            {rows}
        </div>
    );
}

function renderTokens(tokens: XmlToken[], styles: Record<string, string>) {
    return tokens.map((token, index) => (
        <span key={index} className={styles[token.type]}>
            {token.value}
        </span>
    ));
}
