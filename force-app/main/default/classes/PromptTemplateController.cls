/**
 * Controller for the `promptTemplateRunner` LWC.
 *
 * Resolves a Prompt Builder template for a single record and returns the
 * generated text. The component is designed for record pages, so the record
 * Id and template details are passed in from the page context.
 *
 * The ConnectApi call is isolated behind the `Generator` seam so tests can
 * inject a stub without performing a real (billable) LLM generation. There is
 * no platform-provided `setTest...` mock for generateMessagesForPromptTemplate.
 *
 * Reference:
 * https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/connectapi_examples_resolve_prompt_template.htm
 *
 * Prerequisites:
 *   - Einstein Generative AI is enabled in the org.
 *   - The running user has the "Execute Prompt Templates" user permission (and
 *     access to the target prompt template).
 */
public with sharing class PromptTemplateController {
    // Matches the application name used in the official Apex Developer Guide
    // examples for resolving a prompt template with isPreview = false.
    @TestVisible
    private static final String DEFAULT_APPLICATION_NAME = 'PromptTemplateGenerationsInvocable';

    // Seam for the real ConnectApi call. Swappable in tests via @TestVisible.
    @TestVisible
    private static Generator generator = new ConnectApiGenerator();

    /**
     * Resolves a prompt template for the given record and returns the generated
     * text wrapped in a structured result so the LWC can render success and
     * error states inline.
     *
     * @param templateName        Developer name (or Id) of the prompt template.
     * @param recordId            Id of the record that grounds the template.
     * @param inputParameterName  Reference name of the template input, e.g.
     *                            "Input:Account".
     */
    @AuraEnabled
    public static PromptResponse generateResponse(
        String templateName,
        String recordId,
        String inputParameterName
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

        String inputName = String.isBlank(inputParameterName)
            ? 'Input:Account'
            : inputParameterName;

        try {
            String text = generator.generate(templateName, recordId, inputName);

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
            String inputParameterName
        );
    }

    /** Production implementation backed by ConnectApi.EinsteinLLM. */
    public class ConnectApiGenerator implements Generator {
        public String generate(
            String templateName,
            String recordId,
            String inputParameterName
        ) {
            // The template expects a record reference: a map keyed by "id".
            ConnectApi.WrappedValue recordValue = new ConnectApi.WrappedValue();
            recordValue.value = new Map<String, String>{ 'id' => recordId };

            Map<String, ConnectApi.WrappedValue> inputParams = new Map<String, ConnectApi.WrappedValue>();
            inputParams.put(inputParameterName, recordValue);

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