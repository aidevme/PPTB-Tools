import { useCallback, useMemo, useRef, useState } from "react";
import {
    Button,
    MessageBar,
    MessageBarBody,
    MessageBarTitle,
    Tab,
    TabList,
    Text,
    type SelectTabData,
    type SelectTabEvent,
} from "@fluentui/react-components";
import { Apps20Regular, Code20Regular } from "@fluentui/react-icons";
import { useConnection } from "./hooks";
import { useAppStyles } from "./styles";
import { BpfSelector, CopyFormFactorPanel, FieldPropertiesPanel, Footer, FormXmlPanel, PcfConfigPanel, StagesFields } from "./components";
import {
    copyCustomControl,
    getCompatiblePcfControls,
    getExistingCustomControl,
    getStageColor,
    getStages,
    loadBpfFormXml,
    loadBpfProcesses,
    loadEntityAttributes,
    loadEntityDisplayName,
    loadPcfControls,
    parseFormXml,
    publishBpf,
    removeCustomControl,
    saveBpfFormXml,
    serializeFormXml,
    setCustomControl,
} from "./lib";
import type { AttributeInfo, BpfProcess, FieldInfo, FormFactor, PcfControl, StageInfo } from "./lib";

type MainTab = "config" | "xml";

async function notify(title: string, body: string, type: "success" | "error" | "info" | "warning") {
    try {
        await window.toolboxAPI.utils.showNotification({ title, body, type });
    } catch {
        // Notifications are best-effort.
    }
}

function App() {
    const styles = useAppStyles();
    const { connection, isLoading: isConnectionLoading } = useConnection();

    const [activeTab, setActiveTab] = useState<MainTab>("config");

    const [bpfProcesses, setBpfProcesses] = useState<BpfProcess[]>([]);
    const [pcfControls, setPcfControls] = useState<PcfControl[]>([]);
    const [isLoadingBpfs, setIsLoadingBpfs] = useState(false);

    const [selectedBpfId, setSelectedBpfId] = useState("");
    const [isLoadingForm, setIsLoadingForm] = useState(false);
    const [formError, setFormError] = useState<string | null>(null);

    const [entityAttributes, setEntityAttributes] = useState<AttributeInfo[]>([]);
    const [primaryEntityDisplayName, setPrimaryEntityDisplayName] = useState("");
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

    const selectedBpf = useMemo(() => bpfProcesses.find((b) => b.workflowid === selectedBpfId) ?? null, [bpfProcesses, selectedBpfId]);

    const handleLoadBpfs = useCallback(async () => {
        setIsLoadingBpfs(true);
        try {
            const [processes, controls] = await Promise.all([loadBpfProcesses(), loadPcfControls()]);
            setBpfProcesses(processes);
            setPcfControls(controls);
            await notify("Success", `Loaded ${processes.length} Business Process Flow(s) and ${controls.length} PCF control(s)`, "success");
        } catch (error) {
            console.error("Error loading BPFs:", error);
            await notify("Error", `Failed to load Business Process Flows: ${(error as Error).message}`, "error");
        } finally {
            setIsLoadingBpfs(false);
        }
    }, []);

    const resetFormState = useCallback(() => {
        formDocRef.current = null;
        setDocVersion((v) => v + 1);
        setFormId(null);
        setStages([]);
        setOriginalFormXmlText("");
        setFormXmlText("");
        setIsDirty(false);
        setSelectedField(null);
    }, []);

    const handleSelectBpf = useCallback(
        async (workflowId: string) => {
            setSelectedBpfId(workflowId);
            resetFormState();
            setFormError(null);

            const bpf = bpfProcesses.find((b) => b.workflowid === workflowId);
            if (!bpf) return;

            setIsLoadingForm(true);
            try {
                const [{ formId: loadedFormId, formXml }, attributes, entityDisplayName] = await Promise.all([
                    loadBpfFormXml(bpf),
                    loadEntityAttributes(bpf.primaryentity),
                    loadEntityDisplayName(bpf.primaryentity),
                ]);

                const doc = parseFormXml(formXml);
                formDocRef.current = doc;
                setFormId(loadedFormId);
                setEntityAttributes(attributes);
                setPrimaryEntityDisplayName(entityDisplayName);
                setStages(getStages(doc));
                setOriginalFormXmlText(formXml);
                setFormXmlText(serializeFormXml(doc));
                setDocVersion((v) => v + 1);
            } catch (error) {
                console.error("Error loading BPF form:", error);
                setFormError((error as Error).message);
            } finally {
                setIsLoadingForm(false);
            }
        },
        [bpfProcesses, resetFormState],
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
            mutateDoc((doc) => setCustomControl(doc, selectedField, pcf, selectedFormFactor, values));
        },
        [selectedField, selectedFormFactor, mutateDoc],
    );

    const handleRemovePcf = useCallback(() => {
        if (!selectedField) return;
        mutateDoc((doc) => removeCustomControl(doc, selectedField.controlId, selectedFormFactor));
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
                copied ? "PCF configuration copied to the target form factor." : "The source form factor has no PCF control assigned.",
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
            await notify("Error", `Failed to save: ${(error as Error).message}`, "error");
        } finally {
            setIsPublishing(false);
        }
    }, [formId, selectedBpf]);

    const attribute = useMemo(
        () => (selectedField ? entityAttributes.find((a) => a.logicalName === selectedField.datafieldname) : undefined),
        [selectedField, entityAttributes],
    );

    const compatibleControls = useMemo(
        () => (attribute ? getCompatiblePcfControls(attribute.attributeType, pcfControls) : []),
        [attribute, pcfControls],
    );

    const selectedStageIndex = useMemo(
        () => (selectedField ? stages.findIndex((s) => s.id === selectedField.stageId) : -1),
        [selectedField, stages],
    );

    const existingAssignment = useMemo(() => {
        const doc = formDocRef.current;
        if (!doc || !selectedField) return null;
        return getExistingCustomControl(doc, selectedField.controlId, selectedFormFactor);
        // docVersion drives recomputation after in-place XML mutations; doc itself never changes identity.
        // eslint-disable-next-line react-hooks/exhaustive-deps
    }, [selectedField, selectedFormFactor, docVersion]);

    if (isConnectionLoading) {
        return <Text>Checking connection...</Text>;
    }

    if (!connection) {
        return (
            <MessageBar intent="error">
                <MessageBarBody>
                    <MessageBarTitle>No Connection</MessageBarTitle>
                    Please connect to a Dataverse environment first.
                </MessageBarBody>
            </MessageBar>
        );
    }

    const handleTabSelect = (_: SelectTabEvent, data: SelectTabData) => {
        setActiveTab(data.value as MainTab);
    };

    return (
        <div className={styles.root}>
            <TabList selectedValue={activeTab} onTabSelect={handleTabSelect}>
                <Tab value="config" icon={<Apps20Regular />}>
                    PCFs Configuration
                </Tab>
                <Tab value="xml" icon={<Code20Regular />}>
                    Xml Details
                </Tab>
            </TabList>

            <div className={styles.contentArea}>
                {activeTab === "config" && (
                    <div className={styles.configRow}>
                        <div className={styles.leftColumn}>
                            <BpfSelector
                                bpfProcesses={bpfProcesses}
                                selectedBpfId={selectedBpfId}
                                isLoading={isLoadingBpfs}
                                onLoad={() => void handleLoadBpfs()}
                                onSelect={(id) => void handleSelectBpf(id)}
                            />

                            {formError && (
                                <MessageBar intent="error">
                                    <MessageBarBody>{formError}</MessageBarBody>
                                </MessageBar>
                            )}

                            {isLoadingForm ? (
                                <Text italic>Loading form...</Text>
                            ) : (
                                <StagesFields
                                    doc={formDocRef.current}
                                    docVersion={docVersion}
                                    stages={stages}
                                    entityDisplayName={primaryEntityDisplayName}
                                    selectedControlId={selectedField?.controlId ?? null}
                                    onSelectField={setSelectedField}
                                />
                            )}

                            <Button
                                className={styles.fullWidth}
                                appearance="primary"
                                size="large"
                                disabled={!isDirty || isPublishing}
                                onClick={() => void handleUpdateAndPublish()}
                            >
                                {isPublishing ? "Saving & Publishing..." : "Update and Publish"}
                            </Button>
                        </div>

                        <div className={styles.middleColumn}>
                            {selectedField && selectedStageIndex !== -1 && (
                                <FieldPropertiesPanel
                                    field={selectedField}
                                    attribute={attribute}
                                    entityDisplayName={primaryEntityDisplayName}
                                    stageName={stages[selectedStageIndex].name}
                                    stageColor={getStageColor(selectedStageIndex)}
                                />
                            )}
                            <PcfConfigPanel
                                field={selectedField}
                                entityDisplayName={primaryEntityDisplayName}
                                doc={formDocRef.current}
                                docVersion={docVersion}
                                formFactor={selectedFormFactor}
                                onFormFactorChange={setSelectedFormFactor}
                                attribute={attribute}
                                compatibleControls={compatibleControls}
                                existing={existingAssignment}
                                onApply={handleApplyPcf}
                                onRemove={handleRemovePcf}
                            />
                        </div>

                        {selectedField && (
                            <div className={styles.rightColumn}>
                                <CopyFormFactorPanel onCopy={handleCopyFormFactor} />
                            </div>
                        )}
                    </div>
                )}

                {activeTab === "xml" && <FormXmlPanel beforeXml={originalFormXmlText} afterXml={formXmlText} />}
            </div>

            <Footer />
        </div>
    );
}

export default App;
