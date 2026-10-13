import { Card, CardHeader, Field, InfoLabel, Input, Switch, Text, makeStyles, tokens, type InfoLabelProps } from '@fluentui/react-components';
import { DEFAULT_OUTPUT_ROOT, type DataverseGenConfig } from '../../core';

const useStyles = makeStyles({
    body: { display: 'flex', flexDirection: 'column', gap: tokens.spacingVerticalS },
    switches: { display: 'flex', gap: tokens.spacingHorizontalL, flexWrap: 'wrap' },
    outputRoot: { maxWidth: '420px' },
});

export interface OptionsCardProps {
    config: DataverseGenConfig;
    disabled: boolean;
    onChange: (update: Partial<DataverseGenConfig>) => void;
}

/**
 * A label slot that renders an {@link InfoLabel}: the text plus an info button with an explanation. Used for
 * `Field` and `Switch` labels so the label stays associated with its control.
 */
function infoLabel(text: string, info: InfoLabelProps['info']) {
    return {
        children: (_: unknown, props: InfoLabelProps) => (
            <InfoLabel {...props} info={info}>
                {text}
            </InfoLabel>
        ),
    };
}

/** Step 3: output folder and which artefacts to emit (mirrors the dataverse-gen init prompts). */
export function OptionsCard({ config, disabled, onChange }: OptionsCardProps) {
    const styles = useStyles();
    return (
        <Card>
            <CardHeader
                header={
                    <Text weight="semibold" size={400}>
                        3. Options
                    </Text>
                }
                description={<Text size={200}>Saved to .dataverse-gen.json, so the dataverse-gen CLI uses the same settings.</Text>}
            />
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
                </div>
                <Text size={200}>
                    Attribute constants, option-set enums and the metadata cache (metadata.ts) are always generated for the selected
                    tables.
                </Text>
            </div>
        </Card>
    );
}
