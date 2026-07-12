import { Desktop20Regular, Phone20Regular, Tablet20Regular } from "@fluentui/react-icons";
import type { FormFactor } from "../../services";

/** Icon shown for each form factor, reused across `FormFactorsCard`'s tabs and
 * `CopyFormFactorCard`'s "Copy from"/"Copy to" dropdowns. */
export const FORM_FACTOR_ICONS: Record<FormFactor, JSX.Element> = {
    0: <Desktop20Regular />,
    1: <Phone20Regular />,
    2: <Tablet20Regular />,
};
