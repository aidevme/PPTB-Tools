/**
 * The Custom Templates button and popover on the Preview card's switch row: a tile per kind of generated file, saved
 * per project (`pptbEarlyBoundGenerator.customTemplates`). Presentational; `PreviewActionBar` passes the choices and
 * the save callback.
 */
import { useState } from 'react';
import {
    Button,
    Caption1,
    Checkbox,
    CounterBadge,
    Divider,
    Link,
    MessageBar,
    MessageBarBody,
    Popover,
    PopoverSurface,
    PopoverTrigger,
    Text,
    mergeClasses,
    useId,
} from '@fluentui/react-components';
import { DocumentSettingsRegular } from '@fluentui/react-icons';
import { CUSTOM_TEMPLATE_KINDS, type CustomTemplateSelection } from '../../core';
import { useCustomTemplatesPopoverStyles } from '../../styles';
import { infoLabel } from '../shared/infoLabel';
import { CUSTOM_TEMPLATE_LABELS } from './Popovers.const';

/** Props for {@link CustomTemplatesPopover}. */
export interface ICustomTemplatesPopoverProps {
    /** The project's choices, one checkbox per kind. */
    selection: CustomTemplateSelection;
    /** Disables the button (work in progress, or no project open). */
    disabled: boolean;
    /** Called with every kind's value when OK is clicked; not called on Cancel. */
    onChange: (selection: CustomTemplateSelection) => void;
}

const countSelected = (selection: CustomTemplateSelection) => CUSTOM_TEMPLATE_KINDS.filter((kind) => selection[kind]).length;

/**
 * The Custom Templates button and its popover. The button has a count badge of the saved choices: opens a popover with a tile per kind of
 * generated file (Actions, Complex Types, Entities, Enums, Functions, Metadata), one per row. Each tile has an icon,
 * a checkbox with an info label naming its files and dataverse-gen template, and the output location on the right; a click
 * anywhere on the tile toggles it, and checked tiles are highlighted.
 *
 * @remarks
 * The header has Select all and Clear, and an info bar says the choices are saved but not used yet. The tiles edit a
 * draft that starts from `selection` each time the popover opens: OK (with "n of 6 selected" beside it) saves it and
 * closes the popover; Cancel, Escape or a click outside closes it without saving.
 */
export function CustomTemplatesPopover({ selection, disabled, onChange }: ICustomTemplatesPopoverProps) {
    const styles = useCustomTemplatesPopoverStyles();
    const titleId = useId('custom-templates-title');
    const [open, setOpen] = useState(false);
    const [draft, setDraft] = useState(selection);
    const changed = CUSTOM_TEMPLATE_KINDS.some((kind) => draft[kind] !== selection[kind]);
    const saved = countSelected(selection);
    const selected = countSelected(draft);
    const setAll = (value: boolean) => setDraft(Object.fromEntries(CUSTOM_TEMPLATE_KINDS.map((kind) => [kind, value])) as CustomTemplateSelection);
    const onOpenChange = (next: boolean) => {
        if (next) setDraft(selection);
        setOpen(next);
    };
    return (
        <Popover withArrow trapFocus open={open} onOpenChange={(_, data) => onOpenChange(data.open)}>
            <PopoverTrigger disableButtonEnhancement>
                <Button icon={<DocumentSettingsRegular />} disabled={disabled}>
                    Custom Templates
                    {saved > 0 && <CounterBadge className={styles.count} count={saved} size="small" aria-label={`${saved} selected`} />}
                </Button>
            </PopoverTrigger>
            <PopoverSurface aria-labelledby={titleId} className={styles.surface}>
                <div className={styles.body}>
                    <div className={styles.header}>
                        <span className={styles.headerIcon} aria-hidden="true">
                            <DocumentSettingsRegular />
                        </span>
                        <Text weight="semibold" size={400} id={titleId} className={styles.title}>
                            Custom templates
                        </Text>
                        <Link as="button" disabled={selected === CUSTOM_TEMPLATE_KINDS.length} onClick={() => setAll(true)}>
                            Select all
                        </Link>
                        <Link as="button" disabled={selected === 0} onClick={() => setAll(false)}>
                            Clear
                        </Link>
                    </div>
                    <MessageBar intent="info" layout="multiline">
                        <MessageBarBody>Saved with the project. Not used yet: the generated files don't change.</MessageBarBody>
                    </MessageBar>
                    <div className={styles.list} role="group" aria-labelledby={titleId}>
                        {CUSTOM_TEMPLATE_KINDS.map((kind) => {
                            const { label, icon, location, info } = CUSTOM_TEMPLATE_LABELS[kind];
                            const toggle = (checked: boolean) => setDraft({ ...draft, [kind]: checked });
                            return (
                                <div
                                    key={kind}
                                    className={mergeClasses(styles.tile, draft[kind] && styles.tileSelected)}
                                    // The checkbox is the control; a click on the rest of the tile (icon, location) toggles it too.
                                    onClick={(e) => {
                                        if (!(e.target as HTMLElement).closest('input, label, button')) toggle(!draft[kind]);
                                    }}
                                >
                                    <span className={styles.tileIcon} aria-hidden="true">
                                        {icon}
                                    </span>
                                    <div className={styles.tileText}>
                                        <Checkbox label={infoLabel(label, info)} checked={draft[kind]} onChange={(_, data) => toggle(data.checked === true)} />
                                        <Caption1 className={styles.location}>{location}</Caption1>
                                    </div>
                                </div>
                            );
                        })}
                    </div>
                    <Divider />
                    <div className={styles.actions}>
                        <Caption1 className={styles.muted} aria-live="polite">
                            {selected} of {CUSTOM_TEMPLATE_KINDS.length} selected
                        </Caption1>
                        <Button
                            appearance="primary"
                            size="small"
                            disabled={!changed}
                            onClick={() => {
                                onChange(draft);
                                setOpen(false);
                            }}
                        >
                            OK
                        </Button>
                        <Button size="small" onClick={() => setOpen(false)}>
                            Cancel
                        </Button>
                    </div>
                </div>
            </PopoverSurface>
        </Popover>
    );
}
