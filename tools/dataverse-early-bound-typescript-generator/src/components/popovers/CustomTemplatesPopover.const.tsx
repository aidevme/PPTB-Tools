import { BracesRegular, DatabaseRegular, FlashRegular, MathFormulaRegular, NumberSymbolRegular, TableRegular } from '@fluentui/react-icons';
import type { CustomTemplateKind } from '../../core';

/**
 * How Custom Templates shows each kind: its label, icon, output location, and info label (the files and the
 * dataverse-gen template it covers).
 */
export const CUSTOM_TEMPLATE_LABELS: Record<CustomTemplateKind, { label: string; icon: JSX.Element; location: string; info: JSX.Element }> = {
    actions: {
        label: 'Actions',
        icon: <FlashRegular />,
        location: 'actions/',
        info: (
            <>
                A file per selected action in <code>actions/</code>, with its request type and metadata. dataverse-gen's template is{' '}
                <code>action.ejs</code>.
            </>
        ),
    },
    complexTypes: {
        label: 'Complex Types',
        icon: <BracesRegular />,
        location: 'complextypes/',
        info: (
            <>
                A file per complex type the selected actions and functions use (their response types) in <code>complextypes/</code>.
                dataverse-gen's template is <code>complextype.ejs</code>.
            </>
        ),
    },
    entities: {
        label: 'Entities',
        icon: <TableRegular />,
        location: 'entities/',
        info: (
            <>
                A file per selected table in <code>entities/</code>: attribute constants, metadata, and the early-bound interface and form
                context when they're on. dataverse-gen's template is <code>entity.ejs</code>.
            </>
        ),
    },
    enums: {
        label: 'Enums',
        icon: <NumberSymbolRegular />,
        location: 'enums/',
        info: (
            <>
                A file per choice the selected tables use in <code>enums/</code>. dataverse-gen's template is <code>enum.ejs</code>. Separate
                from the Custom enum template switch, which renames duplicate members.
            </>
        ),
    },
    functions: {
        label: 'Functions',
        icon: <MathFormulaRegular />,
        location: 'functions/',
        info: (
            <>
                A file per selected function in <code>functions/</code>, with its request type and metadata. dataverse-gen's template is{' '}
                <code>function.ejs</code>.
            </>
        ),
    },
    metadata: {
        label: 'Metadata',
        icon: <DatabaseRegular />,
        location: 'metadata.ts',
        info: (
            <>
                <code>metadata.ts</code>, the metadata cache dataverse-ify reads for every generated table, action and function.
                dataverse-gen's template is <code>metadata.ejs</code>.
            </>
        ),
    },
};
