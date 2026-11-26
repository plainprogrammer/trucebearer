# trucebearer-adjudicator

A rules engine, written in plain Ruby, for adjudicating orders in the board game Diplomacy. It has no dependency on Rails. Maps are loaded from data files, and behavior is specified by original test fixtures derived from the DATC scenarios.

The gem is the engine behind [Trucebearer](../README.md). You may depend on it from your own projects under the terms of the AGPL-3.0-or-later (`LICENSE`); see `../TRADEMARKS.md` for how the name may be used.

Status: skeleton only, with no engine yet. The public interface is described in `docs/interface.md`.
