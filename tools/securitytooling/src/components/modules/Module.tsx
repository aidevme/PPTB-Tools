import React from "react";
import { Card, Text, Title2 } from "@fluentui/react-components";
import { getModuleContent } from "./moduleRegistry";

export interface IModuleProps {
    /** Name of the module shown as the placeholder's heading. Defaults to `"Module"`. */
    title?: string;
    /** Short description of what the module does. */
    description?: string;
    /** Identifier for the module, matching its `MODULE_CARDS` entry. */
    module?: string;
}

/** Placeholder content view for a Security Tools module. */
export const Module: React.FC<IModuleProps> = ({ title = "Module", description, module }) => {
    const ModuleContent = getModuleContent(module);

    return (
        <Card>
            <Title2>{title}</Title2>
            <Text>This module is not implemented yet.</Text>
            {description && <Text>{description}</Text>}
            {module && <Text>{module}</Text>}
            <ModuleContent module={module} />
        </Card>
    );
};
