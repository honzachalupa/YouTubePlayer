Agent Rules

Skills

- Before starting any task, check whether an applicable skill exists in /Users/janchalupa/.agents/skills.
- Prefer using existing skills from /Users/janchalupa/.agents/skills over inventing new workflows.
- Follow the instructions in matching skills exactly unless they conflict with higher-priority project rules.
- If multiple skills are relevant, use the most specific skill available.
- Only proceed without a skill when no suitable skill exists.

Project Ownership

- Do not modify files in external libraries, except for SwiftCore, which is owned by this project.
- Do not modify generated files unless explicitly instructed.

Before Making Changes

- First inspect nearby code and understand existing patterns.
- Search for existing implementations before creating a new one.
- Reuse existing components whenever possible.
- Follow existing architecture, naming conventions, and coding style already present in the project.
- Prefer consistency with nearby code over introducing new patterns.

Code Changes

- Keep changes as small and localized as possible.
- Implement the simplest solution that satisfies the requirements.
- Do not refactor unrelated code.
- Do not rename files, types, functions, variables, or public APIs unless required to solve the task.
- Do not move code between files unless required to solve the task.

Swift & SwiftUI

- Prefer modern Swift and SwiftUI APIs supported by the project’s deployment target.
- Do not introduce deprecated APIs.
- Prefer native Apple frameworks over third-party dependencies when both solve the problem equally well.
- Prefer simple and idiomatic SwiftUI solutions.
- Avoid unnecessary view modifiers, wrappers, abstractions, helper types, coordinators, managers, extensions, or protocols.
- Reuse existing views, modifiers, services, and utilities before creating new ones.

Code Quality

- Never add code that has no observable effect.
- Never leave TODO, FIXME, placeholder, mock, or temporary code unless explicitly requested.
- Remove dead code when encountered as part of the change.
- Do not add compatibility layers, adapters, abstractions, or future-proofing code unless there is a demonstrated need.
- Do not add comments that merely describe what the code does.
- Do not add logging, analytics, telemetry, debug code, or print statements unless requested.

Validation

- After every change to files that are actually built as part of the app target, run the app directly using Xcode's currently active run destination.
- Use Xcode's Run action / `RunProject` for validation; do not run a separate `BuildProject` first unless the user explicitly asks for build-only validation.
- Do not hard-code or switch to a simulator for validation unless explicitly requested; if a device (physical or simulated) is selected in Xcode, run on that device.
- `XcodeBuildMCP build_run_sim` only validates an iOS Simulator and must not be reported as an app run when Xcode's active destination is `My Mac (Designed for iPad)`.
- For `My Mac (Designed for iPad)`, invoke Xcode's actual Run action (`Cmd-R`) with the existing active scheme and destination. Do not try to launch the built iOS `.app` with `open`; Xcode must create and launch its Designed-for-iPad wrapper.
- After invoking Run on `My Mac`, verify that the app process exists with `pgrep -fl '/iOS.app/|/iOS$'`. A valid run has a path containing `Wrapper/iOS.app/iOS`; a successful build without this process is not a successful Run.
- If the active destination is unclear, inspect `xcodebuild -project YouTube.xcodeproj -scheme iOS -showdestinations`. The compatible Mac destination is the `platform:macOS` entry with `variant:Designed for [iPad,iPhone]`; do not substitute a simulator destination.
- Resolve all compiler errors introduced by your changes.
- Resolve all warnings introduced by your changes.
- Verify that the implemented feature actually works before finishing.
- Do not consider the task complete if the project does not build.

Output

- Explain only the files that were changed.
- Explain why each change was necessary.
- Do not describe alternatives that were not implemented.
- If the requested change conflicts with existing project architecture, explain the conflict before making changes.
- Be concise.
