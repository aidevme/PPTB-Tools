import { Field, Input, Switch, Text } from '@fluentui/react-components';
import { DEFAULT_OUTPUT_ROOT, type DataverseGenConfig } from '../../core';
import { infoLabel } from '../shared/infoLabel';
import { CUSTOM_ENUM_TEMPLATE_INFO, CUSTOM_ENUM_TEMPLATE_TITLE } from '../shared/settingsInfo';
import { useOptionsCardStyles } from '../../styles';
import { StepCard } from '../shared/StepCard';
import type { StepState } from '../shared/workflowSteps';

/** Props for {@link OptionsCard}. */
export interface IOptionsCardProps {
    /** The card's step in the workflow: number, title and completion badge. */
    step: StepState;
    /** The project's `.dataverse-gen.json` settings the inputs show; unset options show dataverse-gen's defaults. */
    config: DataverseGenConfig;
    /** Disables the output folder input and the switches (no connection or project yet, or work in progress). */
    disabled: boolean;
    /**
     * Called on every edit with only the changed settings: `output` (with `outputRoot` merged into the existing
     * `output`), `generateEntityTypes`, `generateFormContext` or `generateIndex`.
     */
    onChange: (update: Partial<DataverseGenConfig>) => void;
    /**
     * Whether the project uses the custom enum template: its `pptbEarlyBoundGenerator.customEnumTemplate`, or the
     * Settings default when the project has no value.
     */
    customEnumTemplate: boolean;
    /**
     * The Custom enum template switch: asks first when turning it on would replace an edited `enum.ejs`, then saves the
     * project's value (see `useCustomEnumTemplateConfirmation`).
     */
    onCustomEnumTemplateChange: (checked: boolean) => void;
}

/** Step 3: output folder and which artefacts to emit (mirrors the dataverse-gen init prompts). */
export function OptionsCard({ step, config, disabled, onChange, customEnumTemplate, onCustomEnumTemplateChange }: IOptionsCardProps) {
    const styles = useOptionsCardStyles();
    return (
        <StepCard step={step} description="Start from the Options in Settings; change them here for this project. Saved to .dataverse-gen.json, so the dataverse-gen CLI uses the same settings.">
            <div className={styles.body}>
                <Field
                    label={infoLabel(
                        'Output folder (relative to the project)',
                        <>
                            Where generated files are written, relative to the project folder. The tool creates <code>entities</code>,{' '}
                            <code>enums</code>, <code>actions</code>, <code>functions</code> and <code>complextypes</code> folders inside
                            it. Saved as <code>output.outputRoot</code>.
                        </>,
                    )}
                    className={styles.outputRoot}
                >
                    <Input
                        value={config.output?.outputRoot ?? DEFAULT_OUTPUT_ROOT}
                        disabled={disabled}
                        onChange={(_, data) => onChange({ output: { ...(config.output ?? {}), outputRoot: data.value } })}
                    />
                </Field>
                <div className={styles.switches}>
                    <Switch
                        label={infoLabel(
                            'Early-bound entity interfaces (dataverse-ify)',
                            <>
                                An interface per table (for example <code>Account extends IEntity</code>) with a typed property per
                                column, for dataverse-ify's typed create, retrieve and update calls. Saved as{' '}
                                <code>generateEntityTypes</code>.
                            </>,
                        )}
                        checked={config.generateEntityTypes ?? true}
                        disabled={disabled}
                        onChange={(_, data) => onChange({ generateEntityTypes: data.checked })}
                    />
                    <Switch
                        label={infoLabel(
                            'Form context helpers (Xrm.FormContext)',
                            <>
                                A <code>&lt;Table&gt;FormContext</code> interface per table for model-driven form scripts, so{' '}
                                <code>getAttribute('name')</code> and <code>getControl('name')</code> return the right Xrm type for
                                each column. Saved as <code>generateFormContext</code>.
                            </>,
                        )}
                        checked={config.generateFormContext ?? false}
                        disabled={disabled}
                        onChange={(_, data) => onChange({ generateFormContext: data.checked })}
                    />
                    <Switch
                        label={infoLabel(
                            'index.ts barrel file',
                            <>
                                An <code>index.ts</code> in the output folder that re-exports every generated file, so you can import
                                everything from one place. Saved as <code>generateIndex</code>.
                            </>,
                        )}
                        checked={config.generateIndex ?? true}
                        disabled={disabled}
                        onChange={(_, data) => onChange({ generateIndex: data.checked })}
                    />
                    <Switch
                        label={infoLabel(CUSTOM_ENUM_TEMPLATE_TITLE, CUSTOM_ENUM_TEMPLATE_INFO)}
                        checked={customEnumTemplate}
                        disabled={disabled}
                        onChange={(_, data) => onCustomEnumTemplateChange(data.checked)}
                    />
                </div>
                <Text size={200}>
                    Attribute constants, option-set enums and the metadata cache (metadata.ts) are always generated for the selected
                    tables.
                </Text>
            </div>
        </StepCard>
    );
}

/** @deprecated Renamed to `IOptionsCardProps`. */
export type OptionsCardProps = IOptionsCardProps;
