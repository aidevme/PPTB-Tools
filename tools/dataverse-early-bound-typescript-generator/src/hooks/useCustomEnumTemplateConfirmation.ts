import { useCallback, useState } from 'react';
import { editedEnumTemplate } from '../services';
import type { WritePlan } from '../types';

/**
 * Turns the project's custom enum template on or off from the Options and Preview cards, asking first when that would replace an edited
 * `enum.ejs` (spec 001, FR-012).
 *
 * @remarks Turning it on with Generate templates on, when the last preview found the project's `enum.ejs` edited
 * ({@link editedEnumTemplate}), opens a confirmation instead of saving: `pendingPath` is then the file's path, and
 * `confirm` saves while `cancel` saves nothing. Every other change (turning it off, Generate templates off, no edited
 * file known) is saved straight away.
 *
 * @param plan - The last preview's write plan, or `null` before the first preview.
 * @param generateTemplates - Whether Generate writes the templates; off, `enum.ejs` isn't written, so nothing is asked.
 * @param save - Saves the project's custom enum template.
 * @returns `request(checked)` for the proposal and the switch, the `pendingPath` of the open confirmation (or
 * `null`), and its `confirm` and `cancel` handlers.
 */
export function useCustomEnumTemplateConfirmation(plan: WritePlan | null, generateTemplates: boolean, save: (checked: boolean) => void) {
    const [pendingPath, setPendingPath] = useState<string | null>(null);

    const request = useCallback(
        (checked: boolean) => {
            const edited = checked && generateTemplates ? editedEnumTemplate(plan) : undefined;
            if (edited) setPendingPath(edited.absolutePath);
            else save(checked);
        },
        [plan, generateTemplates, save],
    );

    const confirm = useCallback(() => {
        setPendingPath(null);
        save(true);
    }, [save]);

    const cancel = useCallback(() => setPendingPath(null), []);

    return { request, pendingPath, confirm, cancel };
}
