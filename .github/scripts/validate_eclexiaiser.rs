// SPDX-License-Identifier: MPL-2.0
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
// Owner: Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
//
// Validates eclexiaiser.toml structure (called by dogfood-gate.yml).
//
// Ported from validate_eclexiaiser.py — Python is banned by governance policy.
// Dependency-free (no crates) so it builds with the preinstalled `rustc` on
// ubuntu-latest: `rustc -O validate_eclexiaiser.rs -o validate_eclexiaiser`.
// The checks are deliberately shallow, matching the original tomllib validator.

use std::process::exit;

/// Return the slice of `s` before an unquoted `#` (TOML inline comment).
fn strip_inline_comment(s: &str) -> &str {
    let bytes = s.as_bytes();
    let mut quote: Option<u8> = None;
    let mut i = 0;
    while i < bytes.len() {
        let c = bytes[i];
        match quote {
            Some(q) => {
                if c == q {
                    quote = None;
                }
            }
            None => match c {
                b'"' | b'\'' => quote = Some(c),
                b'#' => return &s[..i],
                _ => {}
            },
        }
        i += 1;
    }
    s
}

/// Strip one layer of matching single or double quotes, if present.
fn unquote(s: &str) -> String {
    let t = s.trim();
    let b = t.as_bytes();
    if b.len() >= 2 && (b[0] == b'"' || b[0] == b'\'') && b[b.len() - 1] == b[0] {
        t[1..t.len() - 1].to_string()
    } else {
        t.to_string()
    }
}

#[derive(PartialEq)]
enum Section {
    Other,
    Project,
    Function,
}

fn main() {
    const PATH: &str = "eclexiaiser.toml";
    let content = match std::fs::read_to_string(PATH) {
        Ok(c) => c,
        Err(e) => {
            eprintln!("ERROR: cannot read {PATH}: {e}");
            exit(1);
        }
    };

    let mut project_name = String::new();
    // Each [[functions]] entry collects its own (name, source).
    let mut functions: Vec<(String, String)> = Vec::new();
    let mut section = Section::Other;

    for raw in content.lines() {
        let line = strip_inline_comment(raw).trim();
        if line.is_empty() {
            continue;
        }

        if let Some(inner) = line.strip_prefix("[[").and_then(|l| l.strip_suffix("]]")) {
            if inner.trim() == "functions" {
                functions.push((String::new(), String::new()));
                section = Section::Function;
            } else {
                section = Section::Other;
            }
            continue;
        }
        if let Some(inner) = line.strip_prefix('[').and_then(|l| l.strip_suffix(']')) {
            section = if inner.trim() == "project" {
                Section::Project
            } else {
                Section::Other
            };
            continue;
        }

        let Some(eq) = line.find('=') else { continue };
        let key = line[..eq].trim();
        let value = unquote(&line[eq + 1..]);
        match section {
            Section::Project if key == "name" => project_name = value,
            Section::Function => {
                if let Some(f) = functions.last_mut() {
                    match key {
                        "name" => f.0 = value,
                        "source" => f.1 = value,
                        _ => {}
                    }
                }
            }
            _ => {}
        }
    }

    if project_name.trim().is_empty() {
        eprintln!("ERROR: project.name is required");
        exit(1);
    }
    if functions.is_empty() {
        eprintln!("ERROR: at least one [[functions]] entry is required");
        exit(1);
    }
    for (name, source) in &functions {
        if name.trim().is_empty() {
            eprintln!("ERROR: function name cannot be empty");
            exit(1);
        }
        if source.trim().is_empty() {
            eprintln!("ERROR: function {name} has no source path");
            exit(1);
        }
    }

    println!(
        "Valid: {} ({} function(s))",
        project_name.trim(),
        functions.len()
    );
}
