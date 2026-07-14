import { Desktop20Regular, Phone20Regular, Tablet20Regular } from "@fluentui/react-icons";
import type { FormFactor } from "../services";

/** Icon shown for each form factor (`0` = Phone, `1` = Tablet, `2` = Web), reused across
 * `FormFactorsCard`'s tabs and `CopyFormFactorCard`'s "Copy from"/"Copy to" dropdowns. */
export const FORM_FACTOR_ICONS: Record<FormFactor, JSX.Element> = {
    0: <Phone20Regular />,
    1: <Tablet20Regular />,
    2: <Desktop20Regular />,
};
