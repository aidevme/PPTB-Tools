/** Color category a span of tokenized XML text belongs to, used to pick a CSS variable in {@link XmlTheme}. */
export type XmlTokenType = "text" | "tag" | "attrName" | "attrValue" | "comment" | "punctuation";

/** One colorable span produced by {@link tokenizeXml}. */
export interface XmlToken {
    type: XmlTokenType;
    value: string;
}

const TAG_OR_COMMENT_REGEX = /<!--[\s\S]*?-->|<[^>]*>/g;
const ATTRIBUTE_REGEX = /([\w:.-]+)=("[^"]*"|'[^']*')/g;

/**
 * Splits a (typically single-line) chunk of XML into color-codable tokens. This is a lightweight
 * regex pass, not a real parser — see {@link parseXmlDocument} in `xmlParser.ts` for structural
 * parsing (element nesting, line spans) used for folding and pretty-printing.
 */
export function tokenizeXml(xml: string): XmlToken[] {
    const tokens: XmlToken[] = [];
    let lastIndex = 0;
    let match: RegExpExecArray | null;

    TAG_OR_COMMENT_REGEX.lastIndex = 0;
    while ((match = TAG_OR_COMMENT_REGEX.exec(xml)) !== null) {
        if (match.index > lastIndex) {
            tokens.push({ type: "text", value: xml.slice(lastIndex, match.index) });
        }

        const raw = match[0];
        if (raw.startsWith("<!--")) {
            tokens.push({ type: "comment", value: raw });
        } else {
            tokens.push(...tokenizeTag(raw));
        }

        lastIndex = TAG_OR_COMMENT_REGEX.lastIndex;
    }

    if (lastIndex < xml.length) {
        tokens.push({ type: "text", value: xml.slice(lastIndex) });
    }

    return tokens;
}

function tokenizeTag(raw: string): XmlToken[] {
    const tokens: XmlToken[] = [];
    const isClosing = raw.startsWith("</");
    const isSelfClosing = raw.endsWith("/>");

    tokens.push({ type: "punctuation", value: isClosing ? "</" : "<" });

    const bodyStart = isClosing ? 2 : 1;
    const bodyEnd = isSelfClosing ? raw.length - 2 : raw.length - 1;
    tokens.push(...tokenizeTagBody(raw.slice(bodyStart, bodyEnd)));

    tokens.push({ type: "punctuation", value: isSelfClosing ? "/>" : ">" });
    return tokens;
}

function tokenizeTagBody(body: string): XmlToken[] {
    const tokens: XmlToken[] = [];
    let cursor = 0;

    const nameMatch = body.match(/^(\s*)([\w:.-]+)/);
    if (nameMatch) {
        const [whole, leadingWhitespace, name] = nameMatch;
        if (leadingWhitespace) tokens.push({ type: "text", value: leadingWhitespace });
        tokens.push({ type: "tag", value: name });
        cursor = whole.length;
    }

    ATTRIBUTE_REGEX.lastIndex = cursor;
    let lastIndex = cursor;
    let match: RegExpExecArray | null;
    while ((match = ATTRIBUTE_REGEX.exec(body)) !== null) {
        if (match.index > lastIndex) {
            tokens.push({ type: "text", value: body.slice(lastIndex, match.index) });
        }
        tokens.push({ type: "attrName", value: match[1] });
        tokens.push({ type: "punctuation", value: "=" });
        tokens.push({ type: "attrValue", value: match[2] });
        lastIndex = ATTRIBUTE_REGEX.lastIndex;
    }

    if (lastIndex < body.length) {
        tokens.push({ type: "text", value: body.slice(lastIndex) });
    }

    return tokens;
}
