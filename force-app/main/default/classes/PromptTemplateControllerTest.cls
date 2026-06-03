/**
 * Tests for PromptTemplateController.
 *
 * The real ConnectApi.EinsteinLLM call is replaced through the @TestVisible
 * `generator` seam, so these tests are deterministic and never trigger a
 * billable LLM generation. Each mock exercises one branch of the controller.
 */
@isTest
private class PromptTemplateControllerTest {
    private static final String SUMMARY_TEXT = 'Acme is a key account with 3 open opportunities.';

    /** Returns canned text and records what it was called with. */
    private class StubGenerator implements PromptTemplateController.Generator {
        public String returnValue;
        public String lastTemplateName;
        public String lastRecordId;
        public String lastInputName;

        public StubGenerator(String returnValue) {
            this.returnValue = returnValue;
        }

        public String generate(
            String templateName,
            String recordId,
            String inputParameterName
        ) {
            this.lastTemplateName = templateName;
            this.lastRecordId = recordId;
            this.lastInputName = inputParameterName;
            return returnValue;
        }
    }

    /** Always throws, to exercise the error path. */
    private class ThrowingGenerator implements PromptTemplateController.Generator {
        public String generate(
            String templateName,
            String recordId,
            String inputParameterName
        ) {
            throw new CalloutException('LLM unavailable');
        }
    }

    @isTest
    static void generateResponse_success_returnsText() {
        StubGenerator stub = new StubGenerator(SUMMARY_TEXT);
        PromptTemplateController.generator = stub;
        String recordId = '001000000000001AAA';

        Test.startTest();
        PromptTemplateController.PromptResponse result = PromptTemplateController.generateResponse(
            'Account_Summary',
            recordId,
            'Input:Account'
        );
        Test.stopTest();

        Assert.isTrue(result.isSuccess, 'Expected a successful generation');
        Assert.areEqual(SUMMARY_TEXT, result.responseText);
        Assert.isNull(result.errorMessage);
        Assert.areEqual('Account_Summary', stub.lastTemplateName);
        Assert.areEqual(
            'Input:Account',
            stub.lastInputName,
            'The provided input parameter name should pass through.'
        );
    }

    @isTest
    static void generateResponse_blankInputName_defaultsToAccount() {
        StubGenerator stub = new StubGenerator(SUMMARY_TEXT);
        PromptTemplateController.generator = stub;

        Test.startTest();
        PromptTemplateController.generateResponse(
            'Account_Summary',
            '001000000000001AAA',
            null
        );
        Test.stopTest();

        Assert.areEqual(
            'Input:Account',
            stub.lastInputName,
            'A blank input name should default to Input:Account.'
        );
    }

    @isTest
    static void generateResponse_blankTemplate_returnsError() {
        PromptTemplateController.generator = new StubGenerator(SUMMARY_TEXT);

        Test.startTest();
        PromptTemplateController.PromptResponse result = PromptTemplateController.generateResponse(
            '',
            '001000000000001AAA',
            'Input:Account'
        );
        Test.stopTest();

        Assert.isFalse(result.isSuccess, 'Blank template name should fail');
        Assert.isNotNull(result.errorMessage);
    }

    @isTest
    static void generateResponse_blankRecordId_returnsError() {
        PromptTemplateController.generator = new StubGenerator(SUMMARY_TEXT);

        Test.startTest();
        PromptTemplateController.PromptResponse result = PromptTemplateController.generateResponse(
            'Account_Summary',
            '',
            'Input:Account'
        );
        Test.stopTest();

        Assert.isFalse(result.isSuccess, 'Blank record Id should fail');
        Assert.isNotNull(result.errorMessage);
    }

    @isTest
    static void generateResponse_blankGeneration_returnsError() {
        PromptTemplateController.generator = new StubGenerator(null);

        Test.startTest();
        PromptTemplateController.PromptResponse result = PromptTemplateController.generateResponse(
            'Account_Summary',
            '001000000000001AAA',
            'Input:Account'
        );
        Test.stopTest();

        Assert.isFalse(result.isSuccess, 'Empty generation should fail');
        Assert.isNotNull(result.errorMessage);
    }

    @isTest
    static void generateResponse_generatorThrows_returnsError() {
        PromptTemplateController.generator = new ThrowingGenerator();

        Test.startTest();
        PromptTemplateController.PromptResponse result = PromptTemplateController.generateResponse(
            'Account_Summary',
            '001000000000001AAA',
            'Input:Account'
        );
        Test.stopTest();

        Assert.isFalse(result.isSuccess, 'A thrown exception should fail');
        Assert.isTrue(
            result.errorMessage.contains('LLM unavailable'),
            'The underlying error message should surface to the caller.'
        );
    }

    @isTest
    static void connectApiGenerator_isInstantiable() {
        // Covers the production seam construction without invoking the LLM.
        PromptTemplateController.Generator gen = new PromptTemplateController.ConnectApiGenerator();
        Assert.isNotNull(gen, 'Default generator should be constructable');
    }
}