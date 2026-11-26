# Public interface

This file is the contract between the gem and anything that uses it, including the Trucebearer web app. Whatever is described here, callers may rely on. Whatever isn't described here is internal and may change in any release.

Everything that crosses the boundary, in either direction, is an immutable value object. Every value object has a hash form, which can be saved as JSON and rebuilt into an equal object later. The ones the app stores also carry a `format` version (see [Value objects](#value-objects)). The map is the one exception: it is queried, never stored (see [Map](#map)).

The examples in this file use these abbreviations:

```ruby
TA = Trucebearer::Adjudicator
L  = TA::Location
O  = TA::Order
```

How this document may change is set out in [Change rules](#change-rules).

## Releases

Each section below arrives in the release shown here. Before 1.0, any minor version (0.x.0) may change the interface. A patch version (0.x.y) never does.

| Section | Release |
|---|---|
| Identifiers | 0.1.0 |
| Map | 0.1.0 |
| Value objects | 0.1.0 |
| Checking an order | 0.1.0 |
| Legal orders | 0.1.0 |
| Errors: building value objects and checking orders | 0.1.0 |
| Adjudicating a movement phase | 0.2.0 |
| Errors: adjudication | 0.2.0 |
| Retreats | 0.3 |
| Adjustments | 0.3 |

## Identifiers

*Arrives in 0.1.0.*

Maps, powers, provinces, coasts, seasons, phases and unit types are all named by identifiers.

- **In Ruby**, an identifier is a lowercase `Symbol`, such as `:par`.
- **In the hash form**, it is the same text as a `String`, such as `"par"`. It survives a round trip through JSON unchanged.
- `new` accepts symbols only, and `from_h` accepts strings only. Anything else raises `TA::InvalidInput` (see [Errors](#errors)).
- The **map** identifier is the exception: it is the `String` `"classic"` both in Ruby and in the hash form.

| Kind | Identifiers |
|---|---|
| Map | `"classic"` |
| Powers | `:austria`, `:england`, `:france`, `:germany`, `:italy`, `:russia`, `:turkey` |
| Coasts | `:ec`, `:nc`, `:sc` |
| Seasons | `:spring`, `:fall` |
| Phases | `:movement`, `:retreat`, `:adjustment` |
| Unit types | `:army`, `:fleet` |

Three provinces have split coasts: `bul` has `:ec` and `:sc`, while `spa` and `stp` each have `:nc` and `:sc`. Every other province has none.

```ruby
TA::Map.classic.province(:stp).coasts     # => [:nc, :sc]
L.new(province: :stp, coast: :sc).to_h    # => {"province" => "stp", "coast" => "sc"}
L.new(province: "stp")                    # raises TA::InvalidInput (new takes symbols)
```

### Provinces

The classic map has the 75 provinces below, sorted by identifier. Each identifier is the game's standard three-letter abbreviation. "SC" marks a supply center, and "Home" names the power whose home center it is. The same lists are available from the map at run time (see [Map](#map)).

| Id | Name | Type | SC | Home |
|---|---|---|---|---|
| `adr` | Adriatic Sea | sea | | |
| `aeg` | Aegean Sea | sea | | |
| `alb` | Albania | coastal | | |
| `ank` | Ankara | coastal | SC | turkey |
| `apu` | Apulia | coastal | | |
| `arm` | Armenia | coastal | | |
| `bal` | Baltic Sea | sea | | |
| `bar` | Barents Sea | sea | | |
| `bel` | Belgium | coastal | SC | |
| `ber` | Berlin | coastal | SC | germany |
| `bla` | Black Sea | sea | | |
| `boh` | Bohemia | inland | | |
| `bot` | Gulf of Bothnia | sea | | |
| `bre` | Brest | coastal | SC | france |
| `bud` | Budapest | inland | SC | austria |
| `bul` | Bulgaria | coastal | SC | |
| `bur` | Burgundy | inland | | |
| `cly` | Clyde | coastal | | |
| `con` | Constantinople | coastal | SC | turkey |
| `den` | Denmark | coastal | SC | |
| `eas` | Eastern Mediterranean | sea | | |
| `edi` | Edinburgh | coastal | SC | england |
| `eng` | English Channel | sea | | |
| `fin` | Finland | coastal | | |
| `gal` | Galicia | inland | | |
| `gas` | Gascony | coastal | | |
| `gol` | Gulf of Lyon | sea | | |
| `gre` | Greece | coastal | SC | |
| `hel` | Helgoland Bight | sea | | |
| `hol` | Holland | coastal | SC | |
| `ion` | Ionian Sea | sea | | |
| `iri` | Irish Sea | sea | | |
| `kie` | Kiel | coastal | SC | germany |
| `lon` | London | coastal | SC | england |
| `lvn` | Livonia | coastal | | |
| `lvp` | Liverpool | coastal | SC | england |
| `mao` | Mid-Atlantic Ocean | sea | | |
| `mar` | Marseilles | coastal | SC | france |
| `mos` | Moscow | inland | SC | russia |
| `mun` | Munich | inland | SC | germany |
| `naf` | North Africa | coastal | | |
| `nao` | North Atlantic Ocean | sea | | |
| `nap` | Naples | coastal | SC | italy |
| `nth` | North Sea | sea | | |
| `nwg` | Norwegian Sea | sea | | |
| `nwy` | Norway | coastal | SC | |
| `par` | Paris | inland | SC | france |
| `pic` | Picardy | coastal | | |
| `pie` | Piedmont | coastal | | |
| `por` | Portugal | coastal | SC | |
| `pru` | Prussia | coastal | | |
| `rom` | Rome | coastal | SC | italy |
| `ruh` | Ruhr | inland | | |
| `rum` | Rumania | coastal | SC | |
| `ser` | Serbia | inland | SC | |
| `sev` | Sevastopol | coastal | SC | russia |
| `sil` | Silesia | inland | | |
| `ska` | Skagerrak | sea | | |
| `smy` | Smyrna | coastal | SC | turkey |
| `spa` | Spain | coastal | SC | |
| `stp` | St Petersburg | coastal | SC | russia |
| `swe` | Sweden | coastal | SC | |
| `syr` | Syria | coastal | | |
| `tri` | Trieste | coastal | SC | austria |
| `tun` | Tunis | coastal | SC | |
| `tus` | Tuscany | coastal | | |
| `tyr` | Tyrolia | inland | | |
| `tys` | Tyrrhenian Sea | sea | | |
| `ukr` | Ukraine | inland | | |
| `ven` | Venice | coastal | SC | italy |
| `vie` | Vienna | inland | SC | austria |
| `wal` | Wales | coastal | | |
| `war` | Warsaw | inland | SC | russia |
| `wes` | Western Mediterranean | sea | | |
| `yor` | Yorkshire | coastal | | |

In total: 75 provinces (14 inland, 42 coastal, 19 sea), 34 supply centers, and 22 home centers across the seven powers.

## Map

*Arrives in 0.1.0.*

The gem has one map, the classic map, built into the gem. A caller gets it with one call and passes no file path. The map and its records (powers and provinces) are query-only: they are not value objects and have no hash form. A position refers to its map only by identifier, `"classic"` (decided in Issue #56). Every list the map returns is sorted by identifier.

```ruby
map = TA::Map.classic
map.id                                   # => "classic"
map.powers.map(&:id)                     # => [:austria, :england, :france, :germany, :italy, :russia, :turkey]
map.provinces.size                       # => 75
map.province(:spa).coasts                # => [:nc, :sc]
map.coasts(:par)                         # => []
map.adjacent?(:fleet, L.new(province: :mao), L.new(province: :spa, coast: :nc))   # => true
map.adjacent?(:fleet, L.new(province: :gol), L.new(province: :spa, coast: :nc))   # => false
map.adjacent?(:army,  L.new(province: :par), L.new(province: :bur))               # => true
map.supply_centers.size                  # => 34
map.home_centers(:england)               # => [:edi, :lon, :lvp]
start = map.starting_position
[start.season, start.year, start.phase]  # => [:spring, 1901, :movement]
start.units.size                         # => 22
start.ownership.size                     # => 22 (the 12 other centers are unowned, so absent)
```

### `TA::Map.classic`

Returns the classic map, a `TA::Map`.

### `Map#id`

Returns the map's identifier, the `String` `"classic"`.

### `Map#powers` and `Map#power(id)`

`powers` returns the seven powers as an `Array` of `TA::Map::Power`. Each power has:
- `id`: its identifier, such as `:england`;
- `name`: its display name, such as `"England"`.

`power(id)` returns one power. An unknown identifier raises `TA::InvalidInput`.

```ruby
map.power(:england).name                 # => "England"
```

### `Map#provinces` and `Map#province(id)`

`provinces` returns the 75 provinces as an `Array` of `TA::Map::Province`. Each province has:
- `id`: its identifier, such as `:spa`;
- `name`: its full name, such as `"Spain"`;
- `type`: `:inland`, `:coastal` or `:sea`;
- `coasts`: its coasts, or `[]` unless its coast is split;
- `supply_center`: `true` or `false`;
- `home`: the identifier of the power whose home center it is, or `nil`.

`province(id)` returns one province. An unknown identifier raises `TA::InvalidInput`.

```ruby
spa = map.province(:spa)
[spa.name, spa.type, spa.supply_center, spa.home]   # => ["Spain", :coastal, true, nil]
map.province(:lon).home                              # => :england
```

### `Map#coasts(province_id)`

Returns the coasts of a province as an `Array` of `Symbol`: two coasts for `bul`, `spa` and `stp`, and `[]` for every other province. An unknown identifier raises `TA::InvalidInput`.

```ruby
map.coasts(:stp)                         # => [:nc, :sc]
map.coasts(:par)                         # => []
```

### `Map#adjacent?(unit_type, from, to)`

Returns `true` when a unit of the given type (`:army` or `:fleet`) can move from one location to the other in a single step, and `false` otherwise. `from` and `to` are `TA::Location`s.

- For an army, coasts play no part, and a location must not name one.
- For a fleet, the answer depends on the exact coast. A location on a split-coast province must name its coast.

A location that breaks either rule, or names an unknown province or coast, raises `TA::InvalidInput`.

```ruby
map.adjacent?(:fleet, L.new(province: :mao), L.new(province: :spa, coast: :nc))   # => true
map.adjacent?(:fleet, L.new(province: :gol), L.new(province: :spa, coast: :nc))   # => false
map.adjacent?(:army,  L.new(province: :par), L.new(province: :bur))               # => true
map.adjacent?(:army,  L.new(province: :par), L.new(province: :spa, coast: :nc))   # raises TA::InvalidInput
```

### `Map#supply_centers`

Returns the identifiers of the 34 supply-center provinces, as an `Array` of `Symbol`.

```ruby
map.supply_centers.size                  # => 34
map.supply_centers.first(3)              # => [:ank, :bel, :ber]
```

### `Map#home_centers(power_id)`

Returns the identifiers of one power's home centers, as an `Array` of `Symbol`. Across the seven powers there are 22. An unknown power raises `TA::InvalidInput`.

```ruby
map.home_centers(:england)               # => [:edi, :lon, :lvp]
map.home_centers(:russia)                # => [:mos, :sev, :stp, :war]
```

### `Map#starting_position`

Returns the position the game starts from, a `TA::Position` for spring 1901 in the movement phase. In it:
- each power has its starting units;
- each power owns its own home centers;
- the twelve other supply centers are unowned. An unowned center is absent from `ownership`.

```ruby
start = map.starting_position
[start.season, start.year, start.phase]  # => [:spring, 1901, :movement]
start.units.size                         # => 22
start.ownership.size                     # => 22 (the 12 other centers are unowned, so absent)
start.ownership[:lon]                    # => :england
start.ownership.key?(:bel)               # => false
```

## Value objects

*Arrives in 0.1.0.*

Positions, units, orders and results are value objects. These rules hold for every one of them:

- **Immutable.** Each is a Ruby `Data` class. Its fields can't be changed after it is built.
- **`new` takes symbols.** Identifiers are passed as symbols, as set out in [Identifiers](#identifiers).
- **`to_h` gives the hash form.** Its keys are strings all the way down, and its values are only strings, integers, booleans, `nil`, arrays and hashes, so it can be written as JSON with no custom handling.
- **`from_h` takes exactly that shape.** That is the shape `JSON.parse` returns. A missing key or an unknown key raises `TA::InvalidInput`. So does a `"type"` that doesn't match the order class whose `from_h` was called.
- **Round trip.** Converting an object with `to_h`, writing it as JSON, parsing that JSON and rebuilding it with `from_h` always gives an object equal to the original.
- **`format`.** Storable objects (positions, orders, check results and adjudication results) carry a `"format"` key in their hash form. Its value is the integer `1`. There is one value for the whole gem, and it goes up whenever any hash form changes. A storable object's hash form is the same wherever it appears, so an order nested inside an outcome still carries `"format"`. A missing or unknown `format` raises `TA::InvalidInput`. Other value objects only ever appear nested, and carry no `format`.
- **Canonical order.** List fields are put into a fixed order when the object is built, and then frozen (see [Canonical order](#canonical-order)).
- **`Marshal`.** A `Marshal.dump` and `Marshal.load` round trip keeps all of these guarantees: it returns an equal, deeply frozen object, and a payload that describes an impossible object raises `TA::InvalidInput` on load, as `from_h` would. This matters for anything that caches values with `Marshal`, as Rails' default cache does.
- **Validated on construction.** Every value object is checked against the classic map, whether it is built with `new` or with `from_h`. An object that can't exist on that map raises `TA::InvalidInput` (see [Impossible objects](#impossible-objects)). This will be revisited if other maps arrive.

```ruby
O.from_h({"type" => "hold", "power" => "england", "at" => "lon"})                 # raises TA::InvalidInput: missing "format"
O.from_h({"format" => 2, "type" => "hold", "power" => "england", "at" => "lon"})  # raises TA::InvalidInput: unknown format 2
```

A value object is only checked for being well formed. An order that breaks a rule of the game, such as a move to a province the unit can't reach, is still a valid order object. Judging it is the job of checking (see [Checking an order](#checking-an-order)).

### Province fields and location fields

Every field of an order that names a place is one of two kinds:

- A **province field** holds a province identifier and nothing else. It never holds a coast. A coast given in a province field is malformed input, and raises `TA::InvalidInput`.
- A **location field** holds a `TA::Location`: a province, plus a coast when the province has split coasts.

In orders, `at`, `target`, `from` and `to` are province fields. `Move#destination` is the only location field.

### `TA::Location`

A place on the board. It carries no `format`.

- `province`: a province identifier.
- `coast`: a coast identifier, or `nil`. It defaults to `nil`. When set, it must be one of the province's own coasts.

```ruby
L.new(province: :spa, coast: :nc).to_h   # => {"province" => "spa", "coast" => "nc"}
L.new(province: :bud).to_h               # => {"province" => "bud", "coast" => nil}
```

### `TA::Unit`

An army or a fleet on the board. It carries no `format`.

- `power`: a power identifier.
- `type`: `:army` or `:fleet`.
- `location`: a `TA::Location`. An army's location never names a coast. A fleet's location names a coast exactly when its province has split coasts.

```ruby
TA::Unit.new(power: :russia, type: :fleet, location: L.new(province: :stp, coast: :sc)).to_h
# => {"power" => "russia", "type" => "fleet", "location" => {"province" => "stp", "coast" => "sc"}}
```

### `TA::DislodgedUnit`

A unit pushed out of its province, waiting to retreat. It carries no `format`.

- `unit`: a `TA::Unit`, at the location it was dislodged from.
- `attacker_from`: a province identifier, with no coast. It names the province the attacking unit came from.
- `by_convoy`: `true` when the attack came by convoy, otherwise `false`.

```ruby
TA::DislodgedUnit.new(
  unit: TA::Unit.new(power: :austria, type: :army, location: L.new(province: :ser)),
  attacker_from: :bul, by_convoy: false
).to_h
# => {"unit" => {"power" => "austria", "type" => "army", "location" => {"province" => "ser", "coast" => nil}},
#     "attacker_from" => "bul", "by_convoy" => false}
```

### `TA::Position`

The state of the board at one moment. It carries `format`.

- `map`: the map identifier, the `String` `"classic"`.
- `season`: `:spring` or `:fall`.
- `year`: an `Integer`, such as `1901`.
- `phase`: `:movement`, `:retreat` or `:adjustment`.
- `units`: an `Array` of `TA::Unit`, the units on the board. No two share a province.
- `ownership`: a `Hash` from supply-center identifier to power identifier. An unowned center is absent.
- `dislodged_units`: an `Array` of `TA::DislodgedUnit`. These are kept apart from `units`, so a dislodged unit may share a province with the unit that dislodged it. Always empty in a movement phase.
- `standoffs`: an `Array` of province identifiers, the provinces left empty by a standoff. Always empty in a movement phase.

```ruby
position = TA::Position.new(
  map: "classic", season: :spring, year: 1901, phase: :movement,
  units: [TA::Unit.new(power: :austria, type: :army, location: L.new(province: :bud)),
          TA::Unit.new(power: :russia, type: :fleet, location: L.new(province: :stp, coast: :sc))],
  ownership: {bud: :austria, stp: :russia},
  dislodged_units: [], standoffs: []
)
position.to_h
# => {"format" => 1, "map" => "classic", "season" => "spring", "year" => 1901, "phase" => "movement",
#     "units" => [{"power" => "austria", "type" => "army", "location" => {"province" => "bud", "coast" => nil}},
#                 {"power" => "russia", "type" => "fleet", "location" => {"province" => "stp", "coast" => "sc"}}],
#     "ownership" => {"bud" => "austria", "stp" => "russia"},
#     "dislodged_units" => [], "standoffs" => []}
TA::Position.from_h(JSON.parse(JSON.generate(position.to_h))) == position   # => true
```

### `TA::Order`

`TA::Order` is a module that holds the six movement order classes. Every order carries `format`, and its hash form has a `"type"` key naming the order class. Every order has these two fields:

- `power`: the power giving the order.
- `at`: a province field, the province of the ordered unit.

`TA::Order.from_h` reads `"type"` and builds the matching class. The types are `"hold"`, `"move"`, `"move_via_convoy"`, `"support_hold"`, `"support_move"` and `"convoy"`. Any other type raises `TA::InvalidInput`. Each order class also has its own `from_h`, which raises `TA::InvalidInput` when given a hash of another type.

```ruby
O.from_h({"format" => 1, "type" => "hold", "power" => "england", "at" => "lon"})
# => #<data Trucebearer::Adjudicator::Order::Hold power=:england, at=:lon>
O::Move.from_h({"format" => 1, "type" => "hold", "power" => "england", "at" => "lon"})
# raises TA::InvalidInput
```

#### `TA::Order::Hold`

The unit stays where it is. Type `"hold"`. Fields: `power` and `at` only.

```ruby
O::Hold.new(power: :england, at: :lon).to_h
# => {"format" => 1, "type" => "hold", "power" => "england", "at" => "lon"}
```

#### `TA::Order::Move`

The unit moves to another province. An army's move may go by convoy (see [Adjudicating a movement phase](#adjudicating-a-movement-phase)). Type `"move"`. Fields:

- `power` and `at`, as above.
- `destination`: a location field, a `TA::Location`. A fleet moving to a province with split coasts names the coast.

```ruby
O::Move.new(power: :france, at: :mao, destination: L.new(province: :spa, coast: :nc)).to_h
# => {"format" => 1, "type" => "move", "power" => "france", "at" => "mao", "destination" => {"province" => "spa", "coast" => "nc"}}
```

#### `TA::Order::MoveViaConvoy`

An army moves to a province next to it, but by convoy rather than by land. Type `"move_via_convoy"`. Fields:

- `power` and `at`, as above.
- `to`: a province field, the destination.

```ruby
O::MoveViaConvoy.new(power: :england, at: :lon, to: :wal).to_h
# => {"format" => 1, "type" => "move_via_convoy", "power" => "england", "at" => "lon", "to" => "wal"}
```

#### `TA::Order::SupportHold`

The unit supports a unit that isn't moving. Type `"support_hold"`. Fields:

- `power` and `at`, as above.
- `target`: a province field, the province of the supported unit.

```ruby
O::SupportHold.new(power: :germany, at: :mun, target: :ber).to_h
# => {"format" => 1, "type" => "support_hold", "power" => "germany", "at" => "mun", "target" => "ber"}
```

#### `TA::Order::SupportMove`

The unit supports another unit's move. Type `"support_move"`. Fields:

- `power` and `at`, as above.
- `from`: a province field, the province the supported unit moves from.
- `to`: a province field, the province it moves to. A support never names a coast.

```ruby
O::SupportMove.new(power: :france, at: :por, from: :mao, to: :spa).to_h
# => {"format" => 1, "type" => "support_move", "power" => "france", "at" => "por", "from" => "mao", "to" => "spa"}
```

#### `TA::Order::Convoy`

A fleet at sea carries an army across. Type `"convoy"`. Fields:

- `power` and `at`, as above.
- `from`: a province field, the province the army moves from.
- `to`: a province field, the province it moves to.

```ruby
O::Convoy.new(power: :england, at: :nth, from: :lon, to: :nwy).to_h
# => {"format" => 1, "type" => "convoy", "power" => "england", "at" => "nth", "from" => "lon", "to" => "nwy"}
```

### `TA::CheckResult`

The answer to checking one order. It carries `format`.

- `legal`: `true` or `false`.
- `reasons`: an `Array` of rejection-reason symbols. It is empty when `legal` is `true`, and holds exactly one reason when `legal` is `false`. The reasons are listed under [Checking an order](#checking-an-order).

```ruby
TA::CheckResult.new(legal: false, reasons: [:foreign_unit]).to_h
# => {"format" => 1, "legal" => false, "reasons" => ["foreign_unit"]}
TA::CheckResult.new(legal: true, reasons: []).to_h
# => {"format" => 1, "legal" => true, "reasons" => []}
```

### `TA::Outcome`

What happened to one order in an adjudicated phase. It carries no `format` of its own, since it only ever appears inside an adjudication result, but its `order` keeps the order's own `format`. Only the fields are described here. What each value means comes later (see [Adjudicating a movement phase](#adjudicating-a-movement-phase)).

- `order`: one of the six order classes above.
- `result`: one of `:void`, `:held`, `:no_route`, `:bounced`, `:succeeded`, `:unmatched`, `:cut`, `:given` or `:disrupted`.
- `submitted`: `true` for an order that was handed in, `false` for an implied hold.
- `dislodged`: `true` when the unit following this order was dislodged, otherwise `false`.

```ruby
TA::Outcome.new(order: O::Hold.new(power: :england, at: :lon), result: :held, submitted: false, dislodged: false).to_h
# => {"order" => {"format" => 1, "type" => "hold", "power" => "england", "at" => "lon"},
#     "result" => "held", "submitted" => false, "dislodged" => false}
```

### `TA::Adjudication`

The result of adjudicating a phase. It carries `format`. Only the fields are described here. What they mean comes later (see [Adjudicating a movement phase](#adjudicating-a-movement-phase)).

- `outcomes`: an `Array` of `TA::Outcome`. It keeps the order the adjudication gives it, and is not sorted.
- `paradox`: `true` or `false`.
- `position`: a `TA::Position`, the position after the phase.

The example below adjudicates a position, `pos`, that holds only England's fleet in London, with London owned by England. The fleet is ordered to hold.

```ruby
pos = TA::Position.new(map: "classic", season: :spring, year: 1901, phase: :movement,
  units: [TA::Unit.new(power: :england, type: :fleet, location: L.new(province: :lon))],
  ownership: {lon: :england}, dislodged_units: [], standoffs: [])
adjudication = TA.adjudicate(pos, [O::Hold.new(power: :england, at: :lon)])
adjudication.to_h
# => {"format" => 1,
#     "outcomes" => [{"order" => {"format" => 1, "type" => "hold", "power" => "england", "at" => "lon"},
#                     "result" => "held", "submitted" => true, "dislodged" => false}],
#     "paradox" => false,
#     "position" => {"format" => 1, "map" => "classic", "season" => "spring", "year" => 1901, "phase" => "retreat",
#                    "units" => [{"power" => "england", "type" => "fleet", "location" => {"province" => "lon", "coast" => nil}}],
#                    "ownership" => {"lon" => "england"}, "dislodged_units" => [], "standoffs" => []}}
```

### Canonical order

When a value object is built, its list fields are sorted into a fixed order and frozen. Two objects with the same contents are therefore equal, and give the same hash form, whatever order the lists were given in.

- A position's `units` and `dislodged_units` are sorted by the unit's province.
- A position's `standoffs` are sorted by identifier.
- `to_h` writes a position's `ownership` keys sorted by province.
- An adjudication's `outcomes` are the exception. They keep the order the adjudication gives them.

```ruby
army  = TA::Unit.new(power: :austria, type: :army, location: L.new(province: :bud))
fleet = TA::Unit.new(power: :russia, type: :fleet, location: L.new(province: :stp, coast: :sc))
spring = {map: "classic", season: :spring, year: 1901, phase: :movement, dislodged_units: [], standoffs: []}
a = TA::Position.new(**spring, units: [army, fleet], ownership: {bud: :austria, stp: :russia})
b = TA::Position.new(**spring, units: [fleet, army], ownership: {stp: :russia, bud: :austria})
a == b                                   # => true
a.to_h == b.to_h                         # => true
b.units.map { _1.location.province }     # => [:bud, :stp]
b.to_h["ownership"].keys                 # => ["bud", "stp"]
```

### Impossible objects

Each object below can't exist on the classic map, so building it raises `TA::InvalidInput`. This holds whether it is built with `new` or with `from_h`. The examples reuse `army`, `fleet` and `spring` from [Canonical order](#canonical-order).

```ruby
# Two units on the board in one province. (A dislodged unit doesn't count.)
TA::Position.new(**spring, ownership: {},
  units: [TA::Unit.new(power: :france, type: :army, location: L.new(province: :bur)),
          TA::Unit.new(power: :germany, type: :army, location: L.new(province: :bur))])

# A fleet in an inland province, or an army in a sea province.
TA::Unit.new(power: :germany, type: :fleet, location: L.new(province: :mun))
TA::Unit.new(power: :england, type: :army, location: L.new(province: :nth))

# An army with a coast.
TA::Unit.new(power: :france, type: :army, location: L.new(province: :spa, coast: :nc))

# A fleet on a province with split coasts, with no coast given.
TA::Unit.new(power: :france, type: :fleet, location: L.new(province: :spa))

# A coast the province doesn't have.
L.new(province: :par, coast: :nc)
L.new(province: :bul, coast: :nc)

# An unknown identifier, or a map other than "classic".
L.new(province: :xyz)
TA::Position.from_h(JSON.parse(JSON.generate(a.to_h)).merge("map" => "modern"))

# Ownership of a province that isn't a supply center.
TA::Position.new(**spring, units: [army], ownership: {bur: :france})

# A movement-phase position with dislodged units or standoffs.
TA::Position.new(**spring.merge(standoffs: [:bur]), units: [army], ownership: {})
TA::Position.new(**spring.merge(dislodged_units: [TA::DislodgedUnit.new(unit: fleet, attacker_from: :fin, by_convoy: false)]),
  units: [army], ownership: {})

# The same province twice in the standoffs.
TA::Position.new(**spring.merge(phase: :retreat, standoffs: [:bur, :bur]), units: [army], ownership: {})

# Two dislodged units in one province.
TA::Position.new(**spring.merge(phase: :retreat, dislodged_units: [fleet, fleet].map { TA::DislodgedUnit.new(unit: _1, attacker_from: :fin, by_convoy: false) }), units: [army], ownership: {})

# A check result whose legal flag and reasons disagree.
TA::CheckResult.new(legal: true, reasons: [:own_province])
TA::CheckResult.new(legal: false, reasons: [])
TA::CheckResult.new(legal: false, reasons: [:own_province, :not_reachable])
```

## Checking an order

*Arrives in 0.1.0.*

`TA.check(position, order)` takes a `TA::Position` and one order, and returns a `TA::CheckResult` saying whether that order is legal in that position.

- **The position alone decides.** Checking looks only at the position and the order. It never looks at any other order, submitted or not. A unit being supported or convoyed may belong to any power, including another power than the one giving the order.
- **At most one reason.** A legal order has no reasons. An order that is not legal has exactly one: the first condition that fails, in the precedence given for its order type below. `reasons` stays a list so that a later version may report more than one.
- **Never an exception for a broken rule.** An order that breaks the rules gives a result with `legal: false`. Only malformed input raises `TA::InvalidInput`, and a value object that was built without raising is never malformed.

```ruby
start = TA::Map.classic.starting_position
TA.check(start, O::Hold.new(power: :england, at: :lon))
# => #<data Trucebearer::Adjudicator::CheckResult legal=true, reasons=[]>
TA.check(start, O::Hold.new(power: :france, at: :lon))
# => #<data Trucebearer::Adjudicator::CheckResult legal=false, reasons=[:foreign_unit]>
TA.check(start, O::Move.new(power: :england, at: :lon, destination: L.new(province: :bel)))
# => #<data Trucebearer::Adjudicator::CheckResult legal=false, reasons=[:not_reachable]>   # London holds a fleet, which can't reach Belgium
TA.check(start, O::Move.new(power: :russia, at: :sev, destination: L.new(province: :rum)))
# => #<data Trucebearer::Adjudicator::CheckResult legal=true, reasons=[]>
TA.check(start, O::Move.new(power: :france, at: :mar, destination: L.new(province: :spa, coast: :nc)))
# => #<data Trucebearer::Adjudicator::CheckResult legal=false, reasons=[:coast_not_allowed]>   # Marseilles holds an army
TA.check(start, O::MoveViaConvoy.new(power: :england, at: :lvp, to: :wal))
# => #<data Trucebearer::Adjudicator::CheckResult legal=false, reasons=[:no_convoy_route]>   # no fleet is at sea yet
TA.check(start, O::SupportMove.new(power: :austria, at: :vie, from: :war, to: :gal))
# => #<data Trucebearer::Adjudicator::CheckResult legal=true, reasons=[]>   # Austria may support a Russian army
at_sea = TA::Position.new(map: "classic", season: :spring, year: 1901, phase: :movement, ownership: {},
  dislodged_units: [], standoffs: [],
  units: [TA::Unit.new(power: :france, type: :fleet, location: L.new(province: :mao)),
          TA::Unit.new(power: :france, type: :fleet, location: L.new(province: :gol))])
TA.check(at_sea, O::Move.new(power: :france, at: :mao, destination: L.new(province: :spa)))
# => #<data Trucebearer::Adjudicator::CheckResult legal=false, reasons=[:coast_required]>   # both coasts reachable; one must be named
TA.check(at_sea, O::Move.new(power: :france, at: :gol, destination: L.new(province: :spa, coast: :nc)))
# => #<data Trucebearer::Adjudicator::CheckResult legal=false, reasons=[:coast_unreachable]>   # the Gulf of Lyon touches only the south coast
retreat = TA::Position.from_h(start.to_h.merge("phase" => "retreat"))
TA.check(retreat, O::Hold.new(power: :england, at: :lon))
# => #<data Trucebearer::Adjudicator::CheckResult legal=false, reasons=[:wrong_phase]>
TA.check(start, O::Hold.new(power: :england, at: :wal))
# => #<data Trucebearer::Adjudicator::CheckResult legal=false, reasons=[:no_such_unit]>
TA.check(start, O::SupportHold.new(power: :germany, at: :mun, target: :ber))
# => #<data Trucebearer::Adjudicator::CheckResult legal=true, reasons=[]>
TA.check(start, O::SupportHold.new(power: :germany, at: :mun, target: :sil))
# => #<data Trucebearer::Adjudicator::CheckResult legal=false, reasons=[:no_unit]>
TA.check(start, O::Convoy.new(power: :england, at: :lon, from: :lvp, to: :bel))
# => #<data Trucebearer::Adjudicator::CheckResult legal=false, reasons=[:not_fleet_at_sea]>   # London is coastal, not a sea province
```

### Terms used in checking

- **Can reach.** A unit can reach a province when the map's adjacency for its unit type joins the unit's current location to that province. For a fleet, the step must start from the coast the fleet is on, and it is enough to reach any one coast of the province (DATC 6.A.9, 6.A.10, 6.B.4, 6.B.5).
- **Convoy chain.** A sequence of different sea provinces, each with a fleet of any power in it, that links two different coastal provinces: the first sea province borders the origin, each one borders the next, and the last borders the destination. Coasts at the two ends don't matter (DATC 6.B.18, 6.B.19).
- **Minimal convoy chain.** A convoy chain that stops being a chain between the same two provinces if any one or more of its fleets are taken out (DATC 4.E.1, 6.G.19).

### When each order type is legal

Every order first needs a movement-phase position, a unit in its `at` province, and that unit to belong to the order's `power`. Beyond that:

- **Hold** needs nothing more.
- **Move** is legal when the destination is a province other than the unit's own (DATC 6.A.4, 6.A.5) and either the unit can reach it, or the unit is an army and the position has a convoy chain from its province to the destination. A fleet never moves by convoy chain (DATC 6.A.1, 6.A.7). The destination's coast must also fit: an army names none, and a fleet moving to a province with split coasts names one it can reach.
- **MoveViaConvoy** is legal when the unit is an army, the destination is another province, the army could also get there by land, and the position has a convoy chain from its province to the destination. The tag only exists to pick the sea route to a neighboring province. Refusing it for a province the army can't reach by land is our own input-contract choice; DATC 4.A.3 doesn't demand it.
- **SupportHold** is legal when the supported province isn't the supporter's own (DATC 6.A.8), some unit stands there, and the supporter can reach it.
- **SupportMove** is legal when:
  - neither the origin nor the destination is the supporter's own province (DATC 6.D.34);
  - the origin and destination differ;
  - a unit stands in the origin;
  - the supporter can reach the destination;
  - the unit in the origin could make that move as a plain move, to some coast of the destination, without a convoy chain that runs through the supporter's province (DATC 6.D.31).
- **Convoy** is legal when the ordered unit is a fleet in a sea province, the origin and destination are two different coastal provinces, an army stands in the origin, and the fleet is part of at least one minimal convoy chain from the origin to the destination (DATC 6.G.19).

### Rejection reasons

Each order type checks its conditions in the order below, and the first that fails gives the reason. A condition shared by several order types gives the same symbol in each.

| Order type | Reasons, in precedence order |
|---|---|
| every order, checked first | `:wrong_phase`, `:no_such_unit`, `:foreign_unit` |
| Hold | none further |
| Move | `:own_province`, `:not_reachable`, `:coast_not_allowed`, `:coast_required`, `:coast_unreachable` |
| MoveViaConvoy | `:not_army`, `:own_province`, `:not_adjacent`, `:no_convoy_route` |
| SupportHold | `:own_province`, `:no_unit`, `:not_reachable` |
| SupportMove | `:own_province`, `:same_province`, `:no_unit`, `:not_reachable`, `:move_impossible` |
| Convoy | `:not_fleet_at_sea`, `:bad_endpoints`, `:no_unit`, `:not_on_chain` |

What each reason means:

- `:wrong_phase`: the position isn't in a movement phase. No other reason is ever given alongside it.
- `:no_such_unit`: there is no unit in the order's `at` province, so the ordered unit isn't on the board.
- `:foreign_unit`: the ordered unit belongs to a power other than the one giving the order (DATC 6.A.6).
- `:own_province`: the order points at the unit's own province. For a move, that is the destination. For a support to hold, it is the supported province. For a support to move, it is either the origin or the destination (DATC 6.A.4, 6.A.5, 6.A.8, 6.D.34).
- `:not_reachable`: the unit can't reach the province it needs to. For a move, that is the destination, with no convoy chain to help an army. For a support, it is the supported province or the destination (DATC 6.A.1, 6.A.7, 6.A.10).
- `:coast_not_allowed`: an army's move names a coast. This is the strict option of DATC 4.B.6, and departs from the preferred result of 6.B.12 (see `ruleset.md`).
- `:coast_required`: a fleet's move to a province with split coasts names no coast, even when only one coast is in reach. This is the strict option of DATC 4.B.2, and departs from the preferred result of 6.B.2 (see `ruleset.md`).
- `:coast_unreachable`: a fleet's move names a coast it can't reach. The coast is never corrected for the caller (DATC 4.B.3, 6.B.3).
- `:not_army`: a move via convoy is ordered for a fleet.
- `:not_adjacent`: a move via convoy names a province the army couldn't reach by land (DATC 4.A.3).
- `:no_convoy_route`: a move via convoy has no convoy chain in the position.
- `:same_province`: a support to move names the same province as origin and destination.
- `:no_unit`: the province the order refers to has no suitable unit: no unit at all in the supported province or the support's origin, or no army in the convoy's origin.
- `:move_impossible`: the unit in the support's origin couldn't make the supported move itself, judged without any convoy chain through the supporter's province (DATC 6.D.31).
- `:not_fleet_at_sea`: a convoy is ordered for an army, or for a fleet that isn't in a sea province.
- `:bad_endpoints`: a convoy's origin and destination are the same province, or either of them isn't coastal.
- `:not_on_chain`: the convoying fleet isn't part of any minimal convoy chain from the origin to the destination (DATC 6.G.19).

## Legal orders

*Arrives in 0.1.0.*

`TA.legal_orders(position, unit)` takes a `TA::Position` and a `TA::Unit`, and returns an `Array` of every legal order for that unit.

- **The same answer as checking.** Every order in the list passes [`TA.check`](#checking-an-order), and every order for the unit that passes `TA.check` is in the list. Each order has one accepted form, so the list is always finite.
- **The position alone decides.** Like checking, the list depends only on the position, never on what anyone has ordered.
- **The owner gives every order.** Each listed order names the unit's owner as its `power`.
- **Supports for moves nobody has ordered** are included, since checking doesn't look at other orders.
- **One move per coast.** A fleet that can reach a province with split coasts gets one move for each coast it can reach, and no move without a coast.
- **Moves by convoy.** For an army with a convoy chain to a province, a province it can't reach by land appears as a plain move only. A province it can reach by land appears both as a plain move and as a move via convoy.
- **Empty, never an exception.** The list is empty when the position isn't in a movement phase, or when the unit isn't on the board. A unit is on the board only when the position holds a unit with the same power, type and location.

### List order

The list comes in this order, and the same call always gives the same list. Provinces and coasts sort by identifier.

1. the hold
2. moves, by destination province and then coast
3. moves via convoy, by destination
4. supports to hold, by target
5. supports to move, by origin and then destination
6. convoys, by origin and then destination

```ruby
start = TA::Map.classic.starting_position
fleet = TA::Unit.new(power: :england, type: :fleet, location: L.new(province: :lon))
TA.legal_orders(start, fleet).first(3)
# => [O::Hold.new(power: :england, at: :lon),
#     O::Move.new(power: :england, at: :lon, destination: L.new(province: :eng)),
#     O::Move.new(power: :england, at: :lon, destination: L.new(province: :nth))]
TA.legal_orders(start, TA::Unit.new(power: :france, type: :fleet, location: L.new(province: :lon)))
# => []   # no French fleet is in London
```

The next examples reuse `at_sea` and `retreat` from [Checking an order](#checking-an-order). They also use `ln`, a movement position that holds only England's army in London and fleet in the North Sea. By land, the army in London can reach only `wal` and `yor`. The fleet in `nth` links London by sea to the coastal provinces `bel`, `den`, `edi`, `hol`, `nwy` and `yor`. So `yor` is the only destination the army can reach both by land and by convoy.

```ruby
vie = TA::Unit.new(power: :austria, type: :army, location: L.new(province: :vie))
TA.legal_orders(start, vie).include?(O::SupportMove.new(power: :austria, at: :vie, from: :war, to: :gal))
# => true   (a support for a move nobody has ordered)
mao = TA::Unit.new(power: :france, type: :fleet, location: L.new(province: :mao))
TA.legal_orders(at_sea, mao).select { O::Move === _1 && _1.destination.province == :spa }.map { _1.destination.coast }
# => [:nc, :sc]   (one move per reachable coast, none without a coast)
ln = TA::Position.new(map: "classic", season: :spring, year: 1901, phase: :movement, ownership: {},
  dislodged_units: [], standoffs: [],
  units: [TA::Unit.new(power: :england, type: :army, location: L.new(province: :lon)),
          TA::Unit.new(power: :england, type: :fleet, location: L.new(province: :nth))])
army = TA::Unit.new(power: :england, type: :army, location: L.new(province: :lon))
TA.legal_orders(ln, army).grep(O::MoveViaConvoy).map(&:to)                            # => [:yor]
TA.legal_orders(ln, army).any? { O::Move === _1 && _1.destination.province == :nwy }  # => true  (plain move, by convoy)
TA.legal_orders(retreat, fleet)                                                        # => []
```

## Adjudicating a movement phase

*Arrives in 0.2.0.*

`TA.adjudicate(position, orders)` takes a `TA::Position` in the movement phase and an `Array` of orders, and returns a `TA::Adjudication`: an outcome for every order, whether a convoy paradox was found, and the position after the moves.

It raises `TA::InvalidInput` in two cases only:

- the position isn't in the movement phase;
- one power gives two orders for units in the same province, whether the two orders are identical or not. The app keeps one order per unit, so this is an input-contract choice, not one of the options in DATC 4.D.3.

Orders from different powers for the same unit never raise. Any order from a power that doesn't own the unit is void, and the owner's order stands.

```ruby
start = TA::Map.classic.starting_position
orders = [O::Move.new(power: :england, at: :lon, destination: L.new(province: :nth)),
          O::Move.new(power: :germany, at: :kie, destination: L.new(province: :hol))]
result = TA.adjudicate(start, orders)
result.outcomes.first(2).map(&:result)   # => [:succeeded, :succeeded]
result.outcomes.count { !_1.submitted }  # => 20   (implied holds for the other units)
result.paradox                           # => false
result.position.phase                    # => :retreat
result.position.dislodged_units          # => []
result.outcomes.drop(2).first(3).map { _1.order.at }          # => [:ank, :ber, :bre]  (implied holds, by province)
result.position.units.any? { _1.location.province == :nth }   # => true  (units at their new places)
result.position.ownership == start.ownership                  # => true  (ownership unchanged)

bounce = [O::Move.new(power: :russia, at: :war, destination: L.new(province: :gal)),
          O::Move.new(power: :austria, at: :vie, destination: L.new(province: :gal))]
result = TA.adjudicate(start, bounce)
result.outcomes.first(2).map(&:result)   # => [:bounced, :bounced]
result.position.standoffs                # => [:gal]

TA.adjudicate(start, [O::Hold.new(power: :england, at: :lon), O::Hold.new(power: :england, at: :lon)])
# raises TA::InvalidInput   # two orders from England for the unit in London
TA.adjudicate(result.position, [])
# raises TA::InvalidInput   # a retreat position
```

### The outcome list

`outcomes` holds one `TA::Outcome` for each order passed in, in the order they were given, including orders that turn out to be void. After those comes one implied hold for each unit whose owner gave no legal order for it. An implied hold is a `TA::Order::Hold` given by the unit's owner, with `submitted: false`. The implied holds are sorted by province identifier.

### Terms used in adjudication

- **Matching.** A support to move, or a convoy, matches a move when both name the same origin province and the same destination province. Coasts don't count, and neither does whether the move is plain or via convoy (DATC 6.G.10, 6.G.14, 6.G.17). A support to hold matches a unit that doesn't move.
- **Moves.** A unit moves when the order it follows is a `Move` or a `MoveViaConvoy`, whether or not the move works (DATC 6.D.8). The order a unit follows is its owner's legal order for it, or else its implied hold.
- **Working convoy route.** For a move that goes by convoy, a convoy chain (see [Terms used in checking](#terms-used-in-checking)) in which each fleet gives a legal convoy order that matches the move, and no fleet is dislodged. A single working route is enough, so the move loses its route only when every chain is broken (DATC 4.A.1).
- **Convoy paradox.** A set of orders with no consistent result, or with more than one, because whether a convoying fleet is dislodged turns, directly or by way of other orders, on the move of an army that fleet is carrying (DATC 4.A.2). Units moving in a circle, with no such dependency, are not a paradox (DATC 6.C.4, 6.C.6).

### Outcomes

Each outcome's `result` is one symbol. For each order type, the conditions below are tried in order, and the first that applies gives the result. Every order type tries `:void` first.

| Order type | Outcomes, in precedence order |
|---|---|
| every order, checked first | `:void` |
| Hold | `:held` |
| Move, MoveViaConvoy | `:no_route`, `:bounced`, `:succeeded` |
| SupportHold, SupportMove | `:unmatched`, `:cut`, `:given` |
| Convoy | `:unmatched`, `:disrupted`, `:given` |

What each outcome means:

- `:void`: the order didn't pass [checking](#checking-an-order), so it has no effect (see Void orders, below).
- `:held`: the unit stayed in place.
- `:no_route`: the move needed a convoy route and had no working one, either because no fleet convoyed it or because the convoy was disrupted.
- `:bounced`: the move didn't happen. This covers a bounce against a stronger or equal unit, a standoff, and a lost head-to-head battle.
- `:succeeded`: the unit moved to its destination.
- `:unmatched`: for a support, the supported unit isn't following a matching order, so a support to hold for a unit that moves is unmatched. For a convoy, no matching army move went by convoy, which includes an army that went by land.
- `:cut`: the support was cut, including when the supporter itself was dislodged (DATC 6.D.17).
- `:disrupted`: this convoying fleet was dislodged. Other fleets on the same route are not marked. This may widen in 0.3, when paradoxes are resolved (#39).
- `:given`: the support or the convoy was given.

Two further promises:

- The result of a support or a convoy never depends on whether the move it helped succeeded.
- A condition with the same name gets the same symbol under every order type (`:void`, `:unmatched`, `:given`), and no two different conditions share a symbol. The cases grouped under `:bounced` (a bounce, a standoff and a lost head-to-head battle) count as one condition.

### The dislodged flag

An outcome's `dislodged` is `true` only on the outcome of the order the unit actually followed: its owner's legal order, or its implied hold. The outcome of a void order always has `dislodged: false`. So a support can be both `:cut` and dislodged, and a hold can be both `:held` and dislodged.

### Void orders

Each of these is `:void`, and none of them raises:

- an order that fails checking;
- an order from a power that doesn't own the unit;
- an order for a unit that isn't on the board.

When a unit's owner gave no legal order for it, the unit gets an implied hold, which other units can still support (DATC 4.E.1).

```ruby
result = TA.adjudicate(start, [O::Hold.new(power: :france, at: :lon)])
result.outcomes.first.result             # => :void
result.outcomes.find { _1.order.at == :lon && !_1.submitted }.result   # => :held
```

### Convoy routing

These rules decide whether an army's move goes by land or by convoy. They give the DATC's preferred results for 4.A.3.

- A move to a province the army can't reach by land goes by convoy.
- A `MoveViaConvoy` only ever uses the convoy route.
- A plain `Move` to a province the army can reach by land goes by convoy when a fleet of the army's own power gives a matching convoy order that passes checking (DATC 6.G.1, 6.G.7, 6.G.19). Otherwise it goes by land.
- Once a move goes by convoy, it never falls back to the land route, even if the convoy is disrupted or was never ordered (DATC 6.G.8, 6.G.11, 6.G.20).
- The route may use fleets of any power, and it doesn't have to pass through the fleet whose order showed the intent to convoy (DATC 6.G.6).

These examples use `ln` from [Legal orders](#legal-orders): England's army in London and fleet in the North Sea. Yorkshire borders London, so the army could also go by land.

```ruby
by_sea = TA.adjudicate(ln, [O::Move.new(power: :england, at: :lon, destination: L.new(province: :yor)),
                            O::Convoy.new(power: :england, at: :nth, from: :lon, to: :yor)])
by_sea.outcomes.map(&:result)            # => [:succeeded, :given]   (the army went by sea)
by_land = TA.adjudicate(ln, [O::Move.new(power: :england, at: :lon, destination: L.new(province: :yor))])
by_land.outcomes.map(&:result)           # => [:succeeded, :held]    (by land; the fleet's implied hold)
```

### Convoy paradoxes

When the orders hold a convoy paradox, `adjudicate` still returns a result, with `paradox: true`. The flag is `true` exactly when the orders hold a convoy paradox, as defined under [Terms used in adjudication](#terms-used-in-adjudication), and `false` otherwise. While the flag is set, every outcome value and where each unit ends up are unspecified until 0.3, even for orders that have nothing to do with the paradox (DATC 4.A.2). The next position is still a valid `TA::Position`.

The flag is set for each pending case listed under [DATC scope](#datc-scope), and clear for every case that section requires. Resolving paradoxes is #39.

The position below has the shape of the simplest convoy paradox (DATC 6.F.14). France's army in Brest attacks London by convoy, which would cut the support from London. That support decides whether the convoying fleet in the English Channel is dislodged.

```ruby
paradox_pos = TA::Position.new(map: "classic", season: :spring, year: 1901, phase: :movement, ownership: {},
  dislodged_units: [], standoffs: [],
  units: [TA::Unit.new(power: :england, type: :fleet, location: L.new(province: :lon)),
          TA::Unit.new(power: :england, type: :fleet, location: L.new(province: :wal)),
          TA::Unit.new(power: :france, type: :army, location: L.new(province: :bre)),
          TA::Unit.new(power: :france, type: :fleet, location: L.new(province: :eng))])
result = TA.adjudicate(paradox_pos, [
  O::Move.new(power: :england, at: :wal, destination: L.new(province: :eng)),
  O::SupportMove.new(power: :england, at: :lon, from: :wal, to: :eng),
  O::Move.new(power: :france, at: :bre, destination: L.new(province: :lon)),
  O::Convoy.new(power: :france, at: :eng, from: :bre, to: :lon)])
result.paradox                           # => true
# The outcome values and where each unit ends up are unspecified until 0.3 (#39),
# but result.position is still a valid TA::Position.
```

### The next position

In 0.2, `position` is a snapshot taken after the moves. It has:

- the same season and year, with phase `:retreat`, whether or not any unit was dislodged;
- in `units`, every unit that wasn't dislodged, at its location after the moves;
- in `dislodged_units`, each dislodged unit, with `attacker_from` (a province, no coast) and `by_convoy` (DATC 4.A.5, 6.H.11, 6.H.12);
- in `standoffs`, every province left empty by a standoff;
- the same supply-center ownership as before.

In the example below, Germany's army in Bohemia moves into Vienna with support from Tyrolia, and dislodges Austria's holding army.

```ruby
vienna = TA::Position.new(map: "classic", season: :spring, year: 1901, phase: :movement, ownership: {},
  dislodged_units: [], standoffs: [],
  units: [TA::Unit.new(power: :austria, type: :army, location: L.new(province: :vie)),
          TA::Unit.new(power: :germany, type: :army, location: L.new(province: :boh)),
          TA::Unit.new(power: :germany, type: :army, location: L.new(province: :tyr))])
result = TA.adjudicate(vienna, [
  O::Hold.new(power: :austria, at: :vie),
  O::Move.new(power: :germany, at: :boh, destination: L.new(province: :vie)),
  O::SupportMove.new(power: :germany, at: :tyr, from: :boh, to: :vie)])
[result.outcomes.first.result, result.outcomes.first.dislodged]   # => [:held, true]
result.position.dislodged_units
# => [TA::DislodgedUnit.new(unit: TA::Unit.new(power: :austria, type: :army, location: L.new(province: :vie)),
#                           attacker_from: :boh, by_convoy: false)]
result.position.units.find { _1.location.province == :vie }.power   # => :germany
```

0.3 will replace this with the real next phase. Until then, the app builds the next movement position itself, from this retreat position and the host's edits, since `adjudicate` rejects a retreat position.

### DATC scope

Adjudication gives the DATC v3.4 preferred results for the movement test cases 6.A to 6.G.

- **Encoding.** A move marked "via convoy" in the DATC's notation is a `MoveViaConvoy`. Every other move is a `Move`.
- **Matching a result** means the same moves succeed and fail, the same units are dislodged, and the units end in the same places. Outcome labels may differ, since DATC 4.E.2 leaves naming free.

The exceptions are:

- the departures listed in `ruleset.md` (6.B.2, 6.B.9, 6.B.12);
- 6.B.14, which is a build;
- the retreat step of 6.F.7. Its movement step is required;
- the paradox cases, pending #39: 6.F.14 to 6.F.18, 6.F.22 to 6.F.24, 6.F.26 to 6.F.28, and 6.G.11.

Under the DATC's preferred rules, 6.F.19, 6.F.20, 6.F.21, 6.F.25 and 6.F.29 hold no paradox, so they are required.

## Errors

*Building value objects and checking orders arrive in 0.1.0. Adjudication errors arrive in 0.2.0.*

The gem has one error class, `TA::InvalidInput`, a subclass of `StandardError`, with no subclasses of its own. Rescuing it catches every input error the gem raises.

It is raised for:

- a bad hash, or a missing or unknown `format` (see [Value objects](#value-objects));
- a coast in a province field (see [Province fields and location fields](#province-fields-and-location-fields));
- an impossible value object (see [Impossible objects](#impossible-objects));
- one power giving two orders for units in the same province (see [Adjudicating a movement phase](#adjudicating-a-movement-phase));
- adjudicating a position that isn't in the movement phase.

Every message includes the offending key or value.

A rules failure is never an exception. A broken rule shows up as a rejection reason from `TA.check`, or as an outcome from `TA.adjudicate`. Once positions and orders have been built without raising, checking, listing legal orders and adjudicating raise nothing else.

```ruby
O.from_h({"format" => 1, "type" => "hold", "power" => "england"})                            # missing "at"
O.from_h({"format" => 1, "type" => "hold", "power" => "england", "at" => "xyz"})             # unknown identifier
TA::Position.from_h(start.to_h.merge("year" => "1901"))                                      # wrong type
O.from_h({"format" => 1, "type" => "hold", "power" => "england",
          "at" => {"province" => "spa", "coast" => "nc"}})                                   # coast in a province field
# each raises TA::InvalidInput, for example: "at" must be a province identifier, got {"province" => "spa", "coast" => "nc"}
```

## Retreats

*Coming in 0.3.* Issue #36 will fill in this section.

## Adjustments

*Coming in 0.3.* Issue #37 will fill in this section.

## Change rules

See `../AGENTS.md`, under "Changing the interface" and "Releases".
