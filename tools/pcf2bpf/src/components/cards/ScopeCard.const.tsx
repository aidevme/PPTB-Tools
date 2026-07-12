export const RADIO_BUTTON_SOLUTIONS_LABEL = "Solutions";
export const RADIO_BUTTON_PUBLISHERS_LABEL = "Publishers";
export const RADIO_BUTTON_NO_FILTERING_LABEL = "No Filtering";

// Shared across both comboboxes' placeholder-while-loading state and the "Load BPFs" button's
// loading state — literally the same text in every case, so one constant rather than three.
export const LOADING_TEXT = "Loading...";

export const SOLUTION_FIELD_HINT = "Only one solution can be selected.";
export const SOLUTION_COMBOBOX_ARIA_LABEL = "Solution";
export const SOLUTION_COMBOBOX_PLACEHOLDER = "Select a solution...";
export const SOLUTION_OPTION_LOADING_TEXT = "Loading solutions...";
export const SOLUTION_OPTION_NO_ACCESS_TEXT =
    "No solutions were returned — you may not have read access to Solution records in this environment.";
export const SOLUTION_OPTION_NO_MATCH_TEXT = "No solutions match your search.";
export const SOLUTION_OPTION_GROUP_NOT_RECOMMENDED_LABEL = "Not Recommended";
export const SOLUTION_WORD = "solution";

export const PUBLISHER_FIELD_HINT = "Only one publisher can be selected.";
export const PUBLISHER_COMBOBOX_ARIA_LABEL = "Publisher";
export const PUBLISHER_COMBOBOX_PLACEHOLDER = "Select a publisher...";
export const PUBLISHER_OPTION_LOADING_TEXT = "Loading publishers...";
export const PUBLISHER_OPTION_NO_ACCESS_TEXT =
    "No publishers were returned — you may not have read access to Publisher records in this environment.";
export const PUBLISHER_OPTION_NO_MATCH_TEXT = "No publishers match your search.";
export const PUBLISHER_OPTION_PREFIX_LABEL = "Prefix:";
export const PUBLISHER_WORD = "publisher";

export const TOOLTIP_SCOPE_SOLUTION_FRAGMENT = "in the selected solution";
export const TOOLTIP_SCOPE_PUBLISHER_FRAGMENT = "in the selected publisher's solutions";
export const TOOLTIP_SCOPE_UNFILTERED_FRAGMENT = "in the environment, unfiltered";
export const TOOLTIP_ENABLED_PREFIX = "Loads every Business Process Flow";
export const TOOLTIP_ENABLED_SUFFIX =
    ", along with all PCF controls currently registered in the connected environment and their manifest parameters. Run this again after importing a solution that adds a new Business Process Flow or PCF control, since the list is only fetched on click.";
export const TOOLTIP_DISABLED_PREFIX = "Select a";
export const TOOLTIP_DISABLED_SUFFIX = "above to enable loading Business Process Flows.";

export const BUTTON_RELOAD_BPFS_LABEL = "Reload BPFs";
export const BUTTON_LOAD_BPFS_LABEL = "Load BPFs";

export const CARD_TITLE = "Scope";
export const CARD_DESCRIPTION =
    "Choose how to scope which Business Process Flows can be loaded — by solution, by publisher, or unfiltered.";
