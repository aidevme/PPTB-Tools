import { Card, CardHeader, Field, Input, Switch, Text, makeStyles, tokens } from '@fluentui/react-components';
import { DEFAULT_OUTPUT_ROOT, type DataverseGenConfig } from '../core';

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
                <Field label="Output folder (relative to the project)" className={styles.outputRoot}>
                    <Input
                        value={config.output?.outputRoot ?? DEFAULT_OUTPUT_ROOT}
                        disabled={disabled}
                        onChange={(_, data) => onChange({ output: { ...(config.output ?? {}), outputRoot: data.value } })}
                    />
                </Field>
                <div className={styles.switches}>
                    <Switch
                        label="Early-bound entity interfaces (dataverse-ify)"
                        checked={config.generateEntityTypes ?? true}
                        disabled={disabled}
                        onChange={(_, data) => onChange({ generateEntityTypes: data.checked })}
                    />
                    <Switch
                        label="Form context helpers (Xrm.FormContext)"
                        checked={config.generateFormContext ?? false}
                        disabled={disabled}
                        onChange={(_, data) => onChange({ generateFormContext: data.checked })}
                    />
                    <Switch
                        label="index.ts barrel file"
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
