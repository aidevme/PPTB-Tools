import { makeStyles, tokens } from '@fluentui/react-components';

/** Styles for `OptionsCard`: the output folder field and the row of option switches. */
export const useOptionsCardStyles = makeStyles({
    body: { display: 'flex', flexDirection: 'column', gap: tokens.spacingVerticalS },
    switches: { display: 'flex', gap: tokens.spacingHorizontalL, flexWrap: 'wrap' },
    outputRoot: { maxWidth: '420px' },
});
