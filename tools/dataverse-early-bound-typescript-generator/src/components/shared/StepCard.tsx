import type { ReactElement, ReactNode } from 'react';
import { Badge, Card, CardHeader, Text, mergeClasses } from '@fluentui/react-components';
import { CheckmarkRegular } from '@fluentui/react-icons';
import { useStepCardStyles } from '../../styles';
import { stepElementId, type StepState } from './workflowSteps';

/** The numbered circle for a step: a check mark once done, brand-colored while it's the active step. */
export function StepIndicator({ step }: { step: StepState }) {
    const styles = useStepCardStyles();
    return (
        <span
            className={mergeClasses(styles.indicator, step.complete && styles.indicatorComplete, step.active && styles.indicatorActive)}
            aria-hidden="true"
        >
            {step.complete ? <CheckmarkRegular /> : step.number}
        </span>
    );
}

export interface IStepCardProps {
    step: StepState;
    /** Explanation under the title: a string (shown as small text) or an element. */
    description: string | ReactElement;
    children: ReactNode;
}

/**
 * A workflow card: a step indicator, title, description and status badge in the header, a brand accent while
 * it's the active step, and an id the progress bar scrolls to.
 */
export function StepCard({ step, description, children }: IStepCardProps) {
    const styles = useStepCardStyles();
    const state = step.complete ? 'done' : step.active ? 'current step' : 'not started';
    return (
        <Card
            id={stepElementId(step.key)}
            className={mergeClasses(styles.card, step.active && styles.active)}
            aria-label={`Step ${step.number}: ${step.title}, ${state}`}
        >
            <CardHeader
                className={styles.header}
                image={<StepIndicator step={step} />}
                header={
                    <Text as="h2" className={styles.title}>
                        {step.title}
                    </Text>
                }
                description={typeof description === 'string' ? <Text size={200}>{description}</Text> : description}
                action={
                    <Badge appearance="tint" color={step.statusColor} className={styles.status}>
                        {step.status}
                    </Badge>
                }
            />
            {children}
        </Card>
    );
}
