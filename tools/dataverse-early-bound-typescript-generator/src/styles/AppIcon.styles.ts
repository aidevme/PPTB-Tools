import { makeStyles, tokens } from '@fluentui/react-components';

/** Styles for `AppIcon`: the gradient tile, and one class per size. */
export const useAppIconStyles = makeStyles({
    tile: {
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        flexShrink: 0,
        color: tokens.colorNeutralForegroundOnBrand,
        backgroundImage: `linear-gradient(135deg, ${tokens.colorBrandBackground} 0%, ${tokens.colorPaletteTealForeground2} 100%)`,
    },
    large: { width: '44px', height: '44px', borderRadius: tokens.borderRadiusXLarge, fontSize: '24px', boxShadow: tokens.shadow8 },
    small: { width: '28px', height: '28px', borderRadius: tokens.borderRadiusLarge, fontSize: '16px' },
});
