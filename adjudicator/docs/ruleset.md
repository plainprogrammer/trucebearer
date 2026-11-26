# Ruleset

The engine follows the current rulebook, with the DATC (Diplomacy Adjudicator Test Cases) deciding edge cases. Where the DATC leaves a choice open, the option the engine takes is recorded here.

Write every entry in your own words. Cite the DATC section and any rulebook section by number. Never quote either document.

Citations refer to DATC v3.4. The repository keeps an unmodified copy for reading at `docs/reference/datc-v3.4.html`, relative to the gem folder (`adjudicator/`). Don't quote it here.

## Choices

| DATC section | Question, in our words | Option taken | Why |
|---|---|---|---|
| 4.A.1 | When does a convoy with several routes fail, and what carries a convoyed army? | Only when every route is broken. A route is a chain of fleets whose own legal convoy orders match the move, of any power; only dislodging a fleet breaks it, and an attack that fails to dislodge changes nothing | The DATC's preferred option. 6.F.9 to 6.F.13, 6.F.19 and 6.F.20 rest on it |
| 4.A.2 | When the orders hold no paradox, does a convoyed army cut the support of a unit that supports an attack on one of the fleets that carry it? | Yes, like any move that has a route. No paradox rule (the older rulebooks' or Szykman's) is applied | 6.F.19, 6.F.20, 6.F.21, 6.F.25 and 6.F.29 rest on this together with the "every route broken" option of 4.A.1: with both, each has exactly one consistent result, so the flag is clear. For #39: a Szykman-style or 2000-style rule leaves these unchanged; the 1982 rule would change 6.F.19, 6.F.20, 6.F.21 and 6.F.29 (and, by our reading of it, 6.F.25), and disrupting a convoy when any one route is broken (option a of 4.A.1) would change 6.F.19 and 6.F.20. A paradox rule added in #39 must keep all five clear of the flag |
| 4.A.2 | What does the engine do with orders that hold a convoy paradox? | It sets `paradox` and returns a valid result: the moves still undecided after strengths and circular movement all fail, and every other decision stands. Outcomes and where units end up are unspecified until #39. Paradox resolution is not attempted | 6.F.14 to 6.F.18, 6.F.22 to 6.F.24, 6.F.26 to 6.F.28 and 6.G.11 are fixtures that check the flag and a valid position only |
| 4.A.3 | When does a move to a neighboring province go by sea? | When a fleet of the same power orders the convoy, or the move is tagged "via convoy". It never falls back to land. The tag is accepted only for neighboring destinations | Preferred; the tag restriction is our input-contract choice |
| 4.A.4 | Where does an attack carried by sea count as coming from? | From the army's own starting province | Preferred |
| 4.A.5 | May a unit dislodged by a sea-borne attack retreat to where the attacker started? | Yes. The result records `by_convoy` so the 0.3 retreat logic can allow it | Preferred |
| 4.A.7 | Does a dislodged unit still contest the province its attacker left? | It stops contesting only if it lost a head-to-head battle | Preferred |
| 4.A.3, 5.B.9 | Can two units swap places when only one of them goes by convoy, and do circles with convoyed armies move? | Yes. A move that goes by convoy is never a head-to-head battle, so a swap with one convoy, a swap with two, and a circle that holds convoyed armies are circular movement, which succeeds when nothing else stops one of them and every route is sure | 6.C.4, 6.C.6, 6.E.11, 6.G.1, 6.G.5, 6.G.9, 6.G.12 |
| 4.B.2 | Is a fleet move to a split-coast province valid without a coast when only one coast can be reached? | No; the coast is always required | Strict, against the preference. Orders are picked from lists |
| 4.B.3 | What if the named coast can't be reached? | The order is rejected | Preferred |
| 4.B.4 | May a support name a coast? | No; supports name provinces only | Not one of the listed options. It is an input-contract choice |
| 4.B.5 | What if an order gives the wrong coast for the ordered unit? | It can't happen, since the unit is named by province | Gives the preferred results |
| 4.B.6 | What about a coast on an army move, or an unknown coast? | The army move is rejected. An unknown coast raises `InvalidInput` | Strict, against the preference |
| 4.D.3 | What if one power gives the same unit two orders? | `InvalidInput` is raised. Two orders count as two for one unit when the same power names the same province in both, even when no unit stands there. An order from a power that doesn't own the unit is void and counts for the power that gave it | Not one of the listed options. The app keeps one order per unit |
| 4.E.1 | What happens to an order that breaks the rules? | It is void, and the unit holds and can still be supported | Preferred |
| 4.E.2 | What are the results of an order called? | The nine result symbols of `interface.md`; the DATC leaves naming free | Names chosen for display and replay |
| 4.E.3 | What does a unit do when its owner gave it no legal order? | It holds. The hold is implied, is not marked as submitted, and other units can support it | Preferred; with 4.E.1 this also covers a void order |
| 5.B.9 | What happens to a circle of moves, each into the province the next one leaves? | With three or more units, all succeed unless something else stops one of them. A circle of two plain moves is a head-to-head battle and is decided by strength; a swap in which one army goes by convoy is circular movement (see 4.A.3). None of this is a paradox | The DATC's circular-movement rule |
| 5.B.9 | What if moves are still undecided when no rule applies? | They fail, and `paradox` is true: it is a convoy paradox (see 4.A.2). Without convoys it can't happen, which seeded random boards check | The DATC advises failing the non-hold orders of a cycle no rule decides |
| 6.H.6, 6.H.9, 6.H.17 | What is a standoff, for the retreat phase? | A province that is empty after the moves and that at least two moves with a route entered on equal terms: neither lost a head-to-head battle, and they shared the greatest prevent strength. A province whose own unit stays, one that a winner entered, and one whose attackers were stopped by a stronger unit or lost a head-to-head battle are not standoffs | The retreat cases name "contested" provinces without defining them; this is our reading of them |
| 6.D.31 | May a unit support a move that could happen only through a convoy chain that needs the supporter's own fleet? | No. The support is rejected with `move_impossible`, judging the supported army's chain without the supporter's fleet | Our reading of 4.E.1: the order lists offer only orders that could matter. One fleet can't be both the sea route and the support |
| 6.G.19 | May a fleet that no minimal convoy chain needs give a convoy order? | No. It is rejected with `not_on_chain`; a chain counts only when none of its own fleets can be left out and still leave a chain, so a shorter chain elsewhere doesn't matter | Our reading of 4.E.1, as above; it also keeps the question of who showed intent out of checking |

## Departures from preferred results

- **6.B.2:** the order is rejected, because 4.B.2 is taken strictly.
- **6.B.12:** the order is rejected, because 4.B.6 is taken strictly.
- **6.B.9:** can't be expressed, since supports carry no coast.
- **Duplicate orders (4.D.3):** they raise. There is no chapter 6 test for this.

6.B.10 and 6.B.11 are encoded without the unit's coast and give the preferred results. 6.B.7, 6.B.8 and 6.B.15 to 6.B.17 give the preferred results under the province-only rule.
