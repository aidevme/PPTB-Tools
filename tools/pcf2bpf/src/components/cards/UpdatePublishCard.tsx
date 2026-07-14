import { Button } from "@fluentui/react-components";
import { useUpdatePublishCardStyles } from "../../styles";
import { GenericCard } from "./GenericCard";
import { BUTTON_LABEL, BUTTON_LABEL_PUBLISHING, CARD_DESCRIPTION, CARD_TITLE } from "../../consts/UpdatePublishCard.const";

export interface IUpdatePublishCardProps {
    isDirty: boolean;
    isPublishing: boolean;
    onUpdateAndPublish: () => void;
}

/** Card wrapping the "Update and Publish" action — saves the current form XML and publishes the
 * Business Process Flow's customizations, mirroring the button that used to sit directly in
 * `PcfConfigurationPanel`'s left column. */
export function UpdatePublishCard({ isDirty, isPublishing, onUpdateAndPublish }: IUpdatePublishCardProps) {
    const styles = useUpdatePublishCardStyles();

    return (
        <GenericCard title={CARD_TITLE} description={CARD_DESCRIPTION}>
            <Button
                className={styles.fullWidth}
                appearance="primary"
                size="large"
                disabled={!isDirty || isPublishing}
                onClick={onUpdateAndPublish}
            >
                {isPublishing ? BUTTON_LABEL_PUBLISHING : BUTTON_LABEL}
            </Button>
        </GenericCard>
    );
}
