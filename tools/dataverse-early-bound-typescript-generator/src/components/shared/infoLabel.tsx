import { InfoLabel, type InfoLabelProps } from '@fluentui/react-components';

/**
 * A label slot that renders an {@link InfoLabel}: the text plus an info button with an explanation. Used for
 * `Field`, `Switch` and `Checkbox` labels so the label stays associated with its control. The button is named
 * "About <text>", like the Settings panel's.
 */
export function infoLabel(text: string, info: InfoLabelProps['info']) {
    return {
        children: (_: unknown, props: InfoLabelProps) => (
            <InfoLabel {...props} info={info} infoButton={{ 'aria-label': `About ${text}` }}>
                {text}
            </InfoLabel>
        ),
    };
}
