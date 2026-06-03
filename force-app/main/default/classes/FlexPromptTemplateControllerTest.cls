/**
 * Tests for FlexPromptTemplateController.
 *
 * The real ConnectApi.EinsteinLLM call is replaced through the @TestVisible
 * `generator` seam, so these tests are deterministic and never trigger a
 * billable LLM generation. The stub also records the input names it received,
 * which lets us assert that both the record and free-text inputs are wired up.
 */
@isTest
private class FlexPromptTemplateControllerTest {
    private static final String EMAIL_TEXT = '<p>Hi Acme team, ...</p>';

    /** Returns canned text and records what it was called with. */
    private class StubGenerator implements FlexPromptTemplateController.Generator {
        public String returnValue;
        public String lastTemplateName;
        public String lastRecordId;
        public String lastRecordInputName;
        public String lastFreeTextValue;
        public String lastFreeTextInputName;

        public StubGenerator(String returnValue) {
            this.returnValue = returnValue;
        }

        public String generate(
            String templateName,
            String recordId,
            String recordInputName,
            String freeTextValue,
            String freeTextInputName
        ) {
            this.lastTemplateName = templateName;
            this.lastRecordId = recordId;
            this.lastRecordInputName = recordInputName;
            this.lastFreeTextValue = freeTextValue;
            this.lastFreeTextInputName = freeTextInputName;
            return returnValue;
        }
    }

    /** Always throws, to exercise the error path. */
    private class ThrowingGenerator implements FlexPromptTemplateController.Generator {
        public String generate(
            String templateName,
            String recordId,
            String recordInputName,
            String freeTextValue,
            String freeTextInputName
        ) {
            throw new CalloutException('LLM unavailable');
        }
    }

    @isTest
    static void generateResponse_success_passesBothInputs() {
        StubGenerator stub = new StubGenerator(EMAIL_TEXT);
        FlexPromptTemplateController.generator = stub;

        Test.startTest();
        FlexPromptTemplateController.PromptResponse result = FlexPromptTemplateController.generateResponse(
            'Draft_Account_Outreach',
            '001000000000001AAA',
            'Input:Account',
            'Introduce our onboarding services',
            'Input:Outreach_Goal'
        );
        Test.stopTest();

        Assert.isTrue(result.isSuccess, 'Expected a successful generation');
        Assert.areEqual(EMAIL_TEXT, result.responseText);
        Assert.areEqual('Input:Account', stub.lastRecordInputName);
        Assert.areEqual('Input:Outreach_Goal', stub.lastFreeTextInputName);
        Assert.areEqual(
            'Introduce our onboarding services',
            stub.lastFreeTextValue,
            'The typed free text should pass through to the generator.'
        );
    }

    @isTest
    static void generateResponse_blankInputNames_useDefaults() {
        StubGenerator stub = new StubGenerator(EMAIL_TEXT);
        FlexPromptTemplateController.generator = stub;

        Test.startTest();
        FlexPromptTemplateController.generateResponse(
            'Draft_Account_Outreach',
            '001000000000001AAA',
            null,
            'Some goal',
            ''
        );
        Test.stopTest();

        Assert.areEqual('Input:Account', stub.lastRecordInputName);
        Assert.areEqual('Input:Outreach_Goal', stub.lastFreeTextInputName);
    }

    @isTest
    static void generateResponse_blankTemplate_returnsError() {
        FlexPromptTemplateController.generator = new StubGenerator(EMAIL_TEXT);

        Test.startTest();
        FlexPromptTemplateController.PromptResponse result = FlexPromptTemplateController.generateResponse(
            '',
            '001000000000001AAA',
            'Input:Account',
            'Some goal',
            'Input:Outreach_Goal'
        );
        Test.stopTest();

        Assert.isFalse(result.isSuccess, 'Blank template name should fail');
        Assert.isNotNull(result.errorMessage);
    }

    @isTest
    static void generateResponse_blankRecordId_returnsError() {
        FlexPromptTemplateController.generator = new StubGenerator(EMAIL_TEXT);

        Test.startTest();
        FlexPromptTemplateController.PromptResponse result = FlexPromptTemplateController.generateResponse(
            'Draft_Account_Outreach',
            '',
            'Input:Account',
            'Some goal',
            'Input:Outreach_Goal'
        );
        Test.stopTest();

        Assert.isFalse(result.isSuccess, 'Blank record Id should fail');
        Assert.isNotNull(result.errorMessage);
    }

    @isTest
    static void generateResponse_blankFreeText_returnsError() {
        FlexPromptTemplateController.generator = new StubGenerator(EMAIL_TEXT);

        Test.startTest();
        FlexPromptTemplateController.PromptResponse result = FlexPromptTemplateController.generateResponse(
            'Draft_Account_Outreach',
            '001000000000001AAA',
            'Input:Account',
            '   ',
            'Input:Outreach_Goal'
        );
        Test.stopTest();

        Assert.isFalse(result.isSuccess, 'Blank free text should fail');
        Assert.isNotNull(result.errorMessage);
    }

    @isTest
    static void generateResponse_blankGeneration_returnsError() {
        FlexPromptTemplateController.generator = new StubGenerator(null);

        Test.startTest();
        FlexPromptTemplateController.PromptResponse result = FlexPromptTemplateController.generateResponse(
            'Draft_Account_Outreach',
            '001000000000001AAA',
            'Input:Account',
            'Some goal',
            'Input:Outreach_Goal'
        );
        Test.stopTest();

        Assert.isFalse(result.isSuccess, 'Empty generation should fail');
        Assert.isNotNull(result.errorMessage);
    }

    @isTest
    static void generateResponse_generatorThrows_returnsError() {
        FlexPromptTemplateController.generator = new ThrowingGenerator();

        Test.startTest();
        FlexPromptTemplateController.PromptResponse result = FlexPromptTemplateController.generateResponse(
            'Draft_Account_Outreach',
            '001000000000001AAA',
            'Input:Account',
            'Some goal',
            'Input:Outreach_Goal'
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
        FlexPromptTemplateController.Generator gen = new FlexPromptTemplateController.ConnectApiGenerator();
        Assert.isNotNull(gen, 'Default generator should be constructable');
    }
}