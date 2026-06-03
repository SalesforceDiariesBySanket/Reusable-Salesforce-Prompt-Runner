# Reusable Salesforce Prompt Runner

Reusable Lightning Web Components and Apex controllers for resolving Salesforce Prompt Builder templates.

## Overview

This repository contains production-ready components for integrating Prompt Builder templates into Salesforce applications. It includes:

- **PromptTemplateRunner LWC**: A component for resolving single-input prompt templates grounded on a record
- **FlexPromptTemplateRunner LWC**: A component for resolving flex prompt templates that accept both record and free-text inputs
- **Apex Controllers**: Testable, mockable controller classes with built-in error handling
- **Unit Tests**: Comprehensive test coverage with dependency injection via test seams

## Components

### PromptTemplateRunner
A record-page component that generates AI-powered summaries or responses based on a single record input.

**Features:**
- Configurable template name
- Customizable card title, button label, and help text
- Built-in error handling and loading states
- Rich-text HTML response display

**Usage:**
Add to a record page and configure the prompt template to use.

### FlexPromptTemplateRunner
A record-page component that combines record data with user-provided free-text input for more flexible prompt resolutions.

**Features:**
- Accepts both record reference and free-text inputs
- Configurable input labels and placeholders
- Loading and error states with inline feedback
- Rich-text HTML response rendering

**Usage:**
Add to a record page for scenarios requiring user input alongside record context.

## Apex Controllers

### PromptTemplateController
Controller for `PromptTemplateRunner` LWC. Handles single-input prompt template resolutions.

**Key Methods:**
- `generateResponse(templateName, recordId, inputParameterName)`: Resolves the template and returns a structured response

### FlexPromptTemplateController
Controller for `FlexPromptTemplateRunner` LWC. Handles multi-input flex prompt templates.

**Key Methods:**
- `generateResponse(templateName, recordId, recordInputName, freeTextValue, freeTextInputName)`: Resolves the template with mixed inputs

## Prerequisites

- Einstein Generative AI enabled in your Salesforce org
- User with "Execute Prompt Templates" permission
- API v63.0 or higher

## Testing

All controllers include comprehensive unit tests with mockable ConnectApi dependencies:

```
PromptTemplateControllerTest - Tests for single-input templates
FlexPromptTemplateControllerTest - Tests for flex templates
```

Tests use dependency injection through `@TestVisible` seams to avoid billable LLM calls.

## Installation

1. Clone this repository
2. Deploy using SFDX: `sfdx force:source:deploy -p force-app`
3. Assign the required permissions to users
4. Add components to record pages as needed

## License

MIT License - See LICENSE file for details
