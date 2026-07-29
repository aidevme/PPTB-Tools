import { useState } from "react";
import { MODULE_CARDS, type IModuleCardData } from "./consts";
import { Footer, Header, HeaderToolbar, Module, ModuleCard } from "./components";
import { useAppStyles } from "./styles";

function App() {
    const styles = useAppStyles();
    const [activeModule, setActiveModule] = useState<IModuleCardData | null>(null);

    return (
        <div className={styles.root}>
            <Header />
            <div className={styles.toolbarRow}>
                <HeaderToolbar />
            </div>

            {activeModule ? (
                <Module title={activeModule.title} description={activeModule.description} module={activeModule.module} />
            ) : (
                <div className={styles.toolGrid}>
                    {MODULE_CARDS.map((tool) => {
                        const Icon = tool.icon;
                        return (
                            <ModuleCard
                                key={tool.key}
                                icon={<Icon />}
                                tag={tool.tag}
                                eyebrow={tool.eyebrow}
                                title={tool.title}
                                description={tool.description}
                                module={tool.module}
                                accentColor={tool.accentColor}
                                onLaunch={() => setActiveModule(tool)}
                            />
                        );
                    })}
                </div>
            )}

            <Footer />
        </div>
    );
}

export default App;
