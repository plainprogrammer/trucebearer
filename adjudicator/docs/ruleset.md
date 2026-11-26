# Ruleset

The engine follows the current rulebook, with the DATC (Diplomacy Adjudicator Test Cases) deciding edge cases. Where the DATC leaves a choice open, the option the engine takes is recorded here.

Write every entry in your own words. Cite the DATC section and any rulebook section by number. Never quote either document.

Citations refer to DATC v3.4. The repository keeps an unmodified copy for reading at `docs/reference/datc-v3.4.html`, relative to the gem folder (`adjudicator/`). Don't quote it here.

## Choices

| DATC section | Question, in our words | Option taken | Why |
|---|---|---|---|
| 4.A.1 | When does a convoy with several possible routes fail? | Only when every route is broken | The DATC's preferred option |
| 4.A.3 | When does a move to a neighboring province go by sea? | When a fleet of the same power orders the convoy, or the move is tagged "via convoy". It never falls back to land. The tag is accepted only for neighboring destinations | Preferred; the tag restriction is our input-contract choice |
| 4.A.4 | Where does an attack carried by sea count as coming from? | From the army's own starting province | Preferred |
| 4.A.5 | May a unit dislodged by a sea-borne attack retreat to where the attacker started? | Yes. The result records `by_convoy` so the 0.3 retreat logic can allow it | Preferred |
| 4.A.7 | Does a dislodged unit still contest the province its attacker left? | It stops contesting only if it lost a head-to-head battle | Preferred |
| 4.B.2 | Is a fleet move to a split-coast province valid without a coast when only one coast can be reached? | No; the coast is always required | Strict, against the preference. Orders are picked from lists |
| 4.B.3 | What if the named coast can't be reached? | The order is rejected | Preferred |
| 4.B.4 | May a support name a coast? | No; supports name provinces only | Not one of the listed options. It is an input-contract choice |
| 4.B.5 | What if an order gives the wrong coast for the ordered unit? | It can't happen, since the unit is named by province | Gives the preferred results |
| 4.B.6 | What about a coast on an army move, or an unknown coast? | The army move is rejected. An unknown coast raises `InvalidInput` | Strict, against the preference |
| 4.D.3 | What if one power gives the same unit two orders? | `InvalidInput` is raised | Not one of the listed options. The app keeps one order per unit |
| 4.E.1 | What happens to an order that breaks the rules? | It is void, and the unit holds and can still be supported | Preferred |
| 6.D.31 | May a unit support a move that could happen only through a convoy chain that needs the supporter's own fleet? | No. The support is rejected with `move_impossible`, judging the supported army's chain without the supporter's fleet | Our reading of 4.E.1: the order lists offer only orders that could matter. One fleet can't be both the sea route and the support |
| 6.G.19 | May a fleet that no minimal convoy chain needs give a convoy order? | No. It is rejected with `not_on_chain`; a chain counts only when no smaller set of fleets is also a chain | Our reading of 4.E.1, as above; it also keeps the question of who showed intent out of checking |

## Departures from preferred results

- **6.B.2:** the order is rejected, because 4.B.2 is taken strictly.
- **6.B.12:** the order is rejected, because 4.B.6 is taken strictly.
- **6.B.9:** can't be expressed, since supports carry no coast.
- **Duplicate orders (4.D.3):** they raise. There is no chapter 6 test for this.

6.B.10 and 6.B.11 are encoded without the unit's coast and give the preferred results. 6.B.7, 6.B.8 and 6.B.15 to 6.B.17 give the preferred results under the province-only rule.
