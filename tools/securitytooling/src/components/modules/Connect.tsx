import React from "react";
import {
  Button,
  Dropdown,
  Field,
  Input,
  Option,
  Text,
  Title3,
  makeStyles,
  tokens,
} from "@fluentui/react-components";

const useConnectStyles = makeStyles({
  root: {
    display: "flex",
    flexDirection: "column",
    gap: tokens.spacingVerticalM,
    padding: tokens.spacingHorizontalL,
    border: `1px solid ${tokens.colorNeutralStroke2}`,
    borderRadius: tokens.borderRadiusLarge,
    backgroundColor: tokens.colorNeutralBackground2,
  },
  row: {
    display: "grid",
    gridTemplateColumns: "2fr 2fr 1fr",
    gap: tokens.spacingHorizontalM,
    alignItems: "flex-end",
  },
  clientIdField: {
    display: "flex",
    gap: tokens.spacingHorizontalXS,
    alignItems: "center",
  },
  code: {
    fontFamily: tokens.fontFamilyMonospace,
    fontWeight: tokens.fontWeightSemibold,
    color: tokens.colorNeutralForeground1,
  },
  helperText: {
    color: tokens.colorNeutralForeground3,
    fontSize: tokens.fontSizeBase200,
    lineHeight: tokens.lineHeightBase200,
  },
  redirectText: {
    color: tokens.colorNeutralForeground3,
    fontSize: tokens.fontSizeBase200,
  },
});

export interface IConnectProps {
  /** Step title, shown as `"{stepNumber} · {title}"`. Defaults to `"Connect to your tenant"`. */
  title?: string;
  /** Pre-filled Application (client) ID of the Entra app registration. */
  clientId?: string;
  /** Pre-filled Directory (tenant) ID or domain. Defaults to `"organizations"`. */
  tenantId?: string;
  /** Selected Graph API version. Defaults to `"v1.0 (GA)"`. */
  graphApiVersion?: string;
  /** The Single-page application redirect URI to register on the app registration. */
  redirectUri?: string;

  /** Called when the "Sign in" button is clicked. */
  onSignIn?: () => void;
}

/** Tenant-connection form shown as the first step of a Security Tools module: Entra app
 * registration details (client ID, tenant, Graph API version), the delegated permissions the
 * module needs, and a "Sign in" button. */
export const Connect: React.FC<IConnectProps> = ({
  title = "Connect to your tenant",
  clientId = "",
  tenantId = "organizations",
  graphApiVersion = "v1.0 (GA)",
  redirectUri = "",
  
  onSignIn,
}) => {
  const styles = useConnectStyles();

  return (
    <div className={styles.root}>
      <Title3>{title}</Title3>

      <div className={styles.row}>
        <Field
          label="Application (client) ID"
          hint="An app registration of type SPA with delegated, read-only permissions."
        >
          <div className={styles.clientIdField}>
            <Input value={clientId} readOnly style={{ flexGrow: 1 }} />

          </div>
        </Field>
        <Field label="Directory (tenant) ID or domain" hint="Use organizations if unsure.">
          <Input value={tenantId} readOnly />
        </Field>
        <Field
          label="Graph API version"
          hint="Validation message and hint are below the input."
        >
          <Dropdown value={graphApiVersion} selectedOptions={[graphApiVersion]}>
            <Option>v1.0 (GA)</Option>
            <Option>beta</Option>
          </Dropdown>
        </Field>
      </div>

      <Text className={styles.helperText}>
        An app registration of type <span className={styles.code}>SPA</span>{" "}
        with delegated, read-only permissions{" "}
        <span className={styles.code}>Directory.Read.All</span>,{" "}
        <span className={styles.code}>RoleManagement.Read.All</span>,{" "}
        <span className={styles.code}>Application.Read.All</span>,{" "}
        <span className={styles.code}>User.Read</span>. All require admin
        consent. Optional (each degrades gracefully):{" "}
        <span className={styles.code}>AuditLog.Read.All</span> adds per-user
        MFA-method posture + last-sign-in staleness;{" "}
        <span className={styles.code}>Policy.Read.All</span> checks whether each
        admin is actually covered by an enforcing MFA Conditional Access policy;{" "}
        <span className={styles.code}>IdentityRiskyUser.Read.All</span> folds in
        Entra ID Protection risk (P2). PIM eligibility (
        <span className={styles.code}>roleEligibilityScheduleInstances</span>)
        needs P2;{" "}
        <span className={styles.code}>RoleManagementPolicy.Read.Directory</span>{" "}
        detects which eligible roles require approval to activate (lowers the
        score for approval-gated eligibility).
      </Text>

      {redirectUri && (
        <Text className={styles.redirectText}>
          Register this page&apos;s URL as a Single-page application redirect
          URI: <span className={styles.code}>{redirectUri}</span>
        </Text>
      )}

      <div>
        <Button appearance="primary" onClick={onSignIn}>
          Sign in
        </Button>
      </div>
    </div>
  );
};
