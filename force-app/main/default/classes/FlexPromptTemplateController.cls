/**
 * Controller for the `flexPromptTemplateRunner` LWC.
 *
 * Demonstrates a *flex* prompt template, whose defining capability is mixing
 * input types in a single resolution: here a record reference (the Account) is
 * combined with a free-text string the user types in the UI.
 *
 * Compare with PromptTemplateController (a record-summary template) which only
 * passes a single record input. The ConnectApi shape is identical; the flex
 * difference is simply that inputParams holds more than one entry, including a
 * String-valued ConnectApi.WrappedValue.
 *
 * Reference:
 * https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/connectapi_examples_resolve_prompt_template.htm
 *
 * Prerequisites:
 *   - Einstein Generative AI is enabled in the org.
 *   - The running user has the "Execute Prompt Templates" user permission (and
 *     access to the target prompt template).
 */
public with sharing class FlexPromptTemplateController {
    // Matches the application name used in the official Apex Developer Guide
    // examples for resolving a prompt template with isPreview = false.
    @TestVisible
    private static final String DEFAULT_APPLICATION_NAME = 'PromptTemplateGenerationsInvocable';

    // Seam for the real ConnectApi call. Swappable in tests via @TestVisible.
    @TestVisible
    private static Generator generator = new ConnectApiGenerator();

    /**
     * Resolves a flex prompt template that expects one record input and one
     * free-text input, returning the generated text in a structured result.
     *
     * @param templateName       Developer name (or Id) of the flex template.
     * @param recordId           Id of the record that grounds the template.
     * @param recordInputName    Reference name of the record input, e.g.
     *                           "Input:Account".
     * @param freeTextValue      Free-text value the user supplied in the UI.
     * @param freeTextInputName  Reference name of the free-text input, e.g.
     *                           "Input:Outreach_Goal".
     */
    @AuraEnabled
    public static PromptResponse generateResponse(
        String templateName,
        String recordId,
        String recordInputName,
        String freeTextValue,
        String freeTextInputName
    ) {
        PromptResponse result = new PromptResponse();

        if (String.isBlank(templateName)) {
            result.errorMessage = 'A prompt template name is required.';
            return result;
        }
        if (String.isBlank(recordId)) {
            result.errorMessage = 'A record Id is required to ground the prompt.';
            return result;
        }
        if (String.isBlank(freeTextValue)) {
            result.errorMessage = 'Please provide the free-text input the template needs.';
            return result;
        }

        String recordInput = String.isBlank(recordInputName)
            ? 'Input:Account'
            : recordInputName;
        String textInput = String.isBlank(freeTextInputName)
            ? 'Input:Outreach_Goal'
            : freeTextInputName;

        try {
            String text = generator.generate(
                templateName,
                recordId,
                recordInput,
                freeTextValue,
                textInput
            );

            if (String.isBlank(text)) {
                result.errorMessage = 'The prompt template returned no content.';
                return result;
            }

            result.isSuccess = true;
            result.responseText = text;
        } catch (Exception e) {
            result.errorMessage =
                'Could not generate a response: ' + e.getMessage();
            System.debug(LoggingLevel.ERROR, result.errorMessage);
        }

        return result;
    }

    /** Indirection so the ConnectApi dependency can be stubbed in tests. */
    public interface Generator {
        String generate(
            String templateName,
            String recordId,
            String recordInputName,
            String freeTextValue,
            String freeTextInputName
        );
    }

    /** Production implementation backed by ConnectApi.EinsteinLLM. */
    public class ConnectApiGenerator implements Generator {
        public String generate(
            String templateName,
            String recordId,
            String recordInputName,
            String freeTextValue,
            String freeTextInputName
        ) {
            Map<String, ConnectApi.WrappedValue> inputParams = new Map<String, ConnectApi.WrappedValue>();

            // Record input: a wrapped map keyed by "id".
            ConnectApi.WrappedValue recordValue = new ConnectApi.WrappedValue();
            recordValue.value = new Map<String, String>{ 'id' => recordId };
            inputParams.put(recordInputName, recordValue);

            // Free-text input: a wrapped String value.
            ConnectApi.WrappedValue textValue = new ConnectApi.WrappedValue();
            textValue.value = freeTextValue;
            inputParams.put(freeTextInputName, textValue);

            ConnectApi.EinsteinPromptTemplateGenerationsInput input = new ConnectApi.EinsteinPromptTemplateGenerationsInput();
            input.additionalConfig = new ConnectApi.EinsteinLlmAdditionalConfigInput();
            input.additionalConfig.applicationName = DEFAULT_APPLICATION_NAME;
            input.isPreview = false;
            input.inputParams = inputParams;

            ConnectApi.EinsteinPromptTemplateGenerationsRepresentation output = ConnectApi.EinsteinLLM.generateMessagesForPromptTemplate(
                templateName,
                input
            );

            if (output?.generations != null && !output.generations.isEmpty()) {
                return output.generations[0].text;
            }
            return null;
        }
    }

    /** Structured outcome returned to the LWC. */
    public class PromptResponse {
        @AuraEnabled
        public Boolean isSuccess = false;
        @AuraEnabled
        public String responseText;
        @AuraEnabled
        public String errorMessage;
    }
}