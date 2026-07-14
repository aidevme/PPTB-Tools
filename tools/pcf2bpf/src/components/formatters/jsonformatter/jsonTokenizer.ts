/** Color category a span of tokenized JSON text belongs to, used to pick a CSS variable in {@link JsonTheme}. */
export type JsonTokenType = "text" | "key" | "string" | "number" | "boolean" | "null" | "punctuation";

/** One colorable span produced by {@link tokenizeJson}. */
export interface JsonToken {
    type: JsonTokenType;
    value: string;
}

const TOKEN_REGEX = /"(?:\\.|[^"\\])*"|-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?|true|false|null|[{}[\],:]|\s+/g;

/**
 * Splits a (typically single-line) chunk of pretty-printed JSON into color-codable tokens. A
 * lightweight regex pass, not a real parser — relies on the input already being well-formed JSON
 * text (e.g. via `JSON.stringify`), so it doesn't need to track nesting or line spans the way
 * `xmlTokenizer.ts` does for XML's foldable structure.
 *
 * String tokens immediately followed by `:` (an object key) are classified as `"key"` rather than
 * `"string"`, matching how editors color JSON property names differently from string values.
 */
export function tokenizeJson(json: string): JsonToken[] {
    const tokens: JsonToken[] = [];
    let lastIndex = 0;
    let match: RegExpExecArray | null;

    TOKEN_REGEX.lastIndex = 0;
    while ((match = TOKEN_REGEX.exec(json)) !== null) {
        if (match.index > lastIndex) {
            tokens.push({ type: "text", value: json.slice(lastIndex, match.index) });
        }
        tokens.push(classify(match[0]));
        lastIndex = TOKEN_REGEX.lastIndex;
    }

    if (lastIndex < json.length) {
        tokens.push({ type: "text", value: json.slice(lastIndex) });
    }

    return reclassifyKeys(tokens);
}

function classify(raw: string): JsonToken {
    if (raw.startsWith('"')) return { type: "string", value: raw };
    if (raw === "true" || raw === "false") return { type: "boolean", value: raw };
    if (raw === "null") return { type: "null", value: raw };
    if (/^[{}[\],:]$/.test(raw)) return { type: "punctuation", value: raw };
    if (/^\s+$/.test(raw)) return { type: "text", value: raw };
    return { type: "number", value: raw };
}

function reclassifyKeys(tokens: JsonToken[]): JsonToken[] {
    return tokens.map((token, index) => {
        if (token.type !== "string") return token;
        const next = tokens.slice(index + 1).find((t) => t.type !== "text");
        return next?.type === "punctuation" && next.value === ":" ? { type: "key" as const, value: token.value } : token;
    });
}
