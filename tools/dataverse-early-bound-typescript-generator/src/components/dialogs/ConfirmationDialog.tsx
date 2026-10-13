import type { ReactElement, ReactNode } from 'react';
import { Button, Dialog, DialogActions, DialogBody, DialogContent, DialogSurface, DialogTitle, Text } from '@fluentui/react-components';

export interface IConfirmationDialogProps {
    open: boolean;
    title: string;
    /** What will happen if the user confirms. */
    message: ReactNode;
    /** Label of the confirm button, e.g. "Delete". */
    confirmLabel: string;
    /** Label shown on the confirm button while `busy`, e.g. "Deleting…". Defaults to `confirmLabel`. */
    busyLabel?: string;
    /** Optional icon for the confirm button. */
    confirmIcon?: ReactElement;
    cancelLabel?: string;
    /** While true, both buttons are disabled and the dialog can't be dismissed. */
    busy?: boolean;
    onConfirm: () => void;
    /** Called by Cancel or the Escape key (unless `busy`). An alert dialog ignores clicks outside it. */
    onCancel: () => void;
}

/**
 * A modal yes/no dialog for confirming an action that can't be undone. It only reports the user's choice;
 * the caller performs the action and controls `open` and `busy`.
 */
export function ConfirmationDialog({
    open,
    title,
    message,
    confirmLabel,
    busyLabel,
    confirmIcon,
    cancelLabel = 'Cancel',
    busy = false,
    onConfirm,
    onCancel,
}: IConfirmationDialogProps) {
    return (
        <Dialog modalType="alert" open={open} onOpenChange={(_, data) => !data.open && !busy && onCancel()}>
            <DialogSurface>
                <DialogBody>
                    <DialogTitle>{title}</DialogTitle>
                    <DialogContent>{typeof message === 'string' ? <Text>{message}</Text> : message}</DialogContent>
                    <DialogActions>
                        <Button appearance="primary" icon={confirmIcon} disabled={busy} onClick={onConfirm}>
                            {busy ? (busyLabel ?? confirmLabel) : confirmLabel}
                        </Button>
                        <Button appearance="secondary" disabled={busy} onClick={onCancel}>
                            {cancelLabel}
                        </Button>
                    </DialogActions>
                </DialogBody>
            </DialogSurface>
        </Dialog>
    );
}
