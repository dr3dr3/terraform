Drawing on the sources, here is a revised summary including all explicit "I strongly..." suggestions and key stated rules and principles from *Terraform: Up & Running*.

### Explicit "I Strongly Recommend/Suggest" and "Gold Standards"

1.  **Isolated Sandbox Environments:** **I strongly recommend that every team sets up an isolated sandbox environment** where developers can deploy and tear down infrastructure without affecting others. The **gold standard** is that **each developer gets their own completely isolated sandbox environment**, such as their own AWS account, for testing.
2.  **Use of Paid Services:** If you are using IaC tools in production, **I strongly recommend looking into the paid services**, as many of them are well worth the money.
3.  **Documentation (READMEs): I highly recommend to have an amazing readme file** that explains your infrastructure as code, covering code conventions, infrastructure structure, and the logic behind team decisions.
4.  **Code Formatting Automation:** **I recommend running this command** (`terraform fmt`) **as part of a commit hook** to ensure that all code committed uses a consistent style. Running `terraform fmt` is recommended as part of a commit hook to enforce consistent style.

### Stated Rules, Gold Standards, and Key Principles

#### Security and State Management
1.  **Golden Rule of Secrets Management:** The **first rule of secrets management is: Do not store secrets in plain text**. The **second rule of secrets management is: DO NOT STORE SECRETS IN PLAIN TEXT**.
2.  **Database Credentials:** You **should not put database credentials directly into your code in plain text**. Storing credentials in plain text in version control is a bad idea because anyone with access to the version control system has access to that secret.
3.  **State File Manipulation:** You **should never edit the Terraform state files by hand** or write code that reads them directly.
4.  **Prevent Accidental Deletion:** Setting `prevent_destroy` to `true` on a resource is a **good way to prevent accidental deletion of an important resource**.
5.  **Namespacing:** You **must namespace all of your resources** to ensure that multiple tests running in parallel do not conflict.

#### Workflow and Code Quality
6.  **The Golden Rule of Terraform:** The **Golden Rule of Terraform** is that **the main branch of the live repository should be a 1:1 representation of what’s actually deployed in production**.
7.  **Out-of-Band Changes:** After you start using Terraform, **you should only use Terraform**. You should **never make out-of-band changes** to infrastructure managed by Terraform. Making manual changes voids many benefits of IaC.
8.  **Run Plan:** You should **Always run plan before apply**. You should always pause and read the plan output.
9.  **Testing Requirement:** **Infrastructure code without tests is broken**.
10. **DRY Principle:** Follow the **Don’t Repeat Yourself (DRY) principle**: every piece of knowledge must have a single, unambiguous, authoritative representation within a system.
11. **Safety Mechanisms:** You **should include more “safety mechanisms” when working on IaC** than with typical code.
12. **Module Size:** You should **build your code out of small modules that each do one thing**. Smaller modules are easier to create, maintain, use, and test.
13. **Provider Aliases:** You should **caution against using them [provider aliases] too often**, especially when setting up multiregion or multi-account infrastructure, as centralized modules go against the principle of separation and resiliency. **I don’t recommend doing it [using multiple providers in a single module] too often**.
14. **Production Checklist:** When working on a new piece of infrastructure, you should **consciously and explicitly document which items you’ve implemented** from the Production-Grade Infrastructure Checklist, **which ones you’ve decided to skip, and why**.

---
The book mentions that production-grade infrastructure often requires managing dependencies across multiple providers or regions. Would you like to explore the recommended strategies for handling multi-region deployment resilience?