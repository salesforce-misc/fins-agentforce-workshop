## Workshop Markdown Style Guide

This style guide defines how to structure and format workshop instructions that will be read by human participants. It is optimized for **clarity, scannability, and consistency** and is intended to be followed by humans and generative AI systems that produce new workshop docs.

---

### 1. Audience, Tone, and Goals

- **Audience**
  - Salesforce admins, developers, and business users who are completing a guided exercise.
  - Assume basic Salesforce familiarity but **do not** assume deep expertise with the specific feature.

- **Tone**
  - **Friendly, concise, and instructional.**
  - Use **second person ("you")** to speak directly to the participant.
  - Avoid marketing language and unnecessary adjectives; focus on what the user must do and why.

- **Goals**
  - Clearly state **what the participant will accomplish** and **why it matters**.
  - Provide **step-by-step instructions** that can be followed without guessing.
  - Make it easy to **skim** and **resume later** (clear headings, numbered steps, and callouts).

---

### 2. Overall Document Structure

Each workshop document should follow this high-level structure:

1. **Workshop Title (H2)**
2. **Short Overview / Scenario**
3. **What You Will Do / Learn (bulleted list)**
4. **Prerequisites / Setup (optional, if needed)**
5. **Parts / Sections (H3) for each major exercise**
   - Each part may contain sub-steps (H4) and numbered instructions.
6. **Testing / Validation Section**
7. **Wrap-Up / What You Achieved (optional but recommended)**

#### Example high-level outline

- `## Banking and Wealth Agentforce Workshop Overview`
- Short one-paragraph overview of the scenario.
- `We will explore:` followed by a short bullet list.
- `### 1. <First Major Task>`
- `### 2. <Second Major Task>`
- `### 3. Test Your Agent`
- (Additional parts as needed)

---

### 3. Headings and Sections

- **Top-level workshop title**: `##` (H2)
  - Example: `## Banking and Wealth Agentforce Workshop Overview`

- **Major numbered sections / parts**: `###` (H3)
  - Prefix with a number for ordering when there are multiple parts.
  - Example: `### 1. Create Action and Context Variable`

- **Subsections inside a part**: `####` (H4)
  - Use for logical sub-tasks like "Create the flow" or "Configure the flow".

- **Horizontal rules**
  - Use `---` between major parts to visually separate them.

---

### 4. Step-by-Step Instructions

- **Use numbered lists for sequential actions.**
  - Each step should be a complete, clear instruction starting with an **action verb** (Click, Select, Enter, Copy, Paste, etc.).
  - Example:
    1. Click the **Setup** icon and select **Setup**.
    2. In Quick Find, type **Flows**.
    3. Click **New Flow**.

- **Use bullets for non-ordered items or properties.**
  - Example of configuration bullets:
    - **Name**: `accountJson`
    - **Data Type**: `Text`
    - **Allow LLM to use value**: checked

- **One action per step.**
  - Avoid combining multiple independent actions into one step unless they are trivial.

- **Use present tense and second person.**
  - "Click", "Select", "Enter", "Copy", not "You should click" or "You will be selecting".

---

### 5. Formatting Conventions

- **UI labels and navigation**
  - Wrap UI labels, buttons, menu items, and tab names in **bold**.
  - Example: **Agentforce Agents**, **New Variable**, **Flows**, **Next**.
  - When referring to panes or screens, capitalize them: **Topics pane**, **Context tab**.

- **Field names and values**
  - Use **bold** for field labels.
  - Use backticks for literal values or API names.
  - Example:
    - **Reference Action Type**: `Apex`
    - **API Name**: `BWAM_Nearest_Branch`

- **Code, prompts, and long text blocks**
  - Use fenced code blocks with an appropriate language hint (`text`, `json`, `apex`, etc.).
  - Example:

```text
```text
This 'Manage Beneficiaries' topic will allow customers to ask about, add or remove any existing Beneficiaries...
```
```

- **Keyboard-style literals**
  - Use backticks for literal input and system values, such as `MessagingSession EndUserAccountId`.

- **Emphasis**
  - Use **bold** sparingly to highlight key warnings, required settings, or important notes.

---

### 6. Tables

- Use markdown tables to show **field / value / explanation** patterns.
- Example:

```text
| **Field**                     | **Value**               | **Explanation**                                                                   |
| ----------------------------- | ----------------------- | --------------------------------------------------------------------------------- |
| Resource Type                 | Variable                | Variable type                                                                     |
| API Name                      | Account                 | Variable name that is the same as in the flex prompt                             |
| Data Type                     | Record                  | Input is a record                                                                 |
```

- Keep tables **narrow and readable**; avoid more than 3–4 columns when possible.
- Use tables when they reduce scrolling or make comparison easier.

---

### 7. Images and Screenshots

- Reference images using standard markdown or HTML, depending on layout needs.
- Use **descriptive alt text** so that the document remains accessible and understandable even without the image.
  - Example:

```text
<img src="images/aquestion2_1.png"
     alt="Create action and context variable in Agent Builder"
     width="640" />
```

- For side-by-side comparisons or multi-image sequences, use a simple two- or three-column markdown table with images inside each cell.
- Use `width` attributes to keep images readable without overwhelming the page (commonly `320`, `500`, or `640`).

---

### 8. Testing and Validation Sections

- Always include a section to **test what was just built**.
  - Use headings such as:
    - `### 4. Test Our Agent`
    - `### Part 4: Test Your Agentforce in the Builder`

- Provide:
  - Clear instructions on **where** to test (e.g., Conversation Preview, portal site).
  - Example **questions or prompts** the participant can use.
  - A short description of what a **successful outcome** looks like.

- Example structure:
  1. Navigate to the test interface.
  2. Enter or select specific data (e.g., **Kiran Singh**).
  3. Try several prompts or questions.
  4. Explain what the agent should be able to do now.

---

### 9. Readability and Accessibility

- **Short paragraphs**
  - Keep paragraphs to 1–3 sentences where possible.
  - Break long explanations into lists or subsections.

- **Scannability**
  - Use headings, lists, and callouts instead of dense text blocks.
  - Place **critical instructions** early in the sentence.

- **Plain language**
  - Avoid jargon when possible; when it cannot be avoided, briefly define it in context.
  - Prefer concrete language ("Click **Next**") over vague language ("Continue to the next step").

---

### 10. Consistency Rules

- Use **American English** spelling (e.g., "color", "behavior").
- Capitalize Salesforce product names correctly (e.g., **Agentforce**, **Prompt Builder**, **Flow Builder**).
- Use consistent casing for objects and variables:
  - API / code identifiers in backticks, e.g., `BWAM_Grounding_Nearest_Branch`, `accountJson`.
  - UI labels in bold with exact casing from the UI.
- Use `##` only for the workshop title and major top-level sections like new feature segments (for multi-exercise docs). Use `###` and `####` for nested content.

---

### 11. Recommended Generative AI Prompt

Use or adapt this prompt when asking a generative AI to draft or revise a workshop document that follows this style guide:

```text
You are creating a human-readable Salesforce workshop guide in Markdown.

Follow these rules:
- Use a clear workshop structure:
  - H2 title for the workshop.
  - Short overview paragraph describing the scenario and goal.
  - A "We will explore:" or "In this exercise, you will:" section with bullets.
  - Numbered H3 sections (e.g., "### 1. <Task>") for each major part of the exercise.
  - Optional H4 headings to break down sub-tasks (e.g., "#### Create the flow", "#### Configure the flow").
  - A final testing/validation section that shows how to verify the work.
- For instructions:
  - Use numbered lists for sequential actions, one action per step.
  - Start steps with action verbs like "Click", "Select", "Enter", "Copy", "Paste".
  - Use second person ("you") and present tense.
- Formatting:
  - Use **bold** for UI elements, button names, and field labels (e.g., **Agentforce Agents**, **New Variable**).
  - Use backticks for literal values, field values, and API names (e.g., `accountJson`, `BWAM_Grounding_Nearest_Branch`).
  - Use markdown tables for field / value / explanation lists when it improves clarity.
  - Use fenced code blocks (```text) for long snippets or prompt text that must be copied into Salesforce.
- Images:
  - Insert `<img>` tags that reference existing image filenames when they are provided.
  - Always include descriptive alt text and a reasonable width (e.g., 320–640).
- Readability:
  - Keep paragraphs short (1–3 sentences).
  - Prefer concise language and avoid marketing fluff.
  - Explain any non-obvious Salesforce concepts briefly in context.

Apply these rules consistently across the entire document.
```

---

### 12. How to Use This Guide

- When drafting a **new** workshop:
  - Start from the outline in Section 2.
  - Use the prompt in Section 11 with your specific scenario, object names, and images.
- When **reviewing** or **updating** an existing workshop:
  - Check headings and section order.
  - Ensure steps are numbered, actionable, and use the formatting conventions above.
  - Add or refine testing sections so that a participant knows exactly how to validate their work.


