import { mergeClasses } from '@fluentui/react-components';
import { useWorkflowProgressStyles } from '../../styles';
import { StepIndicator } from './StepCard';
import { stepElementId, type StepState } from './workflowSteps';

export interface IWorkflowProgressProps {
    steps: StepState[];
}

/**
 * The workflow steps across the top of the page, joined by lines that turn green once the step before them is
 * done. Clicking a step scrolls to its card.
 */
export function WorkflowProgress({ steps }: IWorkflowProgressProps) {
    const styles = useWorkflowProgressStyles();

    const scrollTo = (step: StepState) => {
        const element = document.getElementById(stepElementId(step.key));
        if (!element) return;
        const reduceMotion = window.matchMedia?.('(prefers-reduced-motion: reduce)').matches ?? false;
        element.scrollIntoView?.({ behavior: reduceMotion ? 'auto' : 'smooth', block: 'start' });
    };

    return (
        <nav aria-label="Workflow progress">
            <ol className={styles.list}>
                {steps.map((step, index) => {
                    const last = index === steps.length - 1;
                    return (
                        <li key={step.key} className={mergeClasses(styles.item, last && styles.lastItem)}>
                            <button
                                type="button"
                                className={styles.step}
                                aria-current={step.active ? 'step' : undefined}
                                aria-label={`Step ${step.number}: ${step.title}, ${step.status}. Go to step.`}
                                onClick={() => scrollTo(step)}
                            >
                                <StepIndicator step={step} />
                                <span className={styles.text}>
                                    <span className={styles.title}>{step.title}</span>
                                    <span className={styles.status}>{step.status}</span>
                                </span>
                            </button>
                            {!last && <span className={mergeClasses(styles.connector, step.complete && styles.connectorComplete)} aria-hidden="true" />}
                        </li>
                    );
                })}
            </ol>
        </nav>
    );
}
