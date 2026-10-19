// Flat-config snippet for eslint-plugin-tsdoc: merge it into the project's existing eslint.config.(js|mjs).
// This is not a complete config. Requires: eslint, @typescript-eslint/parser, eslint-plugin-tsdoc (dev dependencies).
//
// eslint-plugin-tsdoc exports a single rule, `syntax`, and no preset configs; its README documents only the legacy
// .eslintrc setup, so this follows ESLint's standard flat-config plugin pattern. TODO: verify against a future
// eslint-plugin-tsdoc README that documents flat config.

import tsParser from '@typescript-eslint/parser';
import tsdoc from 'eslint-plugin-tsdoc';

/** Add this object to the array the config exports (or to `tseslint.config(...)`). */
export const tsdocConfig = {
    files: ['**/*.{ts,tsx,mts,cts}'],
    languageOptions: { parser: tsParser },
    plugins: { tsdoc },
    rules: { 'tsdoc/syntax': 'warn' },
};

// Example of the merged result:
//
// import { tsdocConfig } from './eslint-tsdoc.snippet.mjs'; // or paste the object inline
// export default [
//     ...existingConfig,
//     tsdocConfig,
// ];
