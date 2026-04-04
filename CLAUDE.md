# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working in this repository.

---

## What This Project Is

This is an early-stage research and development project. The goal is to enable AI agents (Claude Code, Codex, or similar tools) to interact with the **EPA SWMM 5.2.4 desktop GUI application** — the industry-standard stormwater modeling tool used by engineers and hydrologists.

SWMM is a Windows desktop app built in Delphi. Today, engineers use it manually: clicking through dialogs, setting properties one at a time, running simulations, and reading results. There is no API, no scripting interface, and no way for an AI agent to drive it programmatically.

---

## The Problem We Are Solving

Engineers using SWMM spend significant time on repetitive tasks: editing element properties across large networks, running parameter sensitivity studies, comparing multiple scenarios, and interpreting results. These are exactly the kinds of tasks AI agents are good at — but there is no bridge between the agent and the application.

Existing workarounds (UI automation via pywinauto, editing `.inp` files and re-running) are either fragile or require restarting the application for every change, making iterative agent-driven workflows impractical.

---

## The Objective

Build a **thin integration layer** that gives AI agents a reliable, programmatic interface to a live running SWMM session — so an agent can:

- Read and write model element properties directly (junctions, conduits, subcatchments, etc.)
- Trigger simulations and wait for completion
- Retrieve results
- Take screenshots to visually verify state

The integration must work **without modifying the official SWMM installation** — users keep their standard EPA-distributed executable.

---

## What Is in This Repo

- **`SWMM_AGENT_PLUGIN_ARCHITECTURE.md`** — brainstorming document capturing the current thinking on how to build this integration. The architecture is still being designed; treat this as a working draft, not a final spec.
- **`swmm524_gui/`** — the unmodified EPA SWMM 5.2.4 GUI source code (Delphi/Object Pascal). This is reference material for understanding SWMM's internal data structures and how the GUI works. Do not treat this as code to be modified.

---

## Current Status

**Brainstorming / pre-implementation.** No integration code has been written yet. The architecture document reflects one promising approach but decisions are still open. The immediate work is to refine the design before writing any code.
