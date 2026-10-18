#!/usr/bin/env node
/**
 * Checks TSDoc syntax in TypeScript files with ESLint's `tsdoc/syntax` rule (eslint-plugin-tsdoc).
 *
 * Usage:
 *   node check-tsdoc.mjs <file ...>       check the given files
 *   node check-tsdoc.mjs --changed        check the TypeScript files `git diff --name-only HEAD` lists
 *   add --json                            print the findings as JSON instead of a table
 *
 * ESLint, `@typescript-eslint/parser` and `eslint-plugin-tsdoc` are loaded from each file's own project (the
 * nearest folder with a package.json), and only `tsdoc/syntax` runs, with an inline flat config, so the project's
 * own ESLint config doesn't need to enable the rule. Nothing is installed or written.
 *
 * Exit codes: 0 no findings, 1 findings, 2 the check can't run (a package is missing, ESLint is older than 8.57,
 * or there were no files to check).
 */
import { execFileSync } from 'node:child_process';
import { existsSync } from 'node:fs';
import { createRequire } from 'node:module';
import path from 'node:path';
import { pathToFileURL } from 'node:url';

const TS_FILE = /\.(ts|tsx|mts|cts)$/i;
// Generated output the skill never edits; `.d.ts` files are usually emitted.
const GENERATED = /(^|[\\/])(generated|dist|build)[\\/]|\.d\.(ts|mts|cts)$/i;
const REQUIRED = ['eslint', '@typescript-eslint/parser', 'eslint-plugin-tsdoc'];

function fail(message) {
    console.error(message);
    process.exit(2);
}

function changedFiles() {
    try {
        return execFileSync('git', ['diff', '--name-only', 'HEAD'], { encoding: 'utf8' }).split(/\r?\n/).filter(Boolean);
    } catch {
        fail('Could not run `git diff --name-only HEAD`; pass the files instead.');
    }
}

/** The nearest folder at or above `dir` that has a package.json, or undefined. */
function projectRoot(dir) {
    for (let current = dir; ; current = path.dirname(current)) {
        if (existsSync(path.join(current, 'package.json'))) return current;
        if (path.dirname(current) === current) return undefined;
    }
}

async function load(require, name) {
    const resolved = require.resolve(name);
    const module = await import(pathToFileURL(resolved).href);
    return module.default ?? module;
}

/** Loads ESLint, the parser and the plugin from `root`, or explains what's missing. */
async function toolsFor(root) {
    const require = createRequire(path.join(root, 'package.json'));
    const missing = REQUIRED.filter((name) => {
        try {
            require.resolve(name);
            return false;
        } catch {
            return true;
        }
    });
    if (missing.length > 0) {
        return { problem: `missing ${missing.join(', ')} (see references/setup.md; install only with the user's approval)` };
    }
    const eslint = await load(require, 'eslint');
    if (typeof eslint.loadESLint !== 'function') {
        return { problem: 'ESLint 8.57 or later is required (loadESLint API)' };
    }
    const ESLint = await eslint.loadESLint({ useFlatConfig: true });
    const parser = await load(require, '@typescript-eslint/parser');
    const tsdoc = await load(require, 'eslint-plugin-tsdoc');
    return { ESLint, parser, tsdoc };
}

async function main(argv) {
    const json = argv.includes('--json');
    const args = argv.filter((a) => a !== '--json');
    const requested = args.includes('--changed') ? changedFiles() : args.filter((a) => !a.startsWith('--'));
    if (requested.length === 0) fail('Usage: node check-tsdoc.mjs <file ...> | --changed [--json]');

    const files = [];
    const skipped = [];
    for (const file of requested) {
        const absolute = path.resolve(file);
        if (!existsSync(absolute)) skipped.push({ file, reason: 'not found' });
        else if (!TS_FILE.test(file)) skipped.push({ file, reason: 'not a TypeScript file' });
        else if (GENERATED.test(file)) skipped.push({ file, reason: 'generated file' });
        else files.push(absolute);
    }
    if (files.length === 0) fail(`No TypeScript files to check.${skipped.length ? ` Skipped: ${skipped.map((s) => `${s.file} (${s.reason})`).join(', ')}` : ''}`);

    // Group by project, since each project has its own node_modules.
    const byProject = new Map();
    for (const file of files) {
        const root = projectRoot(path.dirname(file));
        if (!root) fail(`No package.json above ${file}.`);
        byProject.set(root, [...(byProject.get(root) ?? []), file]);
    }

    const findings = [];
    const unavailable = [];
    for (const [root, projectFiles] of byProject) {
        const tools = await toolsFor(root);
        if (tools.problem) {
            unavailable.push({ project: root, problem: tools.problem });
            continue;
        }
        const linter = new tools.ESLint({
            cwd: root,
            overrideConfigFile: true,
            overrideConfig: [
                {
                    files: ['**/*.{ts,tsx,mts,cts}'],
                    languageOptions: { parser: tools.parser },
                    // Only the TSDoc rule runs, so `eslint-disable` comments for other rules would be reported as
                    // unknown or unused rules; ignore inline config instead.
                    linterOptions: { noInlineConfig: true, reportUnusedDisableDirectives: 'off' },
                    plugins: { tsdoc: tools.tsdoc },
                    rules: { 'tsdoc/syntax': 'warn' },
                },
            ],
        });
        for (const result of await linter.lintFiles(projectFiles)) {
            // Keep TSDoc findings and parse errors; drop ESLint's notes about the ignored inline config.
            for (const message of result.messages.filter((m) => m.ruleId === 'tsdoc/syntax' || m.fatal)) {
                findings.push({
                    file: path.relative(process.cwd(), result.filePath),
                    line: message.line,
                    column: message.column,
                    id: message.messageId ?? message.ruleId ?? (message.fatal ? 'parse-error' : ''),
                    message: message.message,
                });
            }
        }
    }

    if (json) {
        console.log(JSON.stringify({ findings, unavailable, skipped }, null, 2));
    } else {
        for (const f of findings) console.log(`${f.file}:${f.line}:${f.column}  ${f.id}  ${f.message}`);
        for (const u of unavailable) console.log(`check unavailable for ${u.project}: ${u.problem}`);
        for (const s of skipped) console.log(`skipped ${s.file} (${s.reason})`);
        const checked = files.length - unavailable.reduce((n, u) => n + byProject.get(u.project).length, 0);
        console.log(`\n${findings.length} finding(s) in ${checked} checked file(s).`);
    }
    if (unavailable.length > 0) process.exit(2);
    process.exit(findings.length > 0 ? 1 : 0);
}

main(process.argv.slice(2)).catch((error) => fail(`check-tsdoc failed: ${error.message}`));
