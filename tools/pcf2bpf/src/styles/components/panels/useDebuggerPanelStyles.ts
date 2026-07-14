import { makeStyles, tokens } from "@fluentui/react-components";

export const useDebuggerPanelStyles = makeStyles({
    body: {
        display: "flex",
        flexDirection: "column",
        gap: "12px",
    },
    entityLabel: {
        marginBottom: "-4px",
    },
    tableHeaderCell: {
        fontWeight: tokens.fontWeightSemibold,
    },
    // `table-layout: fixed` so every row honors the header cells' widths below instead of the
    // browser's default auto-layout, which only treats a `<th>` width as a hint — with long `nameCell`
    // content and no clipping, auto-layout let the Name column's text visually spill into the next
    // column's cell rather than wrapping/truncating within its own.
    pcfControlsTable: {
        width: "100%",
        tableLayout: "fixed",
    },
    nameHeaderCell: {
        width: "400px",
    },
    controlTypeHeaderCell: {
        width: "150px",
    },
    templateTypeHeaderCell: {
        width: "150px",
    },
    versionHeaderCell: {
        width: "200px",
    },
    parametersHeaderCell: {
        width: "100px",
    },
    nameCell: {
        display: "flex",
        alignItems: "center",
        gap: "6px",
        minWidth: 0,
    },
    nameText: {
        overflow: "hidden",
        textOverflow: "ellipsis",
        whiteSpace: "nowrap",
        minWidth: 0,
    },
    pagingRow: {
        display: "flex",
        alignItems: "center",
        justifyContent: "space-between",
        marginTop: "4px",
    },
    pagingControls: {
        display: "flex",
        alignItems: "center",
        gap: "8px",
    },
});
