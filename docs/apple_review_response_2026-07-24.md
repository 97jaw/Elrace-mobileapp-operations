# App Store Review Response — Elrace (v2.0.6)
Prepared 2026-07-24

## Context / why the review is stuck

Apple has now asked the 3.2 (Business) question twice. Your first reply framed Elrace as an open B2B platform "any company can become a client of." Apple didn't buy it and asked point-blank: *is this app for El Race Contracting's own partners/clients/employees only, and if not, why is it branded for El Race Contracting?*

Codebase check confirms the app is a single-organization tool: package name `el_race`, bundle display name "Elrace Company," UAE Pass (government ID) login, and no self-serve company-signup flow anywhere — just internal ops modules (attendance, HR, tasks, projects, petty cash, chat). You confirmed the actual user base is El Race Contracting's own employees, subcontractors, and El Race Contracting's clients (not unrelated third-party businesses subscribing to a shared platform).

Recommendation: stop arguing for generic public distribution and instead confirm the business-specific nature of the app, then move to **Unlisted App distribution**. This directly satisfies Guideline 3.2, ends the back-and-forth, and (unlike Apple Business Manager Custom Apps) doesn't require your external clients to be enrolled in ABM/ASM themselves — they can still install via a direct link with a regular Apple ID.

---

## Reply to post in App Store Connect Resolution Center

> Hello,
>
> Thank you for the follow-up.
>
> **Guideline 3.2 — Business**
>
> 1. Yes — Elrace is intended exclusively for people affiliated with El Race Contracting's own business operations: our employees, our subcontractors and site partners working on El Race Contracting projects, and the clients we serve on those projects (e.g., project owners/stakeholders who need visibility into site progress, documents, attendance, and communication).
> 2. The app is branded "Elrace Company" because it is our company's own internal operations and field-management tool, built specifically for our organization's workflows. It is not a multi-tenant product marketed or sold to unrelated companies outside our business relationships.
>
> Given this, we agree the app fits Apple's definition of an app intended for a specific business rather than the general public. We will request **Unlisted App distribution** so the app remains available only via direct link to our employees, subcontractors, and clients rather than public discovery, and will submit the unlisted-distribution request per Apple's process.
>
> **Guideline 2.3.6 — Accurate Metadata (Age Rating)**
>
> Confirmed — the app includes messaging/chat functionality for internal team and site communication. We will update the Age Rating questionnaire in App Store Connect to select "Yes" for Messaging and Chat before resubmission.
>
> Please let us know if anything further is needed.

---

## Action items (your side, in order)

1. **Age Rating** — App Store Connect → App Information → Age Rating → set "Messaging and Chat" to **Yes**. Do this regardless of the 3.2 outcome; it's a separate, uncontested finding.
2. **Post the reply above** in the Resolution Center for this submission.
3. **Add a Review Notes line** to your next build's submission stating the app is intended for unlisted distribution (Apple checks for this note as a precondition).
4. **Submit the Unlisted App Request** at https://developer.apple.com/support/unlisted-app-distribution — needs to be filed by the account holder (Apple Developer Program account owner), with your App Name, App ID, and a short description of the business problem and why unlisted fits. Apple confirms by email; the app's Pricing & Availability then shows "Unlisted App" and generates a direct install link for employees/subcontractors/clients.
5. Once switched to Unlisted, resubmit build 2.0.6 (or later) for review.

Note: if it turns out any of the "clients" using the app are actually unrelated companies who could plausibly download this off the public store on their own (not tied to an El Race Contracting engagement), unlisted distribution is the wrong fit and public distribution could still be defensible — but that's not what the codebase or your answer indicates here.

Sources:
- [Unlisted app distribution](https://developer.apple.com/support/unlisted-app-distribution)
- [App Store Connect Help — Set distribution methods](https://www.developer.apple.com/help/app-store-connect/manage-your-apps-availability/set-distribution-methods)
