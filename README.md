# FINS Agentforce Workshop

Hands-on Salesforce workshop assets for building Agentforce agents in Financial
Services. The exercises use representative Banking, Wealth, Insurance, and
relationship-management scenarios to show how agents can retrieve context,
invoke actions, apply deterministic instructions, and work with prompts and
flows.

These assets are intended for learning and demonstration. Sample data, prompts,
and configuration should be reviewed and adapted before use in a production
environment.

## What you will build

The workshop provides guided exercises for common financial-services agent
experiences:

| Area | Representative use cases |
| --- | --- |
| Banking and wealth | Answer financial-account questions, manage beneficiaries, and ground a nearest-branch response. |
| Insurance | Answer policy questions, add drivers, update billing preferences, and guide an address change. |
| Relationship management | Analyze income statements, use Document AI and intelligent context, and automate agent testing. |
| Prompt Builder | Route inbound insurance cases and summarize recent policy-case activity. |

Across the exercises, you will create agent actions and context variables,
connect flows and Apex actions, add subagents and instructions, ground responses
with CRM data, test agent behavior, and preview or activate an agent in
Salesforce.

## Repository contents

| Location | Purpose |
| --- | --- |
| `src-static/` | Editable, step-by-step workshop guides and their images. |
| `force-app/` | Salesforce metadata, including the FINS Agentforce app, Agentforce bundle, flows, prompt templates, Apex, permissions, and static resources. |
| `data/` | Representative Financial Services Cloud data and sample documents used by the exercises. |
| `orgInit.sh` | Scratch-org bootstrap script that can deploy the workshop metadata, load the standard data export, assign access, and upload the sample files. |
| `scripts/build-staticresources.sh` | Builds deployable static-resource archives from the guides in `src-static/`. |

## Workshop guides

Start with the setup guide, then select the track that fits your audience.

| Guide | Path | Focus |
| --- | --- | --- |
| Environment setup | `src-static/SETUP/doc.md` | Enable the required capabilities and configure messaging. |
| Banking and wealth | `src-static/BWAMAGENTSCRIPT/doc.md` | Agent actions, Apex actions, beneficiary management, prompt flows, and grounding. |
| Insurance | `src-static/INSAGENTSCRIPT/doc.md` | Policy and quote analysis, driver and billing subagents, and RAG-backed address changes. |
| Relationship assistant | `src-static/GENERALAGENTSCRIPT/doc.md` | Multimodal prompts, Document AI, intelligent context, and automated testing. |
| Prompt Builder | `src-static/PROMPT/doc.md` | Case routing and policy-case summarization. |

## Get started

### Prerequisites

- Salesforce CLI (`sf`) and Node.js.
- A Salesforce Dev Hub if you plan to create a scratch org.
- Access to the Agentforce, Financial Services Cloud, and Data 360 capabilities
  required for the exercises in your environment.

### Create a workshop org

The bootstrap script is the recommended starting point. It creates a scratch
org, deploys the FINS Agentforce metadata, assigns workshop access, imports the
standard Financial Services Cloud data export, and uploads the sample files.

```bash
./orgInit.sh --devhub <your-devhub-alias> --alias fins-af-workshop
```

Pass `--username <username>` to set the scratch-org admin username and email to
the same value. Use `--admin-email <email>` when the admin email should differ
from the username.

To inspect all options, including resuming an existing org or skipping a
specific setup stage:

```bash
./orgInit.sh --help
```

If your environment already exists, deploy the metadata to its authenticated
alias:

```bash
sf project deploy start --source-dir force-app --target-org <your-org-alias>
```

Then use the workshop guides above to configure, test, and activate the
exercises appropriate for your org.

## Maintain the guides

The guides in `src-static/` are the editable sources. When you change a guide
or its images, rebuild its corresponding static resource before deploying:

```bash
npm install
npm run build:staticresources
```

The generated resources are placed in
`force-app/main/default/staticresources/`. Commit the generated resource and
metadata changes along with the source-guide change.

## Validate changes

```bash
npm run lint
npm test
npm run prettier:verify
```

For changes that affect agent configuration or metadata, also deploy to a
workshop org and use the guide's test steps to validate the complete agent
experience.

## Important notes

- Capability availability and setup vary by Salesforce edition, licenses, and
  enabled features. Complete the environment setup before beginning the agent
  exercises.
- The metadata and documentation are workshop assets; they do not by themselves
  deploy, activate, or expose an Agentforce agent.
- Do not use the included representative data as production customer data.

## Contributing

Keep source guides and generated static resources in sync, and validate both
metadata deployment and the relevant agent scenario before submitting changes.
Please follow the repository's [Code of Conduct](CODE_OF_CONDUCT.md).
