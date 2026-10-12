import React, { useState } from "react";
import {
  Toolbar,
  ToolbarButton,
  ToggleButton,
  Tooltip,
  
} from "@fluentui/react-components";
import {
  SettingsRegular,
  WeatherMoonRegular,
  WeatherSunnyRegular,
  WindowConsoleRegular,
} from "@fluentui/react-icons";
import { useAppContext } from "../hooks";
import { SettingsPanel } from "./panels/SettingsPanel";

/** Toolbar of header-level actions: a Light/Dark theme toggle, and opening the settings panel. The
 * theme toggle reads/writes `AppContext` directly (see `main.tsx`'s `Root`), overriding whatever
 * mode PPTB originally reported. */
export const HeaderToolbar: React.FC = () => {
  const { themeMode: mode, setThemeMode: setMode } = useAppContext();
  const isDark = mode === "dark";
  const [isSettingsOpen, setIsSettingsOpen] = useState(false);

  return (
    <>
      <Toolbar aria-label="Header actions">
        <Tooltip
          content={`Switch to ${isDark ? "light" : "dark"} theme.`}
          relationship="description"
          positioning="below"
          withArrow
        >
          <ToggleButton
            checked={isDark}
            icon={isDark ? <WeatherMoonRegular /> : <WeatherSunnyRegular />}
            appearance="transparent"
            onClick={() => setMode(isDark ? "light" : "dark")}
          >

          </ToggleButton>
        </Tooltip>
        <Tooltip
          content="Show Console"
          relationship="description"
          positioning="below"
          withArrow
        >
          <ToolbarButton
            icon={<WindowConsoleRegular />}
            appearance="transparent"
          >

          </ToolbarButton>
        </Tooltip>
        
        <Tooltip
          content="Open Security Tools settings."
          relationship="description"
          positioning="below"
          withArrow
        >
          <ToolbarButton
            icon={<SettingsRegular />}
            appearance="transparent"
            onClick={() => setIsSettingsOpen(true)}
          >

          </ToolbarButton>
        </Tooltip>
      </Toolbar>

      <SettingsPanel open={isSettingsOpen} onOpenChange={setIsSettingsOpen} />
    </>
  );
};
