---
name: enable-agentforce-data-cloud
description: Salesforce org bootstrap workflow for logging in with a supplied username and password, explicitly enabling Data Cloud by switching from the top-left Setup dropdown to Data Cloud Setup and clicking the bottom Get Started button, then enabling Agentforce from Setup > Agentforce Agents. Use when the user asks Codex to authenticate to a Salesforce org and turn on Data Cloud and Agentforce, especially for Agentforce workshop or trial org setup tasks.
---

# Enable Agentforce Data Cloud

## Inputs

Require these inputs from the user or the current task context:

- `username`: Salesforce login username.
- `password`: Salesforce login password. Treat as sensitive and transient; do not write it to files, commands, logs, or final answers.

Optional inputs:

- `alias`: Salesforce CLI alias. Default to a short safe alias derived from the username, such as `principal0` for `principal@0.agentforce`.
- `login_url`: Salesforce login host. Default to `https://login.salesforce.com`.

## Workflow

1. Check existing Salesforce CLI state first:

```bash
sf org list --json
sf org display --target-org <alias> --json
```

If the alias is already authorized for the requested username, reuse it. Otherwise start a browser login:

```bash
sf org login web --alias <alias> --set-default --instance-url <login_url>
```

2. Complete the browser login with Chrome or Computer Use:

- Fill the supplied `username` and `password` only in the Salesforce login page.
- If Salesforce shows saved usernames, choose the option to log in with a different username rather than selecting another account.
- If prompted to allow Salesforce CLI OAuth access, allow it only for the requested username.
- Do not save the password if the browser prompts.
- Wait for the CLI command to report successful authorization and capture the org ID if shown.

3. Start Data Cloud setup. Do not skip this step just because Agentforce can be enabled independently.

```bash
sf org open --target-org <alias> --path lightning/setup/DataCloudSetup/home --json
```

Use the top-left Setup app/dropdown as the primary navigation path:

- Open the top-left `Setup` dropdown/app switcher in Setup.
- Select `Data Cloud Setup`.
- Wait for the Data Cloud Setup page to load.
- Scroll to the bottom of the page.
- Click the bottom `Get Started` button.
- Wait 30-60 seconds after clicking because provisioning status appears slowly.

The left-nav `Data Cloud Setup Home` page and `/lightning/setup/CDPSetupHome/home` route can show status, but do not rely on them as the primary way to start Data Cloud. The required action is the bottom `Get Started` button after entering `Data Cloud Setup` from the top-left dropdown.

If the top-left `Data Cloud Setup` option is not visible, use this fallback only to inspect state:

- In the Setup left navigation, expand `Data Cloud`.
- Wait for the child link `Data Cloud Setup Home` to appear. In these orgs, that child link commonly points to `/lightning/setup/CDPSetupHome/home`.
- Click `Data Cloud Setup Home`.
- Verify the page title or heading is `Data Cloud Setup Home`.

Opening `lightning/setup/SetupOneHome/home` or `lightning/setup/CDPSetupHome/home` is only a generic/status fallback; it is not enough by itself unless it exposes the same bottom `Get Started` button and that button is clicked.

For verification, make the Data Cloud provisioning state the source of truth:

- Verify one of these automated provisioning steps is visible: `Creating your Data Cloud instance`, `Setting up your metadata`, `Initializing the Customer 360 Data Model`, or `Making sure everything is ready to go`.

Treat Data Cloud as enabled/started only after clicking the bottom `Get Started` button from `Data Cloud Setup` or when one of those provisioning steps is visible. Do not report Data Cloud success from `Page not found`, generic `Setup Home`, `Data Cloud Setup Home` alone, or the existence of a `Data Cloud` left-nav item alone. Data Cloud provisioning can continue asynchronously; do not wait for full completion unless the user asks.

4. Enable Agentforce:

```bash
sf org open --target-org <alias> --path lightning/setup/EinsteinCopilot/home --json
```

On the `Agentforce Agents` Setup page, locate the `Agentforce` switch. If it is `Off`, toggle it once and verify the switch reads `On`. If it is already `On`, leave it unchanged and report that it was already enabled.

## UI Automation Notes

- Prefer Chrome for Salesforce auth and Setup pages when the task depends on the user's browser session, cookies, or OAuth callback.
- With Computer Use, call `get_app_state` before interacting with the app in each assistant turn. If a click reports the app is not active, refresh app state and retry against `com.google.Chrome`.
- Salesforce Setup pages may load slowly or reroute between `*.my.salesforce.com` and `*.my.salesforce-setup.com`; verify by visible page headings and controls rather than URL alone.
- Use exact visible labels when possible: top-left `Setup` dropdown, `Data Cloud Setup`, bottom `Get Started`, `Data Cloud Setup Home`, `Set Up Your Data Cloud Instance`, `Agentforce Agents`, and `Agentforce`.
- If automating with Playwright or DOM APIs, prefer the top-left dropdown path to `Data Cloud Setup`, then scroll to and click the bottom `Get Started` button. Ignore top navigation tabs named `Get Started`; they do not start provisioning.

## Failure Handling

- If login fails because credentials are invalid, MFA is required, or OAuth access is denied, stop and report the concrete blocker.
- If the bottom Data Cloud `Get Started` button is absent, disabled, or replaced by an in-progress state, report the visible state. If the page is still `Page not found`, generic `Setup Home`, or merely `Data Cloud Setup Home` without provisioning steps, Data Cloud has not been verified; navigate through the top-left `Data Cloud Setup` dropdown path before reporting.
- If the Agentforce toggle is unavailable, report the current page heading, visible state, and whether Data Cloud provisioning is still active.

## Completion Response

Summarize only the verified outcomes. Do not repeat the password. A good completion response is:

`Done. I logged into <username>, clicked Get Started for Data Cloud setup, and toggled Agentforce to On.`
