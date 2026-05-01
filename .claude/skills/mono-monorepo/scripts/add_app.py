#!/usr/bin/env python3
"""
Add an app to an existing mono-monorepo.

Usage:
    add_app.py <app-name> --lang <python|node|go|rust|other> --repo-root <path>

Examples:
    add_app.py scraper --lang python --repo-root ~/Projects/my-saas
    add_app.py api --lang node --repo-root ~/Projects/my-saas
    add_app.py worker --lang go --repo-root ~/Projects/my-saas
    add_app.py tool --lang rust --repo-root ~/Projects/my-saas
"""

import argparse
import sys
from pathlib import Path


def title_from_slug(slug: str) -> str:
    return " ".join(w.capitalize() for w in slug.split("-"))


# ---------------------------------------------------------------------------
# Language-specific scaffolds
# ---------------------------------------------------------------------------

def scaffold_python(app_dir: Path, app_name: str) -> None:
    module_name = app_name.replace("-", "_")

    pyproject = f"""\
[project]
name = "{app_name}"
version = "0.1.0"
requires-python = ">=3.11"
dependencies = []

[tool.pytest.ini_options]
testpaths = ["tests"]
pythonpath = ["."]
"""
    (app_dir / "pyproject.toml").write_text(pyproject)
    (app_dir / "__init__.py").write_text("")

    tests = app_dir / "tests"
    tests.mkdir()
    (tests / "__init__.py").write_text("")


def scaffold_node(app_dir: Path, app_name: str) -> None:
    package_json = f"""\
{{
  "name": "{app_name}",
  "version": "0.1.0",
  "private": true,
  "scripts": {{
    "build": "tsc",
    "test": "echo \\"no tests yet\\""
  }},
  "dependencies": {{}},
  "devDependencies": {{}}
}}
"""
    (app_dir / "package.json").write_text(package_json)

    src = app_dir / "src"
    src.mkdir()
    (src / "index.ts").write_text('console.log("hello");\n')

    (app_dir / "tests").mkdir()


def scaffold_go(app_dir: Path, app_name: str) -> None:
    # Use the app name as the Go module path placeholder.
    # The user will adjust to their actual module path.
    go_mod = f"""\
module {app_name}

go 1.22
"""
    (app_dir / "go.mod").write_text(go_mod)

    main_go = f"""\
package main

import "fmt"

func main() {{
\tfmt.Println("hello")
}}
"""
    (app_dir / "main.go").write_text(main_go)

    main_test = f"""\
package main

import "testing"

func TestMain(t *testing.T) {{
\t// TODO
}}
"""
    (app_dir / "main_test.go").write_text(main_test)


def scaffold_rust(app_dir: Path, app_name: str) -> None:
    cargo_toml = f"""\
[package]
name = "{app_name}"
version = "0.1.0"
edition = "2021"
publish = false

[dependencies]
"""
    (app_dir / "Cargo.toml").write_text(cargo_toml)

    src = app_dir / "src"
    src.mkdir()
    (src / "main.rs").write_text('fn main() {\n    println!("hello");\n}\n')


def scaffold_other(app_dir: Path, app_name: str) -> None:
    (app_dir / "tests").mkdir()


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

SCAFFOLDERS = {
    "python": scaffold_python,
    "node": scaffold_node,
    "go": scaffold_go,
    "rust": scaffold_rust,
    "other": scaffold_other,
}


def add_app(app_name: str, lang: str, repo_root: Path) -> Path:
    apps_dir = repo_root / "code" / "apps"

    if not apps_dir.exists():
        print(f"Error: {apps_dir} does not exist. Is this a mono-monorepo?")
        return None

    app_dir = apps_dir / app_name

    if app_dir.exists():
        print(f"Error: {app_dir} already exists")
        return None

    app_dir.mkdir(parents=True)

    # README
    readme = f"# {title_from_slug(app_name)}\n"
    (app_dir / "README.md").write_text(readme)

    # Language-specific scaffold
    scaffolder = SCAFFOLDERS.get(lang, scaffold_other)
    scaffolder(app_dir, app_name)

    # Remove .gitkeep from code/apps/ if it exists (no longer empty)
    gitkeep = apps_dir / ".gitkeep"
    if gitkeep.exists():
        gitkeep.unlink()

    return app_dir


def main():
    parser = argparse.ArgumentParser(description="Add an app to a mono-monorepo")
    parser.add_argument("app_name", help="App name (kebab-case)")
    parser.add_argument(
        "--lang",
        required=True,
        choices=["python", "node", "go", "rust", "other"],
        help="Language/runtime for the app",
    )
    parser.add_argument("--repo-root", required=True, help="Path to the mono-monorepo root")

    args = parser.parse_args()
    repo_root = Path(args.repo_root).expanduser().resolve()

    if not repo_root.exists():
        print(f"Error: repo root does not exist: {repo_root}")
        sys.exit(1)

    result = add_app(args.app_name, args.lang, repo_root)

    if result:
        print(f"Added app '{args.app_name}' ({args.lang}) at {result}")
        sys.exit(0)
    else:
        sys.exit(1)


if __name__ == "__main__":
    main()
