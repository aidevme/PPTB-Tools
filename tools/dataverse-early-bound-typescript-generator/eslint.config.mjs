// ESLint is used here only to check TSDoc comment syntax (`npm run lint:tsdoc`); there's no general lint setup.
import tsParser from '@typescript-eslint/parser';
import tsdoc from 'eslint-plugin-tsdoc';

// Two lines carry `eslint-disable-line react-hooks/exhaustive-deps` from an earlier lint setup. Registering the rule
// name as a no-op keeps those comments valid without installing eslint-plugin-react-hooks; since this config runs
// only the TSDoc rule, disable comments for other rules aren't reported as unused.
const reactHooksPlaceholder = { rules: { 'exhaustive-deps': { create: () => ({}) } } };

export default [
    {
        files: ['src/**/*.{ts,tsx}'],
        languageOptions: { parser: tsParser },
        linterOptions: { reportUnusedDisableDirectives: 'off' },
        plugins: { tsdoc, 'react-hooks': reactHooksPlaceholder },
        rules: { 'tsdoc/syntax': 'warn' },
    },
];
