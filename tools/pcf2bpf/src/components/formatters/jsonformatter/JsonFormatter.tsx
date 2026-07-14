import { useCallback, useMemo, useState, type CSSProperties } from "react";
import { Button, mergeClasses, Tooltip } from "@fluentui/react-components";
import { Checkmark20Regular, Copy20Regular } from "@fluentui/react-icons";
import { useJsonFormatterStyles } from "../../../styles";
import { tokenizeJson, type JsonToken } from "./jsonTokenizer";
import { resolveJsonTheme, type JsonTheme, type JsonThemeName } from "./jsonTheme";

/** Props for {@link JsonFormatter}. */
export interface IJsonFormatterProps {
    /** The value to display: a raw JSON string (reformatted via `JSON.parse`/`JSON.stringify`) or
     * any JSON-serializable value (stringified directly). A string that fails to parse as JSON is
     * shown as-is, with no syntax highlighting. */
    value: unknown;
    /** Built-in palette name, or a fully custom palette. @default "dark" */
    theme?: JsonThemeName | JsonTheme;
    /** Indent unit used when beautifying. @default "  " (two spaces) */
    indent?: string;
    /** Show a line-number gutter. @default false */
    showLineNumbers?: boolean;
    /** Show a floating copy-to-clipboard button in the top-right corner. @default true */
    showCopyButton?: boolean;
    /** Message shown in place of the content when `value` is empty. */
    placeholder?: string;
    /** Additional class applied to the root element. */
    className?: string;
    /** Additional inline styles applied to the root element, merged after the theme's CSS custom properties. */
    style?: CSSProperties;
}

/** Beautifies `value` into pretty-printed JSON text. Returns `ok: false` (text shown as-is, no
 * highlighting) when `value` is a string that isn't valid JSON. */
function beautify(value: unknown, indent: string): { text: string; ok: boolean } {
    if (value === undefined || value === "") return { text: "", ok: true };

    if (typeof value === "string") {
        try {
            return { text: JSON.stringify(JSON.parse(value), null, indent), ok: true };
        } catch {
            return { text: value, ok: false };
        }
    }

    try {
        return { text: JSON.stringify(value, null, indent), ok: true };
    } catch {
        return { text: String(value), ok: false };
    }
}

/**
 * Read-only, syntax-highlighted display of a beautified JSON value: keys, strings, numbers,
 * booleans, and `null` colored separately, with an optional line-number gutter and a floating copy
 * button.
 *
 * @remarks
 * Deliberately smaller in scope than `XmlFormatter` — no folding, diffing, or maximize toggle, since
 * this exists to show a single beautified JSON blob (e.g. a `customcontrol.clientjson` value) rather
 * than a large document users need to navigate or compare.
 */
export function JsonFormatter({
    value,
    theme,
    indent = "  ",
    showLineNumbers = false,
    showCopyButton = true,
    placeholder,
    className,
    style,
}: IJsonFormatterProps) {
    const styles = useJsonFormatterStyles();
    const resolvedTheme = resolveJsonTheme(theme);

    const { text: displayText, ok: isValidJson } = useMemo(() => beautify(value, indent), [value, indent]);

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
        // Custom properties consumed by useJsonFormatterStyles' classes.
        ["--json-background" as string]: resolvedTheme.background,
        ["--json-text" as string]: resolvedTheme.text,
        ["--json-key" as string]: resolvedTheme.key,
        ["--json-string" as string]: resolvedTheme.string,
        ["--json-number" as string]: resolvedTheme.number,
        ["--json-boolean" as string]: resolvedTheme.boolean,
        ["--json-null" as string]: resolvedTheme.nullLiteral,
        ["--json-punctuation" as string]: resolvedTheme.punctuation,
        ["--json-placeholder" as string]: resolvedTheme.placeholder,
        ["--json-line-number" as string]: resolvedTheme.lineNumber,
        ["--json-border" as string]: resolvedTheme.border,
        ["--json-highlight" as string]: resolvedTheme.highlight,
        ...style,
    };

    if (!displayText) {
        return (
            <div className={mergeClasses(styles.root, className)} style={cssVars}>
                <span className={styles.placeholder}>{placeholder ?? ""}</span>
            </div>
        );
    }

    const lines = displayText.split("\n");

    return (
        <div className={mergeClasses(styles.root, className)} style={cssVars}>
            {showCopyButton && (
                <div className={styles.cornerActionsAnchor}>
                    <div className={styles.cornerActions}>
                        <Tooltip content={copied ? "Copied" : "Copy"} relationship="label">
                            <Button
                                appearance="subtle"
                                size="small"
                                icon={copied ? <Checkmark20Regular /> : <Copy20Regular />}
                                onClick={handleCopy}
                            />
                        </Tooltip>
                    </div>
                </div>
            )}
            {lines.map((line, index) => (
                <div key={index} className={styles.lineRow}>
                    {showLineNumbers && <span className={styles.lineNumber}>{index + 1}</span>}
                    <span className={styles.lineContent}>
                        {isValidJson ? renderTokens(tokenizeJson(line), styles) : line}
                    </span>
                </div>
            ))}
        </div>
    );
}

function renderTokens(tokens: JsonToken[], styles: Record<string, string>) {
    return tokens.map((token, index) => (
        <span key={index} className={styles[token.type]}>
            {token.value}
        </span>
    ));
}
