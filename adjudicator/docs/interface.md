# Public interface

This file is the contract between the gem and anything that uses it, including the Trucebearer web app. Whatever is described here, callers may rely on. Whatever isn't described here is internal and may change in any release.

Everything that crosses the boundary, in either direction, is an immutable value object. Each one that the app may store has a hash form, which can be saved as JSON and rebuilt into an equal object later. The map is the one exception: it is queried, never stored (see [Map](#map)).

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
- `new` accepts symbols only, and `from_h` accepts strings only. Anything else raises `TA::InvalidInput` (see Errors).
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

## Change rules

See `../AGENTS.md`, under "Changing the interface" and "Releases".
