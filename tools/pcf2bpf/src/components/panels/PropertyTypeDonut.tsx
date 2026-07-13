import { Text } from "@fluentui/react-components";
import { DonutChart, type ChartDataPoint, type ChartProps } from "@fluentui/react-charts";
import type { PcfParameter, PcfTypeGroup } from "../../services";
import { CATEGORY_COLORS, CATEGORY_LABELS, CATEGORY_ORDER, categorizePcfParameter } from "./pcfParameterCategory";

export interface IPropertyTypeDonutProps {
    parameters: PcfParameter[];
    typeGroups: PcfTypeGroup[];
}

/**
 * Donut chart (Fluent UI `@fluentui/react-charts`) showing the mix of Dataverse type categories
 * (text/number/choice/date/lookup/object) across a PCF control's manifest parameters. Colors come
 * from `CATEGORY_COLORS` (Fluent's own `DataVizPalette`, assigned in a fixed order) so this stays
 * visually consistent with the Properties tab's type swatches; hover callouts, the legend, and
 * keyboard/accessibility behavior are the library's built-in handling rather than anything hand-rolled.
 */
export function PropertyTypeDonut({ parameters, typeGroups }: IPropertyTypeDonutProps) {
    const countByCategory = new Map<string, number>();
    for (const param of parameters) {
        const category = categorizePcfParameter(param, typeGroups);
        countByCategory.set(category, (countByCategory.get(category) ?? 0) + 1);
    }

    const total = parameters.length;
    const points: ChartDataPoint[] = CATEGORY_ORDER.filter((category) => (countByCategory.get(category) ?? 0) > 0).map(
        (category) => ({
            legend: CATEGORY_LABELS[category],
            data: countByCategory.get(category) ?? 0,
            color: CATEGORY_COLORS[category],
        }),
    );

    if (points.length === 0) {
        return (
            <Text italic size={200}>
                No manifest parameters.
            </Text>
        );
    }

    const chartProps: ChartProps = {
        chartTitle: "Property type mix",
        chartData: points,
    };

    return (
        <DonutChart
            culture={typeof window !== "undefined" ? window.navigator.language : "en-us"}
            data={chartProps}
            innerRadius={45}
            height={180}
            hideLegend={false}
            valueInsideDonut={total}
        />
    );
}
