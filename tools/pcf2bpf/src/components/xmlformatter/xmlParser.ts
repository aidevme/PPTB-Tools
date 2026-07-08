/** An XML element, as produced by {@link parseXmlDocument}. */
export interface XmlElementNode {
    kind: "element";
    /** Stable within one parse: assigned in document order, so a fresh re-parse of structurally
     * unchanged XML (e.g. after re-indenting) yields the same ids. */
    id: number;
    name: string;
    attributes: Array<{ name: string; value: string }>;
    children: XmlNode[];
    selfClosing: boolean;
    /** 1-based line number the element's opening tag starts on. */
    startLine: number;
    /** 1-based line number the element's closing tag (or self-closing tag) ends on. */
    endLine: number;
}

/** A run of non-markup text between/inside elements, as produced by {@link parseXmlDocument}. */
export interface XmlTextNode {
    kind: "text";
    value: string;
}

/** An XML comment (`<!-- ... -->`), as produced by {@link parseXmlDocument}. */
export interface XmlCommentNode {
    kind: "comment";
    value: string;
}

/** Any node in the tree returned by {@link parseXmlDocument}. */
export type XmlNode = XmlElementNode | XmlTextNode | XmlCommentNode;

interface ParserState {
    pos: number;
    line: number;
    nextId: number;
}

/**
 * Parses an XML string into a lightweight node tree annotated with line numbers, used for
 * fold-region detection and pretty-printing. Returns `null` if the input isn't well-formed enough
 * for this parser to handle — it supports elements, attributes, text, and comments only (no
 * processing instructions, CDATA, or DOCTYPE), which covers Dataverse form XML but not arbitrary
 * XML documents.
 */
export function parseXmlDocument(xml: string): XmlNode[] | null {
    const state: ParserState = { pos: 0, line: 1, nextId: 0 };
    try {
        const nodes = parseNodeList(xml, state);
        skipWhitespace(xml, state);
        if (state.pos < xml.length) return null;
        return nodes;
    } catch {
        return null;
    }
}

function countNewlines(text: string): number {
    let count = 0;
    for (let i = 0; i < text.length; i++) {
        if (text[i] === "\n") count++;
    }
    return count;
}

function consume(xml: string, state: ParserState, length: number): string {
    const chunk = xml.slice(state.pos, state.pos + length);
    state.line += countNewlines(chunk);
    state.pos += length;
    return chunk;
}

function skipWhitespace(xml: string, state: ParserState): void {
    while (state.pos < xml.length && /\s/.test(xml[state.pos])) consume(xml, state, 1);
}

function parseNodeList(xml: string, state: ParserState): XmlNode[] {
    const nodes: XmlNode[] = [];
    while (state.pos < xml.length && !xml.startsWith("</", state.pos)) {
        if (xml.startsWith("<!--", state.pos)) {
            nodes.push(parseComment(xml, state));
        } else if (xml[state.pos] === "<") {
            nodes.push(parseElement(xml, state));
        } else {
            const text = parseText(xml, state);
            if (text.value.length > 0) nodes.push(text);
        }
    }
    return nodes;
}

function parseComment(xml: string, state: ParserState): XmlCommentNode {
    const end = xml.indexOf("-->", state.pos + 4);
    if (end === -1) throw new Error("Unterminated comment");
    const value = consume(xml, state, end + 3 - state.pos);
    return { kind: "comment", value };
}

function parseText(xml: string, state: ParserState): XmlTextNode {
    const nextTag = xml.indexOf("<", state.pos);
    const end = nextTag === -1 ? xml.length : nextTag;
    const value = consume(xml, state, end - state.pos);
    return { kind: "text", value };
}

const NAME_REGEX = /[^\s/>]+/y;
const ATTR_NAME_REGEX = /[^\s=/>]+/y;

function matchAt(regex: RegExp, xml: string, pos: number): string | null {
    regex.lastIndex = pos;
    const match = regex.exec(xml);
    return match ? match[0] : null;
}

function parseElement(xml: string, state: ParserState): XmlElementNode {
    const startLine = state.line;
    consume(xml, state, 1); // '<'

    const name = matchAt(NAME_REGEX, xml, state.pos);
    if (!name) throw new Error("Expected element name");
    consume(xml, state, name.length);

    const attributes = parseAttributes(xml, state);

    if (xml.startsWith("/>", state.pos)) {
        consume(xml, state, 2);
        return { kind: "element", id: state.nextId++, name, attributes, children: [], selfClosing: true, startLine, endLine: state.line };
    }

    if (xml[state.pos] !== ">") throw new Error(`Expected '>' after <${name}`);
    consume(xml, state, 1);

    const id = state.nextId++;
    const children = parseNodeList(xml, state);

    if (!xml.startsWith(`</${name}`, state.pos)) throw new Error(`Expected closing tag for <${name}>`);
    consume(xml, state, 2 + name.length);
    skipWhitespace(xml, state);
    if (xml[state.pos] !== ">") throw new Error(`Malformed closing tag for <${name}>`);
    consume(xml, state, 1);

    return { kind: "element", id, name, attributes, children, selfClosing: false, startLine, endLine: state.line };
}

function parseAttributes(xml: string, state: ParserState): Array<{ name: string; value: string }> {
    const attributes: Array<{ name: string; value: string }> = [];
    for (;;) {
        skipWhitespace(xml, state);
        if (xml.startsWith("/>", state.pos) || xml[state.pos] === ">") break;

        const name = matchAt(ATTR_NAME_REGEX, xml, state.pos);
        if (!name) throw new Error("Expected attribute name");
        consume(xml, state, name.length);

        skipWhitespace(xml, state);
        if (xml[state.pos] !== "=") throw new Error(`Expected '=' after attribute "${name}"`);
        consume(xml, state, 1);
        skipWhitespace(xml, state);

        const quote = xml[state.pos];
        if (quote !== '"' && quote !== "'") throw new Error(`Expected quoted value for attribute "${name}"`);
        consume(xml, state, 1);
        const closeQuoteIndex = xml.indexOf(quote, state.pos);
        if (closeQuoteIndex === -1) throw new Error(`Unterminated attribute value for "${name}"`);
        const value = consume(xml, state, closeQuoteIndex - state.pos);
        consume(xml, state, 1); // closing quote

        attributes.push({ name, value });
    }
    return attributes;
}

/** Re-serializes a parsed node list with consistent indentation, discarding the original formatting. */
export function formatXml(nodes: XmlNode[], indent: string): string {
    const lines: string[] = [];
    for (const node of nodes) formatNode(node, 0, indent, lines);
    return lines.join("\n");
}

function formatNode(node: XmlNode, depth: number, indent: string, lines: string[]): void {
    const pad = indent.repeat(depth);

    if (node.kind === "text") {
        const trimmed = node.value.trim();
        if (trimmed) lines.push(pad + trimmed);
        return;
    }

    if (node.kind === "comment") {
        lines.push(pad + node.value);
        return;
    }

    const attrs = node.attributes.map((a) => ` ${a.name}="${a.value}"`).join("");

    if (node.selfClosing) {
        lines.push(`${pad}<${node.name}${attrs} />`);
        return;
    }

    const meaningfulChildren = node.children.filter((c) => !(c.kind === "text" && c.value.trim() === ""));

    if (meaningfulChildren.length === 0) {
        lines.push(`${pad}<${node.name}${attrs}></${node.name}>`);
        return;
    }

    if (meaningfulChildren.length === 1 && meaningfulChildren[0].kind === "text") {
        lines.push(`${pad}<${node.name}${attrs}>${meaningfulChildren[0].value.trim()}</${node.name}>`);
        return;
    }

    lines.push(`${pad}<${node.name}${attrs}>`);
    for (const child of meaningfulChildren) formatNode(child, depth + 1, indent, lines);
    lines.push(`${pad}</${node.name}>`);
}

/** A collapsible element span produced by {@link collectFoldRegions}, keyed by the element's `id`. */
export interface XmlFoldRegion {
    id: number;
    name: string;
    startLine: number;
    endLine: number;
}

/** Collects every element that spans more than one line — the candidates for fold chevrons. */
export function collectFoldRegions(nodes: XmlNode[]): XmlFoldRegion[] {
    const regions: XmlFoldRegion[] = [];
    const visit = (list: XmlNode[]) => {
        for (const node of list) {
            if (node.kind !== "element") continue;
            if (!node.selfClosing && node.endLine > node.startLine) {
                regions.push({ id: node.id, name: node.name, startLine: node.startLine, endLine: node.endLine });
            }
            visit(node.children);
        }
    };
    visit(nodes);
    return regions;
}
