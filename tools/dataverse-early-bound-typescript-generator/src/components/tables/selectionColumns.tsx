/**
 * The Select card's table columns, with the explanations shown in their header tooltips, and the badge colour per
 * table type. Data only: `SelectionCard` renders them.
 */
import type { ReactNode } from 'react';
import type { BadgeProps } from '@fluentui/react-components';
import type { TableType } from '../../types';

/** A column header: its label and the explanation shown in its tooltip. */
export interface SelectionColumn {
    /** The header text; also the header cell's React key, so unique within a tab. */
    label: string;
    /** The explanation shown in the header's tooltip. */
    help: ReactNode;
}

/** Columns of the Tables tab. */
export const ENTITY_COLUMNS: SelectionColumn[] = [
    {
        label: 'Display Name',
        help: <><strong>Display Name:</strong> the table's name as shown in Power Apps, in the user's language. Click to sort by display name.</>,
    },
    {
        label: 'Logical Name',
        help: <><strong>Logical Name:</strong> the lowercase name used in the Web API and stored in .dataverse-gen.json. Generated file names are based on it. Click to sort by logical name.</>,
    },
    {
        label: 'Schema Name',
        help: <><strong>Schema Name:</strong> the PascalCase name the generated interface and metadata constants are named after. Click to sort by schema name.</>,
    },
    {
        label: 'Description',
        help: <><strong>Description:</strong> the table's description from its metadata; hover over a description to read all of it. Tables without one are listed last. Click to sort by description.</>,
    },
    {
        label: 'Type',
        help: (
            <>
                <strong>Type:</strong> the kind of table, as Power Apps shows it.
                <ul>
                    <li><strong>Standard</strong>: an ordinary table stored in Dataverse</li>
                    <li><strong>Activity</strong>: an activity such as a task, email or appointment, with a subject and dates</li>
                    <li><strong>Virtual</strong>: data from an external source, shown in Dataverse but not stored in it</li>
                    <li><strong>Elastic</strong>: built for very large data volumes (tens of millions of rows)</li>
                </ul>
                Click to sort by type.
            </>
        ),
    },
];

/** Columns of the Actions tab: custom APIs, custom process actions and built-in actions. */
export const ACTION_COLUMNS: SelectionColumn[] = [
    {
        label: 'Name',
        help: <><strong>Name:</strong> the action's unique name, used in .dataverse-gen.json and for the generated request type, with its display name above it when it has a different one. Click to sort by name.</>,
    },
    {
        label: 'Binding',
        help: (
            <>
                <strong>Binding:</strong> how the action is called.
                <ul>
                    <li><strong>Bound to &lt;table&gt;</strong>: called on a record of that table, which is generated automatically</li>
                    <li><strong>Unbound</strong>: called on its own</li>
                </ul>
                Click to sort by binding.
            </>
        ),
    },
    {
        label: 'Parameters',
        help: <><strong>Parameters:</strong> the number of request parameters in $metadata. "From definition" means the action isn't in $metadata (a private custom API), so its types are built from the custom API record; these are listed last. Click to sort by parameter count.</>,
    },
    {
        label: 'Type',
        help: (
            <>
                <strong>Type:</strong> where the action comes from.
                <ul>
                    <li><strong>Custom API</strong> / <strong>Private custom API</strong>: a customapi record</li>
                    <li><strong>Custom action</strong>: a custom process action</li>
                    <li><strong>Built-in</strong>: a standard Dataverse action</li>
                </ul>
                Click to sort by type.
            </>
        ),
    },
];

/** Columns of the Functions tab: custom API functions and built-in functions (process actions are never functions). */
export const FUNCTION_COLUMNS: SelectionColumn[] = [
    {
        label: 'Name',
        help: <><strong>Name:</strong> the function's unique name, used in .dataverse-gen.json and for the generated request type, with its display name above it when it has a different one. Click to sort by name.</>,
    },
    {
        label: 'Binding',
        help: (
            <>
                <strong>Binding:</strong> how the function is called.
                <ul>
                    <li><strong>Bound to &lt;table&gt;</strong>: called on a record or collection of that table, which is generated automatically</li>
                    <li><strong>Unbound</strong>: called on its own</li>
                </ul>
                Click to sort by binding.
            </>
        ),
    },
    {
        label: 'Parameters',
        help: <><strong>Parameters:</strong> the number of parameters in $metadata. "From definition" means the function isn't in $metadata (a private custom API), so its types are built from the custom API record; these are listed last. Click to sort by parameter count.</>,
    },
    {
        label: 'Type',
        help: (
            <>
                <strong>Type:</strong> where the function comes from.
                <ul>
                    <li><strong>Custom API</strong> / <strong>Private custom API</strong>: a customapi record marked as a function</li>
                    <li><strong>Built-in</strong>: a standard Dataverse function</li>
                </ul>
                Click to sort by type.
            </>
        ),
    },
];

/**
 * Badge colour per table type, from Fluent UI's semantic palette so it adapts to light and dark themes. Red
 * (danger/severe) is avoided, since nothing here is an error.
 */
export const TABLE_TYPE_COLORS: Record<TableType, BadgeProps['color']> = {
    Standard: 'informative',
    Activity: 'brand',
    Virtual: 'warning',
    Elastic: 'success',
};
