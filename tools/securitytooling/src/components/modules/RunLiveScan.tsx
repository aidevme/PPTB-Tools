import React from "react";
import {
    Accordion,
    AccordionHeader,
    AccordionItem,
    AccordionPanel,
    Button,
    Checkbox,
    Field,
    Input,
    Text,
    Textarea,
    makeStyles,
    tokens,
} from "@fluentui/react-components";
import { MoreHorizontalRegular } from "@fluentui/react-icons";
import { useAppContext } from "../../hooks";

const useRunLiveScanStyles = makeStyles({
    root: {
        border: `1px solid ${tokens.colorNeutralStroke2}`,
        borderRadius: tokens.borderRadiusLarge,
        backgroundColor: tokens.colorNeutralBackground2,
    },
    header: {
        fontFamily: tokens.fontFamilyMonospace,
        fontWeight: tokens.fontWeightSemibold,
        letterSpacing: "0.04em",
        textTransform: "uppercase",
    },
    panel: {
        display: "flex",
        flexDirection: "column",
        gap: tokens.spacingVerticalM,
    },
    row: {
        display: "grid",
        gridTemplateColumns: "1fr 1fr",
        gap: tokens.spacingHorizontalM,
    },
    clientIdField: {
        display: "flex",
        gap: tokens.spacingHorizontalXS,
        alignItems: "center",
    },
    helperText: {
        color: tokens.colorNeutralForeground3,
        fontSize: tokens.fontSizeBase200,
        lineHeight: tokens.lineHeightBase200,
    },
    code: {
        fontFamily: tokens.fontFamilyMonospace,
        fontWeight: tokens.fontWeightSemibold,
        color: tokens.colorNeutralForeground1,
    },
    checkboxRow: {
        display: "flex",
        gap: tokens.spacingHorizontalL,
        flexWrap: "wrap",
    },
    buttonRow: {
        display: "flex",
        gap: tokens.spacingHorizontalS,
    },
    requirementsPanel: {
        display: "flex",
        flexDirection: "column",
        gap: tokens.spacingVerticalS,
    },
    ownAppRow: {
        display: "flex",
        alignItems: "center",
        gap: tokens.spacingHorizontalS,
        flexWrap: "wrap",
    },
    permissionsList: {
        margin: 0,
        paddingLeft: tokens.spacingHorizontalL,
        color: tokens.colorNeutralForeground3,
        fontSize: tokens.fontSizeBase200,
        lineHeight: tokens.lineHeightBase200,
    },
    statusText: {
        color: tokens.colorNeutralForeground3,
        fontSize: tokens.fontSizeBase200,
        fontStyle: "italic",
    },
});

export interface IRunLiveScanProps {
    /** Section title. Defaults to `"Run a live scan (your sign-in, your access)"`. */
    title?: string;
    /** Pre-filled Application (client) ID of the app registration used for the live scan. */
    clientId?: string;
    /** Pre-filled Directory (tenant) ID or domain. Defaults to `"organizations"`. */
    tenantId?: string;
    /** Newline-separated list of Dataverse environment URLs to scan. */
    environmentUrls?: string;
    /** Whether "Scan agent components" is checked by default. Defaults to `true`. */
    scanAgentComponents?: boolean;
    /** Whether "Resolve sharing" is checked by default. Defaults to `false`. */
    resolveSharing?: boolean;
    /** This tool's own published app registration's client ID. */
    ownAppClientId?: string;
    /** The Single-page application redirect URI to register on the app registration. */
    redirectUri?: string;
    /** Status line shown at the bottom, e.g. describing the current sign-in/session state. */
    statusMessage?: string;
    /** Called when the "..." button next to the client ID field is clicked. */
    onBrowseClientId?: () => void;
    /** Called when the "Sign in & scan" button is clicked. */
    onSignInAndScan?: () => void;
    /** Called when the "Discover my environments" button is clicked. */
    onDiscoverEnvironments?: () => void;
    /** Called when the "Use this Client ID" button is clicked. */
    onUseThisClientId?: () => void;
}

/** Collapsible "Run a live scan" panel for a Security Tools module: sign-in details, the
 * environments to scan, scan options, and a nested "App registration requirements" panel
 * describing the Entra app registration the module needs. */
export const RunLiveScan: React.FC<IRunLiveScanProps> = ({
    title = "Run a live scan (your sign-in, your access)",
    clientId = "",
    tenantId = "",
    environmentUrls = "",
    scanAgentComponents = true,
    resolveSharing = false,
    ownAppClientId = "96e9b5f4-e974-4355-ae9f-4487099ef210",
    redirectUri = "https://blue16.nl/Copilot-Studio-Security-Auditor.html",
    statusMessage = 'Opened from the portal but no cached session found — click "Sign in & scan".',
    onBrowseClientId,
    onSignInAndScan,
    onDiscoverEnvironments,
    onUseThisClientId,
}) => {
    const styles = useRunLiveScanStyles();
    const { connection } = useAppContext();
    // PPTB's `Connection` has no `clientId`/`tenantId` field (only `url`), so only the
    // environment URL can come from the active connection; client/tenant ID stay props-only.
    const resolvedEnvironmentUrls = connection?.url || environmentUrls;

    return (
        <Accordion className={styles.root} collapsible defaultOpenItems="scan">
            <AccordionItem value="scan">
                <AccordionHeader className={styles.header}>{title}</AccordionHeader>
                <AccordionPanel className={styles.panel}>
                    <div className={styles.row}>
                        <Field label="Application (client) ID">
                            <div className={styles.clientIdField}>
                                <Input value={clientId} readOnly style={{ flexGrow: 1 }} />
                                <Button
                                    appearance="secondary"
                                    aria-label="Browse for an app registration"
                                    icon={<MoreHorizontalRegular />}
                                    onClick={onBrowseClientId}
                                />
                            </div>
                        </Field>
                        <Field label="Directory (tenant) ID or domain">
                            <Input value={tenantId} readOnly />
                        </Field>
                    </div>

                    <Text className={styles.helperText}>
                        Pre-filled with the published multi-tenant app. For a{" "}
                        <span className={styles.code}>single-tenant</span> app registration, enter your own{" "}
                        <span className={styles.code}>Client ID</span> and its{" "}
                        <span className={styles.code}>home tenant</span> (ID or domain) — leave the tenant as{" "}
                        <span className={styles.code}>organizations</span> for a multi-tenant app, otherwise
                        sign-in fails with <span className={styles.code}>AADSTS650059</span>.
                    </Text>

                    <Field label='Environment URL(s) — one per line (or use "Discover my environments")'>
                        <Textarea value={resolvedEnvironmentUrls} readOnly resize="vertical" rows={3} />
                    </Field>

                    <div className={styles.checkboxRow}>
                        <Checkbox
                            label="Scan agent components (Maker / HTTP / MCP / Send Mail)"
                            defaultChecked={scanAgentComponents}
                        />
                        <Checkbox label="Resolve sharing (slower — 1 call per agent)" defaultChecked={resolveSharing} />
                    </div>

                    <div className={styles.buttonRow}>
                        <Button appearance="primary" onClick={onSignInAndScan}>
                            Sign in &amp; scan
                        </Button>
                        <Button appearance="secondary" onClick={onDiscoverEnvironments}>
                            Discover my environments
                        </Button>
                    </div>

                    <Accordion collapsible defaultOpenItems="requirements">
                        <AccordionItem value="requirements">
                            <AccordionHeader className={styles.header}>App registration requirements</AccordionHeader>
                            <AccordionPanel className={styles.requirementsPanel}>
                                <div className={styles.ownAppRow}>
                                    <Text className={styles.helperText}>
                                        This tool&apos;s own app: <span className={styles.code}>{ownAppClientId}</span>
                                    </Text>
                                    <Button appearance="secondary" onClick={onUseThisClientId}>
                                        Use this Client ID
                                    </Button>
                                </div>

                                <Text className={styles.helperText}>
                                    Platform — <span className={styles.code}>Single-page application (SPA)</span>.
                                    Add this exact Redirect URI: <span className={styles.code}>{redirectUri}</span>
                                </Text>

                                <div>
                                    <Text className={styles.helperText}>
                                        API permissions (delegated) — <em>API permissions → Add a permission</em>:
                                    </Text>
                                    <ul className={styles.permissionsList}>
                                        <li>
                                            <span className={styles.code}>Microsoft Graph → User.Read</span> —
                                            sign-in only.
                                        </li>
                                        <li>
                                            <span className={styles.code}>Dynamics CRM → user_impersonation</span> —
                                            required; reads agents from Dataverse and discovers environments. Found
                                            under{" "}
                                            <em>
                                                APIs my organization uses → Dynamics CRM
                                                (00000007-0000-0000-c000-000000000000)
                                            </em>
                                            . Without it every environment fails with{" "}
                                            <span className={styles.code}>AADSTS650057</span>.
                                        </li>
                                    </ul>
                                </div>

                                <Text className={styles.helperText}>
                                    Then Grant admin consent. Coverage is still limited to environments where your
                                    account holds a Dataverse security role — permissions alone don&apos;t grant
                                    data access.
                                </Text>
                            </AccordionPanel>
                        </AccordionItem>
                    </Accordion>

                    {statusMessage && <Text className={styles.statusText}>{statusMessage}</Text>}
                </AccordionPanel>
            </AccordionItem>
        </Accordion>
    );
};
