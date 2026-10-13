import { makeStyles, tokens } from '@fluentui/react-components';

/** Styles for `NewProjectDialog`: the form layout, and the Location input beside its Browse button. */
export const useNewProjectDialogStyles = makeStyles({
    form: { display: 'flex', flexDirection: 'column', gap: tokens.spacingVerticalM },
    location: { display: 'flex', gap: tokens.spacingHorizontalS },
    locationInput: { flexGrow: 1, minWidth: 0 },
});
