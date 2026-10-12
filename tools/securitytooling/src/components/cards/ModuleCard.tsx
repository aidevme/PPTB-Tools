import React, { type CSSProperties } from "react";
import {
  Button,
  Card,
  CardFooter,
  CardPreview,
  Text,
} from "@fluentui/react-components";
import { useAppContext } from "../../hooks";
import { useModuleCardStyles } from "../../styles";

// Fixed per-mode palettes (not sourced from Fluent's semantic tokens) so the card's "terminal"
// aesthetic — dark background, monospace neon labels — is preserved exactly in dark mode, while
// still giving light-theme hosts a legible light-background/black-text variant instead of the same
// near-black card. Set as CSS custom properties (see `--card-*` below) rather than swapped classes,
// so the rest of the stylesheet only has to reference one set of variables.
const PALETTES = {
  light: {
    background: "#ffffff", // brand-exception
    border: "rgba(0,0,0,0.08)", // brand-exception
    iconBg: "rgba(0,0,0,0.04)", // brand-exception
    title: "#000000", // brand-exception
    description: "#4b5563", // brand-exception
    module: "#6b7280", // brand-exception
  },
  dark: {
    background: "#0d1117", // brand-exception
    border: "rgba(255,255,255,0.08)", // brand-exception
    iconBg: "rgba(255,255,255,0.06)", // brand-exception
    title: "#f0f6fc", // brand-exception
    description: "#8b949e", // brand-exception
    module: "#6e7681", // brand-exception
  },
} as const;

export interface IModuleCardProps {
  /** Icon representing the tool, rendered in the accent-tinted badge next to the category tag. */
  icon: React.ReactElement;
  /** Short category badge shown top-right, e.g. `"USER"`, `"WORKLOAD"`, `"AGENT"`. */
  tag: string;
  /** Optional small-caps classification line above the title, e.g. `"USER SECURITY"`. */
  eyebrow?: string;
  /** The module's display name. */
  title: string;
  /** Short description of what the module does. */
  description: string;
  /** Destination the "Launch Module" link opens — an absolute URL or a relative page path. Also
   * displayed verbatim (monospace) beneath the link. */
  module: string;
  /** CSS color used for the tag, eyebrow, icon badge, and launch link — one per module category. */
  accentColor: string;
  /** Called when the "Launch Module" link is clicked, instead of navigating to `module`. */
  onLaunch?: () => void;
}

/** One entry in the Security Tools dashboard grid: category tag, icon, title, description, and a
 * "Launch Module" link to the module's page. Its background/text palette follows the PPTB host's
 * light/dark theme (see `AppContext`) while the accent color stays per-card. */
export const ModuleCard: React.FC<IModuleCardProps> = ({
  icon,
  tag,
  eyebrow,
  title,
  description,
  accentColor,
  onLaunch,
}) => {
  const styles = useModuleCardStyles();
  const { themeMode: mode } = useAppContext();
  const palette = PALETTES[mode];

  return (
    <Card
      className={styles.card}
      style={
        {
          "--accent": accentColor,
          "--card-bg": palette.background,
          "--card-border": palette.border,
          "--card-icon-bg": palette.iconBg,
          "--card-title": palette.title,
          "--card-description": palette.description,
          "--card-path": palette.module,
        } as CSSProperties
      }
    >
      <div className={styles.topRow}>
        <div className={styles.iconBadge}>{icon}</div>
        <Text className={styles.tag}>{tag}</Text>
      </div>

      {eyebrow && <Text className={styles.eyebrow}>{eyebrow}</Text>}
      <Text as="h3" className={styles.title}>
        {title}
      </Text>
      <CardPreview>
        <Text className={styles.description}>{description}</Text>
      </CardPreview>

      <CardFooter>
        <Button appearance="subtle" className={styles.launchLink} onClick={() => onLaunch?.()}>
          Launch Module
        </Button>
      </CardFooter>
    </Card>
  );
};
