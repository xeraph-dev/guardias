# AGENTS.md — Guardias (Tcl/Tk)

## Project purpose
- Desktop application **Guardias** (Tcl/Tk) for managing a team duty/guard calendar.
- Main entry point: `main.tcl`. The app stores data under the platform data directory returned by `get_data_dir()` in `src/helpers.tcl`.

## Stack and dependencies
- Tcl 9.1 + Tk.
- Key packages (see `main.tcl` / scripts): `snit`, `sqlite3`, `msgcat`, `widget::dialog` (Tklib). Tcllib/Tklib components are also bundled/installed via the build scripts (`scripts/common.tcl`, `scripts/prepare.tcl`, `scripts/build.tcl`).
- Localization with `msgcat`; message catalogs in `msgs/` (e.g. `msgs/es.msg`). Default locale: `es` (`DEFAULT_LOCALE` in `main.tcl`).

## Run and build (scripts)
- Development run: `tclsh scripts/run.tcl` (invokes `wish9.1 main.tcl` per `scripts/common.tcl`).
- Prepare toolchain/environment: `tclsh scripts/prepare.tcl ...` (see script options).
- Build artifacts: `tclsh scripts/build.tcl ...` (outputs under `build/`).
- Platform/packaging details: `scripts/common.tcl`, `scripts/prepare.tcl`, `scripts/build.tcl`.

## Code layout and conventions
- `main.tcl`: bootstrap (paths, `auto_path`, recursive `source` of `src/` and `migrations/` via `source_files`, opens SQLite `db`, sets PRAGMAs, runs migrations, loads messages, builds UI with `main-content .content`).
- Application code lives in `src/` (subdirectories such as `src/calendar`, `src/workers`, `src/assign`, etc.). There is no separate app build step; code is loaded by `source`.
- Migrations in `migrations/*.tcl`, registered/executed by `src/migrations.tcl` (`migrations register ...`, `migrations run_pending`).
- Shared helpers in `src/helpers.tcl` (e.g. `find_files`, `get_data_dir`, `center_over`, `update_minsize`). Macros in `src/macros.tcl`.
- Assets in `res/`. Local docs in `docs/`.

## Database
- Global SQLite handle `db` opened in `main.tcl`. PRAGMAs: `foreign_keys=ON`, `journal_mode=WAL`, `synchronous=NORMAL`.
- Schema/versioning via `schema_migrations`, managed by `migrations.tcl`.

## Documentation (required)
- **If you need documentation, use `tclsh scripts/doc.tcl <doc to look up>`** (examples: `tclsh scripts/doc.tcl widget::dialog`, `tclsh scripts/doc.tcl panedwindow`).
  - Do **not** browse random system documentation or hunt generic manuals outside this flow if this repo path applies.
- `scripts/doc.tcl` runs `man` with a project-specific `MANPATH` derived from the toolchain prefix (see the script). Use it to consult relevant man pages/docs for this project environment.

## Change guidelines
- Keep the existing style and patterns (Tcl + snit + loading via `source_files`, messages in `msgs/*.msg`).
- When adding migrations, follow the pattern in `migrations/*.tcl` and `migrations.tcl`.
- Do not introduce new dependencies without reviewing `scripts/common.tcl` and the build scripts.

## Commit conventions
Follow a **Conventional Commits**-style format (lightweight, widely used). Write messages in **English**.

### Format
- `type(scope): short imperative summary`
- Scope is optional but encouraged when it clarifies area (e.g. `calendar`, `workers`, `migrations`, `build`, `docs`).
- Subject: imperative, concise, ideally **≤ 72 characters**, no trailing period.

Examples:
- `feat(calendar): add month navigation controls`
- `fix(workers): prevent duplicate assignment on save`
- `chore: update .gitignore for local artifacts`
- `docs: add AGENTS.md with project guidelines`

### Common types (use the closest match)
- `feat`: new user-visible feature or capability.
- `fix`: bug fix.
- `chore`: maintenance tasks (tooling, deps wiring, repo chores) with no intended user-facing behavior change.
- `docs`: documentation only.
- `refactor`: code change that neither fixes a bug nor adds a feature (structure/clarity).
- `style`: formatting/style-only changes (no logic change) when you truly mean that; avoid mixing with behavior changes.
- `test`: adding or adjusting tests (if/when tests exist).
- `build`: build system or external dependencies (e.g. `scripts/build.tcl`, packaging).
- `ci`: CI configuration/scripts (if added later).
- `perf`: performance improvement.
- `revert`: reverting a previous commit (describe what is reverted in the body if helpful).

### Body and footer (optional)
- Separate subject from body with a blank line.
- Body explains **what** and **why** (not only how). Wrap around **~72 characters**.
- Use footer for references/breaking changes when relevant, e.g. `Refs #123`, or `BREAKING CHANGE: ...` on its own line.

### Rules of thumb
- One logical change per commit when practical; avoid mixing unrelated refactors, formatting-only noise, and feature work.
- Do **not** commit generated/build outputs or local-only artifacts unless the project explicitly tracks them (follow `.gitignore`; be careful with `build/` contents and OS files like `.DS_Store`).

## Verification
- Do not run `tclsh` or `wish` to test or verify changes (ad-hoc snippets,
  launching the app, etc.); the user runs those commands locally.
- Exception: `tclsh scripts/doc.tcl <doc>` is allowed for documentation lookups.
