import {
  type Dispatch,
  type SetStateAction,
  useEffect,
  useMemo,
  useRef,
  useState,
} from "react";
import {
  Button,
  Dropdown,
  Field,
  MessageBar,
  MessageBarBody,
  MessageBarTitle,  
  Option,
  Tab,
  TabList,
  Text,
  Tooltip,
  type SelectTabData,
  type SelectTabEvent,
} from "@fluentui/react-components";
import { AppsRegular, CheckmarkCircle16Filled } from "@fluentui/react-icons";
import {
  getExistingCustomControl,
  FORM_FACTORS,
  FORM_FACTOR_LABELS,
} from "../../services";
import type {
  AttributeInfo,
  FieldInfo,
  FormFactor,
  PcfAssignment,
  PcfControl,
} from "../../services";
import { useFormFactorsCardStyles } from "../../styles";
import { PcfDetailsPanel } from "../panels/PcfDetailsPanel";
import { PcfConfiguratorTable } from "../tables/PcfConfiguratorTable";
import { FORM_FACTOR_ICONS } from "./Common.const";
import { GenericCard } from "./GenericCard";
import {
  BUTTON_APPLY_LABEL,
  BUTTON_REMOVE_LABEL,
  CARD_DESCRIPTION,
  CARD_TITLE_PREFIX,
  FIELD_SELECT_PCF_LABEL,
  TAB_ASSIGNED_ICON_ARIA_LABEL,
  TEXT_METADATA_UNRESOLVED_PREFIX,
  TEXT_NO_COMPATIBLE_CONTROL_PREFIX,
  TEXT_NO_COMPATIBLE_CONTROL_SUFFIX,
  TIPS_BODY_TEXT,
  TIPS_TITLE,
  TOOLTIP_APPLY_DISABLED_TEXT,
  TOOLTIP_APPLY_ENABLED_PART1,
  TOOLTIP_APPLY_ENABLED_PART2,
  TOOLTIP_APPLY_ENABLED_PART3,
  TOOLTIP_PCF_DETAILS_TEXT,
  TOOLTIP_REMOVE_DISABLED_TEXT,
  TOOLTIP_REMOVE_ENABLED_PART1,
  TOOLTIP_REMOVE_ENABLED_PART2,
  TOOLTIP_REMOVE_ENABLED_PART3,
} from "./FormFactorsCard.const";

export interface IFormFactorsCardProps {
  field: FieldInfo | null;
  entityDisplayName: string;
  doc: XMLDocument | null;
  docVersion: number;
  formFactor: FormFactor;
  onFormFactorChange: (formFactor: FormFactor) => void;
  attribute: AttributeInfo | undefined;
  compatibleControls: PcfControl[];
  existing: PcfAssignment | null;
  onApply: (pcf: PcfControl, values: Record<string, string>) => void;
  onRemove: () => void;
  /** Reports the (possibly unapplied) PCF pick per form factor whenever it changes, so a parent
   * (e.g. `CopyFormFactorCard`'s "Copy from" enablement) can reflect what's currently in each
   * dropdown rather than only what's been applied to the doc. */
  onDraftSelectionChange?: (selectedPcfIdByFf: Partial<Record<FormFactor, string>>) => void;
}

/** Form-factor picker, PCF dropdown, and parameter editor for the currently selected field. */
export function FormFactorsCard({
  field,
  entityDisplayName,
  doc,
  docVersion,
  formFactor,
  onFormFactorChange,
  attribute,
  compatibleControls,
  existing,
  onApply,
  onRemove,
  onDraftSelectionChange,
}: IFormFactorsCardProps) {
  const styles = useFormFactorsCardStyles();
  const [isPcfDetailsOpen, setIsPcfDetailsOpen] = useState(false);
  // Per-form-factor drafts, keyed by FormFactor, so switching tabs doesn't discard an unapplied pick
  // on another tab. Only re-seeded (per key) when that form factor's actual doc assignment changes.
  const [selectedPcfIdByFf, setSelectedPcfIdByFf] = useState<
    Partial<Record<FormFactor, string>>
  >({});
  const [paramValuesByFf, setParamValuesByFf] = useState<
    Partial<Record<FormFactor, Record<string, string>>>
  >({});
  // "Is Static?" per non-Enum parameter, owned here (rather than by PcfConfiguratorTable) so it can
  // be reset alongside `paramValues` on the same field/PCF changes below.
  const [staticOverridesByFf, setStaticOverridesByFf] = useState<
    Partial<Record<FormFactor, Record<string, boolean>>>
  >({});

  useEffect(() => {
    onDraftSelectionChange?.(selectedPcfIdByFf);
  }, [selectedPcfIdByFf, onDraftSelectionChange]);

  const existingByFormFactor = useMemo(() => {
    const map: Partial<Record<FormFactor, PcfAssignment | null>> = {};
    if (doc && field) {
      FORM_FACTORS.forEach((ff) => {
        map[ff] = getExistingCustomControl(doc, field.controlId, ff);
      });
    }
    return map;
    // docVersion drives recomputation after in-place XML mutations; doc itself never changes identity.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [doc, docVersion, field?.controlId]);

  // Tracks what each form factor's slot was last seeded from, so the effect below can tell an actual
  // doc mutation (Apply/Remove/Copy) apart from merely switching tabs.
  const syncedRef = useRef<{
    controlId: string | undefined;
    assignments: Partial<Record<FormFactor, PcfAssignment | null>>;
  }>({
    controlId: undefined,
    assignments: {},
  });

  useEffect(() => {
    const fieldChanged = syncedRef.current.controlId !== field?.controlId;
    const changedFormFactors = fieldChanged
      ? FORM_FACTORS
      : FORM_FACTORS.filter((ff) => {
          const prevAssignment = syncedRef.current.assignments[ff];
          const assignment = existingByFormFactor[ff];
          return (
            (prevAssignment?.name ?? null) !== (assignment?.name ?? null) ||
            JSON.stringify(prevAssignment?.parameters ?? {}) !==
              JSON.stringify(assignment?.parameters ?? {})
          );
        });

    if (changedFormFactors.length > 0) {
      setSelectedPcfIdByFf((prev) => {
        const next = fieldChanged ? {} : { ...prev };
        changedFormFactors.forEach((ff) => {
          const assignment = existingByFormFactor[ff];
          const match = compatibleControls.find(
            (c) => c.parameters[0]?.controlName === assignment?.name,
          );
          next[ff] = match?.id ?? "";
        });
        return next;
      });
      setParamValuesByFf((prev) => {
        const next = fieldChanged ? {} : { ...prev };
        changedFormFactors.forEach((ff) => {
          next[ff] = existingByFormFactor[ff]?.parameters ?? {};
        });
        return next;
      });
      setStaticOverridesByFf((prev) => {
        const next = fieldChanged ? {} : { ...prev };
        changedFormFactors.forEach((ff) => {
          next[ff] = {};
        });
        return next;
      });
    }

    syncedRef.current = {
      controlId: field?.controlId,
      assignments: existingByFormFactor,
    };
  }, [field?.controlId, existingByFormFactor, compatibleControls]);

  if (!field) {
    return null;
  }

  const selectedPcfId = selectedPcfIdByFf[formFactor] ?? "";
  const paramValues = paramValuesByFf[formFactor] ?? {};
  const staticOverrides = staticOverridesByFf[formFactor] ?? {};
  const selectedPcf = compatibleControls.find((c) => c.id === selectedPcfId);

  const setParamValues: Dispatch<SetStateAction<Record<string, string>>> = (
    update,
  ) => {
    setParamValuesByFf((prev) => {
      const current = prev[formFactor] ?? {};
      const next =
        typeof update === "function"
          ? (update as (p: Record<string, string>) => Record<string, string>)(
              current,
            )
          : update;
      return { ...prev, [formFactor]: next };
    });
  };

  const setStaticOverrides: Dispatch<
    SetStateAction<Record<string, boolean>>
  > = (update) => {
    setStaticOverridesByFf((prev) => {
      const current = prev[formFactor] ?? {};
      const next =
        typeof update === "function"
          ? (update as (p: Record<string, boolean>) => Record<string, boolean>)(
              current,
            )
          : update;
      return { ...prev, [formFactor]: next };
    });
  };

  const handlePcfChange = (pcfId: string) => {
    setSelectedPcfIdByFf((prev) => ({ ...prev, [formFactor]: pcfId }));
    const pcf = compatibleControls.find((c) => c.id === pcfId);
    const assignment = existingByFormFactor[formFactor];
    setParamValuesByFf((prev) => ({
      ...prev,
      [formFactor]:
        pcf?.parameters[0]?.controlName === assignment?.name ? (assignment?.parameters ?? {}) : {},
    }));
    setStaticOverridesByFf((prev) => ({ ...prev, [formFactor]: {} }));
  };

  const WebPanel = (
    <>
      {!attribute ? (
        <Text italic>
          {TEXT_METADATA_UNRESOLVED_PREFIX} &quot;{field.datafieldname}&quot;
        </Text>
      ) : compatibleControls.length === 0 ? (
        <Text italic>
          {TEXT_NO_COMPATIBLE_CONTROL_PREFIX} &quot;{attribute.attributeType}
          &quot; {TEXT_NO_COMPATIBLE_CONTROL_SUFFIX}
        </Text>
      ) : (
        <>
          <div className={styles.pcfSelectRow}>
            <Field
              label={`${FIELD_SELECT_PCF_LABEL} - Web`}
              className={styles.pcfSelectField}
            >
              <Dropdown
                clearable
                value={selectedPcf?.parameters[0]?.controlName ?? ""}
                selectedOptions={selectedPcfId ? [selectedPcfId] : []}
                onOptionSelect={(_, data) =>
                  handlePcfChange(data.optionValue ?? "")
                }
                button={
                  !selectedPcf
                    ? undefined
                    : {
                        children: (
                          <span className={styles.tabLabel}>
                            <AppsRegular />
                            {selectedPcf.parameters[0]?.controlName ?? ""}
                          </span>
                        ),
                      }
                }
              >
                {compatibleControls.map((pcf) => (
                  <Option key={pcf.id} value={pcf.id} text={pcf.parameters[0]?.controlName ?? ""}>
                    <span className={styles.tabLabel}>
                      <AppsRegular />
                      {pcf.parameters[0]?.controlName ?? ""}
                    </span>
                  </Option>
                ))}
              </Dropdown>
            </Field>

            <Tooltip
              content={TOOLTIP_PCF_DETAILS_TEXT}
              relationship="label"
              positioning="below"
              withArrow
            >
              <Button
                appearance="subtle"
                size="medium"
                icon={<AppsRegular />}
                disabledFocusable={!selectedPcf}
                aria-label="PcfDetails"
                onClick={() => selectedPcf && setIsPcfDetailsOpen(true)}
              />
            </Tooltip>
          </div>

          {selectedPcf && (
            <MessageBar intent="warning">
              <MessageBarBody>
                <MessageBarTitle>{TIPS_TITLE}</MessageBarTitle> {TIPS_BODY_TEXT}
              </MessageBarBody>
            </MessageBar>
          )}
        </>
      )}

      <PcfConfiguratorTable
        selectedPcf={selectedPcf}
        formFactorId={String(formFactor)}
        entityLogicalName={field.entityLogicalName}
        paramValues={paramValues}
        onParamValuesChange={setParamValues}
        staticOverrides={staticOverrides}
        onStaticOverridesChange={setStaticOverrides}
      />

      <div style={{ display: "flex", gap: 8 }}>
        <Tooltip
          content={
            selectedPcf
              ? `${TOOLTIP_APPLY_ENABLED_PART1}${selectedPcf.parameters[0]?.controlName ?? ""}${TOOLTIP_APPLY_ENABLED_PART2} ${FORM_FACTOR_LABELS[formFactor]} ${TOOLTIP_APPLY_ENABLED_PART3}`
              : TOOLTIP_APPLY_DISABLED_TEXT
          }
          relationship="description"
          positioning="below"
          withArrow
        >
          <Button
            appearance="primary"
            disabledFocusable={!selectedPcf}
            onClick={() => selectedPcf && onApply(selectedPcf, paramValues)}
          >
            {BUTTON_APPLY_LABEL}
          </Button>
        </Tooltip>
        <Tooltip
          content={
            existing
              ? `${TOOLTIP_REMOVE_ENABLED_PART1}${existing.name}${TOOLTIP_REMOVE_ENABLED_PART2} ${FORM_FACTOR_LABELS[formFactor]} ${TOOLTIP_REMOVE_ENABLED_PART3}`
              : TOOLTIP_REMOVE_DISABLED_TEXT
          }
          relationship="description"
          positioning="below"
          withArrow
        >
          <Button
            appearance="secondary"
            disabledFocusable={!existing}
            onClick={() => existing && onRemove()}
          >
            {BUTTON_REMOVE_LABEL}
          </Button>
        </Tooltip>
      </div>
    </>
  );

  const PhonePanel = (
    <>
      {!attribute ? (
        <Text italic>
          {TEXT_METADATA_UNRESOLVED_PREFIX} &quot;{field.datafieldname}&quot;
        </Text>
      ) : compatibleControls.length === 0 ? (
        <Text italic>
          {TEXT_NO_COMPATIBLE_CONTROL_PREFIX} &quot;{attribute.attributeType}
          &quot; {TEXT_NO_COMPATIBLE_CONTROL_SUFFIX}
        </Text>
      ) : (
        <>
          <div className={styles.pcfSelectRow}>
            <Field
              label={`${FIELD_SELECT_PCF_LABEL} - Phone`}
              className={styles.pcfSelectField}
            >
              <Dropdown
                clearable
                value={selectedPcf?.parameters[0]?.controlName ?? ""}
                selectedOptions={selectedPcfId ? [selectedPcfId] : []}
                onOptionSelect={(_, data) =>
                  handlePcfChange(data.optionValue ?? "")
                }
                button={
                  !selectedPcf
                    ? undefined
                    : {
                        children: (
                          <span className={styles.tabLabel}>
                            <AppsRegular />
                            {selectedPcf.parameters[0]?.controlName ?? ""}
                          </span>
                        ),
                      }
                }
              >
                {compatibleControls.map((pcf) => (
                  <Option key={pcf.id} value={pcf.id} text={pcf.parameters[0]?.controlName ?? ""}>
                    <span className={styles.tabLabel}>
                      <AppsRegular />
                      {pcf.parameters[0]?.controlName ?? ""}
                    </span>
                  </Option>
                ))}
              </Dropdown>
            </Field>

            <Tooltip
              content={TOOLTIP_PCF_DETAILS_TEXT}
              relationship="label"
              positioning="below"
              withArrow
            >
              <Button
                appearance="subtle"
                size="medium"
                icon={<AppsRegular />}
                disabledFocusable={!selectedPcf}
                aria-label="PcfDetails"
                onClick={() => selectedPcf && setIsPcfDetailsOpen(true)}
              />
            </Tooltip>
          </div>

          {selectedPcf && (
            <MessageBar intent="warning">
              <MessageBarBody>
                <MessageBarTitle>{TIPS_TITLE}</MessageBarTitle> {TIPS_BODY_TEXT}
              </MessageBarBody>
            </MessageBar>
          )}
        </>
      )}

      <PcfConfiguratorTable
        selectedPcf={selectedPcf}
        formFactorId={String(formFactor)}
        entityLogicalName={field.entityLogicalName}
        paramValues={paramValues}
        onParamValuesChange={setParamValues}
        staticOverrides={staticOverrides}
        onStaticOverridesChange={setStaticOverrides}
      />

      <div style={{ display: "flex", gap: 8 }}>
        <Tooltip
          content={
            selectedPcf
              ? `${TOOLTIP_APPLY_ENABLED_PART1}${selectedPcf.parameters[0]?.controlName ?? ""}${TOOLTIP_APPLY_ENABLED_PART2} ${FORM_FACTOR_LABELS[formFactor]} ${TOOLTIP_APPLY_ENABLED_PART3}`
              : TOOLTIP_APPLY_DISABLED_TEXT
          }
          relationship="description"
          positioning="below"
          withArrow
        >
          <Button
            appearance="primary"
            disabledFocusable={!selectedPcf}
            onClick={() => selectedPcf && onApply(selectedPcf, paramValues)}
          >
            {BUTTON_APPLY_LABEL}
          </Button>
        </Tooltip>
        <Tooltip
          content={
            existing
              ? `${TOOLTIP_REMOVE_ENABLED_PART1}${existing.name}${TOOLTIP_REMOVE_ENABLED_PART2} ${FORM_FACTOR_LABELS[formFactor]} ${TOOLTIP_REMOVE_ENABLED_PART3}`
              : TOOLTIP_REMOVE_DISABLED_TEXT
          }
          relationship="description"
          positioning="below"
          withArrow
        >
          <Button
            appearance="secondary"
            disabledFocusable={!existing}
            onClick={() => existing && onRemove()}
          >
            {BUTTON_REMOVE_LABEL}
          </Button>
        </Tooltip>
      </div>
    </>
  );

  const TabletPanel = (
    <>
      {!attribute ? (
        <Text italic>
          {TEXT_METADATA_UNRESOLVED_PREFIX} &quot;{field.datafieldname}&quot;
        </Text>
      ) : compatibleControls.length === 0 ? (
        <Text italic>
          {TEXT_NO_COMPATIBLE_CONTROL_PREFIX} &quot;{attribute.attributeType}
          &quot; {TEXT_NO_COMPATIBLE_CONTROL_SUFFIX}
        </Text>
      ) : (
        <>
          <div className={styles.pcfSelectRow}>
            <Field
              label={`${FIELD_SELECT_PCF_LABEL} - Tablet`}
              className={styles.pcfSelectField}
            >
              <Dropdown
                clearable
                value={selectedPcf?.parameters[0]?.controlName ?? ""}
                selectedOptions={selectedPcfId ? [selectedPcfId] : []}
                onOptionSelect={(_, data) =>
                  handlePcfChange(data.optionValue ?? "")
                }
                button={
                  !selectedPcf
                    ? undefined
                    : {
                        children: (
                          <span className={styles.tabLabel}>
                            <AppsRegular />
                            {selectedPcf.parameters[0]?.controlName ?? ""}
                          </span>
                        ),
                      }
                }
              >
                {compatibleControls.map((pcf) => (
                  <Option key={pcf.id} value={pcf.id} text={pcf.parameters[0]?.controlName ?? ""}>
                    <span className={styles.tabLabel}>
                      <AppsRegular />
                      {pcf.parameters[0]?.controlName ?? ""}
                    </span>
                  </Option>
                ))}
              </Dropdown>
            </Field>

            <Tooltip
              content={TOOLTIP_PCF_DETAILS_TEXT}
              relationship="label"
              positioning="below"
              withArrow
            >
              <Button
                appearance="subtle"
                size="medium"
                icon={<AppsRegular />}
                disabledFocusable={!selectedPcf}
                aria-label="PcfDetails"
                onClick={() => selectedPcf && setIsPcfDetailsOpen(true)}
              />
            </Tooltip>
          </div>

          {selectedPcf && (
            <MessageBar intent="warning">
              <MessageBarBody>
                <MessageBarTitle>{TIPS_TITLE}</MessageBarTitle> {TIPS_BODY_TEXT}
              </MessageBarBody>
            </MessageBar>
          )}
        </>
      )}

      <PcfConfiguratorTable
        selectedPcf={selectedPcf}
        formFactorId={String(formFactor)}
        entityLogicalName={field.entityLogicalName}
        paramValues={paramValues}
        onParamValuesChange={setParamValues}
        staticOverrides={staticOverrides}
        onStaticOverridesChange={setStaticOverrides}
      />

      <div style={{ display: "flex", gap: 8 }}>
        <Tooltip
          content={
            selectedPcf
              ? `${TOOLTIP_APPLY_ENABLED_PART1}${selectedPcf.parameters[0]?.controlName ?? ""}${TOOLTIP_APPLY_ENABLED_PART2} ${FORM_FACTOR_LABELS[formFactor]} ${TOOLTIP_APPLY_ENABLED_PART3}`
              : TOOLTIP_APPLY_DISABLED_TEXT
          }
          relationship="description"
          positioning="below"
          withArrow
        >
          <Button
            appearance="primary"
            disabledFocusable={!selectedPcf}
            onClick={() => selectedPcf && onApply(selectedPcf, paramValues)}
          >
            {BUTTON_APPLY_LABEL}
          </Button>
        </Tooltip>
        <Tooltip
          content={
            existing
              ? `${TOOLTIP_REMOVE_ENABLED_PART1}${existing.name}${TOOLTIP_REMOVE_ENABLED_PART2} ${FORM_FACTOR_LABELS[formFactor]} ${TOOLTIP_REMOVE_ENABLED_PART3}`
              : TOOLTIP_REMOVE_DISABLED_TEXT
          }
          relationship="description"
          positioning="below"
          withArrow
        >
          <Button
            appearance="secondary"
            disabledFocusable={!existing}
            onClick={() => existing && onRemove()}
          >
            {BUTTON_REMOVE_LABEL}
          </Button>
        </Tooltip>
      </div>
    </>
  );

  return (
    <>
      <GenericCard
        title={
          <>
            {CARD_TITLE_PREFIX}{" "}
            <span style={{ fontWeight: 600 }}>
              {field.label} ({entityDisplayName})
            </span>
          </>
        }
        description={CARD_DESCRIPTION}
      >
        <div className={styles.content}>
          <TabList
            selectedValue={String(formFactor)}
            onTabSelect={(_: SelectTabEvent, data: SelectTabData) =>
              onFormFactorChange(Number(data.value) as FormFactor)
            }
          >
            {FORM_FACTORS.map((ff) => (
              <Tab key={ff} value={String(ff)} icon={FORM_FACTOR_ICONS[ff]}>
                <span className={styles.tabLabel}>
                  {FORM_FACTOR_LABELS[ff]}
                  {existingByFormFactor[ff] && (
                    <CheckmarkCircle16Filled
                      className={styles.assignedIcon}
                      aria-label={TAB_ASSIGNED_ICON_ARIA_LABEL}
                    />
                  )}
                </span>
              </Tab>
            ))}
          </TabList>
          <div className={styles.content}>
            {formFactor === 0 && WebPanel}
            {formFactor === 1 && PhonePanel}
            {formFactor === 2 && TabletPanel}
          </div>
        </div>
      </GenericCard>

      <PcfDetailsPanel
        open={isPcfDetailsOpen}
        onOpenChange={setIsPcfDetailsOpen}
        pcf={selectedPcf}
      />
    </>
  );
}
