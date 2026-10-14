/**
 * File-system abstraction used by the write planner, plus the PPTB implementation and an in-memory one
 * for tests. All paths are absolute host paths (PPTB's `toolboxAPI.fileSystem` rejects relative ones).
 */

export interface DirectoryEntry {
    name: string;
    type: 'file' | 'directory';
}

export interface FileSink {
    exists(path: string): Promise<boolean>;
    /** Directory listing; resolves to `[]` when the directory does not exist. */
    list(dir: string): Promise<DirectoryEntry[]>;
    /** File contents, or `null` when the file does not exist. */
    read(path: string): Promise<string | null>;
    write(path: string, content: string): Promise<void>;
    /** Create a directory and any missing parents. */
    createDirectory(path: string): Promise<void>;
    /** Delete files; resolves to the paths that still exist afterwards (empty when every delete succeeded). */
    deleteFiles(paths: string[]): Promise<string[]>;
}

/** Whether a path is a Windows one (`C:\…` or `\\server\…`), which decides the shell used to delete files. */
export function isWindowsPath(path: string): boolean {
    return /^[a-zA-Z]:[\\/]/.test(path) || path.startsWith('\\\\');
}

/** Paths deleted per terminal command, to keep each command line well under the shells' length limits. */
const DELETE_BATCH_SIZE = 20;

/**
 * Shell commands that delete `paths`, in batches: PowerShell's `Remove-Item -LiteralPath` for Windows paths (no
 * wildcard expansion), `rm -f --` otherwise. Every path is single-quoted, so spaces, `$` and backticks are literal.
 */
export function buildDeleteCommands(paths: string[]): string[] {
    const commands: string[] = [];
    for (let i = 0; i < paths.length; i += DELETE_BATCH_SIZE) {
        const batch = paths.slice(i, i + DELETE_BATCH_SIZE);
        if (isWindowsPath(batch[0])) {
            const quoted = batch.map((p) => `'${p.replace(/'/g, "''")}'`).join(',');
            commands.push(`Remove-Item -LiteralPath ${quoted} -Force -ErrorAction SilentlyContinue`);
        } else {
            const quoted = batch.map((p) => `'${p.replace(/'/g, `'\\''`)}'`).join(' ');
            commands.push(`rm -f -- ${quoted}`);
        }
    }
    return commands;
}

/** `toolboxAPI.fileSystem` adapter. */
export class PptbFileSink implements FileSink {
    private get fs(): ToolBoxAPI.FileSystemAPI {
        if (!window.toolboxAPI?.fileSystem) throw new Error('The PPTB file system API is not available (not running inside Power Platform ToolBox?)');
        return window.toolboxAPI.fileSystem;
    }

    exists(path: string): Promise<boolean> {
        return this.fs.exists(path);
    }

    async list(dir: string): Promise<DirectoryEntry[]> {
        if (!(await this.fs.exists(dir))) return [];
        return this.fs.readDirectory(dir);
    }

    async read(path: string): Promise<string | null> {
        if (!(await this.fs.exists(path))) return null;
        return this.fs.readText(path);
    }

    write(path: string, content: string): Promise<void> {
        return this.fs.writeText(path, content);
    }

    createDirectory(path: string): Promise<void> {
        return this.fs.createDirectory(path);
    }

    /**
     * PPTB's file system API has no delete, so this runs the commands from {@link buildDeleteCommands} in a hidden
     * PPTB terminal (PowerShell on Windows), closes it, and then checks which files still exist. The check, not
     * the terminal's output, decides what was deleted.
     */
    async deleteFiles(paths: string[]): Promise<string[]> {
        if (paths.length === 0) return [];
        const terminalApi = window.toolboxAPI?.terminal;
        if (!terminalApi) throw new Error('The PPTB terminal API is not available, so files cannot be deleted.');
        const windows = isWindowsPath(paths[0]);
        const terminal = await terminalApi.create({ name: 'Delete orphaned files', shell: windows ? 'powershell.exe' : '/bin/sh', visible: false });
        try {
            for (const command of buildDeleteCommands(paths)) {
                const result = await terminalApi.execute(terminal.id, command);
                if (result.error) console.warn('Deleting orphaned files reported an error', result.error);
            }
        } finally {
            await terminalApi.close(terminal.id).catch((e: unknown) => console.warn('Could not close the delete terminal', e));
        }
        const remaining: string[] = [];
        for (const path of paths) if (await this.fs.exists(path)) remaining.push(path);
        return remaining;
    }
}

/** In-memory implementation for unit tests. Paths are compared case-sensitively, like a Linux disk. */
export class InMemoryFileSink implements FileSink {
    readonly files = new Map<string, string>();
    readonly directories = new Set<string>();

    constructor(initialFiles: Record<string, string> = {}) {
        for (const [path, content] of Object.entries(initialFiles)) this.seed(path, content);
    }

    private parentOf(path: string): string {
        const index = Math.max(path.lastIndexOf('/'), path.lastIndexOf('\\'));
        return index > 0 ? path.substring(0, index) : '';
    }

    seed(path: string, content: string): void {
        this.files.set(path, content);
        let dir = this.parentOf(path);
        while (dir && !this.directories.has(dir)) {
            this.directories.add(dir);
            dir = this.parentOf(dir);
        }
    }

    async exists(path: string): Promise<boolean> {
        return this.files.has(path) || this.directories.has(path);
    }

    async list(dir: string): Promise<DirectoryEntry[]> {
        if (!this.directories.has(dir)) return [];
        const entries = new Map<string, DirectoryEntry>();
        for (const path of [...this.files.keys(), ...this.directories]) {
            if (this.parentOf(path) !== dir) continue;
            const name = path.substring(dir.length + 1);
            entries.set(name, { name, type: this.files.has(path) ? 'file' : 'directory' });
        }
        return [...entries.values()];
    }

    async read(path: string): Promise<string | null> {
        return this.files.get(path) ?? null;
    }

    async write(path: string, content: string): Promise<void> {
        if (!this.directories.has(this.parentOf(path))) throw new Error(`Directory does not exist: ${this.parentOf(path)}`);
        this.files.set(path, content);
    }

    async createDirectory(path: string): Promise<void> {
        let dir = path;
        while (dir && !this.directories.has(dir)) {
            this.directories.add(dir);
            dir = this.parentOf(dir);
        }
    }

    async deleteFiles(paths: string[]): Promise<string[]> {
        for (const path of paths) this.files.delete(path);
        return [];
    }
}
