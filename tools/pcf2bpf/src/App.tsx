import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import {
  Spinner,
  Tab,
  TabList,
  Text,
  Tooltip,
  type SelectTabData,
  type SelectTabEvent,
} from "@fluentui/react-components";
import { Apps20Regular, Code20Regular } from "@fluentui/react-icons";
import {
  useToolContext,
  usePcfContextService,
} from "./services/pptbtoolservice";
import { useConnection } from "./hooks";
import { useAppStyles } from "./styles";
import { Footer, FormXmlPanel, PcfConfigurationPanel } from "./components";
import {
  copyCustomControl,
  getCompatiblePcfControls,
  getExistingCustomControl,
  getFieldsForStage,
  getStages,
  loadBpfFormXml,
  loadEntityAttributes,
  loadEntityDisplayName,
  parseFormXml,
  publishBpf,
  removeCustomControl,
  saveBpfFormXml,
  serializeFormXml,
  setCustomControl,
} from "./services";
import type {
  AttributeInfo,
  FieldInfo,
  FormFactor,
  PcfControl,
  StageInfo,
} from "./services";

type MainTab = "config" | "xml";

function App() {
  const styles = useAppStyles();
  const { connection, isLoading: isConnectionLoading } = useConnection();
  const {
    bpfProcesses,
    selectedBpfId,
    setSelectedBpfId,
    pcfControls,
    isLoadingBpfs,
    isLoadingSolutionsPublishers,
    loadEntityMetadataInfos,
  } = useToolContext();
  const { notify } = usePcfContextService();

  const [activeTab, setActiveTab] = useState<MainTab>("config");

  const [isLoadingForm, setIsLoadingForm] = useState(false);
  const [formError, setFormError] = useState<string | null>(null);

  // Keyed by entity logical name rather than a single flat list/string: multi-entity BPFs (e.g. a
  // Lead → Opportunity sales process) have fields from different entities (see
  // `FieldInfo.entityLogicalName`, resolved from each field's own `relationship` attribute), so
  // attribute metadata and display names must be resolved per entity, not once for `bpf.primaryentity`.
  const [entityAttributesByEntity, setEntityAttributesByEntity] = useState<
    Record<string, AttributeInfo[]>
  >({});
  const [entityDisplayNamesByEntity, setEntityDisplayNamesByEntity] = useState<
    Record<string, string>
  >({});
  const [stages, setStages] = useState<StageInfo[]>([]);
  const [formId, setFormId] = useState<string | null>(null);
  const formDocRef = useRef<XMLDocument | null>(null);
  const [docVersion, setDocVersion] = useState(0);
  const [originalFormXmlText, setOriginalFormXmlText] = useState("");
  const [formXmlText, setFormXmlText] = useState("");
  const [isDirty, setIsDirty] = useState(false);

  const [selectedFormFactor, setSelectedFormFactor] = useState<FormFactor>(0);
  const [selectedField, setSelectedField] = useState<FieldInfo | null>(null);

  const [isPublishing, setIsPublishing] = useState(false);

  const selectedBpf = useMemo(
    () => bpfProcesses.find((b) => b.workflowid === selectedBpfId) ?? null,
    [bpfProcesses, selectedBpfId],
  );

  // The Xml Details tab is disabled without a selected BPF; if the selection is cleared while
  // it's active (e.g. via the BPF combobox's clear button), fall back to the config tab instead
  // of leaving a disabled-looking tab showing stale content.
  useEffect(() => {
    if (!selectedBpf) setActiveTab("config");
  }, [selectedBpf]);

  const resetFormState = useCallback(() => {
    formDocRef.current = null;
    setDocVersion((v) => v + 1);
    setFormId(null);
    setStages([]);
    setEntityAttributesByEntity({});
    setEntityDisplayNamesByEntity({});
    void loadEntityMetadataInfos([]);
    setOriginalFormXmlText("");
    setFormXmlText("");
    setIsDirty(false);
    setSelectedField(null);
  }, [loadEntityMetadataInfos]);

  const handleSelectBpf = useCallback(
    async (workflowId: string) => {
      setSelectedBpfId(workflowId);
      resetFormState();
      setFormError(null);

      const bpf = bpfProcesses.find((b) => b.workflowid === workflowId);
      if (!bpf) return;

      setIsLoadingForm(true);
      try {
        const { formId: loadedFormId, formXml } = await loadBpfFormXml(bpf);
        const doc = parseFormXml(formXml);
        const loadedStages = getStages(doc);

        // Each field resolves its own entity from its <control relationship="..."> attribute
        // (see getFieldEntityLogicalName in services/formxml.ts) — collect every distinct
        // entity actually in play across all stages before loading their metadata.
        const allFields = loadedStages.flatMap((stage) =>
          getFieldsForStage(doc, stage.id, bpf.primaryentity),
        );
        const entityLogicalNames = Array.from(
          new Set([
            bpf.primaryentity,
            ...allFields.map((f) => f.entityLogicalName),
          ]),
        );

        const [entityResults] = await Promise.all([
          Promise.all(
            entityLogicalNames.map(async (entity) => {
              const [displayName, attributes] = await Promise.all([
                loadEntityDisplayName(entity),
                loadEntityAttributes(entity),
              ]);
              return { entity, displayName, attributes };
            }),
          ),
          loadEntityMetadataInfos(entityLogicalNames),
        ]);

        const displayNamesByEntity: Record<string, string> = {};
        const attributesByEntity: Record<string, AttributeInfo[]> = {};
        for (const { entity, displayName, attributes } of entityResults) {
          displayNamesByEntity[entity] = displayName;
          attributesByEntity[entity] = attributes;
        }

        formDocRef.current = doc;
        setFormId(loadedFormId);
        setEntityAttributesByEntity(attributesByEntity);
        setEntityDisplayNamesByEntity(displayNamesByEntity);
        setStages(loadedStages);
        setOriginalFormXmlText(formXml);
        setFormXmlText(serializeFormXml(doc));
        setDocVersion((v) => v + 1);
        await notify(
          "Success",
          `Loaded "${bpf.name}" (${loadedStages.length} stage(s)).`,
          "success",
        );
      } catch (error) {
        console.error("Error loading BPF form:", error);
        setFormError((error as Error).message);
        await notify(
          "Error",
          `Failed to load "${bpf.name}": ${(error as Error).message}`,
          "error",
        );
      } finally {
        setIsLoadingForm(false);
      }
    },
    [bpfProcesses, resetFormState, setSelectedBpfId, loadEntityMetadataInfos],
  );

  const mutateDoc = useCallback((mutator: (doc: XMLDocument) => void) => {
    const doc = formDocRef.current;
    if (!doc) return;
    mutator(doc);
    setFormXmlText(serializeFormXml(doc));
    setDocVersion((v) => v + 1);
    setIsDirty(true);
  }, []);

  const handleApplyPcf = useCallback(
    (pcf: PcfControl, values: Record<string, string>) => {
      if (!selectedField) return;
      mutateDoc((doc) =>
        setCustomControl(doc, selectedField, pcf, selectedFormFactor, values),
      );
    },
    [selectedField, selectedFormFactor, mutateDoc],
  );

  const handleRemovePcf = useCallback(() => {
    if (!selectedField) return;
    mutateDoc((doc) =>
      removeCustomControl(doc, selectedField.controlId, selectedFormFactor),
    );
  }, [selectedField, selectedFormFactor, mutateDoc]);

  const handleCopyFormFactor = useCallback(
    (from: FormFactor, to: FormFactor) => {
      if (!selectedField) return;
      let copied = false;
      mutateDoc((doc) => {
        copied = copyCustomControl(doc, selectedField.controlId, from, to);
      });
      void notify(
        copied ? "Copied" : "Nothing to copy",
        copied
          ? "PCF configuration copied to the target form factor."
          : "The source form factor has no PCF control assigned.",
        copied ? "success" : "warning",
      );
    },
    [selectedField, mutateDoc],
  );

  const handleUpdateAndPublish = useCallback(async () => {
    if (!formId || !formDocRef.current || !selectedBpf) return;
    setIsPublishing(true);
    try {
      await saveBpfFormXml(formId, serializeFormXml(formDocRef.current));
      await publishBpf(selectedBpf);
      setIsDirty(false);
      await notify("Success", "Form saved and published.", "success");
    } catch (error) {
      console.error("Error saving BPF form:", error);
      await notify(
        "Error",
        `Failed to save: ${(error as Error).message}`,
        "error",
      );
    } finally {
      setIsPublishing(false);
    }
  }, [formId, selectedBpf]);

  const attribute = useMemo(
    () =>
      selectedField
        ? (
            entityAttributesByEntity[selectedField.entityLogicalName] ?? []
          ).find((a) => a.logicalName === selectedField.datafieldname)
        : undefined,
    [selectedField, entityAttributesByEntity],
  );

  const selectedFieldEntityDisplayName = selectedField
    ? (entityDisplayNamesByEntity[selectedField.entityLogicalName] ??
      selectedField.entityLogicalName)
    : "";

  const compatibleControls = useMemo(
    () =>
      attribute
        ? getCompatiblePcfControls(attribute.attributeType, pcfControls)
        : [],
    [attribute, pcfControls],
  );

  const selectedStageIndex = useMemo(
    () =>
      selectedField
        ? stages.findIndex((s) => s.id === selectedField.stageId)
        : -1,
    [selectedField, stages],
  );

  const existingAssignment = useMemo(() => {
    const doc = formDocRef.current;
    if (!doc || !selectedField) return null;
    return getExistingCustomControl(
      doc,
      selectedField.controlId,
      selectedFormFactor,
    );
    // docVersion drives recomputation after in-place XML mutations; doc itself never changes identity.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [selectedField, selectedFormFactor, docVersion]);

  useEffect(() => {
    if (!isConnectionLoading && !connection) {
      void notify(
        "Error",
        "Please connect to a Dataverse environment first.",
        "error",
      );
    }
  }, [isConnectionLoading, connection]);

  if (isConnectionLoading) {
    return <Text>Checking connection...</Text>;
  }

  if (!connection) {
    return null;
  }

  const handleTabSelect = (_: SelectTabEvent, data: SelectTabData) => {
    setActiveTab(data.value as MainTab);
  };

  return (
    <div className={styles.root}>
      {(isLoadingBpfs || isLoadingSolutionsPublishers || isLoadingForm) && (
        <div className={styles.loadingOverlay}>
          <Spinner
            size="extra-large"
            label={
              isLoadingForm
                ? "Loading Business Process Flow details..."
                : isLoadingBpfs
                  ? "Loading Business Process Flows and PCF controls..."
                  : "Loading Solutions and Publishers..."
            }
          />
        </div>
      )}

      <TabList selectedValue={activeTab} onTabSelect={handleTabSelect}>
        <Tooltip
          content="Pick a solution or publisher, load its Business Process Flows and registered PCF controls, then select a BPF to browse its stages and fields. Assign, reconfigure, or remove a PCF control on the selected field per form factor (Web/Phone/Tablet), and copy a field's PCF configuration between form factors. Nothing is saved to Dataverse until you click Update and Publish."
          relationship="description"
          positioning="below"
          withArrow
        >
          <Tab value="config" icon={<Apps20Regular />}>
            PCFs Configuration
          </Tab>
        </Tooltip>
        <Tooltip
          content={
            selectedBpf
              ? "Compare the selected Business Process Flow's form XML before and after your changes, with search highlighting and an optional GitHub-style diff view."
              : "Select a Business Process Flow in the PCFs Configuration tab to enable this tab."
          }
          relationship="description"
          positioning="below"
          withArrow
        >
          <Tab value="xml" icon={<Code20Regular />} disabled={!selectedBpf}>
            Xml Details
          </Tab>
        </Tooltip>
      </TabList>

      <div className={styles.contentArea}>
        {/* Both tabs stay mounted, toggled via `hidden`, rather than conditionally rendered —
                    unmounting PcfConfigurationPanel on every tab switch would remount
                    ScopeCard and reset its local search/filter-mode state every time the
                    user came back to this tab. (Solutions/publishers themselves live in ToolContext,
                    above App, so they wouldn't be re-fetched either way.) */}
        <div hidden={activeTab !== "config"}>
          <PcfConfigurationPanel
            onSelectBpf={(id) => void handleSelectBpf(id)}
            selectedBpf={selectedBpf}
            formError={formError}
            doc={formDocRef.current}
            docVersion={docVersion}
            stages={stages}
            entityDisplayNamesByEntity={entityDisplayNamesByEntity}
            selectedFieldEntityDisplayName={selectedFieldEntityDisplayName}
            primaryEntityLogicalName={selectedBpf?.primaryentity ?? ""}
            selectedField={selectedField}
            onSelectField={setSelectedField}
            isDirty={isDirty}
            isPublishing={isPublishing}
            onUpdateAndPublish={() => void handleUpdateAndPublish()}
            attribute={attribute}
            selectedStageIndex={selectedStageIndex}
            compatibleControls={compatibleControls}
            selectedFormFactor={selectedFormFactor}
            onFormFactorChange={setSelectedFormFactor}
            existingAssignment={existingAssignment}
            onApplyPcf={handleApplyPcf}
            onRemovePcf={handleRemovePcf}
            onCopyFormFactor={handleCopyFormFactor}
          />
        </div>

        <div hidden={activeTab !== "xml"}>
          <FormXmlPanel
            beforeXml={originalFormXmlText}
            afterXml={formXmlText}
          />
        </div>
      </div>

      <Footer />
    </div>
  );
}

export default App;
