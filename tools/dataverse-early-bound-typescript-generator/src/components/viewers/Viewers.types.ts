import type { useCodeViewerStyles } from '../../styles';

/** The CodeViewer style classes that color a token: every class except the layout ones. */
export type TokenStyle = Exclude<keyof ReturnType<typeof useCodeViewerStyles>, 'code' | 'line' | 'lineNumber' | 'lineContent' | 'flagged' | 'flaggedNumber'>;

/** The FileViewer's tabs: Changes (the diff against the file on disk) and Content (the generated file). */
export type ViewerTab = 'changes' | 'content';
