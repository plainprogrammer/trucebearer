# Implementation Plan: Adjudicate convoys

**Spec:** adjudicator/docs/specs/015-convoys/spec.md (v1.2.0, Approved at Gate A)
**Decisions:** none in `docs/adr/`. The recorded decisions are `docs/architecture.md` and the contract in `adjudicator/docs/interface.md`. The algorithm is spec 014's decision-based resolution, extended as in the spec's "How convoys are adjudicated". The Gate A rulings are in the spec's changelog.
**Created:** 2026-11-26

## Global Constraints

- **Read `spec.md` in full before starting any phase.** Where a phase cites an AC, the spec's wording is what the code must satisfy.
- Change files in `adjudicator/` only. The spec and this plan ship in the same pull request.
- **`docs/interface.md` is not edited.** `TA.adjudicate` keeps its signature and `Resolver` stays `private_constant`. If a phase shows the contract is wrong or contradicts itself, stop and `ask` the coordinator.
- **Two stop-and-ask conditions from Gate A.** (1) If the independent reference (`spec/support/reference.rb`) ever disagrees with the resolver on any board, stop and `ask`; do not widen the rule inside the plan. (2) If any of the twelve pending cases turns out to have exactly one consistent result, the contract's list is wrong: stop and `ask`.
- Never give anything a name that contains or echoes the game's trademarked name or its three-letter prefix: files, classes, methods, specs, comments, fixtures, commit messages.
- No copied rules text and no DATC prose, in code, comments, specs, fixtures or docs. Fixture summaries are in our own words; every case is cited by number only. The DATC overlap check (Phase 6) must find 0 shared 8-word runs over every file the pull request changes.
- No new dependency: standard library only.
- **Test first.** Each phase writes its specs, runs them, and sees them fail for the right reason before it writes the code. Phase 1 commits the first spec alone, red, as the first code commit.
- Run every command from `adjudicator/`. Spec files begin with `require "trucebearer/adjudicator"` and a `require_relative` of the support file they use. Code files begin with `# frozen_string_literal: true`.
- `TA`, `L` and `O` stand for `Trucebearer::Adjudicator`, `TA::Location` and `TA::Order` (`spec/support/board.rb` defines them for the specs).
- `Check` is **not edited**. `Reach` gets one new method (Phase 4). Nothing else in `lib/` changes except `resolver.rb` and a comment in `adjudicator.rb`.
- Commit messages are plain imperative sentences, one commit per phase (plus the red first commit, and one per batch of fixtures), each ending with the attribution line the session gives. One git operation per shell call.
- **The code in this plan was run.** It was written and run in a scratch copy of the gem (outside the repository) before this plan was written; see "What was run". A step that shows a different result than the plan says is a bug to find, not a number to edit.

## What was run (evidence for this plan)

In the scratch copy, with every file of this plan applied:

- The full suite: `2719 examples, 0 failures, 12 pending`; the 12 pending are the skipped "preferred result" examples of the twelve paradox cases, and nothing else. Spec 014's 80 cases and its random-board specs pass unchanged.
- All 58 convoy fixtures (46 encoded, 12 pending) were produced from the notation of Phase 3. The generator asserts the DATC's own success, failure, dislodgement and illegal-order marks for every case, and the flag for the twelve; its `PROBLEMS` list came out empty.
- The reference of Phase 5 agrees with the resolver on all 58 cases: each encoded case has exactly one consistent result and it equals the fixture's; each pending case has none (6.F.16, 6.F.17, 6.F.18, 6.F.24, 6.F.27) or two (6.F.14, 6.F.15, 6.F.22, 6.F.23, 6.F.26, 6.F.28, 6.G.11).
- The reference agrees with the resolver on about 6 600 seeded random convoy boards of 4 to 12 units (flag, and every result and dislodged mark when the flag is clear; about 10 % of boards are paradoxes), and on 300 boards of 13 to 34 units (valid, consistent).
- Mutations, each in the scratch resolver, each caught: widening an open route to full strength (1 of 1 000 boards, and the extra-support example of Phase 4); a move with an open route cuts (59 of 600); a route that needs every carrying fleet instead of one chain (34 of 1 000, and 6.F.9 to 6.F.11); a route kept alive by fleets that are surely dislodged (165 of 1 000). One more, circular movement that ignores routes, is equivalent on every board (an open route never sits in a circle), which is why AC-8.3 and the rule's wording both treat it as unreachable.

## Goal

`TA.adjudicate` adjudicates convoys as `docs/interface.md` promises for 0.2.0: routes, disruption, `by_convoy`, convoys to neighbors, circles and swaps by convoy, and the `paradox` flag for the twelve cases the contract lists, which are detected and not resolved. The DATC cases that need a convoy are fixtures with exact results (126 adjudicated fixtures in all), the twelve paradox cases are fixtures that check the flag and a valid position, an independent brute-force reference and seeded random boards with convoys guard the flag, and the temporary stub is gone.

---

## Pre-implementation gates

- **Simplicity (≤3 components):** the route question in `Resolver` (three values over carrying fleets, using one new `Reach` method), the residue rule (the last four lines of the resolve loop), and the spec-side reference. No new class in `lib/`. No dependency.
- **Anti-abstraction:** no new object in `lib/`. `Resolver#route` and `#dislodged_state` are private methods of the existing class. The reference and the board generator live in `spec/support/` and are not part of the gem.
- **Integration-first:** the contract is `docs/interface.md`. The first spec is its `by_sea` example (Phase 1); the DATC fixtures are committed red before the resolver changes (Phase 3 before Phase 4).

## Decisions the plan settles (spec left them open)

| Decision | Choice | Spec |
|---|---|---|
| Route question | `Resolver#route(move)` returns `:sure`, `:lost` or `:open`. It reads each carrying fleet's `dislodged_state` (true, false or nil) and asks `Reach.linked?` of the seas of the fleets that surely stay (sure) and of those not surely dislodged (possible) | "The route of a move that goes by convoy" |
| Carrying fleets | Computed once per convoyed move, in `@carriers`: the entries whose followed order is a `Convoy` with the same origin and destination | same |
| Widening | `attack` and `prevent` become `widen(move, strength)`: unchanged for a sure route, `[0, 0]` for a lost one, `[0, most]` for an open one. `cuts?` returns true, false or nil | "What a route changes in the conditions" |
| Circles | `circle?` accepts a cycle of three or more, or of two when one move goes by convoy, whose routes are all sure | "Circular movement with convoys" |
| Residue | `fail_residue` replaces `last_resort`: every move still undecided fails and `paradox` is set. No search | "Detecting a paradox" |
| Convoy result | `:unmatched` unless a move that goes by convoy matches; then `:disrupted` when this fleet is dislodged, else `:given` | "Results of the orders" |
| `Reach` | `chain?` keeps its signature and calls the new `Reach.linked?(seas, from, to)`, which is the old loop over a given set of seas | Notes for the plan |
| Fixtures | Written from the compact notation of Phase 3 by a one-off generator that is **not committed**. The DATC's marks are asserted by the generator; labels and standoffs come from the scratch resolver and are confirmed independently by the reference in Phase 5 | AC-6.1, AC-6.6 |
| Pending cases | A `paradox: true` fixture with no `after:`; a `skip`ped "preferred result" example per case | AC-6.2 |
| Reference | `spec/support/reference.rb`: tries every set of move results for at most 12 moves, derives every fact from them, keeps the consistent sets, applies the circle tie-break of AC-8.3 | AC-8.2, AC-8.3 |
| Split | None: about 960 added lines of code, specs and docs apart from fixtures, under the spec's 1 200 threshold. One pull request | Open Question 4 |

## Phases at a glance

| Phase | Deliverable | Commit |
|---|---|---|
| 1 | The `by_sea` and `paradox_pos` examples as real specs, red | "Make the by_sea and paradox_pos examples real specs" |
| 2 | The loader reads `paradox: true` | "Let a DATC fixture mark a convoy paradox that waits for #39" |
| 3 | The 58 fixtures, the runners and the constants; red against the stub | "Encode the convoy cases of 6.B to 6.E", "…of 6.F", "…of 6.G", "Encode the twelve convoy paradoxes that wait for #39" (four commits) |
| 4 | `Reach.linked?`, the resolver, the convoy specs; the stub spec deleted; green | "Give convoys a route and flag the paradox" |
| 5 | The reference, the random convoy boards and their specs | "Check convoys against a brute-force reference and on random boards" |
| 6 | `ruleset.md`, `CHANGELOG.md`, comments, the final checks | "Record the convoy choices and the changelog entry" |

---

## Phase 1: The first spec, red

**Implements:** AC-1.1, AC-1.2, AC-1.3. **Files:** `spec/trucebearer/adjudicator/adjudicate_examples_spec.rb`.

The contract's `by_sea` example becomes a real spec, and so does `paradox_pos`. Edit the examples spec:

```ruby
# header comment, last sentence
# a working convoy are real specs since #15.
```

Replace the comment and the two `pending` lines, and extend the paradox example so it also shows the position is valid:

```ruby
  # AC-1.1 and AC-1.2 of spec 015: the two examples that need convoys.
  it "sends an army by sea when a fleet convoys it (the by_sea example)" do
    by_sea = TA.adjudicate(ln, [O::Move.new(power: :england, at: :lon, destination: L.new(province: :yor)),
                                O::Convoy.new(power: :england, at: :nth, from: :lon, to: :yor)])
    expect(by_sea.outcomes.map(&:result)).to eq(%i[succeeded given])
  end

  it "flags the convoy paradox of the paradox_pos example" do
    # ... the existing position and orders, unchanged, then:
    expect(result.paradox).to be(true)
    expect(result.position).to be_a(TA::Position)
    expect(result.position.units.size + result.position.dislodged_units.size).to eq(4)
  end
```

- [ ] **Step 1:** make the edit. Run `bundle exec rspec spec/trucebearer/adjudicator/adjudicate_examples_spec.rb`. Expected: the two examples fail (`got: [:no_route, :unmatched]`, and `paradox` false); the rest pass.
- [ ] **Step 2:** commit, red, as the first code commit: "Make the by_sea and paradox_pos examples real specs".

---

## Phase 2: The loader reads `paradox: true`

**Implements:** AC-6.4. **Files:** `spec/datc/datc_loader_spec.rb`, `spec/support/datc.rb`.

- [ ] **Step 1: the spec first.** In `datc_loader_spec.rb`, add before `it "reads a real file with no classes and no aliases"`:

```ruby
  it "reads a paradox mark, and refuses one with an after or any value but true (AC-6.4 of spec 015)" do
    pending_case = good.merge("paradox" => true)
    expect(parse(pending_case).paradox).to be(true)
    expect(parse(good).paradox).to be(false)
    with_after = pending_case.merge("orders" => [good["orders"][0].merge("result" => "held")],
                                    "after" => { "units" => [{ "power" => "england", "type" => "fleet", "at" => "lon" }] })
    [with_after, good.merge("paradox" => false), good.merge("paradox" => "yes"),
     pending_case.merge("orders" => [good["orders"][0].merge("result" => "held")])].each do |data|
      expect { parse(data) }.to raise_error(Datc::FormatError, /6\.X\.1/)
    end
  end
```

Run it: it fails (`unknown key "paradox"`, `undefined method paradox`).

- [ ] **Step 2: the loader.** In `spec/support/datc.rb`: add `:paradox` to the case struct, add `paradox` to `TOP_KEYS`, extend the header comment, and read the key in `parse`:

```ruby
# header comment: add after the `after:` paragraph
# A case with `paradox: true` holds a convoy paradox whose result is pending (#39): it has no
# `after:` and no `result:`, and is only tested for the flag and a valid position.

  Case = Data.define(:id, :departure, :position, :entries, :after, :paradox)
  TOP_KEYS = %w[case summary departure paradox position orders after].freeze

    # in parse, before `after = ...`
    paradox = data.fetch("paradox", false)
    fail!(name, "\"paradox\" must be true when given, got #{paradox.inspect}") unless [true, false].include?(paradox) && (paradox || !data.key?("paradox"))
    fail!(name, "a case with \"paradox\" has no \"after\", since its result is pending") if paradox && data.key?("after")
    after = data.key?("after") ? build_after(data["after"], position, entries, name) : nil
    fail!(name, "an order has a \"result\" but the case has no \"after\"") if after.nil? && entries.any?(&:result)
    Case.new(id: name, departure: departure, position: position, entries: entries, after: after, paradox: paradox)
```

(The last two lines replace the existing ones; a `result:` in a paradox case is refused by the rule that was already there.) Run `bundle exec rspec spec/datc/datc_loader_spec.rb`: green. Run the whole suite: still green except Phase 1's two.
- [ ] **Step 3:** commit "Let a DATC fixture mark a convoy paradox that waits for #39".

---

## Phase 3: The fixtures, the runners and the constants

**Implements:** AC-6.1, AC-6.2, AC-6.3 (partly: Phase 5 finishes it), AC-6.5, AC-6.7. **Files:** 58 files in `spec/datc/` (46 encoded: 43 new and 3 existing that gain `result:` and `after:`; 12 pending: new), `spec/support/datc.rb`, `spec/datc/datc_check_spec.rb`, `spec/datc/datc_adjudicate_spec.rb`.

### 3.1 The notation and the generator (a scratch tool, never committed)

Create a scratch directory outside the repository (for example under the session scratchpad), copy `adjudicator/` into it as `proto/`, and apply Phases 4 and 5's `lib/` code to the copy (this is the resolver the fixtures are read from). Put the two files below in a `gen/` folder beside it. `cases.rb` is the data: each unit is written `"<A|F> <prov>[/coast]<order>"`, where the order is `-dest` (a move), `-dest via` (move via convoy), ` c from-to` (convoy), ` s from-to` (support move), ` s prov` (support hold) or ` h` (hold), and the flags after `;` are the DATC's own marks, read from the reference copy and not quoted: `S` the move succeeds, `F` it fails, `D` the unit is dislodged, `I` the order is illegal. The generator refuses to write a fixture unless every flag holds, the legality of every order matches its `I`, and the paradox flag equals "is in `PARADOX`".

`gen/cases.rb`:

```ruby
# frozen_string_literal: true

# Compact notation for the convoy cases. Each unit is "<A|F> <prov>[/coast] <order>" with an
# optional ";flags" suffix: S = the move succeeds, F = the move fails, D = the unit is
# dislodged, I = the order is illegal. The flags come from the DATC's own listing (read, not
# quoted) and are asserted against the prototype before a fixture is written.
CASES = {
  "6.B.18" => ["A convoy that starts in a split-coast province, and its convoy order, are legal",
               { turkey: ["A bul-sev ;S", "F bla c bul-sev"] }],
  "6.B.19" => ["A convoy that ends in a split-coast province, and its convoy order, are legal",
               { italy: ["A tus-spa ;S", "F gol c tus-spa"] }],
  "6.C.4" => ["A circle of three moves holds a convoyed army, and a convoy fleet that is attacked but not dislodged",
              { austria: ["A tri-ser ;S", "A ser-bul ;S"],
                turkey: ["A bul-tri ;S", "F aeg c bul-tri", "F ion c bul-tri", "F adr c bul-tri"],
                italy: ["F nap-ion ;F"] }],
  "6.C.5" => ["A convoy fleet in a circle is dislodged, so every army of the circle stays",
              { austria: ["A tri-ser ;F", "A ser-bul ;F"],
                turkey: ["A bul-tri ;F", "F aeg c bul-tri", "F ion c bul-tri ;D", "F adr c bul-tri"],
                italy: ["F nap-ion ;S", "F tun s nap-ion"] }],
  "6.C.6" => ["Two armies swap places by two convoys",
              { england: ["F nth c lon-bel", "A lon-bel ;S"], france: ["F eng c bel-lon", "A bel-lon ;S"] }],
  "6.C.7" => ["One army of a swap by convoy is stopped by a third unit, so neither moves",
              { england: ["F nth c lon-bel", "A lon-bel ;F"],
                france: ["F eng c bel-lon", "A bel-lon ;F", "A bur-bel ;F"] }],
  "6.D.6" => ["A fleet that is convoying may be supported to hold",
              { germany: ["A ber-swe ;S", "F bal c ber-swe", "F pru s bal"],
                russia: ["F lvn-bal ;F", "F bot s lvn-bal"] }],
  "6.D.16" => ["A power may convoy a foreign army that dislodges its own unit",
               { england: ["A lon h ;D", "F nth c bel-lon"], france: ["F eng s bel-lon", "A bel-lon ;S"] }],
  "6.E.11" => ["A swap by convoy with a fleet on a split-coast province, the attacker behind is stopped",
               { france: ["A spa-por via ;S", "F mao c spa-por", "F gol s por-spa"],
                 germany: ["A mar s gas-spa", "A gas-spa ;F"],
                 italy: ["F por-spa/nc ;S", "F wes s por-spa"] }],
  "6.F.2" => ["A convoyed army bounces like any other",
              { england: ["F eng c lon-bre", "A lon-bre ;F"], france: ["A par-bre ;F"] }],
  "6.F.3" => ["A convoyed army can be supported",
              { england: ["F eng c lon-bre", "A lon-bre ;S", "F mao s lon-bre"], france: ["A par-bre ;F"] }],
  "6.F.4" => ["An attack on a convoying fleet that doesn't dislodge it changes nothing",
              { england: ["F nth c lon-hol", "A lon-hol ;S"], germany: ["F ska-nth ;F"] }],
  "6.F.5" => ["A convoying fleet in a beleaguered province is not dislodged",
              { england: ["F nth c lon-hol", "A lon-hol ;S"],
                france: ["F eng-nth ;F", "F bel s eng-nth"],
                germany: ["F ska-nth ;F", "F den s ska-nth"] }],
  "6.F.6" => ["A dislodged convoying fleet cancels the convoy, so the army it carried cuts no support",
              { england: ["F nth c lon-hol ;D", "A lon-hol ;F"],
                germany: ["A hol s bel", "A bel s hol", "F hel s ska-nth", "F ska-nth ;S"],
                france: ["A pic-bel ;F", "A bur s pic-bel"] }],
  "6.F.7" => ["A dislodged convoying fleet leaves the landing province uncontested (movement step)",
              { england: ["F nth c lon-hol ;D", "A lon-hol ;F"], germany: ["F hel s ska-nth", "F ska-nth ;S"] }],
  "6.F.8" => ["The army's fleet is dislodged, so its destination stays open to another unit",
              { england: ["F nth c lon-hol ;D", "A lon-hol ;F"],
                germany: ["F hel s ska-nth", "F ska-nth ;S", "A bel-hol ;S"] }],
  "6.F.9" => ["A convoy with two routes survives the loss of one fleet",
              { england: ["F eng c lon-bel ;D", "F nth c lon-bel", "A lon-bel ;S"],
                france: ["F bre s mao-eng", "F mao-eng ;S"] }],
  "6.F.10" => ["A convoy with two routes, one fleet foreign, survives the loss of the foreign fleet",
               { england: ["F nth c lon-bel", "A lon-bel ;S"], germany: ["F eng c lon-bel ;D"],
                 france: ["F bre s mao-eng", "F mao-eng ;S"] }],
  "6.F.11" => ["A convoy with two routes, both fleets foreign, survives the loss of one",
               { england: ["A lon-bel ;S"], germany: ["F eng c lon-bel ;D"], russia: ["F nth c lon-bel"],
                 france: ["F bre s mao-eng", "F mao-eng ;S"] }],
  "6.F.12" => ["A dislodged fleet whose convoy order is illegal is on no route, so the convoy stands",
               { england: ["F eng c lon-bel", "A lon-bel ;S", "F iri c lon-bel ;I,D"],
                 france: ["F nao s mao-iri", "F mao-iri ;S"] }],
  "6.F.13" => ["The other route carries the army even when its owner wanted the dislodged one",
               { england: ["A lon-bel ;S", "F nth c lon-bel ;D"], france: ["F eng c lon-bel"],
                 germany: ["F hol s den-nth", "F den-nth ;S"] }],
  "6.F.14" => ["The simplest paradox: the attacked unit supports an attack on a convoying fleet",
               { england: ["F lon s wal-eng", "F wal-eng"], france: ["A bre-lon", "F eng c bre-lon"] }],
  "6.F.15" => ["The simplest paradox next to an unrelated convoy",
               { england: ["F lon s wal-eng", "F wal-eng"], france: ["A bre-lon", "F eng c bre-lon"],
                 italy: ["F iri c naf-wal", "F mao c naf-wal", "A naf-wal"] }],
  "6.F.16" => ["Pandin-style paradox: the supporter that the army attacks shields the fleet through a beleaguered province",
               { england: ["F lon s wal-eng", "F wal-eng"], france: ["A bre-lon", "F eng c bre-lon"],
                 germany: ["F nth s bel-eng", "F bel-eng"] }],
  "6.F.17" => ["The same shape, but the army's destination can displace the unit that shields its fleet",
               { england: ["F lon s wal-eng", "F wal-eng"],
                 france: ["A bre-lon", "F eng c bre-lon", "F yor s bre-lon"],
                 germany: ["F nth s bel-eng", "F bel-eng"] }],
  "6.F.18" => ["A paradox where the attacked unit supports the convoying fleet itself",
               { england: ["F nth c lon-bel", "A lon-bel", "F eng s lon-bel"], france: ["F bel s nth"],
                 germany: ["F hel s ska-nth", "F ska-nth"] }],
  "6.F.19" => ["A convoy with two routes: the other route decides, so no paradox",
               { france: ["A tun-nap ;F", "F tys c tun-nap", "F ion c tun-nap"],
                 italy: ["F nap s rom-tys", "F rom-tys ;F"] }],
  "6.F.20" => ["A convoy whose other route keeps the move alive, so the support is cut and the fleet falls",
               { france: ["A tun-nap ;F", "F tys c tun-nap"],
                 italy: ["F nap s ion", "F ion c tun-nap ;D"],
                 turkey: ["F aeg s eas-ion", "F eas-ion ;S"] }],
  "6.F.21" => ["A convoyed army cuts a support that is not part of a paradox",
               { russia: ["A edi s nwy-cly", "F nwg c nwy-cly", "A nwy-cly ;S"],
                 france: ["F iri s mao-nao", "F mao-nao ;S"],
                 england: ["A lvp-cly via ;F", "F nao c lvp-cly ;D", "F cly s nao ;D"] }],
  "6.F.22" => ["A second-order paradox: two convoys tied together",
               { england: ["F edi-nth", "F lon s edi-nth"], france: ["A bre-lon", "F eng c bre-lon"],
                 germany: ["F bel s pic-eng", "F pic-eng"], russia: ["A nwy-bel", "F nth c nwy-bel"] }],
  "6.F.23" => ["A second-order paradox with two exclusive convoys",
               { england: ["F edi-nth", "F yor s edi-nth"], france: ["A bre-lon", "F eng c bre-lon"],
                 germany: ["F bel s eng", "F lon s nth"], italy: ["F mao-eng", "F iri s mao-eng"],
                 russia: ["A nwy-bel", "F nth c nwy-bel"] }],
  "6.F.24" => ["A second-order paradox with no consistent result",
               { england: ["F edi-nth", "F lon s edi-nth", "F iri-eng", "F mao s iri-eng"],
                 france: ["A bre-lon", "F eng c bre-lon", "F bel s eng"], russia: ["A nwy-bel", "F nth c nwy-bel"] }],
  "6.F.25" => ["A support cut last: cuts from convoyed armies unwind a whole chain of dependencies",
               { germany: ["A ruh-bel ;F", "A hol s ruh-bel ;D", "A den-nwy ;S", "F ska c den-nwy", "A fin s den-nwy"],
                 england: ["A yor-hol ;S", "F nth c yor-hol", "F hel s yor-hol", "A bel h"],
                 russia: ["F nwg-nth ;F", "F nwy s nwg-nth ;D", "F swe-ska ;F"] }],
  "6.F.26" => ["The simplest paradox next to more convoys that are related to it",
               { england: ["F lon s wal-eng", "F wal-eng"], france: ["A bre-lon", "F eng c bre-lon"],
                 italy: ["A gas s spa-bre", "A spa-bre", "F mao c spa-bre"],
                 russia: ["A cly-wal", "F nao c cly-wal", "F iri c cly-wal"] }],
  "6.F.27" => ["Two separate paradoxes at once",
               { england: ["F nth c lon-bel", "A lon-bel", "F eng s lon-bel"], france: ["F bel s nth"],
                 germany: ["F hel s ska-nth", "F ska-nth"], italy: ["A tun-gre", "F ion c tun-gre"],
                 turkey: ["F aeg-ion", "F gre s aeg-ion"] }],
  "6.F.28" => ["A ring of six convoyed armies, each convoy fleet attacked",
               { russia: ["F fin-bot", "F stp/sc s fin-bot", "F pru-bal", "F swe s pru-bal", "F ska-nth", "F den s ska-nth",
                          "F nwy-nwg", "F cly s nwy-nwg"],
                 germany: ["A lvn-swe", "F bot c lvn-swe", "A ber-den", "F bal c ber-den", "A hol-lon", "F nth c hol-lon",
                           "A bel-bre", "F eng c bel-bre"],
                 england: ["F wal-eng", "F lon s wal-eng", "A naf-cly", "F mao c naf-cly", "F nao c naf-cly",
                           "A edi-stp", "F nwg c edi-stp", "F bar c edi-stp"],
                 france: ["F spa/nc-mao", "F bre s spa-mao"] }],
  "6.F.29" => ["The same ring with one more support for a fleet, so no paradox and every attack fails",
               { russia: ["F fin-bot ;F", "F stp/sc s fin-bot", "F pru-bal ;F", "F swe s pru-bal", "F ska-nth ;F",
                          "F den s ska-nth", "F nwy-nwg ;F", "F cly s nwy-nwg"],
                 germany: ["A lvn-swe ;F", "F bot c lvn-swe", "A ber-den ;F", "F bal c ber-den", "A hol-lon ;F",
                           "F nth c hol-lon", "A bel-bre ;F", "F eng c bel-bre"],
                 england: ["F wal-eng ;F", "F lon s wal-eng", "A naf-cly ;F", "F mao c naf-cly", "F nao c naf-cly",
                           "A edi-stp ;F", "F nwg c edi-stp", "F bar c edi-stp", "F por s mao"],
                 france: ["F spa/nc-mao ;F", "F bre s spa-mao"] }],
  "6.F.30" => ["A convoyed attack counts as coming from the army's own province",
               { england: ["A lon-bel ;F", "F eng c lon-bel ;D", "F nth s lon-bel"],
                 france: ["F bel-eng ;S", "F bre s bel-eng"] }],
  "6.G.1" => ["Two armies swap provinces with one convoy",
              { england: ["A nwy-swe ;S", "F ska c nwy-swe"], russia: ["A swe-nwy ;S"] }],
  "6.G.2" => ["A foreign convoy order gives no intent: the armies stay",
              { england: ["A nwy-swe ;F"], russia: ["F swe-nwy ;F"], germany: ["F ska c nwy-swe"] }],
  "6.G.3" => ["An unwanted convoy of a neighbor move by a foreign fleet is not used",
              { france: ["F bre-eng ;S", "A pic-bel ;S", "A bur s pic-bel", "F mao s bre-eng"],
                england: ["F eng c pic-bel ;D"] }],
  "6.G.4" => ["The same, with a unit moving the other way",
              { france: ["F bre-eng ;S", "A pic-bel ;S", "A bur s pic-bel", "F mao s bre-eng"],
                england: ["F eng c pic-bel ;D", "A bel-pic ;F,D"] }],
  "6.G.5" => ["One fleet of the same power shows the intent, a second fleet is also needed on the route",
              { italy: ["A rom-apu ;S", "F tys c apu-rom"], turkey: ["A apu-rom ;S", "F ion c apu-rom"] }],
  "6.G.6" => ["The intent stands even when the route runs through other fleets",
              { england: ["A lvp-edi ;S", "F eng c lvp-edi"], germany: ["A edi-lvp ;S"],
                france: ["F iri h", "F nth h"], russia: ["F nwg c lvp-edi", "F nao c lvp-edi"] }],
  "6.G.7" => ["An illegal convoy order gives no intent: the armies stay",
              { england: ["F ska c swe-nwy", "F nwy-swe ;F"], russia: ["A swe-nwy ;F", "F bot c swe-nwy ;I"] }],
  "6.G.8" => ["A move via convoy with no convoy ordered fails and does not fall back to land",
              { france: ["A bel-hol via ;F"], england: ["F nth-hel ;S", "A hol-kie ;S"] }],
  "6.G.9" => ["An own convoy order to a neighbor makes the swap, not a battle",
              { england: ["A nwy-swe ;S", "F ska c nwy-swe", "F fin s nwy-swe"], russia: ["A swe-nwy ;S"] }],
  "6.G.10" => ["A move explicitly via convoy is not a head-to-head battle",
               { england: ["A nwy-swe via ;S", "F den s nwy-swe", "F fin s nwy-swe"], germany: ["F ska c nwy-swe"],
                 russia: ["A swe-nwy ;F,D", "F bar s swe-nwy"], france: ["F nwg-nwy ;F", "F nth s nwg-nwy"] }],
  "6.G.11" => ["A convoy to a neighbor, ordered via convoy, whose own support-cut decides its fleet",
               { england: ["F nwy s nth-ska", "F nth-ska"], russia: ["A swe-nwy", "F ska c swe-nwy", "F bar s swe-nwy"] }],
  "6.G.12" => ["Two armies swap with two convoys, both explicitly via convoy",
               { england: ["A lvp-edi via ;S", "F nao c lvp-edi", "F nwg c lvp-edi"],
                 germany: ["A edi-lvp via ;S", "F nth c edi-lvp", "F eng c edi-lvp", "F iri c edi-lvp"] }],
  "6.G.13" => ["A move via convoy to a neighbor counts as coming from its own province",
               { austria: ["F adr c tri-ven", "A tri-ven via ;F,D"], italy: ["A ven s alb-tri", "F alb-tri ;S"] }],
  "6.G.14" => ["A convoyed move to a neighbor bounces another unit",
               { england: ["A nwy-swe ;S", "F den s nwy-swe", "F fin s nwy-swe"], france: ["F nwg-nwy ;F", "F nth s nwg-nwy"],
                 germany: ["F ska c swe-nwy"], russia: ["A swe-nwy via ;F,D", "F bar s swe-nwy"] }],
  "6.G.15" => ["Bounce and dislodge when both armies go by convoy",
               { england: ["F nth c lon-bel", "A hol s lon-bel", "A yor-lon ;F", "A lon-bel ;S"],
                 france: ["F eng c bel-lon", "A bel-lon ;F,D"] }],
  "6.G.16" => ["Two units must not end in one province: a convoyed move out of the way",
               { england: ["A nwy-swe ;S", "A den s nwy-swe", "F bal s nwy-swe", "F nth-nwy ;F"],
                 russia: ["A swe-nwy via ;S", "F ska c swe-nwy", "F nwg s swe-nwy"] }],
  "6.G.17" => ["The same, with the other army convoyed",
               { england: ["A nwy-swe via ;S", "A den s nwy-swe", "F bal s nwy-swe", "F ska c nwy-swe", "F nth-nwy ;F"],
                 russia: ["A swe-nwy ;S", "F nwg s swe-nwy"] }],
  "6.G.18" => ["The same, with both armies convoyed",
               { england: ["F nth c lon-bel", "A hol s lon-bel", "A yor-lon ;F", "A lon-bel ;S", "A ruh s lon-bel"],
                 france: ["F eng c bel-lon", "A bel-lon ;S", "A wal s bel-lon"] }],
  "6.G.19" => ["A convoy order from a fleet that no minimal chain needs is illegal",
               { france: ["A mar-spa ;F", "F wes c mar-spa ;I"], italy: ["F gol c mar-spa", "A spa-mar ;F"] }],
  "6.G.20" => ["A move via convoy to a neighbor whose convoy is disrupted does not fall back to land",
               { france: ["F bre-eng ;S", "A pic-bel via ;F", "A bur s pic-bel", "F mao s bre-eng"],
                 england: ["F eng c pic-bel ;D"] }]
}.freeze

PARADOX = (%w[14 15 16 17 18 22 23 24 26 27 28].map { |n| "6.F.#{n}" } + %w[6.G.11]).freeze
```

`gen/gen.rb` (run from `proto/` with `bundle exec ruby -I lib -I spec/support ../gen/gen.rb ../gen/out`):

```ruby
# frozen_string_literal: true

# Usage: bundle exec ruby -I lib -I spec/support <this file> <out_dir>
require "trucebearer/adjudicator"
require_relative "cases"
require "board"

OUT = ARGV.fetch(0)
LOC = ->(text) { prov, coast = text.split("/"); [prov.to_sym, coast&.to_sym] }
UNIT = %r{\A([AF]) (\w+(?:/\w+)?)}

def parse(text, power)
  main, flags = text.split(";").map(&:strip)
  flags = (flags || "").split(",")
  m = main.match(%r{\A([AF]) (\w+)(?:/(\w+))?(?: |(?=-))(.*)\z}) or raise "bad unit #{text}"
  type = m[1] == "A" ? :army : :fleet
  at = m[2].to_sym
  coast = m[3]&.to_sym
  rest = m[4]
  order =
    case rest
    when "h" then { type: "hold", power: power, at: at }
    when /\Ac (\w+)-(\w+)\z/ then { type: "convoy", power: power, at: at, from: $1, to: $2 }
    when %r{\As (\w+)-(\w+)\z} then { type: "support_move", power: power, at: at, from: $1, to: $2 }
    when /\As (\w+)\z/ then { type: "support_hold", power: power, at: at, target: $1 }
    when %r{\A-(\w+) via\z} then { type: "move_via_convoy", power: power, at: at, to: $1 }
    when %r{\A-(\w+(?:/\w+)?)\z} then { type: "move", power: power, at: at, destination: $1 }
    else raise "bad order #{text}"
    end
  { unit: [power, type, at, coast], order: order, flags: flags, text: text }
end

def to_order(h)
  fields = h.transform_keys(&:to_s).transform_values { |v| v.is_a?(Symbol) || v.is_a?(String) ? v.to_s : v }
  fields["destination"] = { "province" => h[:destination].split("/")[0], "coast" => h[:destination].split("/")[1] } if h[:destination]
  TA::Order.from_h({ "format" => 1 }.merge(fields))
end

def loc_text(province, coast) = coast ? "#{province}/#{coast}" : province.to_s

def unit_text(u) = "{power: #{u.power}, type: #{u.type}, at: #{loc_text(u.location.province, u.location.coast)}}"

def order_flow(order)
  case order
  when TA::Order::Hold then "{type: hold, power: #{order.power}, at: #{order.at}}"
  when TA::Order::Move
    d = order.destination
    "{type: move, power: #{order.power}, at: #{order.at}, destination: #{loc_text(d.province, d.coast)}}"
  when TA::Order::MoveViaConvoy then "{type: move_via_convoy, power: #{order.power}, at: #{order.at}, to: #{order.to}}"
  when TA::Order::SupportHold then "{type: support_hold, power: #{order.power}, at: #{order.at}, target: #{order.target}}"
  when TA::Order::SupportMove then "{type: support_move, power: #{order.power}, at: #{order.at}, from: #{order.from}, to: #{order.to}}"
  when TA::Order::Convoy then "{type: convoy, power: #{order.power}, at: #{order.at}, from: #{order.from}, to: #{order.to}}"
  end
end

problems = []
CASES.each do |id, (summary, groups)|
  entries = groups.flat_map { |power, list| list.map { |text| parse(text, power) } }
  units = entries.map { |e| power, type, at, coast = e[:unit]; TA::Unit.new(power: power, type: type, location: TA::Location.new(province: at, coast: coast)) }
  position = Board.position(*units)
  orders = entries.map { |e| to_order(e[:order]) }
  checks = orders.map { |o| TA.check(position, o) }
  entries.each_with_index do |e, i|
    illegal = e[:flags].include?("I")
    problems << "#{id}: #{e[:text]} legality #{checks[i].reasons.inspect}" if illegal == checks[i].legal
  end
  adj = TA.adjudicate(position, orders)
  paradox_expected = PARADOX.include?(id)
  problems << "#{id}: paradox flag #{adj.paradox}, expected #{paradox_expected}" if adj.paradox != paradox_expected
  puts "#{id} paradox=#{adj.paradox} #{adj.outcomes.size} outcomes"
  if paradox_expected
    File.open(File.join(OUT, "#{id}.yml"), "w") do |f|
      f.puts "case: \"#{id}\""
      f.puts "summary: #{summary.include?(":") ? summary.dump : summary}"
      f.puts "paradox: true"
      f.puts "position:", "  units:"
      units.each { |u| f.puts "    - #{unit_text(u)}" }
      f.puts "orders:"
      orders.each_with_index do |o, i|
        f.puts "  - order: #{order_flow(o)}"
        c = checks[i]
        f.puts "    check: #{c.legal ? '{legal: true}' : "{legal: false, reason: #{c.reasons.first}}"}"
      end
    end
    next puts("   (pending: #{id})")
  end

  entries.each_with_index do |e, i|
    o = adj.outcomes[i]
    move = [TA::Order::Move, TA::Order::MoveViaConvoy].any? { |k| orders[i].is_a?(k) }
    if move && !paradox_expected
      problems << "#{id}: #{e[:text]} result #{o.result}" if e[:flags].include?("S") != (o.result == :succeeded) && (e[:flags].include?("S") || e[:flags].include?("F"))
    end
    # D on a legal order: that order's outcome must be dislodged; on an illegal one, the implied hold is.
    expect_d = e[:flags].include?("D") && !e[:flags].include?("I")
    problems << "#{id}: #{e[:text]} dislodged #{o.dislodged}" if !paradox_expected && o.dislodged != expect_d
    puts "   #{e[:text].ljust(26)} #{o.result.to_s.ljust(10)} #{'DISLODGED' if o.dislodged}"
  end
  adj.outcomes.drop(orders.size).each { |o| puts "   implied hold #{o.order.at} #{o.result} #{'DISLODGED' if o.dislodged}" }
  pos = adj.position
  puts "   after: #{pos.units.map { |u| "#{u.location.province}#{"/#{u.location.coast}" if u.location.coast}" }.sort.join(' ')}"
  puts "   dislodged: #{pos.dislodged_units.map { |d| "#{d.unit.location.province}<-#{d.attacker_from}#{' (convoy)' if d.by_convoy}" }.join(' ')}"
  puts "   standoffs: #{pos.standoffs.inspect}"
  next if paradox_expected

  File.open(File.join(OUT, "#{id}.yml"), "w") do |f|
    f.puts "case: \"#{id}\""
    f.puts "summary: #{summary.include?(":") ? summary.dump : summary}"
    f.puts "position:", "  units:"
    units.each { |u| f.puts "    - #{unit_text(u)}" }
    f.puts "orders:"
    orders.each_with_index do |o, i|
      f.puts "  - order: #{order_flow(o)}"
      c = checks[i]
      f.puts "    check: #{c.legal ? '{legal: true}' : "{legal: false, reason: #{c.reasons.first}}"}"
      f.puts "    result: #{adj.outcomes[i].result}"
      f.puts "    dislodged: true" if adj.outcomes[i].dislodged
    end
    f.puts "after:", "  units:"
    pos.units.sort_by { |u| u.location.province }.each { |u| f.puts "    - #{unit_text(u)}" }
    unless pos.dislodged_units.empty?
      f.puts "  dislodged:"
      pos.dislodged_units.each do |d|
        u = d.unit
        f.puts "    - {power: #{u.power}, type: #{u.type}, at: #{loc_text(u.location.province, u.location.coast)}, from: #{d.attacker_from}#{', by_convoy: true' if d.by_convoy}}"
      end
    end
    f.puts "  standoffs: [#{pos.standoffs.join(', ')}]" unless pos.standoffs.empty?
  end
end
puts "\nPROBLEMS:", problems
```

- [ ] **Step 1:** run it. Expected: 58 lines `<id> paradox=<bool> …`, then `PROBLEMS:` with nothing after it, and 58 files in `gen/out/`. A problem line is a case the scratch resolver gets wrong against the DATC's marks: fix the resolver (Phase 4), never the marks.
- [ ] **Step 2: review the labels and standoffs by hand.** The DATC's marks fix who moves and who is dislodged. Everything else in a fixture is our reading, and Phase 5's reference confirms it independently. Check the ones that are not obvious from the DATC listing:

| Case | What to see in the generated file |
|---|---|
| 6.F.2 | `standoffs: [bre]`: two armies of equal strength bounced in Brest, one by convoy |
| 6.F.6, 6.F.7, 6.F.8, 6.F.30 | the carrying fleet's convoy order is `disrupted` (6.F.30: its army has `no_route`); 6.F.6 to 6.F.8 dislodge the fleet from `ska`; no standoff in the landing province |
| 6.F.12 | the Irish Sea order is `void` with `reason: not_on_chain`, and the fleet is dislodged as an implied hold (`after.dislodged` has it; the order's `dislodged` is false) |
| 6.F.19, 6.F.20, 6.F.21, 6.F.25, 6.F.29 | `paradox` false: no file carries the key; supports `cut`, convoys `given` or `disrupted` as listed; 6.F.21 dislodges `cly` by convoy (`by_convoy: true`) |
| 6.G.2, 6.G.3, 6.G.4, 6.G.7, 6.G.19 | the convoy order is `unmatched` (the army went by land); 6.G.3 and 6.G.4 dislodge the convoy fleet in `eng` |
| 6.G.8, 6.G.20 | the move via convoy is `no_route` and the unit stays; no fallback to land |
| 6.G.10, 6.G.14 | `standoffs: [nwy]`: the dislodged army and the fleet from the Norwegian Sea bounced each other there; 6.G.15 `standoffs: [lon]` likewise |
| 6.G.13 | `tri` is dislodged by `alb` (not by convoy); the support in `ven` is not cut |

- [ ] **Step 3:** copy the 46 encoded files into `adjudicator/spec/datc/` (the three existing ones, 6.B.18, 6.B.19 and 6.G.19, are replaced by the generated ones, which keep their orders and checks and gain results; read the diff of each). Do not copy anything yet from `gen/out` for the pending cases.

### 3.2 The constants and the runners (spec first, then code)

- [ ] **Step 4: the checking runner.** In `spec/datc/datc_check_spec.rb`:

```ruby
# header: "#14 added its cases through Datc::ADJUDICATED, and #15 added the convoy cases to it
# and the paradox cases that wait for #39 (Datc::PARADOX_PENDING)."
  encoded = (Datc::ADJUDICATED + Datc::PARADOX_PENDING).sort.freeze
  ...
    expect(encoded.size).to eq(138)
```

- [ ] **Step 5: the adjudication runner.** In `spec/datc/datc_adjudicate_spec.rb` replace the first example's body and add the paradox section at the end of the file:

```ruby
  it "has an after: in exactly the encoded files, and in none of the cases left out (AC-11.2)" do
    expect(Datc::ADJUDICATED.size).to eq(126)
    expect(cases.map(&:id).sort).to eq(Datc::ADJUDICATED)
    without = Datc.load_all.reject(&:after).map(&:id)
    expect(without).to eq(Datc::PARADOX_PENDING)
    expect(Datc.load_all.select(&:paradox).map(&:id)).to eq(Datc::PARADOX_PENDING)
    left_out = %w[6.B.9 6.B.14]
    expect(cases.map(&:id) & left_out).to eq([])
  end
```

```ruby
  # The convoy paradoxes of the contract's list. Their result is unspecified until 0.3 (#39),
  # so each is tested for what the contract promises: the flag is set, nothing raises, the
  # position is valid and every unit is in it once (AC-6.2, AC-6.7 of spec 015).
  Datc.load_all.select(&:paradox).each do |kase|
    describe "#{kase.id} (convoy paradox, result pending: #39)" do
      let(:orders) { kase.entries.map(&:order) }
      let(:units_in_place) { kase.position.units.map { |unit| [unit.power, unit.type] }.tally }

      def kept_once(adjudication)
        position = adjudication.position
        (position.units + position.dislodged_units.map(&:unit)).map { |unit| [unit.power, unit.type] }.tally
      end

      def implied_holds(kase)
        legal = kase.entries.select { |entry| entry.expected.legal }.map(&:order)
        kase.position.units.count { |unit| legal.none? { |order| order.at == unit.location.province && order.power == unit.power } }
      end

      it "sets the paradox flag, builds a valid position and keeps every unit once" do
        adjudication = TA.adjudicate(kase.position, orders)
        expect(adjudication.paradox).to be(true)
        expect(adjudication.position).to be_a(TA::Position)
        expect(adjudication.position.phase).to eq(:retreat)
        expect(kept_once(adjudication)).to eq(units_in_place)
        expect(adjudication.outcomes.size).to eq(orders.size + implied_holds(kase))
      end

      it "gives the same flag and a valid position for the orders in any order" do
        arrangements = Array.new(6) { |seed| orders.shuffle(random: Random.new(seed)) }
        arrangements.each do |arranged|
          other = TA.adjudicate(kase.position, arranged)
          expect(other.paradox).to be(true)
          expect(kept_once(other)).to eq(units_in_place)
          expect(other.outcomes.size).to eq(orders.size + implied_holds(kase))
        end
      end

      it "gives the preferred result of the DATC" do
        skip "paradox resolution: #39"
      end
    end
  end
```

Also update the file's header comment to say the paradox cases are tested only for the flag and a valid position.

- [ ] **Step 6: the constants.** In `spec/support/datc.rb` replace the `ADJUDICATED` and `CHECKING_ONLY` definitions:

```ruby
  # The cases that carry `after:`: the ones adjudicated. The checking runner expects these
  # files and the ones with `paradox: true`.
  ADJUDICATED = (
    (1..12).map { |n| "6.A.#{n}" } +
    [1, 2, 3, 4, 5, 6, 7, 8, 10, 11, 12, 13, 15, 16, 17, 18, 19].map { |n| "6.B.#{n}" } +
    (1..9).map { |n| "6.C.#{n}" } +
    (1..35).map { |n| "6.D.#{n}" } +
    (1..15).map { |n| "6.E.#{n}" } +
    ((1..30).to_a - [14, 15, 16, 17, 18, 22, 23, 24, 26, 27, 28]).map { |n| "6.F.#{n}" } +
    ((1..20).to_a - [11]).map { |n| "6.G.#{n}" }
  ).sort.freeze
  # The convoy paradoxes the contract leaves to #39 (docs/interface.md, "DATC scope").
  PARADOX_PENDING = (
    [14, 15, 16, 17, 18, 22, 23, 24, 26, 27, 28].map { |n| "6.F.#{n}" } + %w[6.G.11]
  ).sort.freeze
```

(`CHECKING_ONLY` is deleted.) Confirm from a console: `Datc::ADJUDICATED.size` is 126 and `Datc::PARADOX_PENDING.size` is 12.

- [ ] **Step 7: batches.** Commit the encoded fixtures with their runner changes in three commits by section, then the pending ones: "Encode the convoy cases of 6.B to 6.E" (6.B.18, 6.B.19, 6.C.4 to 6.C.7, 6.D.6, 6.D.16, 6.E.11), "Encode the convoy cases of 6.F" (6.F.2 to 6.F.13, 6.F.19 to 6.F.21, 6.F.25, 6.F.29, 6.F.30), "Encode the convoy cases of 6.G" (6.G.1 to 6.G.10, 6.G.12 to 6.G.20), and, last, copy the 12 pending files from `gen/out/` and commit "Encode the twelve convoy paradoxes that wait for #39". The constants and runner edits go in the first commit; the suite is red (the stub resolver) from then on until Phase 4, except the loader, checking and legality specs.
- [ ] **Step 8:** run `bundle exec rspec spec/datc`. Expected before Phase 4: the checking runner is green (every order's `check:` holds, 138 files); the adjudication runner is red for the convoy cases (46 minus those the stub happens to get right) and for the twelve flags; the DATC overlap check is run in Phase 6.

---

## Phase 4: Routes, disruption and the residue

**Implements:** AC-1.1 to AC-1.3, AC-2.1 to AC-2.6, AC-3.1 to AC-3.5, AC-4.1, AC-4.2, AC-5.1, AC-5.2, AC-5.5, AC-5.6, AC-6.1, AC-6.2, AC-6.5, AC-6.7, AC-7.1 to AC-7.3. **Files:** `lib/trucebearer/adjudicator/reach.rb`, `lib/trucebearer/adjudicator/resolver.rb`, `lib/trucebearer/adjudicator.rb` (a comment), `spec/trucebearer/adjudicator/reach_spec.rb`, `spec/trucebearer/adjudicator/adjudicate_convoys_spec.rb` (new), `spec/trucebearer/adjudicator/adjudicate_convoy_stub_spec.rb` (deleted).

- [ ] **Step 1: the specs first.**

`reach_spec.rb`: add, inside `describe "chain?"` after the `without:` example:

```ruby
    it "links a set of seas the same way (linked?, used to decide whether a convoy route works)" do
      expect(reach.linked?(Set[:nth], :lon, :hol)).to be(true)
      expect(reach.linked?(Set[:eng], :lon, :hol)).to be(false)
      expect(reach.linked?(Set[:eng, :nth], :lon, :nwy)).to be(true)
      expect(reach.linked?(Set.new, :lon, :hol)).to be(false)
    end
```

Create `spec/trucebearer/adjudicator/adjudicate_convoys_spec.rb`. It is the replacement of the stub spec: small hand-built positions, one rule each, the DATC cases being in `spec/datc/`.

```ruby
# frozen_string_literal: true

require "trucebearer/adjudicator"
require_relative "../../support/adjudicating"

# Convoys in TA.adjudicate (spec 015, Stories 2 to 5): routes, disruption, the results of
# convoy orders, by_convoy, circular movement with convoys and the paradox flag. The DATC cases
# are in spec/datc/; this file holds the small hand-built positions that show one rule each.
RSpec.describe "TA.adjudicate: convoys" do
  let(:england) { [u(:england, :army, "lon"), u(:england, :fleet, "nth")] }

  describe "routes (AC-2.1 to AC-2.5)" do
    it "carries an army across a chain of fleets that all give matching convoy orders" do
      units = [u(:england, :army, "lon"), u(:england, :fleet, "eng")]
      result = run(units, [mv(:england, :lon, "bel"), cv(:england, :eng, :lon, :bel)])
      expect(results(result, 2)).to eq(%i[succeeded given])
      expect(after(result)).to eq(bel: :england, eng: :england)
    end

    it "has no route when a fleet of the chain gives no matching order, and the army stays" do
      result = run(england, [mv(:england, :lon, "nwy")])
      expect(results(result, 1)).to eq([:no_route])
      expect(after(result)).to eq(lon: :england, nth: :england)
    end

    it "never falls back to land for a move via convoy that nobody convoys (6.G.8)" do
      expect(results(run(england, [mvc(:england, :lon, :yor)]), 1)).to eq([:no_route])
    end

    it "sends a plain move to a neighbor by land when only another power's fleet convoys it (6.G.2)" do
      units = [u(:england, :army, "lon"), u(:germany, :fleet, "nth")]
      result = run(units, [mv(:england, :lon, "yor"), cv(:germany, :nth, :lon, :yor)])
      expect(results(result, 2)).to eq(%i[succeeded unmatched])
    end

    it "uses a route made of other powers' fleets, and needs no help from the fleet that gave the intent (6.G.6)" do
      units = [u(:england, :army, "lon"), u(:england, :fleet, "eng"), u(:germany, :fleet, "nth"), u(:france, :army, "bel")]
      result = run(units, [mv(:england, :lon, "bel"), cv(:germany, :nth, :lon, :bel)])
      expect(results(result, 2)).to eq(%i[bounced given])
    end

    it "lets a convoyed army bounce and receive support like any move (6.F.2, 6.F.3)" do
      units = [u(:england, :army, "lon"), u(:england, :fleet, "eng"), u(:england, :fleet, "mao"), u(:france, :army, "par")]
      plain = [mv(:england, :lon, "bre"), cv(:england, :eng, :lon, :bre), mv(:france, :par, "bre")]
      expect(results(run(units, plain), 3)).to eq(%i[bounced given bounced])
      supported = run(units, plain + [sm(:england, :mao, :lon, :bre)])
      expect(results(supported, 4)).to eq(%i[succeeded given bounced given])
    end
  end

  describe "disruption (AC-3.1 to AC-3.5)" do
    let(:units) { england + [u(:germany, :fleet, "ska"), u(:germany, :fleet, "hel")] }
    let(:convoy) { [mv(:england, :lon, "hol"), cv(:england, :nth, :lon, :hol)] }

    it "does not disrupt a convoy whose fleet is attacked but not dislodged (6.F.4)" do
      result = run(units, convoy + [mv(:germany, :ska, "nth")])
      expect(results(result, 3)).to eq(%i[succeeded given bounced])
    end

    it "disrupts the convoy of a dislodged fleet, and the army it carried has no route (6.F.6)" do
      result = run(units, convoy + [mv(:germany, :ska, "nth"), sm(:germany, :hel, :ska, :nth)])
      expect(results(result, 4)).to eq(%i[no_route disrupted succeeded given])
      expect(result.outcomes[1].dislodged).to be(true)
      expect(dislodged(result)).to eq(nth: :ska)
      expect(result.position.dislodged_units.first.by_convoy).to be(false)
    end

    it "gives a convoy order :unmatched when its army goes by land or doesn't move, even if the fleet is dislodged (6.G.3)" do
      by_land = [u(:england, :army, "lon"), u(:germany, :fleet, "nth")]
      expect(results(run(by_land, [mv(:england, :lon, "yor"), cv(:germany, :nth, :lon, :yor)]), 2)).to eq(%i[succeeded unmatched])
      holds = run(units, [hd(:england, :lon), cv(:england, :nth, :lon, :hol), mv(:germany, :ska, "nth"), sm(:germany, :hel, :ska, :nth)])
      expect(results(holds, 4)).to eq(%i[held unmatched succeeded given])
      expect(holds.outcomes[1].dislodged).to be(true)
    end

    it "does not let the result of a convoy depend on the army's fate (AC-3.5)" do
      free = run(units, convoy)
      stopped = run(units + [u(:france, :army, "hol")], convoy + [hd(:france, :hol)])
      expect(results(free, 2)).to eq(%i[succeeded given])
      expect(results(stopped, 2)).to eq(%i[bounced given])
    end

    it "marks the dislodged unit as taken by convoy and attacked from the army's own province (6.D.16)" do
      units = [u(:england, :army, "lon"), u(:england, :fleet, "nth"), u(:france, :army, "bel"), u(:france, :fleet, "eng")]
      result = run(units, [hd(:england, :lon), cv(:england, :nth, :bel, :lon), sm(:france, :eng, :bel, :lon), mv(:france, :bel, "lon")])
      expect(results(result, 4)).to eq(%i[held given given succeeded])
      entry = result.position.dislodged_units.first
      expect([entry.unit.location.province, entry.attacker_from, entry.by_convoy]).to eq([:lon, :bel, true])
    end

    it "keeps a convoyed move from cutting a support when the move has no route (6.F.6)" do
      units = [u(:england, :army, "lon"), u(:england, :fleet, "nth"), u(:germany, :army, "hol"), u(:germany, :army, "bel"),
               u(:germany, :fleet, "ska"), u(:germany, :fleet, "hel")]
      orders = [mv(:england, :lon, "hol"), cv(:england, :nth, :lon, :hol), sh(:germany, :hol, :bel),
                mv(:germany, :ska, "nth"), sm(:germany, :hel, :ska, :nth)]
      expect(results(run(units, orders), 5)).to eq(%i[no_route disrupted given succeeded given])
    end
  end

  describe "swaps and circles with convoys (AC-2.6, AC-4.1)" do
    it "swaps two armies when one goes by convoy, which is not a head-to-head battle (6.G.1)" do
      units = [u(:england, :army, "nwy"), u(:england, :fleet, "ska"), u(:russia, :army, "swe")]
      result = run(units, [mv(:england, :nwy, "swe"), cv(:england, :ska, :nwy, :swe), mv(:russia, :swe, "nwy")])
      expect(results(result, 3)).to eq(%i[succeeded given succeeded])
      expect(after(result)).to eq(swe: :england, nwy: :russia, ska: :england)
    end

    it "swaps two armies that both go by convoy (6.C.6)" do
      units = [u(:england, :army, "lon"), u(:england, :fleet, "nth"), u(:france, :army, "bel"), u(:france, :fleet, "eng")]
      orders = [mv(:england, :lon, "bel"), cv(:england, :nth, :lon, :bel), mv(:france, :bel, "lon"), cv(:france, :eng, :bel, :lon)]
      expect(results(run(units, orders), 4)).to eq(%i[succeeded given succeeded given])
    end

    it "fails both armies of a swap when a third unit bounces one of them (6.C.7)" do
      units = [u(:england, :army, "lon"), u(:england, :fleet, "nth"), u(:france, :army, "bel"), u(:france, :fleet, "eng"), u(:france, :army, "bur")]
      orders = [mv(:england, :lon, "bel"), cv(:england, :nth, :lon, :bel), mv(:france, :bel, "lon"), cv(:france, :eng, :bel, :lon),
                mv(:france, :bur, "bel")]
      expect(results(run(units, orders), 5)).to eq(%i[bounced given bounced given bounced])
    end
  end

  describe "convoy paradoxes (AC-5.1 to AC-5.6)" do
    let(:paradox_units) { [u(:england, :fleet, "lon"), u(:england, :fleet, "wal"), u(:france, :army, "bre"), u(:france, :fleet, "eng")] }
    let(:paradox_orders) do
      [mv(:england, :wal, "eng"), sm(:england, :lon, :wal, :eng), mv(:france, :bre, "lon"), cv(:france, :eng, :bre, :lon)]
    end

    it "sets the flag for the simplest paradox and still returns a valid position" do
      result = run(paradox_units, paradox_orders)
      expect(result.paradox).to be(true)
      expect(result.position.units.size + result.position.dislodged_units.size).to eq(4)
      expect(result.outcomes.size).to eq(4)
    end

    it "sets the flag when the convoyed army has a support too, since a cut doesn't need success" do
      units = paradox_units + [u(:france, :fleet, "yor")]
      result = run(units, paradox_orders + [sm(:france, :yor, :bre, :lon)])
      expect(result.paradox).to be(true)
    end

    it "keeps the flag clear when the convoyed army attacks nothing that decides its fleet" do
      steady = run(paradox_units, [mv(:england, :wal, "eng"), mv(:france, :bre, "lon"), cv(:france, :eng, :bre, :lon)])
      expect(steady.paradox).to be(false)
      expect(results(steady, 3)).to eq(%i[bounced bounced given])
    end

    it "flags a paradox next to independent orders, and still places every unit once" do
      units = paradox_units + [u(:italy, :army, "tun"), u(:italy, :fleet, "ion")]
      result = run(units, paradox_orders + [mv(:italy, :tun, "gre"), cv(:italy, :ion, :tun, :gre)])
      expect(result.paradox).to be(true)
      expect(result.position.units.size + result.position.dislodged_units.size).to eq(6)
      expect(result.outcomes.size).to eq(6)
    end

    it "does not flag a circle that holds a convoyed army (6.C.4)" do
      units = [u(:austria, :army, "tri"), u(:austria, :army, "ser"), u(:turkey, :army, "bul"), u(:turkey, :fleet, "aeg"),
               u(:turkey, :fleet, "ion"), u(:turkey, :fleet, "adr")]
      orders = [mv(:austria, :tri, "ser"), mv(:austria, :ser, "bul"), mv(:turkey, :bul, "tri"),
                cv(:turkey, :aeg, :bul, :tri), cv(:turkey, :ion, :bul, :tri), cv(:turkey, :adr, :bul, :tri)]
      result = run(units, orders)
      expect(results(result, 6)).to eq(%i[succeeded succeeded succeeded given given given])
      expect(result.paradox).to be(false)
    end
  end
end
```

Delete the stub: `git rm spec/trucebearer/adjudicator/adjudicate_convoy_stub_spec.rb` (AC-7.1).

Run `bundle exec rspec spec/trucebearer/adjudicator/reach_spec.rb spec/trucebearer/adjudicator/adjudicate_convoys_spec.rb`. Expected: `linked?` is undefined; the convoy examples fail where the stub gives `:no_route` or `:unmatched` (`got: [:no_route, :unmatched]` and the like) and the paradox examples fail on the flag.

- [ ] **Step 2: `Reach.linked?`.** In `reach.rb`, split `chain?` so that its loop works on a given set of seas:

```ruby
      def chain?(position, from, to, without: nil)
        return false if from == to

        linked?(fleet_seas(position, without), from, to)
      end

      # True when the given sea provinces hold a convoy chain from `from` to `to`: some of
      # them, each next to the one before, the first next to `from` and the last next to `to`.
      def linked?(seas, from, to)
        frontier = seas.select { |sea| touches?(sea, from) }
        reached = frontier.to_set
        until frontier.empty?
          sea = frontier.pop
          return true if touches?(sea, to)

          (SEA_LINKS.fetch(sea) & seas).each { |next_sea| frontier << next_sea if reached.add?(next_sea) }
        end
        false
      end
```

(`linked?` goes where the old body was, so the file's order is unchanged; the old loop is moved, not rewritten.)

- [ ] **Step 3: the resolver.** Apply this patch to `lib/trucebearer/adjudicator/resolver.rb` (`diff -u` of the repository file against the scratch copy; the `---` and `+++` paths are the scratch ones, apply the hunks to the repository file):

```diff
--- lib/trucebearer/adjudicator/resolver.rb	2026-11-26 03:04:40
+++ /private/tmp/claude-501/-Users-james-orca-workspaces-trucebearer-tb-15-convoys/f5b8b8d3-56a5-4b94-ac88-3c8b6c7f0396/scratchpad/proto/lib/trucebearer/adjudicator/resolver.rb	2026-11-26 03:34:30
@@ -6,12 +6,16 @@
   module Adjudicator
     # Internal: decides every move of a movement phase, following the decision-based approach
     # of Kruijswijk's "The Math of Adjudication" (docs/specs/014-adjudicate-movement/spec.md,
-    # "How the conditions are resolved"). Not part of docs/interface.md.
+    # "How the conditions are resolved"; convoys: docs/specs/015-convoys/spec.md). Not part of
+    # docs/interface.md.
     #
     # It is given one followed order for each unit. A move's decision starts unknown. Each
     # strength is kept as a range [least, most] given what is already decided, and a move is
-    # decided as soon as its range settles it. When nothing more can be decided, the moves
-    # that remain wait on each other in a circle, and circular movement decides them.
+    # decided as soon as its range settles it. Whether a move that goes by convoy has a route
+    # depends on whether its carrying fleets are dislodged, so it is sure, lost or open, and an
+    # open route widens the ranges. When nothing more can be decided, circular movement decides
+    # the circles, and whatever is still undecided is a convoy paradox: those moves fail and
+    # `paradox` is set. Resolving a paradox properly is #39.
     class Resolver
       Entry = Data.define(:order, :unit) do
         def province = unit.location.province
@@ -20,12 +24,8 @@
         def destination = order.is_a?(Order::Move) ? order.destination.province : order.to
       end
 
-      # True when the last-resort rule ran: the moves on the cycles that are stuck failed. It
-      # can't run in this release: a move that goes by convoy fails at once, so every other
-      # undecided move waits on at most one move, and the cycles that remain are circles that
-      # `circle_pass` decides (docs/specs/014-adjudicate-movement/spec.md, "The paradox flag").
-      # #15 makes it reachable, once whether a convoy route works depends on a fleet that may
-      # be dislodged, and decides what it becomes.
+      # True when moves were left undecided after the ranges and circular movement: the orders
+      # hold a convoy paradox (docs/specs/015-convoys/spec.md, "Detecting a paradox").
       attr_reader :paradox
 
       def initialize(position, orders)
@@ -35,6 +35,7 @@
         @moves = @entries.select(&:move?)
         @into = @moves.group_by(&:destination)
         @by_convoy = @moves.select { |move| goes_by_convoy?(move) }.to_set
+        @carriers = @by_convoy.to_h { |move| [move, carriers_of(move)] }
         @state = {}
         @paradox = false
         resolve
@@ -53,7 +54,7 @@
 
           succeeded?(entry) ? :succeeded : :bounced
         when Order::SupportHold, Order::SupportMove then support_result(entry)
-        when Order::Convoy then :unmatched
+        when Order::Convoy then convoy_result(entry)
         end
       end
 
@@ -114,9 +115,46 @@
         end
       end
 
-      # The one place a later release decides whether a convoy route works (#15). `result` reads
-      # it too, so a move without a route is :no_route.
-      def path?(move) = !convoy?(move)
+      # The fleets that carry a move that goes by convoy: those whose followed order is a
+      # Convoy that matches it, of any power.
+      def carriers_of(move)
+        @entries.select do |entry|
+          entry.order.is_a?(Order::Convoy) && entry.order.from == move.province && entry.order.to == move.destination
+        end
+      end
+
+      # Does the move have a working route? :sure when some chain of carrying fleets has no
+      # fleet that might be dislodged, :lost when every chain has one that surely is (or there
+      # is none), :open otherwise. A move that goes by land always has one.
+      def route(move)
+        return :sure unless convoy?(move)
+
+        fleets = @carriers.fetch(move)
+        safe = fleets.select { |fleet| dislodged_state(fleet) == false }.to_set(&:province)
+        return :sure if Reach.linked?(safe, move.province, move.destination)
+
+        possible = fleets.reject { |fleet| dislodged_state(fleet) == true }.to_set(&:province)
+        Reach.linked?(possible, move.province, move.destination) ? :open : :lost
+      end
+
+      # Only called once everything is decided (by `result`, `standoffs`).
+      def path?(move) = route(move) == :sure
+
+      # true when some move into the unit's province has succeeded, false when none can,
+      # nil while that is not known.
+      def dislodged_state(entry)
+        states = (@into[entry.province] || []).map { |move| @state[move] }
+        return true if states.any?(true)
+
+        states.all?(false) ? false : nil
+      end
+
+      def convoy_result(entry)
+        matched = @by_convoy.any? { |move| move.province == entry.order.from && move.destination == entry.order.to }
+        return :unmatched unless matched
+
+        dislodged_state(entry) ? :disrupted : :given
+      end
 
       def destination_location(entry)
         entry.order.is_a?(Order::Move) ? entry.order.destination : Location.new(province: entry.order.to)
@@ -156,17 +194,14 @@
           next if decide_pass
           next if circle_pass
 
-          last_resort
+          fail_residue
         end
       end
 
-      # Nothing can be decided and no circle of three or more is left. This can't happen in
-      # this release (see `paradox`). The moves on the cycles that are stuck fail, or every
-      # undecided move if there is no cycle, so the loop always ends.
-      def last_resort
-        stuck = cycles.flatten
-        stuck = @moves.select { |move| @state[move].nil? } if stuck.empty?
-        stuck.each { |move| @state[move] = false }
+      # Nothing more can be decided and no circle is left: the moves still undecided are the
+      # residue, which holds a convoy paradox. They all fail, and the flag is set.
+      def fail_residue
+        @moves.each { |move| @state[move] = false if @state[move].nil? }
         @paradox = true
       end
 
@@ -187,11 +222,17 @@
       # Moves that wait on each other in a circle of three or more units, each into the
       # province the next one leaves, all succeed (circular movement).
       def circle_pass
-        circles = cycles.select { |circle| circle.size >= 3 }
+        circles = cycles.select { |circle| circle?(circle) }
         circles.each { |circle| circle.each { |move| @state[move] = true } }
         !circles.empty?
       end
 
+      # Three or more moves, or two when one of them goes by convoy (two plain moves are a
+      # head-to-head battle), and every route sure.
+      def circle?(moves)
+        (moves.size >= 3 || moves.any? { |move| convoy?(move) }) && moves.all? { |move| route(move) == :sure }
+      end
+
       # The cycles that the undecided moves form: each move waits on the undecided move of the
       # unit in its destination, so every move has at most one successor.
       def cycles
@@ -250,8 +291,10 @@
       end
 
       def attack(move)
-        return [0, 0] unless path?(move)
+        widen(move, attack_with_route(move))
+      end
 
+      def attack_with_route(move)
         other = @at[move.destination]
         return range(1, move_supporters(move)) unless other
         return staying_attack(move, other) if !other.move? || head_to_head?(move)
@@ -266,6 +309,15 @@
         end
       end
 
+      # A move with no route has no strength; one whose route is open might have none.
+      def widen(move, strength)
+        case route(move)
+        when :sure then strength
+        when :lost then [0, 0]
+        else [0, strength[1]]
+        end
+      end
+
       # Against a unit that stays: nothing against its own power, and no help from its owner.
       def staying_attack(move, other)
         return [0, 0] if other.power == move.power
@@ -274,8 +326,10 @@
       end
 
       def prevent(move)
-        return [0, 0] unless path?(move)
+        widen(move, prevent_with_route(move))
+      end
 
+      def prevent_with_route(move)
         if head_to_head?(move)
           case @state[@at[move.destination]]
           when true then return [0, 0]
@@ -302,18 +356,24 @@
       # the supported move goes to the province that move comes from; and by dislodgement.
       def cut?(support)
         attackers = @into[support.province] || []
-        return true if attackers.any? { |move| cuts?(move, support) }
+        cuts = attackers.map { |move| cuts?(move, support) }
+        return true if cuts.any?(true)
 
         states = attackers.map { |move| @state[move] }
         return true if states.any?(true)
 
-        states.all?(false) ? false : nil
+        cuts.all?(false) && states.all?(false) ? false : nil
       end
 
+      # true, false, or nil while the move's route is open.
       def cuts?(move, support)
-        return false if !path?(move) || move.power == support.power
+        return false if move.power == support.power
+        return false unless support.order.is_a?(Order::SupportHold) || move.province != support.order.to
 
-        support.order.is_a?(Order::SupportHold) || move.province != support.order.to
+        case route(move)
+        when :sure then true
+        when :lost then false
+        end
       end
 
       def occupied_after?(province)
```

- [ ] **Step 4: the comment** in `lib/trucebearer/adjudicator.rb`:

```ruby
    # Adjudicates a movement phase (docs/interface.md, "Adjudicating a movement phase"): one
    # outcome for every order, then an implied hold for every unit that has none, and the
    # position after the moves. Raises InvalidInput for an argument of the wrong class, a
    # position that isn't in the movement phase, or one power giving two orders for one
    # province; a broken rule is an outcome, never an error. A convoy paradox is flagged, not
    # resolved (#39).
    def self.adjudicate(position, orders) = Adjudicate.call(position, orders)
```

- [ ] **Step 5:** run `bundle exec rspec`. Expected: 0 failures, 12 pending (the twelve skipped "preferred result" examples, and nothing else). The `by_sea` and `paradox_pos` examples pass for real. Run `bundle exec rake`.
- [ ] **Step 6:** commit "Give convoys a route and flag the paradox".

---

## Phase 5: The reference and the random convoy boards

**Implements:** AC-5.3, AC-5.4, AC-6.3, AC-8.1 to AC-8.6. **Files:** `spec/support/reference.rb`, `spec/support/random_convoy_boards.rb`, `spec/datc/datc_reference_spec.rb`, `spec/trucebearer/adjudicator/adjudicate_convoy_random_spec.rb` (all new).

- [ ] **Step 1: the reference.** It is written from the contract and the DATC's section 5, apart from the resolver: given the orders and a choice of which moves succeed, it derives every route, cut, strength and dislodgement and says whether the choice is consistent; it tries all choices for at most 12 moves, applies circular movement (the tie-break of AC-8.3), and says a board holds a paradox when none or more than one choice is left. It uses `TA.check` to know which orders are legal and nothing from `Resolver`.

`spec/support/reference.rb`:

```ruby
# frozen_string_literal: true

require_relative "board"

# A slow reference for the conditions of the DATC, written in the spec from the contract
# (docs/interface.md) and the DATC's section 5, and not from the resolver (spec 015, AC-8.2
# and AC-8.3). Given a position, orders and a choice of which moves succeed, it works out
# every other fact (routes, cuts, strengths, dislodgements) and says whether the choice is
# consistent with the conditions. It tries every choice for a small board, applies circular
# movement, and says the board holds a convoy paradox when no consistent choice is left, or
# more than one.
module Reference
  Entry = Data.define(:unit, :order) do
    def province = unit.location.province
    def power = unit.power
    def move? = order.is_a?(O::Move) || order.is_a?(O::MoveViaConvoy)
    def destination = order.is_a?(O::Move) ? order.destination.province : order.to
  end

  MAP = TA::Map.classic
  SEAS = MAP.provinces.select { |province| province.type == :sea }.map(&:id)

  module_function

  # One entry per unit: the owner's order when it passes checking, else a hold.
  def entries(position, orders)
    legal = orders.select { |order| TA.check(position, order).legal }.to_h { |order| [order.at, order] }
    position.units.map do |unit|
      Entry.new(unit: unit, order: legal[unit.location.province] || O::Hold.new(power: unit.power, at: unit.location.province))
    end
  end

  def by_land?(entry)
    MAP.adjacent?(:army, entry.unit.location, L.new(province: entry.destination))
  end

  # Does the move go by convoy? An army's move does when it is tagged, when the army can't walk
  # there, or when a fleet of its own power orders a matching convoy.
  def convoy?(entry, entries)
    return false unless entry.move? && entry.unit.type == :army
    return true if entry.order.is_a?(O::MoveViaConvoy) || !by_land?(entry)

    entries.any? { |other| carries?(other, entry) && other.power == entry.power }
  end

  def carries?(fleet, move)
    fleet.order.is_a?(O::Convoy) && fleet.order.from == move.province && fleet.order.to == move.destination
  end

  # Every fact that follows from `success` ({move entry => true/false}).
  def facts(entries, success)
    at = entries.to_h { |entry| [entry.province, entry] }
    moves = entries.select(&:move?)
    into = moves.group_by(&:destination)
    convoyed = moves.select { |move| convoy?(move, entries) }
    dislodged = entries.to_h do |entry|
      stays = !(entry.move? && success[entry])
      [entry, stays && (into[entry.province] || []).any? { |move| success[move] }]
    end
    route = moves.to_h do |move|
      next [move, true] unless convoyed.include?(move)

      seas = entries.select { |fleet| carries?(fleet, move) && !dislodged[fleet] }.map(&:province)
      [move, linked?(seas, move.province, move.destination)]
    end
    facts = { at: at, moves: moves, into: into, convoyed: convoyed, dislodged: dislodged, route: route, success: success }
    facts[:given] = entries.select { |entry| support?(entry) }.to_h { |entry| [entry, given?(entry, facts)] }
    facts
  end

  # A chain of the given seas from `from` to `to`: each next to the one before.
  def linked?(seas, from, to)
    touching = ->(sea, province) { MAP.province(province).type == :coastal && fleet_steps(sea).include?(province) }
    frontier = seas.select { |sea| touching.call(sea, from) }
    reached = frontier.dup
    until frontier.empty?
      sea = frontier.pop
      return true if touching.call(sea, to)

      (seas - reached).select { |next_sea| fleet_steps(sea).include?(next_sea) }.each do |next_sea|
        reached << next_sea
        frontier << next_sea
      end
    end
    false
  end

  def fleet_steps(province)
    @steps ||= {}
    @steps[province] ||= MAP.province(province).then do |p|
      places = p.coasts.empty? ? [L.new(province: province)] : p.coasts.map { |c| L.new(province: province, coast: c) }
      MAP.provinces.flat_map do |other|
        spots = other.coasts.empty? ? [L.new(province: other.id)] : other.coasts.map { |c| L.new(province: other.id, coast: c) }
        spots.select { |spot| places.any? { |place| MAP.adjacent?(:fleet, place, spot) } }.map { |spot| spot.province }
      end.uniq
    end
  end

  def support?(entry) = entry.order.is_a?(O::SupportHold) || entry.order.is_a?(O::SupportMove)

  def matched?(entry, at)
    case entry.order
    when O::SupportHold then !at[entry.order.target].move?
    when O::SupportMove then at[entry.order.from].move? && at[entry.order.from].destination == entry.order.to
    end
  end

  def cut?(support, facts)
    return true if facts[:dislodged][support]

    (facts[:into][support.province] || []).any? do |move|
      move.power != support.power && facts[:route][move] &&
        (support.order.is_a?(O::SupportHold) || move.province != support.order.to)
    end
  end

  def given?(support, facts) = matched?(support, facts[:at]) && !cut?(support, facts)

  def move_supports(move, facts, entries, except_power: nil)
    entries.count do |entry|
      entry.order.is_a?(O::SupportMove) && entry.order.from == move.province && entry.order.to == move.destination &&
        facts[:given][entry] && entry.power != except_power
    end
  end

  def head_to_head?(move, facts)
    other = facts[:at][move.destination]
    other&.move? && other.destination == move.province && !facts[:convoyed].include?(move) && !facts[:convoyed].include?(other)
  end

  def hold_strength(province, facts, entries)
    entry = facts[:at][province]
    return 0 unless entry
    return facts[:success][entry] ? 0 : 1 if entry.move?

    1 + entries.count { |other| other.order.is_a?(O::SupportHold) && other.order.target == province && facts[:given][other] }
  end

  def attack(move, facts, entries)
    return 0 unless facts[:route][move]

    other = facts[:at][move.destination]
    leaving = other&.move? && !head_to_head?(move, facts) && facts[:success][other]
    return 1 + move_supports(move, facts, entries) if other.nil? || leaving
    return 0 if other.power == move.power

    1 + move_supports(move, facts, entries, except_power: other.power)
  end

  def prevent(move, facts, entries)
    return 0 unless facts[:route][move]
    return 0 if head_to_head?(move, facts) && facts[:success][facts[:at][move.destination]]

    1 + move_supports(move, facts, entries)
  end

  # The success each move's strengths demand, given the facts.
  def demanded(move, facts, entries)
    strength = attack(move, facts, entries)
    other = facts[:at][move.destination]
    against = head_to_head?(move, facts) ? 1 + move_supports(other, facts, entries) : hold_strength(move.destination, facts, entries)
    rivals = (facts[:into][move.destination] - [move]).map { |rival| prevent(rival, facts, entries) }
    strength > against && rivals.all? { |rival| strength > rival }
  end

  def consistent?(entries, success)
    facts = facts(entries, success)
    facts[:moves].all? { |move| success[move] == demanded(move, facts, entries) }
  end

  # Circles of moves, read from the orders: each move into the province the next one leaves,
  # three or more of them, or two when one goes by convoy.
  def circles(entries)
    moves = entries.select(&:move?).to_h { |move| [move.province, move] }
    found = []
    moves.each_value do |start|
      path = [start]
      path << moves[path.last.destination] while moves[path.last.destination] && !path.include?(moves[path.last.destination])
      follower = moves[path.last.destination]
      next unless follower && path.include?(follower)

      circle = path[path.index(follower)..]
      convoyed = circle.any? { |move| convoy?(move, entries) }
      found << circle if (circle.size >= 3 || (circle.size == 2 && convoyed)) && found.none? { |c| (c & circle).any? }
    end
    found
  end

  # Every consistent choice that circular movement leaves.
  def solutions(entries)
    moves = entries.select(&:move?)
    raise "too many moves (#{moves.size})" if moves.size > 12

    all = [true, false].repeated_permutation(moves.size).map { |values| moves.zip(values).to_h }
                       .select { |success| consistent?(entries, success) }
    circles = circles(entries)
    all.reject do |success|
      circles.any? do |circle|
        circle.none? { |move| success[move] } && consistent?(entries, success.merge(circle.to_h { |move| [move, true] }))
      end
    end
  end

  def paradox?(entries) = solutions(entries).size != 1

  # The result symbol each entry's order must get, and whether it is dislodged, under `success`.
  def results(entries, success)
    facts = facts(entries, success)
    entries.to_h do |entry|
      result =
        case entry.order
        when O::Hold then :held
        when O::Move, O::MoveViaConvoy
          facts[:route][entry] ? (success[entry] ? :succeeded : :bounced) : :no_route
        when O::SupportHold, O::SupportMove
          matched?(entry, facts[:at]) ? (cut?(entry, facts) ? :cut : :given) : :unmatched
        when O::Convoy
          if facts[:convoyed].any? { |move| carries?(entry, move) }
            facts[:dislodged][entry] ? :disrupted : :given
          else
            :unmatched
          end
        end
      [entry, [result, facts[:dislodged][entry]]]
    end
  end
end
```

- [ ] **Step 2: the reference over the fixtures** (AC-6.3). `spec/datc/datc_reference_spec.rb`:

```ruby
# frozen_string_literal: true

require "trucebearer/adjudicator"
require_relative "../support/datc"
require_relative "../support/reference"

# The reference of the conditions (spec/support/reference.rb) run over every DATC fixture: the
# adjudicated cases have exactly one consistent result, and it is the one the fixture records;
# the convoy paradoxes that wait for #39 have none or more than one (AC-6.3 of spec 015). The
# reference is written from the contract and the DATC, apart from the resolver, so this checks
# the fixtures' results and the resolver's flag without either vouching for the other.
RSpec.describe "DATC fixtures: the reference of the conditions" do
  Datc.load_all.each do |kase|
    describe kase.id do
      let(:entries) { Reference.entries(kase.position, kase.entries.map(&:order)) }
      let(:solutions) { Reference.solutions(entries) }

      if kase.paradox
        it "has no consistent result, or more than one" do
          expect([0, 2]).to include(solutions.size)
        end
      else
        it "has one consistent result, and the fixture records it" do
          expect(solutions.size).to eq(1)
          wanted = Reference.results(entries, solutions.first)
          kase.entries.each do |fixture|
            if fixture.expected.legal
              entry = entries.find { |candidate| candidate.order == fixture.order }
              expect(wanted.fetch(entry)).to eq([fixture.result, fixture.dislodged]), "order at #{fixture.order.at}"
            else
              expect(fixture.result).to eq(:void)
            end
          end
        end
      end
    end
  end
end
```

Run it: green. This confirms every label and dislodged mark of the 46 fixtures independently of the resolver, and that each of the twelve has none or two results. **If a pending case has exactly one, or any fixture's result differs, stop and `ask` (Global Constraints).**

- [ ] **Step 3: the random convoy boards.** `spec/support/random_convoy_boards.rb`: a seeded generator whose boards hold an army, a chain of one to three fleets (or a second one-fleet route), a destination across them, then some of: attacks on carrying fleets with supports, a unit on the destination supporting such an attack (the paradox shape), a unit moving the other way (a swap), and filler units with random legal orders (convoy orders and moves via convoy included).

```ruby
# frozen_string_literal: true

require_relative "random_boards"

# Random movement positions and orders that hold convoys (spec 015, Story 8). Every board is
# made from a seeded Random. A board starts with an army, a chain of one to three fleets at sea
# and a destination across them, and then gets some of: an attack on a carrying fleet with
# supports, a unit on the destination that supports that attack (the shape of the simplest
# paradox), a unit moving the other way (a swap), and random units with random legal orders.
module RandomConvoyBoards
  REACH = TA.const_get(:Reach)
  COASTAL = REACH::COASTAL
  POWERS = RandomBoards::POWERS

  module_function

  # [position, orders]. `size` is the number of units, 3 to 34.
  def board(rng, size: rng.rand(4..12))
    units = {}
    orders = []
    from, path, to = chain(rng)
    army = place(units, rng, :army, from)
    orders << (REACH.reaches?(army, to) && rng.rand < 0.5 ? O::MoveViaConvoy.new(power: army.power, at: from, to: to) :
                                                             O::Move.new(power: army.power, at: from, destination: L.new(province: to)))
    path.each do |sea|
      fleet = place(units, rng, :fleet, sea, power: rng.rand < 0.6 ? army.power : nil)
      orders << O::Convoy.new(power: fleet.power, at: sea, from: from, to: to) unless rng.rand < 0.1
    end
    path += alternative(rng, units, orders, army, from, path, to) if path.size == 1 && rng.rand < 0.5
    2.times { attack_carrier(rng, units, orders, path, to) if rng.rand < 0.7 }
    swap(rng, units, orders, from, to) if rng.rand < 0.25
    fill(rng, units, size)
    position = Board.position(*units.values)
    given = orders.map(&:at)
    [position, orders + random_orders(rng, position, units.values.reject { |unit| given.include?(unit.location.province) })]
  end

  def chain(rng)
    loop do
      from = COASTAL.sample(random: rng)
      first = REACH::SEA_TOUCHES.fetch(from).to_a.sample(random: rng)
      next unless first

      path = [first]
      rng.rand(0..2).times do
        options = (REACH::SEA_LINKS.fetch(path.last) - path).reject { |sea| REACH.touches?(sea, from) }
        break if options.empty?

        path << options.to_a.sample(random: rng)
      end
      ends = COASTAL.select { |to| to != from && REACH.touches?(path.last, to) && path[0...-1].none? { |sea| REACH.touches?(sea, to) } }
      return [from, path, ends.sample(random: rng)] unless ends.empty?
    end
  end

  # A second sea that touches both ends is a second route. Returns it in an array, or none.
  def alternative(rng, units, orders, army, from, path, to)
    seas = REACH::SEAS.select { |sea| !units.key?(sea) && !path.include?(sea) && REACH.touches?(sea, from) && REACH.touches?(sea, to) }
    return [] if seas.empty?

    sea = seas.sample(random: rng)
    fleet = place(units, rng, :fleet, sea, power: rng.rand < 0.6 ? army.power : nil)
    orders << O::Convoy.new(power: fleet.power, at: sea, from: from, to: to) unless rng.rand < 0.1
    [sea]
  end

  def place(units, rng, type, province, power: nil)
    coast = type == :fleet && !TA::Map.classic.coasts(province).empty? ? TA::Map.classic.coasts(province).sample(random: rng) : nil
    units[province] = TA::Unit.new(power: power || POWERS.sample(random: rng), type: type, location: L.new(province: province, coast: coast))
  end

  # A fleet next to a carrying sea moves into it, with supports; a fleet on the destination may
  # support that move, which the convoyed army then attacks.
  def attack_carrier(rng, units, orders, path, to)
    sea = path.sample(random: rng)
    starts = REACH::FLEET_STEPS.keys.select do |(province, coast)|
      !units.key?(province) && REACH::FLEET_STEPS[[province, coast]].any? { |(next_province, _)| next_province == sea }
    end
    return if starts.empty?

    province, coast = starts.sample(random: rng)
    attacker = units[province] = TA::Unit.new(power: POWERS.sample(random: rng), type: :fleet, location: L.new(province: province, coast: coast))
    orders << O::Move.new(power: attacker.power, at: province, destination: L.new(province: sea))
    supporters = REACH::FLEET_STEPS.keys.select do |(p, c)|
      !units.key?(p) && p != province && REACH::FLEET_STEPS[[p, c]].any? { |(n, _)| n == sea }
    end
    supporters.sample(rng.rand(0..2), random: rng).each do |(p, c)|
      next if units.key?(p)

      support = units[p] = TA::Unit.new(power: POWERS.sample(random: rng), type: :fleet, location: L.new(province: p, coast: c))
      orders << O::SupportMove.new(power: support.power, at: p, from: province, to: sea)
    end
    return if units.key?(to) || rng.rand < 0.4

    near = REACH::FLEET_STEPS.keys.select { |(p, _)| p == to }.select { |key| REACH::FLEET_STEPS[key].any? { |(n, _)| n == sea } }
    return if near.empty?

    _, coast = near.sample(random: rng)
    mine = units[to] = TA::Unit.new(power: POWERS.sample(random: rng), type: :fleet, location: L.new(province: to, coast: coast))
    orders << O::SupportMove.new(power: mine.power, at: to, from: province, to: sea)
  end

  # An army on the destination moves the other way.
  def swap(rng, units, orders, from, to)
    return if units.key?(to)

    other = place(units, rng, :army, to)
    orders << O::Move.new(power: other.power, at: to, destination: L.new(province: from))
  end

  def fill(rng, units, size)
    while units.size < [size, 34].min
      if rng.rand < 0.5
        province = (RandomBoards::LAND - units.keys).sample(random: rng)
        place(units, rng, :army, province)
      else
        province, = RandomBoards::FLEET_PLACES.reject { |(id, _)| units.key?(id) }.sample(random: rng)
        place(units, rng, :fleet, province)
      end
    end
  end

  def random_orders(rng, position, units)
    weights = { O::Hold => 1, O::Move => 3, O::MoveViaConvoy => 1, O::SupportHold => 1, O::SupportMove => 3, O::Convoy => 3 }
    units.filter_map do |unit|
      next if rng.rand < 0.1

      legal = TA.legal_orders(position, unit)
      klass = weights.flat_map { |k, w| [k] * w }.sample(random: rng)
      pool = legal.select { |order| klass === order }
      (pool.empty? ? legal : pool).sample(random: rng)
    end
  end
end
```

- [ ] **Step 4: the random spec.** `spec/trucebearer/adjudicator/adjudicate_convoy_random_spec.rb`:

```ruby
# frozen_string_literal: true

require "trucebearer/adjudicator"
require_relative "../../support/random_convoy_boards"
require_relative "../../support/reference"

# Convoys on seeded random boards (spec 015, Story 8). Small boards are checked against the
# brute-force reference of spec/support/reference.rb, which says whether a board holds a paradox
# and what every result must be; large boards are checked for validity, and, when no paradox
# is flagged, for being a consistent result.
RSpec.describe "TA.adjudicate on random boards with convoys" do
  small = Array.new(500) { |index| [index, Random.new(15_000 + index)] }.map do |index, rng|
    position, orders = RandomConvoyBoards.board(rng)
    [index, position, orders, TA.adjudicate(position, orders)]
  end
  large = Array.new(150) { |index| [index, Random.new(34_000 + index)] }.map do |index, rng|
    position, orders = RandomConvoyBoards.board(rng, size: rng.rand(13..34))
    [index, position, orders, TA.adjudicate(position, orders)]
  end

  def outcome_for(adjudication, entry)
    adjudication.outcomes.find { |o| o.order == entry.order && o.submitted } ||
      adjudication.outcomes.find { |o| o.order.at == entry.province && !o.submitted }
  end

  def placed_once(position, adjudication)
    after = adjudication.position
    (after.units + after.dislodged_units.map(&:unit)).map { |unit| [unit.power, unit.type] }.tally ==
      position.units.map { |unit| [unit.power, unit.type] }.tally
  end

  def no_self_dislodgement(position, adjudication)
    adjudication.position.dislodged_units.none? do |entry|
      position.units.find { |unit| unit.location.province == entry.attacker_from }.power == entry.unit.power
    end
  end

  it "adjudicates every board, builds a valid position, keeps every unit once and dislodges no unit of its own power (AC-8.2)" do
    (small + large).each do |index, position, orders, adjudication|
      expect(adjudication).to be_a(TA::Adjudication), "board #{index}"
      expect(adjudication.outcomes.size).to be >= orders.size
      expect(placed_once(position, adjudication)).to be(true), "board #{index}"
      expect(no_self_dislodgement(position, adjudication)).to be(true), "board #{index}"
    end
  end

  it "sets the flag exactly when the reference finds none or more than one result, and gives the reference's results otherwise (AC-8.3)" do
    small.each do |index, position, orders, adjudication|
      entries = Reference.entries(position, orders)
      solutions = Reference.solutions(entries)
      expect(adjudication.paradox).to be(solutions.size != 1), "board #{index}"
      next if adjudication.paradox

      wanted = Reference.results(entries, solutions.first)
      entries.each do |entry|
        outcome = outcome_for(adjudication, entry)
        expect([outcome.result, outcome.dislodged]).to eq(wanted.fetch(entry)), "board #{index}, unit at #{entry.province}"
      end
    end
  end

  it "holds each hard shape in at least 20 small boards, counted from the orders and the reference (AC-8.1)" do
    counts = Hash.new(0)
    small.each do |_, position, orders, adjudication|
      entries = Reference.entries(position, orders)
      counts[:convoyed] += 1 if entries.any? { |entry| entry.move? && Reference.convoy?(entry, entries) }
      counts[:carrier_dislodged] += 1 if adjudication.outcomes.any? { |o| o.order.is_a?(O::Convoy) && o.result == :disrupted }
      counts[:swap_by_convoy] += 1 if Reference.circles(entries).any? { |circle| circle.size == 2 }
      counts[:paradox] += 1 if Reference.paradox?(entries)
      counts[:convoyed_no_paradox] += 1 if entries.any? { |entry| entry.move? && Reference.convoy?(entry, entries) } && !Reference.paradox?(entries)
    end
    expect(counts.values_at(:convoyed, :carrier_dislodged, :swap_by_convoy, :paradox, :convoyed_no_paradox).min).to be >= 20, counts.inspect
  end

  it "gives a result that is consistent with the conditions on every large board with no paradox flagged (AC-8.2)" do
    large.each do |index, position, orders, adjudication|
      entries = Reference.entries(position, orders)
      if adjudication.paradox
        expect(entries.any? { |entry| entry.move? && Reference.convoy?(entry, entries) }).to be(true), "board #{index}"
        next
      end

      success = entries.select(&:move?).to_h { |entry| [entry, outcome_for(adjudication, entry).result == :succeeded] }
      expect(Reference.consistent?(entries, success)).to be(true), "board #{index}"
      wanted = Reference.results(entries, success)
      entries.each do |entry|
        outcome = outcome_for(adjudication, entry)
        expect([outcome.result, outcome.dislodged]).to eq(wanted.fetch(entry)), "board #{index}, unit at #{entry.province}"
      end
    end
  end

  it "sets the flag only where a move goes by convoy (AC-8.4)" do
    (small + large).select { |*, adjudication| adjudication.paradox }.each do |index, position, orders, _|
      entries = Reference.entries(position, orders)
      expect(entries.any? { |entry| entry.move? && Reference.convoy?(entry, entries) }).to be(true), "board #{index}"
    end
  end

  it "gives the same flag, a valid position and, with no paradox, the same results for shuffled orders (AC-8.6)" do
    key = lambda do |adjudication|
      adjudication.outcomes.to_h { |o| [o.order, [o.result, o.submitted, o.dislodged]] }
    end
    (small + large).each_with_index do |(index, position, orders, adjudication), number|
      shuffled = TA.adjudicate(position, orders.shuffle(random: Random.new(number)))
      expect(shuffled.paradox).to be(adjudication.paradox), "board #{index}"
      expect(placed_once(position, shuffled)).to be(true), "board #{index}"
      expect([key.call(shuffled), shuffled.position]).to eq([key.call(adjudication), adjudication.position]) unless adjudication.paradox
    end
  end

  it "adjudicates a position of 34 units with convoys in under a second (AC-8.5)" do
    position, orders = RandomConvoyBoards.board(Random.new(34), size: 34)
    expect(position.units.size).to eq(34)
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    TA.adjudicate(position, orders)
    expect(Process.clock_gettime(Process::CLOCK_MONOTONIC) - started).to be < 1.0
  end
end
```

Run both files: green (about 3 s). The existing `adjudicate_random_spec.rb` stays as it is: its boards hold no convoy, so its "never sets the paradox flag" example still states what is true of them.
- [ ] **Step 5: mutation check.** In the scratch copy only (never in the repository), make each of these changes to `resolver.rb`, run `bundle exec rspec spec/datc spec/trucebearer/adjudicator`, see failures, and restore the file: (a) in `widen`, `else [0, strength[1]]` becomes `else strength`; (b) in `cuts?`, an open route returns `true`; (c) in `route`, `safe` requires every carrying fleet instead of one chain; (d) in `route`, `possible` ignores dislodgement. Each must fail at least one example. (The scratch run saw 1, 59, 34 and 165 failing boards of 1 000, 600, 1 000 and 1 000, and the fixtures and the convoys spec fail too.)
- [ ] **Step 6:** `bundle exec rake`; commit "Check convoys against a brute-force reference and on random boards".

---

## Phase 6: The records and the final checks

**Implements:** AC-9.1 to AC-9.3, AC-6.6 (the overlap check), AC-7.3. **Files:** `docs/ruleset.md`, `CHANGELOG.md`.

- [ ] **Step 1: `docs/ruleset.md`.** Delete the row `4.A.1, 4.A.3 | (Temporary) Does a convoy route work in this build? ...`. Replace the existing `4.A.1` row with:

```markdown
| 4.A.1 | When does a convoy with several routes fail, and what carries a convoyed army? | Only when every route is broken. A route is a chain of fleets whose own legal convoy orders match the move, of any power; only dislodging a fleet breaks it, and an attack that fails to dislodge changes nothing | The DATC's preferred option. 6.F.9 to 6.F.13, 6.F.19 and 6.F.20 rest on it |
```

Add after the `4.A.3` row:

```markdown
| 4.A.2 | Does a convoyed army cut the support of a unit that supports an attack on one of the fleets that carry it? | Yes, like any move that has a route. No paradox rule (the older rulebooks' or Szykman's) is applied | 6.F.19, 6.F.20, 6.F.21, 6.F.25 and 6.F.29 rest on this together with the "every route broken" option of 4.A.1: with both, each has exactly one consistent result, so the flag is clear. A paradox rule added in #39 must leave these five unchanged; they are the cases to check first |
| 4.A.2 | What does the engine do with orders that hold a convoy paradox? | It sets `paradox` and returns a valid result: the moves still undecided after strengths and circular movement all fail, and every other decision stands. Outcomes and where units end up are unspecified until #39. Paradox resolution is not attempted | 6.F.14 to 6.F.18, 6.F.22 to 6.F.24, 6.F.26 to 6.F.28 and 6.G.11 are fixtures that check the flag and a valid position only |
| 4.A.3, 5.B.9 | Can two units swap places when only one of them goes by convoy, and do circles with convoyed armies move? | Yes. A move that goes by convoy is never a head-to-head battle, so a swap with one convoy, a swap with two, and a circle that holds convoyed armies are circular movement, which succeeds when nothing else stops one of them and every route is sure | 6.C.4, 6.C.6, 6.E.11, 6.G.1, 6.G.5, 6.G.9, 6.G.12 |
```

Replace the second `5.B.9` row (the one that says "#15 decides what it becomes") with:

```markdown
| 5.B.9 | What if moves are still undecided when no rule applies? | They fail, and `paradox` is true: it is a convoy paradox (see 4.A.2). Without convoys it can't happen, which seeded random boards check | The DATC advises failing the non-hold orders of a cycle no rule decides |
```

- [ ] **Step 2: `CHANGELOG.md`.** In the #14 entry under "Unreleased", "Added": change "adjudicating a movement phase with no convoys," to "adjudicating a movement phase,", and delete the sentence "**Convoy routing arrives with #15, before 0.2.0 ships:** until then a move that goes by convoy is `:no_route` and a legal convoy order is `:unmatched`." (the sentence about the DATC cases of 6.A to 6.E and 6.F.1 stays: it is still true). Add a new item below it:

```markdown
- Convoys in `TA.adjudicate`: a move that goes by convoy needs a route of the fleets that convoy it and fails only when every route is broken; a convoy order is `:given`, `:disrupted` or `:unmatched`; a unit dislodged by a convoyed army has `by_convoy: true`; a swap by convoy and a circle that holds a convoyed army move; and `paradox` is set when the orders hold a convoy paradox, whose outcomes stay unspecified until #39. The DATC cases of 6.B to 6.G that need a convoy are fixtures with their results (126 adjudicated fixtures in all), the twelve paradox cases wait for #39 as fixtures that check the flag and a valid position, and a slow reference written in the specs, with seeded random boards that hold convoys, confirms them. (#15)
```

No "Changed" entry: nothing in the contract changed.
- [ ] **Step 3: the DATC overlap check** over every file the pull request changes (the maintainer's check: lowercase the words, strip the tags, compare 8-word runs against `docs/reference/datc-v3.4.html`). Save this as a scratch script and run it from `adjudicator/`:

```python
import re, sys, html


def words(t):
    t = re.sub(r'<(script|style).*?</\1>', '', t, flags=re.S)
    t = re.sub(r'<[^>]+>', ' ', t)
    t = html.unescape(t).lower()
    return re.findall(r"[a-z0-9']+", t)


ref = words(open('docs/reference/datc-v3.4.html', encoding='latin-1').read())
runs = {tuple(ref[i:i + 8]) for i in range(len(ref) - 7)}
total = 0
for f in sys.argv[1:]:
    w = words(open(f, encoding='utf-8', errors='replace').read())
    hits = [' '.join(w[i:i + 8]) for i in range(len(w) - 7) if tuple(w[i:i + 8]) in runs]
    total += len(hits)
    if hits:
        print(f, len(hits), hits[:5])
print('files', len(sys.argv) - 1, 'shared 8-word runs', total)
```

```
python3 -I overlap.py $(git diff --name-only main...HEAD | sed 's|^adjudicator/||')
```

Expected: `shared 8-word runs 0`. Put the output in the pull request. A hit is a sentence to reword (the 6.E.3 fix of #14 is the precedent).
- [ ] **Step 4: the final checks.** From `adjudicator/`: `bundle exec rspec` and `bundle exec rake` pass with 0 failures and 12 pending, and the 12 are the skipped paradox examples; `git diff --name-only main...HEAD` lists only paths under `adjudicator/`, and `docs/interface.md` is not among them; `grep -rn "pending \"convoys" spec` finds nothing; `grep -rn "last_resort\|temporary" lib spec` finds nothing that describes convoys as not working.
- [ ] **Step 5:** commit "Record the convoy choices and the changelog entry".

---

## Finish (after Phase 6)

1. Dispatch the implementation review: a read-only Opus subagent over the diff, with the spec and this plan. Record its findings, and how each was handled, in the pull request description.
2. Run `sdd-superpowers:session-wrap`; commit only memory items a fresh session could not rediscover, inside `adjudicator/`, or none.
3. Push; the first push opens a draft pull request that follows `.github/pull_request_template.md`, says "Closes #15", includes the overlap-check output, and ends with the attribution line. Run the tests locally; wait for the `Adjudicator` job to go green.
4. `gh pr ready`, then `gh pr edit --add-assignee @me`. Report to the coordinator.

## Self-review

- **Spec coverage.** AC-1.x: Phase 1 and 4. AC-2.x and 3.x: the convoys spec and the fixtures (Phases 3 and 4). AC-4.x: 6.C.4 to 6.C.7 and the convoys spec. AC-5.1, 5.2, 5.5, 5.6: the paradox runner and the convoys spec; AC-5.3 and 5.4: the reference spec and the random spec. AC-6.1 to 6.7: Phases 2, 3 and 5. AC-7.x: Phase 4 and 6. AC-8.1 to 8.6: Phase 5. AC-9.1 to 9.3: Phase 6. No gap.
- **Placeholders.** None: every code step shows code, and the generated files are produced by code that is in this plan.
- **Type consistency.** `Datc::Case#paradox`, `Datc::ADJUDICATED`, `Datc::PARADOX_PENDING`, `Reach.linked?(seas, from, to)`, `Resolver#route`, `#dislodged_state`, `#widen`, `#circle?`, `#fail_residue`, `Reference.entries`, `.solutions`, `.results`, `.consistent?`, `.circles`, `.convoy?`, `.paradox?` and `RandomConvoyBoards.board(rng, size:)` are named the same in every phase.
- **Size.** About 960 added lines of code, specs and docs apart from the 58 fixtures; one pull request.
