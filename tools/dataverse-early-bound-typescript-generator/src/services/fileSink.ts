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
}
