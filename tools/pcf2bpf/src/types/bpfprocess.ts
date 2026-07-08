/** A Business Process Flow definition (Dataverse `workflow` record with category = 4). */
export interface BpfProcess {
    workflowid: string;
    name: string;
    uniquename: string;
    primaryentity: string;
    xaml: string;
}
