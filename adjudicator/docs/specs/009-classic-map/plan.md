# Implementation Plan: The classic map as a data file

**Spec:** adjudicator/docs/specs/009-classic-map/spec.md (v1.1.0, Approved)
**Decisions:** none in `docs/adr/`. The recorded decisions are `docs/architecture.md` ("Classic map only at first, loaded from a data file") and the contract in `adjudicator/docs/interface.md`. The data format (YAML) is decided in spec FR-1.
**Created:** 2026-11-25

## Global Constraints

- **Read `spec.md` in full before starting any phase.** Where a phase cites an AC or FR, the spec's wording is what the code must satisfy.
- Change files in `adjudicator/` only. The pull request touches one side. The spec and this plan ship in the same pull request.
- `docs/interface.md` is not edited. If a phase shows the contract is wrong, stop and open an Issue.
- Never give anything a name that contains or echoes the game's trademarked name or its three-letter prefix. That covers files, classes, methods, specs, comments and commit messages.
- No copied rules text, and no copied data. The map is written from public geographic knowledge and the game's terms of art, never from an image of a board and never from another engine's data. Phase 3 writes the data from the tables in this plan.
- Standard library only, no new dependency. `yaml` (Psych) is a default gem, and works under `bundle exec` (checked on Ruby 4.0.10).
- Test first: every phase writes its specs, runs them and sees them fail for the right reason before it writes any code.
- Run every command from `adjudicator/`. The spec files begin with `require "trucebearer/adjudicator"` (the `lib` directory is on RSpec's load path), and `.rspec` already loads `spec_helper`.
- `TA` below stands for `Trucebearer::Adjudicator`. Code files begin with `# frozen_string_literal: true`.
- Commit messages are plain imperative sentences, one commit per phase step noted below, each ending with the trailer `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`. One git operation per shell call.
- Scratch files (the data generator) live in the session scratchpad and are not committed.

## Pre-implementation gates

- **Simplicity:** three small components, in three files: `errors.rb` (one class), `location.rb` (one `Data` class) and `map.rb` (the map, with its two record types and the loader). No dependency. The map loads eagerly when the file is required, so there is no lock, no lazy state and no re-entry between `Location` and the loader.
- **Anti-abstraction:** `Data.define` is used directly. There is no loader class, no registry and no schema layer. The loader is one private class method on `Map`.
- **Integration-first:** the contract is `docs/interface.md`, and the first spec in each phase is taken from its examples before any code is written.

## Decisions the plan settles (spec left them open)

| Decision | Choice | Spec |
|---|---|---|
| Files | `lib/trucebearer/adjudicator/{errors,location,map}.rb`, required from `lib/trucebearer/adjudicator.rb` | FR-2, FR-4, FR-5 |
| Loading | Eager. `map.rb` builds the map once when required, and stores it. `Map.classic` returns it. Threads therefore always see the same object | FR-2, NFR |
| Record types | `Map::Power = Data.define(:id, :name)` and `Map::Province = Data.define(:id, :name, :type, :coasts, :supply_center, :home)`. Built-in `to_h` is left alone, and the spec calls it "not part of the contract" | FR-2 |
| Lookup tables | Army neighbors: `Hash` from province `Symbol` to a frozen `Set` of province symbols. Fleet neighbors: `Hash` from a `[province, coast]` pair (coast `nil` when unsplit) to a frozen `Set` of such pairs | FR-3 |
| Data file layout | `map`, `powers`, `provinces`, `armies`, `fleets`, `starting_units` (shown in Phase 1 and filled in Phases 1, 3 and 4). Fleet location keys are `"spa/nc"` or `"alb"` | FR-1 |
| Starting units reader | `Map#starting_units` builds the list on each call from stored raw entries, so no `Location` is built while the map loads | FR-6 |
| Data generation | A scratch script, not committed, writes `classic.yml` once from the tables below. The committed file is then the source of truth and is edited by hand afterwards | FR-1 |

## Files

| File | Change | Responsibility |
|---|---|---|
| `adjudicator/data/maps/classic.yml` | create | The classic map |
| `adjudicator/data/maps/.gitkeep` | delete | Placeholder no longer needed |
| `adjudicator/lib/trucebearer/adjudicator.rb` | edit | Require the three new files |
| `adjudicator/lib/trucebearer/adjudicator/errors.rb` | create | `TA::InvalidInput` |
| `adjudicator/lib/trucebearer/adjudicator/map.rb` | create | `TA::Map`, `Map::Power`, `Map::Province`, loader, queries |
| `adjudicator/lib/trucebearer/adjudicator/location.rb` | create | `TA::Location` |
| `adjudicator/spec/trucebearer/adjudicator/map_spec.rb` | create | Counts, queries, interface examples, samples, symmetry, starting units |
| `adjudicator/spec/trucebearer/adjudicator/map_data_spec.rb` | create | The raw file: format, integrity, packaging |
| `adjudicator/spec/trucebearer/adjudicator/location_spec.rb` | create | `TA::Location` |
| `adjudicator/spec/trucebearer/adjudicator/errors_spec.rb` | create | `TA::InvalidInput` |
| `adjudicator/CHANGELOG.md` | edit | "Unreleased" → "Added" entry |

---

## Phase 1: Provinces, powers and the loader (the first failing spec)

**Implements:** FR-1 (provinces, powers), FR-2, FR-3 (all queries except `adjacent?`), FR-5 | **Satisfies:** AC-1.1 to AC-1.9, AC-5.1 (province part), AC-6.1, AC-6.2, AC-6.3 (province part)
**Files:** `data/maps/classic.yml`, `lib/trucebearer/adjudicator.rb`, `errors.rb`, `map.rb`, `map_spec.rb`, `map_data_spec.rb`, `errors_spec.rb`
**Interfaces:** `TA::InvalidInput`; `TA::Map.classic`, `#id`, `#powers`, `#power(id)`, `#provinces`, `#province(id)`, `#coasts(id)`, `#supply_centers`, `#home_centers(power_id)`

### Step 1.1: Write the first failing spec

`spec/trucebearer/adjudicator/map_spec.rb` (this file grows in later phases):

```ruby
# frozen_string_literal: true

require "trucebearer/adjudicator"

RSpec.describe Trucebearer::Adjudicator::Map do
  TA = Trucebearer::Adjudicator unless defined?(TA)

  let(:map) { described_class.classic }

  describe "the province count" do
    it "has 75 provinces: 14 inland, 42 coastal and 19 sea" do
      expect(TA::Map.classic.provinces.size).to eq(75)
      expect(TA::Map.classic.provinces.map(&:type).tally).to eq(inland: 14, coastal: 42, sea: 19)
    end
  end
end
```

Run `bundle exec rspec spec/trucebearer/adjudicator/map_spec.rb`. Expected: `An error occurred while loading ./spec/trucebearer/adjudicator/map_spec.rb` with `NameError: uninitialized constant Trucebearer::Adjudicator::Map`, and `0 examples, 0 failures, 1 error occurred outside of examples`. RSpec reads `RSpec.describe Trucebearer::Adjudicator::Map` while loading the file, so a missing class shows up as a load error and not as a failed example. That is the right failure, because the loader does not exist yet. Do not commit yet.

### Step 1.2: Write the remaining Phase 1 specs, and watch them fail

Replace the body of `map_spec.rb` with the full Phase 1 version. It keeps the first example and adds the rest.

```ruby
# frozen_string_literal: true

require "trucebearer/adjudicator"

RSpec.describe Trucebearer::Adjudicator::Map do
  TA = Trucebearer::Adjudicator unless defined?(TA)

  INTERFACE_DOC = File.expand_path("../../../docs/interface.md", __dir__)

  # Reads the province table in docs/interface.md (the source of truth).
  def self.table_rows
    section = File.read(INTERFACE_DOC)[/^### Provinces\n(.*?)^## Map/m, 1]
    section.lines.filter_map do |line|
      next unless line.start_with?("| `")

      id, name, type, sc, home = line.split("|", -1)[1..5].map(&:strip)
      { id: id.delete("`").to_sym, name: name, type: type.to_sym,
        supply_center: sc == "SC", home: home.empty? ? nil : home.to_sym }
    end
  end

  let(:map) { described_class.classic }

  describe "the province count" do
    it "has 75 provinces: 14 inland, 42 coastal and 19 sea" do
      expect(TA::Map.classic.provinces.size).to eq(75)
      expect(TA::Map.classic.provinces.map(&:type).tally).to eq(inland: 14, coastal: 42, sea: 19)
    end
  end

  describe ".classic" do
    it "returns the same map every time, and the map's id is the string classic" do
      expect(described_class.classic).to be_a(described_class)
      expect(described_class.classic).to equal(described_class.classic)
      expect(map.id).to eq("classic")
    end

    it "offers no way to load another file or build another map" do
      expect(described_class).not_to respond_to(:from_file)
      expect(described_class).not_to respond_to(:new)
    end

    it "gives every thread the same object" do
      maps = Array.new(8) { Thread.new { described_class.classic } }.map(&:value)
      expect(maps.uniq(&:object_id).size).to eq(1)
    end
  end

  describe "#provinces and the interface table" do
    it "reads 75 rows from the table" do
      expect(self.class.table_rows.size).to eq(75)
    end

    it "agrees with the table on every province, and has none the table lacks" do
      actual = map.provinces.map do |p|
        { id: p.id, name: p.name, type: p.type, supply_center: p.supply_center, home: p.home }
      end
      expect(actual).to eq(self.class.table_rows)
    end

    it "is sorted by identifier and frozen" do
      expect(map.provinces.map(&:id)).to eq(map.provinces.map(&:id).sort)
      expect(map.provinces).to be_frozen
      expect(map.provinces).to all(be_frozen)
    end
  end

  describe "#supply_centers and #home_centers" do
    it "lists 34 supply centers, sorted, starting with ank, bel and ber" do
      expect(map.supply_centers.size).to eq(34)
      expect(map.supply_centers).to eq(map.supply_centers.sort)
      expect(map.supply_centers.first(3)).to eq(%i[ank bel ber])
      expect(map.supply_centers).to be_frozen
    end

    it "lists 22 home centers across the seven powers" do
      homes = map.powers.to_h { |power| [power.id, map.home_centers(power.id)] }
      expect(homes.values.sum(&:size)).to eq(22)
      expect(homes.values).to all(be_frozen)
      expect(homes.values.map(&:sort)).to eq(homes.values)
      expect(homes.transform_values(&:size)).to eq(
        austria: 3, england: 3, france: 3, germany: 3, italy: 3, russia: 4, turkey: 3
      )
    end

    it "matches the interface examples" do
      expect(map.home_centers(:england)).to eq(%i[edi lon lvp])
      expect(map.home_centers(:russia)).to eq(%i[mos sev stp war])
    end

    it "leaves 12 neutral supply centers" do
      neutral = map.supply_centers - map.powers.flat_map { |power| map.home_centers(power.id) }
      expect(neutral).to eq(%i[bel bul den gre hol nwy por rum ser spa swe tun])
    end
  end

  describe "#powers and #power" do
    it "lists the seven powers, sorted, with their names" do
      expect(map.powers.map(&:id)).to eq(%i[austria england france germany italy russia turkey])
      expect(map.powers.map(&:name)).to eq(%w[Austria England France Germany Italy Russia Turkey])
      expect(map.powers).to be_frozen
      expect(map.powers).to all(be_frozen)
    end

    it "finds one power" do
      expect(map.power(:england).name).to eq("England")
    end
  end

  describe "#province" do
    it "returns the record with all its fields" do
      spa = map.province(:spa)
      expect([spa.name, spa.type, spa.supply_center, spa.home]).to eq(["Spain", :coastal, true, nil])
      expect(map.province(:lon).home).to eq(:england)
    end
  end

  describe "#coasts" do
    it "names the coasts of the three split-coast provinces and no others" do
      expect(map.coasts(:bul)).to eq(%i[ec sc])
      expect(map.coasts(:spa)).to eq(%i[nc sc])
      expect(map.coasts(:stp)).to eq(%i[nc sc])
      others = map.provinces.map(&:id) - %i[bul spa stp]
      expect(others.map { |id| map.coasts(id) }.uniq).to eq([[]])
    end

    it "agrees with each province record, and is frozen" do
      map.provinces.each do |province|
        expect(province.coasts).to eq(map.coasts(province.id))
        expect(province.coasts).to be_frozen
      end
    end
  end

  describe "unknown identifiers" do
    {
      province: :xyz, coasts: :xyz, power: :xyz, home_centers: :xyz
    }.each do |query, bad|
      it "makes #{query}(#{bad.inspect}) raise InvalidInput naming the value" do
        expect { map.public_send(query, bad) }.to raise_error(TA::InvalidInput, /:xyz/)
      end
    end

    [["spa", '"spa"'], [nil, "nil"]].each do |bad, shown|
      %i[province coasts power home_centers].each do |query|
        it "makes #{query}(#{shown}) raise InvalidInput naming the value" do
          expect { map.public_send(query, bad) }.to raise_error(TA::InvalidInput, /#{Regexp.escape(shown)}/)
        end
      end
    end
  end
end
```

`spec/trucebearer/adjudicator/errors_spec.rb`:

```ruby
# frozen_string_literal: true

require "trucebearer/adjudicator"

RSpec.describe Trucebearer::Adjudicator::InvalidInput do
  it "is a direct subclass of StandardError" do
    expect(described_class.superclass).to equal(StandardError)
  end

  it "has no subclasses of its own" do
    expect(described_class.subclasses).to be_empty
  end
end
```

`spec/trucebearer/adjudicator/map_data_spec.rb` (Phase 1 version: format and packaging; Phase 3 adds adjacency, Phase 4 adds starting units):

```ruby
# frozen_string_literal: true

require "yaml"

RSpec.describe "data/maps/classic.yml" do
  data_path = File.expand_path("../../../data/maps/classic.yml", __dir__)
  let(:raw) { YAML.safe_load_file(data_path, permitted_classes: [], aliases: false) }

  # Every place an identifier appears, as the loader would meet it.
  def identifiers(raw)
    provinces = raw["provinces"].flat_map do |p|
      [p["id"], p["type"], p["home"], *p["coasts"]].compact
    end
    powers = raw["powers"].map { |power| power["id"] }
    armies = raw["armies"].flat_map { |from, tos| [from, *tos] }
    fleets = raw["fleets"].flat_map { |from, tos| [from, *tos] }.flat_map { |loc| loc.split("/") }
    units = raw["starting_units"].flat_map { |u| [u["power"], u["type"], u["province"], u["coast"]].compact }
    provinces + powers + armies + fleets + units
  end

  it "is found at data/maps/classic.yml and parses with the safe loader" do
    expect(File.file?(data_path)).to be(true)
    expect(raw.keys).to include("map", "powers", "provinces")
  end

  it "holds only strings where an identifier belongs" do
    expect(raw["map"]).to eq("classic")
    expect(identifiers(raw)).to all(be_a(String))
  end

  it "ships in the gem" do
    spec = Gem::Specification.load(File.expand_path("../../../trucebearer-adjudicator.gemspec", __dir__))
    expect(spec.files).to include("data/maps/classic.yml")
  end
end
```

In Phase 1 the data file has no `armies`, `fleets` or `starting_units` keys yet, so `identifiers` would fail on `nil.flat_map`. Write it from the start with `raw.fetch("armies", {})`, `raw.fetch("fleets", {})` and `raw.fetch("starting_units", [])`, and tighten those three to `raw["..."]` in Phases 3 and 4 when the keys exist. (In the code above, use `fetch` in Phase 1.)

Run `bundle exec rspec spec/trucebearer/adjudicator/map_spec.rb spec/trucebearer/adjudicator/errors_spec.rb`. Expected: two load errors (`NameError: uninitialized constant Trucebearer::Adjudicator::Map`, and `...::InvalidInput`), and `0 examples`. A load error stops the whole run, so the version spec is not run either.

Then run the raw-file spec on its own: `bundle exec rspec spec/trucebearer/adjudicator/map_data_spec.rb`. Expected: 3 failures. `File.file?` is false, the safe load raises `Errno::ENOENT`, and the gemspec's file list lacks `data/maps/classic.yml`.

### Step 1.3: Generate the Phase 1 data

Create the scratch script `<scratchpad>/gen_classic.rb`. In this phase it writes the file header, `powers` and `provinces`; Phase 3 extends it. The province rows come from the table in `docs/interface.md` (the contract's source of truth), so the data and the table cannot drift apart on a typo.

```ruby
# frozen_string_literal: true
# Scratch generator: writes data/maps/classic.yml once. Not committed.

ROOT = "/Users/james/orca/workspaces/trucebearer/tb-9-classic-map/adjudicator"
doc = File.read("#{ROOT}/docs/interface.md")
section = doc[/^### Provinces\n(.*?)^## Map/m, 1]
rows = section.lines.filter_map do |line|
  next unless line.start_with?("| `")
  id, name, type, sc, home = line.split("|", -1)[1..5].map(&:strip)
  [id.delete("`"), name, type, sc == "SC", home]
end
abort "expected 75 rows, got #{rows.size}" unless rows.size == 75

COASTS = { "bul" => %w[ec sc], "spa" => %w[nc sc], "stp" => %w[nc sc] }.freeze
POWERS = %w[austria england france germany italy russia turkey].freeze

out = +<<~HEADER
  # The classic map: provinces, coasts, adjacency, supply centers, home centers
  # and the starting units for spring 1901.
  #
  # Written independently from public geographic knowledge and the game's terms
  # of art. It is not derived from a scan or image of any board, and not copied
  # from any other engine's data files.
  #
  # Every identifier is a quoted string, so YAML never reads one as a boolean or
  # a number. The loader reads this file with the safe loader only.
  map: "classic"

HEADER

out << "powers:\n"
POWERS.each { |id| out << %(  - { id: "#{id}", name: "#{id.capitalize}" }\n) }

out << "\nprovinces:\n"
rows.each do |id, name, type, sc, home|
  fields = [%(id: "#{id}"), %(name: "#{name}"), %(type: "#{type}")]
  fields << "supply_center: true" if sc
  fields << %(home: "#{home}") unless home.empty?
  fields << %(coasts: [#{COASTS[id].map { |c| %("#{c}") }.join(", ")}]) if COASTS.key?(id)
  out << "  - { #{fields.join(", ")} }\n"
end

File.write("#{ROOT}/data/maps/classic.yml", out)
puts "wrote #{rows.size} provinces"
```

Run it with `ruby <scratchpad>/gen_classic.rb`. Expected output: `wrote 75 provinces`.

### Step 1.4: Write the code

`lib/trucebearer/adjudicator/errors.rb`:

```ruby
# frozen_string_literal: true

module Trucebearer
  module Adjudicator
    # Raised for every input error the gem detects: a bad hash, an unknown
    # identifier, an impossible value. There is deliberately only this one class.
    class InvalidInput < StandardError; end
  end
end
```

`lib/trucebearer/adjudicator/map.rb` (the army and fleet tables and `adjacent?` arrive in Phase 3, and `starting_units` in Phase 4):

```ruby
# frozen_string_literal: true

require "yaml"
require "set"

module Trucebearer
  module Adjudicator
    # The map: provinces, powers and what touches what. Query-only, never stored.
    # Built once from data/maps/classic.yml when this file is required.
    class Map
      Power = Data.define(:id, :name)
      Province = Data.define(:id, :name, :type, :coasts, :supply_center, :home)

      DATA_PATH = File.expand_path("../../../data/maps/classic.yml", __dir__)

      class << self
        # The classic map. Takes no path: the gem has one map, built in. The loader
        # and the constructor are private, so there is no way to load another file.
        attr_reader :classic

        private

        def from_file(path)
          raw = YAML.safe_load_file(path, permitted_classes: [], aliases: false)
          new(
            id: raw["map"],
            powers: raw["powers"].map { |p| Power.new(id: p["id"].to_sym, name: p["name"]) },
            provinces: raw["provinces"].map { |p| build_province(p) }
          )
        end

        def build_province(entry)
          Province.new(
            id: entry["id"].to_sym,
            name: entry["name"],
            type: entry["type"].to_sym,
            coasts: entry.fetch("coasts", []).map(&:to_sym).freeze,
            supply_center: entry.fetch("supply_center", false),
            home: entry["home"]&.to_sym
          ).freeze
        end
      end

      private_class_method :new

      attr_reader :id, :powers, :provinces, :supply_centers

      def initialize(id:, powers:, provinces:)
        @id = id.freeze
        @powers = powers.sort_by(&:id).freeze
        @provinces = provinces.sort_by(&:id).freeze
        @powers_by_id = @powers.to_h { |power| [power.id, power] }.freeze
        @provinces_by_id = @provinces.to_h { |province| [province.id, province] }.freeze
        @supply_centers = @provinces.select(&:supply_center).map(&:id).freeze
        @home_centers = @powers.to_h do |power|
          [power.id, @provinces.select { |province| province.home == power.id }.map(&:id).freeze]
        end.freeze
        freeze
      end

      def power(id)
        @powers_by_id.fetch(id) { raise InvalidInput, "unknown power #{id.inspect}" }
      end

      def province(id)
        @provinces_by_id.fetch(id) { raise InvalidInput, "unknown province #{id.inspect}" }
      end

      def coasts(province_id)
        province(province_id).coasts
      end

      def home_centers(power_id)
        @home_centers.fetch(power_id) { raise InvalidInput, "unknown power #{power_id.inspect}" }
      end

      @classic = from_file(DATA_PATH)
    end
  end
end
```

`lib/trucebearer/adjudicator.rb` becomes:

```ruby
# frozen_string_literal: true

require_relative "adjudicator/version"
require_relative "adjudicator/errors"
require_relative "adjudicator/map"

module Trucebearer
  # The rules engine: checks orders and adjudicates each phase of a game turn.
  module Adjudicator
  end
end
```

(`location.rb` joins the requires in Phase 2.)

`git rm data/maps/.gitkeep` (the placeholder is tracked, so this works).

### Step 1.5: Run to green, then commit

Run `bundle exec rspec`. Expected: 0 failures, with every Phase 1 example passing. Run `bundle exec rake`; it prints the same.

Sanity check that the data matches the counts: `bundle exec ruby -Ilib -rtrucebearer/adjudicator -e 'm = Trucebearer::Adjudicator::Map.classic; p m.provinces.size, m.supply_centers.size, m.powers.sum { |x| m.home_centers(x.id).size }'`. Expected: `75`, `34`, `22`.

Commit, as one commit with the specs and the code together, so that no commit fails its own specs: "Load the classic map's provinces and powers from a data file".

---

## Phase 2: `TA::Location`

**Implements:** FR-4 | **Satisfies:** AC-3.1 to AC-3.8
**Files:** `location.rb`, `adjudicator.rb`, `location_spec.rb`
**Interfaces:** `TA::Location.new(province:, coast: nil)`, `#province`, `#coast`, `#to_h`, `TA::Location.from_h(hash)`

### Step 2.1: Write the failing specs

`spec/trucebearer/adjudicator/location_spec.rb`:

```ruby
# frozen_string_literal: true

require "json"
require "trucebearer/adjudicator"

RSpec.describe Trucebearer::Adjudicator::Location do
  TA = Trucebearer::Adjudicator unless defined?(TA)
  L = described_class unless defined?(L)

  describe ".new" do
    it "keeps the province and coast, and defaults the coast to nil" do
      location = L.new(province: :spa, coast: :nc)
      expect([location.province, location.coast]).to eq(%i[spa nc])
      expect(L.new(province: :bud).coast).to be_nil
    end

    it "is immutable, and equal to another location with the same contents" do
      expect(L.new(province: :spa, coast: :nc)).to be_frozen
      expect(L.new(province: :spa, coast: :nc)).to eq(L.new(province: :spa, coast: :nc))
      expect(L.new(province: :spa, coast: :nc).hash).to eq(L.new(province: :spa, coast: :nc).hash)
      expect(L.new(province: :spa, coast: :nc)).not_to eq(L.new(province: :spa, coast: :sc))
    end

    it "accepts a split-coast province with no coast" do
      expect(L.new(province: :spa).coast).to be_nil
    end

    it "rejects strings and other non-symbols, naming the value" do
      expect { L.new(province: "stp") }.to raise_error(TA::InvalidInput, /"stp"/)
      expect { L.new(province: :stp, coast: "sc") }.to raise_error(TA::InvalidInput, /"sc"/)
      expect { L.new(province: nil) }.to raise_error(TA::InvalidInput, /nil/)
      expect { L.new(province: 7) }.to raise_error(TA::InvalidInput, /7/)
    end

    it "rejects provinces and coasts that cannot exist, naming the value" do
      expect { L.new(province: :xyz) }.to raise_error(TA::InvalidInput, /:xyz/)
      expect { L.new(province: :spa, coast: :xx) }.to raise_error(TA::InvalidInput, /:xx/)
      expect { L.new(province: :par, coast: :nc) }.to raise_error(TA::InvalidInput, /:nc/)
      expect { L.new(province: :bul, coast: :nc) }.to raise_error(TA::InvalidInput, /:nc/)
      expect { L.new(province: :spa, coast: :ec) }.to raise_error(TA::InvalidInput, /:ec/)
    end
  end

  describe "#to_h" do
    it "gives string keys and string or nil values, with no format" do
      expect(L.new(province: :spa, coast: :nc).to_h).to eq("province" => "spa", "coast" => "nc")
      expect(L.new(province: :bud).to_h).to eq("province" => "bud", "coast" => nil)
    end
  end

  describe ".from_h" do
    let(:all_locations) do
      map = TA::Map.classic
      map.provinces.map { |p| L.new(province: p.id) } +
        map.provinces.flat_map { |p| p.coasts.map { |c| L.new(province: p.id, coast: c) } }
    end

    it "round-trips all 81 valid locations through JSON" do
      expect(all_locations.size).to eq(81)
      all_locations.each do |location|
        expect(L.from_h(JSON.parse(JSON.generate(location.to_h)))).to eq(location)
      end
    end

    it "rejects symbols where strings are required" do
      expect { L.from_h({ "province" => :stp, "coast" => nil }) }.to raise_error(TA::InvalidInput, /:stp/)
      expect { L.from_h({ "province" => "stp", "coast" => :sc }) }.to raise_error(TA::InvalidInput, /:sc/)
    end

    it "rejects a province that is nil or not a string" do
      expect { L.from_h({ "province" => nil, "coast" => nil }) }.to raise_error(TA::InvalidInput, /nil/)
      expect { L.from_h({ "province" => 7, "coast" => nil }) }.to raise_error(TA::InvalidInput, /7/)
    end

    it "rejects provinces and coasts that cannot exist" do
      expect { L.from_h({ "province" => "xyz", "coast" => nil }) }.to raise_error(TA::InvalidInput, /xyz/)
      expect { L.from_h({ "province" => "par", "coast" => "nc" }) }.to raise_error(TA::InvalidInput, /nc/)
      expect { L.from_h({ "province" => "spa", "coast" => "xx" }) }.to raise_error(TA::InvalidInput, /xx/)
      expect { L.from_h({ "province" => "bul", "coast" => "nc" }) }.to raise_error(TA::InvalidInput, /nc/)
      expect { L.from_h({ "province" => "spa", "coast" => "ec" }) }.to raise_error(TA::InvalidInput, /ec/)
    end

    it "rejects a missing key, an unknown key, symbol keys and a non-hash, naming the item" do
      expect { L.from_h({ "coast" => nil }) }.to raise_error(TA::InvalidInput, /"province"/)
      expect { L.from_h({ "province" => "spa" }) }.to raise_error(TA::InvalidInput, /"coast"/)
      expect { L.from_h({ "province" => "spa", "coast" => nil, "extra" => 1 }) }
        .to raise_error(TA::InvalidInput, /"extra"/)
      expect { L.from_h({ province: "spa", coast: nil }) }.to raise_error(TA::InvalidInput)
      expect { L.from_h("spa") }.to raise_error(TA::InvalidInput, /"spa"/)
    end
  end
end
```

Run `bundle exec rspec spec/trucebearer/adjudicator/location_spec.rb`. Expected: an error while loading the file, `NameError: uninitialized constant Trucebearer::Adjudicator::Location`, and `0 examples`. (`TA` and `L` are defined with `unless defined?` guards because several spec files define them. Each file's guard keeps them from warning twice.)

### Step 2.2: Write `TA::Location`

`lib/trucebearer/adjudicator/location.rb`:

```ruby
# frozen_string_literal: true

module Trucebearer
  module Adjudicator
    # A place on the board: a province and, for a split-coast province, optionally
    # a coast. `new` takes symbols, `from_h` takes strings. Checked against the
    # classic map when built. It carries no format (it only appears nested).
    Location = Data.define(:province, :coast) do
      def initialize(province:, coast: nil)
        raise InvalidInput, "province must be a Symbol, got #{province.inspect}" unless province.is_a?(Symbol)
        raise InvalidInput, "coast must be a Symbol or nil, got #{coast.inspect}" unless coast.nil? || coast.is_a?(Symbol)

        known = Map.classic.province(province)
        unless coast.nil? || known.coasts.include?(coast)
          raise InvalidInput, "province #{province.inspect} has no coast #{coast.inspect}"
        end

        super
      end

      def to_h
        { "province" => province.to_s, "coast" => coast&.to_s }
      end

      def self.from_h(hash)
        raise InvalidInput, "expected a Hash, got #{hash.inspect}" unless hash.is_a?(Hash)

        keys = %w[province coast]
        (keys - hash.keys).each { |key| raise InvalidInput, "missing key #{key.inspect}" }
        (hash.keys - keys).each { |key| raise InvalidInput, "unknown key #{key.inspect}" }
        province = hash["province"]
        coast = hash["coast"]
        raise InvalidInput, "\"province\" must be a String, got #{province.inspect}" unless province.is_a?(String)
        raise InvalidInput, "\"coast\" must be a String or nil, got #{coast.inspect}" unless coast.nil? || coast.is_a?(String)

        new(province: province.to_sym, coast: coast&.to_sym)
      end
    end
  end
end
```

Add `require_relative "adjudicator/location"` to `lib/trucebearer/adjudicator.rb`, after `map`.

(`super` with no arguments passes the current keyword arguments on, which is what `Data#initialize` needs. `Data.define` keeps `new` working with positional or keyword arguments, and the overridden `initialize` gives `coast` its default.)

### Step 2.3: Run to green, then commit

`bundle exec rspec`. Expected: 0 failures. Commit: "Add TA::Location with validation and a hash form".

---

## Phase 3: Adjacency

**Implements:** FR-1 (adjacency), FR-3 (`adjacent?`), FR-6 not touched | **Satisfies:** AC-2.1 to AC-2.10, AC-5.2, AC-5.3, AC-5.4, AC-5.1 (adjacency part), AC-6.3 (unchanged)
**Files:** `classic.yml`, `map.rb`, `map_spec.rb`, `map_data_spec.rb`, scratch `gen_classic.rb`
**Interfaces:** `TA::Map#adjacent?(unit_type, from, to)`

### Step 3.1: Write the failing specs

Add to `map_data_spec.rb` (and tighten `fetch` to direct access for `armies` and `fleets` in `identifiers`):

```ruby
  describe "army adjacency" do
    it "is symmetric, has no self-loops or duplicates, and names only known land provinces" do
      armies = raw["armies"]
      known = raw["provinces"].to_h { |p| [p["id"], p["type"]] }
      armies.each do |from, tos|
        expect(known[from]).not_to be_nil, "#{from} is not a province"
        expect(known[from]).not_to eq("sea"), "#{from} is a sea province with army neighbors"
        expect(tos).not_to include(from)
        expect(tos.uniq).to eq(tos), "#{from} lists a neighbor twice"
        tos.each do |to|
          expect(known[to]).not_to be_nil, "#{from} lists unknown #{to}"
          expect(known[to]).not_to eq("sea"), "#{from} lists sea province #{to}"
          expect(armies[to]).to include(from), "#{from} lists #{to}, but not the other way round"
        end
      end
    end
  end

  describe "fleet adjacency" do
    it "is symmetric, has no self-loops or duplicates, and names only known non-inland locations" do
      fleets = raw["fleets"]
      known = raw["provinces"].to_h { |p| [p["id"], p["type"]] }
      fleets.each do |from, tos|
        expect(tos).not_to include(from)
        expect(tos.uniq).to eq(tos), "#{from} lists a neighbor twice"
        [from, *tos].each do |loc|
          province = loc.split("/").first
          expect(known[province]).not_to be_nil, "unknown province in #{loc}"
          expect(known[province]).not_to eq("inland"), "inland province in #{loc}"
        end
        tos.each { |to| expect(fleets[to]).to include(from), "#{from} lists #{to}, but not the other way round" }
      end
    end

    it "names a coast exactly on the three split-coast provinces, and one the province has" do
      coasts = raw["provinces"].to_h { |p| [p["id"], p["coasts"] || []] }
      locations = raw["fleets"].flat_map { |from, tos| [from, *tos] }.uniq
      locations.each do |loc|
        province, coast = loc.split("/")
        if coasts[province].empty?
          expect(coast).to be_nil, "#{loc} names a coast on an unsplit province"
        else
          expect(coasts[province]).to include(coast), "#{loc} lacks a valid coast"
        end
      end
      expect(raw["fleets"].keys.size).to eq(64)
    end
  end
```

Add to `map_spec.rb`, inside the `describe Map` block:

```ruby
  describe "#adjacent?" do
    def loc(province, coast = nil)
      TA::Location.new(province: province, coast: coast)
    end

    def fleet(from, to)
      from_province, from_coast = from.to_s.split("/").map(&:to_sym)
      to_province, to_coast = to.to_s.split("/").map(&:to_sym)
      map.adjacent?(:fleet, loc(from_province, from_coast), loc(to_province, to_coast))
    end

    def army(from, to)
      map.adjacent?(:army, loc(from), loc(to))
    end

    let(:provinces) { map.provinces }
    let(:fleet_locations) do
      provinces.reject { |p| p.type == :inland }.flat_map do |p|
        p.coasts.empty? ? [loc(p.id)] : p.coasts.map { |c| loc(p.id, c) }
      end
    end

    it "matches the examples in the interface document" do
      expect(map.adjacent?(:fleet, loc(:mao), loc(:spa, :nc))).to be(true)
      expect(map.adjacent?(:fleet, loc(:gol), loc(:spa, :nc))).to be(false)
      expect(map.adjacent?(:army, loc(:par), loc(:bur))).to be(true)
      expect { map.adjacent?(:army, loc(:par), loc(:spa, :nc)) }.to raise_error(TA::InvalidInput)
    end

    it "is symmetric for armies, with no province next to itself" do
      provinces.each do |a|
        expect(army(a.id, a.id)).to be(false)
        provinces.each { |b| expect(army(a.id, b.id)).to eq(army(b.id, a.id)) }
      end
    end

    it "is symmetric for fleets by coast, with no location next to itself" do
      expect(fleet_locations.size).to eq(64)
      fleet_locations.each do |a|
        expect(map.adjacent?(:fleet, a, a)).to be(false)
        fleet_locations.each do |b|
          expect(map.adjacent?(:fleet, a, b)).to eq(map.adjacent?(:fleet, b, a))
        end
      end
    end

    describe "each split coast, for a fleet" do
      {
        "spa/nc" => { true => %i[mao gas por], false => %i[gol wes mar] },
        "spa/sc" => { true => %i[mao por gol wes mar], false => %i[gas] },
        "stp/nc" => { true => %i[bar nwy], false => %i[bot fin lvn] },
        "stp/sc" => { true => %i[bot fin lvn], false => %i[bar nwy] },
        "bul/ec" => { true => %i[bla con rum], false => %i[aeg gre] },
        "bul/sc" => { true => %i[aeg con gre], false => %i[bla rum] }
      }.each do |coast, expected|
        expected.each do |answer, neighbors|
          neighbors.each do |neighbor|
            it "says #{neighbor} -> #{coast} is #{answer}, and the same the other way" do
              expect(fleet(neighbor, coast)).to be(answer)
              expect(fleet(coast, neighbor)).to be(answer)
            end
          end
        end
      end

      it "never joins the two coasts of one province" do
        expect(fleet("spa/nc", "spa/sc")).to be(false)
        expect(fleet("stp/nc", "stp/sc")).to be(false)
        expect(fleet("bul/ec", "bul/sc")).to be(false)
      end
    end

    describe "a sample of land borders, for armies" do
      %w[par-bur par-pic par-gas par-bre spa-por spa-gas spa-mar stp-fin stp-nwy stp-lvn stp-mos
         bul-con bul-gre bul-rum bul-ser vie-boh ber-sil kie-den rom-apu lon-wal rom-tus tun-naf
         fin-nwy ank-smy arm-smy arm-syr lvp-yor wal-yor edi-lvp pie-ven tus-ven gas-mar].each do |pair|
        a, b = pair.split("-").map(&:to_sym)
        it("joins #{a} and #{b}") { expect(army(a, b)).to be(true) }
      end

      %w[par-mar par-lon spa-bre lon-bel rom-pie].each do |pair|
        a, b = pair.split("-").map(&:to_sym)
        it("does not join #{a} and #{b}") { expect(army(a, b)).to be(false) }
      end

      it "never joins a pair with a sea province on either side" do
        seas = provinces.select { |p| p.type == :sea }.map(&:id)
        provinces.each do |p|
          seas.each do |sea|
            expect(army(p.id, sea)).to be(false)
            expect(army(sea, p.id)).to be(false)
          end
        end
      end
    end

    describe "a sample of plain locations, for fleets" do
      %w[lon-nth lon-eng kie-den kie-hol kie-ber kie-hel kie-bal ven-adr con-bla con-aeg con-smy nth-nwg
         bal-bot bar-nwy adr-ion naf-mao den-swe nwy-swe den-bal ion-tun mao-wes].each do |pair|
        a, b = pair.split("-")
        it("joins #{a} and #{b}") { expect(fleet(a, b)).to be(true) }
      end

      %w[par-bur mun-boh rom-ven adr-tys lon-bel fin-nwy ank-smy arm-syr lvp-yor wal-yor edi-lvp pie-ven
         tus-ven gas-mar ska-bal hel-bal aeg-bla mao-gol].each do |pair|
        a, b = pair.split("-")
        it("does not join #{a} and #{b}") { expect(fleet(a, b)).to be(false) }
      end
    end

    it "gives every fleet location a fleet neighbor" do
      fleet_locations.each do |a|
        expect(fleet_locations.any? { |b| map.adjacent?(:fleet, a, b) }).to be(true), "#{a} has no fleet neighbor"
      end
    end

    it "keeps armies on land: no army neighbors at sea, at least one everywhere else" do
      provinces.each do |a|
        army_neighbors = provinces.select { |b| army(a.id, b.id) }
        if a.type == :sea
          expect(army_neighbors).to be_empty
        else
          expect(army_neighbors).not_to be_empty, "#{a.id} has no army neighbor"
        end
      end
    end

    it "keeps fleets off inland provinces" do
      provinces.select { |p| p.type == :inland }.each do |inland|
        expect(fleet_locations.none? { |b| map.adjacent?(:fleet, loc(inland.id), b) }).to be(true)
      end
    end

    it "makes every fleet-adjacent pair of non-sea provinces army-adjacent too" do
      coastal = fleet_locations.reject { |l| map.province(l.province).type == :sea }
      coastal.product(coastal).each do |a, b|
        next unless map.adjacent?(:fleet, a, b)
        next if a.province == b.province

        expect(army(a.province, b.province)).to be(true), "#{a} and #{b} touch for fleets but not armies"
      end
    end

    it "answers false, and raises nothing, for an army at sea or a fleet inland" do
      expect(map.adjacent?(:army, loc(:nth), loc(:eng))).to be(false)
      expect(map.adjacent?(:army, loc(:par), loc(:nth))).to be(false)
      expect(map.adjacent?(:fleet, loc(:par), loc(:bur))).to be(false)
      expect(map.adjacent?(:fleet, loc(:nth), loc(:mun))).to be(false)
    end

    describe "arguments that break the rules" do
      it "raises for an army location that names a coast, in from or in to" do
        shown = Regexp.escape(loc(:spa, :nc).inspect)
        expect { map.adjacent?(:army, loc(:par), loc(:spa, :nc)) }.to raise_error(TA::InvalidInput, /#{shown}/)
        expect { map.adjacent?(:army, loc(:spa, :nc), loc(:par)) }.to raise_error(TA::InvalidInput, /#{shown}/)
      end

      it "raises for a fleet location on a split-coast province with no coast, in from or in to" do
        shown = Regexp.escape(loc(:spa).inspect)
        expect { map.adjacent?(:fleet, loc(:mao), loc(:spa)) }.to raise_error(TA::InvalidInput, /#{shown}/)
        expect { map.adjacent?(:fleet, loc(:spa), loc(:mao)) }.to raise_error(TA::InvalidInput, /#{shown}/)
      end

      it "raises before working out an answer, even when the partner is far away" do
        expect { map.adjacent?(:army, loc(:spa, :nc), loc(:nth)) }.to raise_error(TA::InvalidInput)
        expect { map.adjacent?(:fleet, loc(:spa), loc(:par)) }.to raise_error(TA::InvalidInput)
      end

      it "raises for a unit type that is not :army or :fleet, naming the value" do
        ["army", "fleet", :cavalry, nil].each do |bad|
          expect { map.adjacent?(bad, loc(:par), loc(:bur)) }
            .to raise_error(TA::InvalidInput, /#{Regexp.escape(bad.inspect)}/)
        end
      end

      it "raises for a from or to that is not a TA::Location, naming the value" do
        expect { map.adjacent?(:army, :par, loc(:bur)) }.to raise_error(TA::InvalidInput, /:par/)
        expect { map.adjacent?(:army, loc(:par), "bur") }.to raise_error(TA::InvalidInput, /"bur"/)
      end
    end
  end
```

Run `bundle exec rspec`. Expected failures: `adjacent?` examples fail with `NoMethodError: undefined method 'adjacent?'`; the raw-file adjacency examples fail with `NoMethodError` on `nil` (no `armies` key yet). The remaining Phase 1 and 2 examples still pass, except the raw-file example "holds only strings where an identifier belongs": tightening `identifiers` to read `raw["armies"]` and `raw["fleets"]` makes it fail until the data has them, so this step's output shows it failing. (Step 4.1 does the same with `starting_units`, which the Phase 4 data adds.)

### Step 3.2: Extend the generator, and write the adjacency data

Append to `<scratchpad>/gen_classic.rb`, before the `File.write` line. The tables are written from public geographic knowledge of the standard seven-power map.

Army neighbors, listed from both sides on purpose, so that the spec (not the script) is what proves symmetry:

```ruby
ARMIES = <<~TABLE
  alb: gre ser tri
  ank: arm con smy
  apu: nap rom ven
  arm: ank sev smy syr
  bel: bur hol pic ruh
  ber: kie mun pru sil
  boh: gal mun sil tyr vie
  bre: gas par pic
  bud: gal rum ser tri vie
  bul: con gre rum ser
  bur: bel gas mar mun par pic ruh
  cly: edi lvp
  con: ank bul smy
  den: kie swe
  edi: cly lvp yor
  fin: nwy stp swe
  gal: boh bud rum sil ukr vie war
  gas: bre bur mar par spa
  gre: alb bul ser
  hol: bel kie ruh
  kie: ber den hol mun ruh
  lon: wal yor
  lvn: mos pru stp war
  lvp: cly edi wal yor
  mar: bur gas pie spa
  mos: lvn sev stp ukr war
  mun: ber boh bur kie ruh sil tyr
  naf: tun
  nap: apu rom
  nwy: fin stp swe
  par: bre bur gas pic
  pic: bel bre bur par
  pie: mar tus tyr ven
  por: spa
  pru: ber lvn sil war
  rom: apu nap tus ven
  ruh: bel bur hol kie mun
  rum: bud bul gal ser sev ukr
  ser: alb bud bul gre rum tri
  sev: arm mos rum ukr
  sil: ber boh gal mun pru war
  smy: ank arm con syr
  spa: gas mar por
  stp: fin lvn mos nwy
  swe: den fin nwy
  syr: arm smy
  tri: alb bud ser tyr ven vie
  tun: naf
  tus: pie rom ven
  tyr: boh mun pie tri ven vie
  ukr: gal mos rum sev war
  ven: apu pie rom tri tus tyr
  vie: boh bud gal tri tyr
  wal: lon lvp yor
  war: gal lvn mos pru sil ukr
  yor: edi lon lvp wal
TABLE
```

Fleet neighbors. The sea provinces are listed with every location they touch. The coastal pairs are the fleet moves between two coastal locations that share a stretch of coast. The script lists each only once and adds the other direction itself, because the sea table is written from the sea side only:

```ruby
SEAS = <<~TABLE
  adr: alb apu ion tri ven
  aeg: bul/sc con eas gre ion smy
  bal: ber bot den kie lvn pru swe
  bar: nwg nwy stp/nc
  bla: ank arm bul/ec con rum sev
  bot: bal fin lvn stp/sc swe
  eas: aeg ion smy syr
  eng: bel bre iri lon mao nth pic wal
  gol: mar pie spa/sc tus tys wes
  hel: den hol kie nth
  ion: adr aeg alb apu eas gre nap tun tys
  iri: eng lvp mao nao wal
  mao: bre eng gas iri naf nao por spa/nc spa/sc wes
  nao: cly iri lvp mao nwg
  nth: bel den edi eng hel hol lon nwg nwy ska yor
  nwg: bar cly edi nao nth nwy
  ska: den nth nwy swe
  tys: gol ion nap rom tun tus wes
  wes: gol mao naf spa/sc tun tys
TABLE

COAST_PAIRS = <<~TABLE
  alb gre
  alb tri
  ank arm
  ank con
  apu nap
  apu ven
  arm sev
  bel hol
  bel pic
  ber kie
  ber pru
  bre gas
  bre pic
  bul/ec con
  bul/ec rum
  bul/sc con
  bul/sc gre
  cly edi
  cly lvp
  con smy
  den kie
  den swe
  edi yor
  fin stp/sc
  fin swe
  gas spa/nc
  hol kie
  lon wal
  lon yor
  lvn pru
  lvn stp/sc
  lvp wal
  mar pie
  mar spa/sc
  naf tun
  nap rom
  nwy stp/nc
  nwy swe
  por spa/nc
  por spa/sc
  rom tus
  rum sev
  smy syr
  pie tus
  tri ven
TABLE
```

(Each pair is written once. The script uses sets, so a pair written twice would do no harm.)

```ruby
require "set"

armies = ARMIES.lines.to_h do |line|
  from, tos = line.split(":")
  [from.strip, tos.split]
end
armies.each do |from, tos|
  tos.each { |to| abort "army table is not symmetric: #{from} lists #{to}" unless armies.fetch(to, []).include?(from) }
end

fleets = Hash.new { |h, k| h[k] = Set.new }
link = lambda do |a, b|
  fleets[a] << b
  fleets[b] << a
end
SEAS.lines.each do |line|
  from, tos = line.split(":")
  tos.split.each { |to| link.call(from.strip, to) }
end
COAST_PAIRS.lines.each { |line| a, b = line.split; link.call(a, b) }
abort "expected 64 fleet locations, got #{fleets.size}" unless fleets.size == 64

out << "\narmies:\n"
armies.keys.sort.each { |from| out << %(  "#{from}": [#{armies[from].sort.map { |t| %("#{t}") }.join(", ")}]\n) }

out << "\nfleets:\n"
fleets.keys.sort.each { |from| out << %(  "#{from}": [#{fleets[from].to_a.sort.map { |t| %("#{t}") }.join(", ")}]\n) }
```

Run the script again with `ruby <scratchpad>/gen_classic.rb`. Expected: `wrote 75 provinces`, no abort. `classic.yml` now holds both tables in full, with each edge listed from both sides, and it is committed with this phase. From here on, edit the YAML by hand.

### Step 3.3: Write `adjacent?`

Replace `lib/trucebearer/adjudicator/map.rb` with the complete file below. It is the Phase 1 file plus the two adjacency tables, `adjacent?` and its helper. The `starting_units` reader joins in Phase 4.

```ruby
# frozen_string_literal: true

require "yaml"
require "set"

module Trucebearer
  module Adjudicator
    # The map: provinces, powers and what touches what. Query-only, never stored.
    # Built once from data/maps/classic.yml when this file is required.
    class Map
      Power = Data.define(:id, :name)
      Province = Data.define(:id, :name, :type, :coasts, :supply_center, :home)

      DATA_PATH = File.expand_path("../../../data/maps/classic.yml", __dir__)
      NO_NEIGHBORS = Set.new.freeze

      class << self
        # The classic map. Takes no path: the gem has one map, built in. The loader
        # and the constructor are private, so there is no way to load another file.
        attr_reader :classic

        private

        def from_file(path)
          raw = YAML.safe_load_file(path, permitted_classes: [], aliases: false)
          new(
            id: raw["map"],
            powers: raw["powers"].map { |p| Power.new(id: p["id"].to_sym, name: p["name"]) },
            provinces: raw["provinces"].map { |p| build_province(p) },
            armies: raw["armies"].to_h { |from, tos| [from.to_sym, tos.map(&:to_sym).to_set.freeze] }.freeze,
            fleets: raw["fleets"].to_h { |from, tos| [fleet_key(from), tos.map { |to| fleet_key(to) }.to_set.freeze] }.freeze
          )
        end

        def build_province(entry)
          Province.new(
            id: entry["id"].to_sym,
            name: entry["name"],
            type: entry["type"].to_sym,
            coasts: entry.fetch("coasts", []).map(&:to_sym).freeze,
            supply_center: entry.fetch("supply_center", false),
            home: entry["home"]&.to_sym
          )
        end

        # "spa/nc" -> [:spa, :nc]; "alb" -> [:alb, nil]
        def fleet_key(text)
          province, coast = text.split("/")
          [province.to_sym, coast&.to_sym]
        end
      end

      private_class_method :new

      attr_reader :id, :powers, :provinces, :supply_centers

      def initialize(id:, powers:, provinces:, armies:, fleets:)
        @id = id.freeze
        @powers = powers.sort_by(&:id).freeze
        @provinces = provinces.sort_by(&:id).freeze
        @powers_by_id = @powers.to_h { |power| [power.id, power] }.freeze
        @provinces_by_id = @provinces.to_h { |province| [province.id, province] }.freeze
        @supply_centers = @provinces.select(&:supply_center).map(&:id).freeze
        @home_centers = @powers.to_h do |power|
          [power.id, @provinces.select { |province| province.home == power.id }.map(&:id).freeze]
        end.freeze
        @armies = armies
        @fleets = fleets
        freeze
      end

      def power(id)
        @powers_by_id.fetch(id) { raise InvalidInput, "unknown power #{id.inspect}" }
      end

      def province(id)
        @provinces_by_id.fetch(id) { raise InvalidInput, "unknown province #{id.inspect}" }
      end

      def coasts(province_id)
        province(province_id).coasts
      end

      def home_centers(power_id)
        @home_centers.fetch(power_id) { raise InvalidInput, "unknown power #{power_id.inspect}" }
      end

      # True when a unit of this type can move between the two locations in one step.
      # Arguments are checked first, so a malformed question raises instead of answering false.
      def adjacent?(unit_type, from, to)
        unless %i[army fleet].include?(unit_type)
          raise InvalidInput, "unit type must be :army or :fleet, got #{unit_type.inspect}"
        end

        from_key = lookup_key(unit_type, from, "from")
        to_key = lookup_key(unit_type, to, "to")
        table = unit_type == :army ? @armies : @fleets
        table.fetch(from_key, NO_NEIGHBORS).include?(to_key)
      end

      private

      # An army is looked up by province alone. A fleet by province and coast.
      def lookup_key(unit_type, location, label)
        raise InvalidInput, "#{label} must be a TA::Location, got #{location.inspect}" unless location.is_a?(Location)

        if unit_type == :army
          raise InvalidInput, "an army location must not name a coast, got #{location.inspect}" if location.coast

          location.province
        else
          if location.coast.nil? && !province(location.province).coasts.empty?
            raise InvalidInput, "a fleet location on a split-coast province must name a coast, got #{location.inspect}"
          end

          [location.province, location.coast]
        end
      end

      # Last statement of the class body: everything it needs is defined above.
      @classic = from_file(DATA_PATH)
    end
  end
end
```

`Location` is only used inside `lookup_key`, at call time, so requiring `map.rb` before `location.rb` is fine.

### Step 3.4: Run to green, then commit

`bundle exec rspec`. Expected: 0 failures. If a sample fails, the first suspect is the data, not the spec: check the geography, fix the YAML by hand, and rerun. If symmetry fails, the message names the pair. Commit: "Add army and fleet adjacency to the classic map, with coasts".

---

## Phase 4: The starting units

**Implements:** FR-1 (starting units), FR-6 | **Satisfies:** AC-4.1 to AC-4.4, AC-5.5, AC-5.1 (starting units part)
**Files:** `classic.yml`, `map.rb`, `map_spec.rb`, `map_data_spec.rb`
**Interfaces:** `TA::Map#starting_units` (internal)

### Step 4.1: Write the failing specs

Add to `map_data_spec.rb` (and tighten the `starting_units` access in `identifiers`):

```ruby
  describe "starting units" do
    it "name a known power, unit type, province and, where given, a coast the province has" do
      powers = raw["powers"].map { |p| p["id"] }
      provinces = raw["provinces"].to_h { |p| [p["id"], p["coasts"] || []] }
      raw["starting_units"].each do |unit|
        expect(powers).to include(unit["power"])
        expect(%w[army fleet]).to include(unit["type"])
        expect(provinces.keys).to include(unit["province"])
        expect(provinces[unit["province"]]).to include(unit["coast"]) if unit["coast"]
      end
    end
  end
```

Add to `map_spec.rb`:

```ruby
  describe "#starting_units (internal)" do
    let(:units) { map.starting_units }

    it "returns 22 frozen entries sorted by province, each with a power, a type and a location" do
      expect(units.size).to eq(22)
      expect(units).to be_frozen
      expect(units).to all(be_frozen)
      expect(units.map(&:keys).uniq).to eq([%i[power type location]])
      expect(units.map { |u| u[:location].province }).to eq(units.map { |u| u[:location].province }.sort)
      expect(units.map { |u| u[:location] }).to all(be_a(TA::Location))
    end

    it "gives each power its starting units" do
      by_power = units.group_by { |u| u[:power] }.transform_values do |list|
        list.map { |u| [u[:type], u[:location].province, u[:location].coast] }.sort_by { |_, p, _| p }
      end
      expect(by_power).to eq(
        austria: [[:army, :bud, nil], [:fleet, :tri, nil], [:army, :vie, nil]],
        england: [[:fleet, :edi, nil], [:fleet, :lon, nil], [:army, :lvp, nil]],
        france: [[:fleet, :bre, nil], [:army, :mar, nil], [:army, :par, nil]],
        germany: [[:army, :ber, nil], [:fleet, :kie, nil], [:army, :mun, nil]],
        italy: [[:fleet, :nap, nil], [:army, :rom, nil], [:army, :ven, nil]],
        russia: [[:army, :mos, nil], [:fleet, :sev, nil], [:fleet, :stp, :sc], [:army, :war, nil]],
        turkey: [[:fleet, :ank, nil], [:army, :con, nil], [:army, :smy, nil]]
      )
    end

    it "puts no two units in one province" do
      expect(units.map { |u| u[:location].province }.uniq.size).to eq(22)
    end

    it "puts each unit on a home center of its own power, one unit per home center" do
      map.powers.each do |power|
        provinces = units.select { |u| u[:power] == power.id }.map { |u| u[:location].province }
        expect(provinces.sort).to eq(map.home_centers(power.id))
      end
    end

    it "keeps armies off the sea, fleets out of inland provinces, and gives split-coast fleets a coast" do
      units.each do |unit|
        province = map.province(unit[:location].province)
        expect(province.type).not_to eq(:sea) if unit[:type] == :army
        expect(province.type).not_to eq(:inland) if unit[:type] == :fleet
        expect(unit[:location].coast.nil?).to eq(unit[:type] == :army || province.coasts.empty?)
      end
    end

    it "is not mentioned in the interface document, and starting_position is not built here" do
      expect(File.read(INTERFACE_DOC)).not_to include("starting_units")
    end
  end
```

Run `bundle exec rspec`. Expected failures: `NoMethodError: undefined method 'starting_units'`, and `NoMethodError` on `nil` for the raw `starting_units` key.

### Step 4.2: Add the data and the reader

Append to `classic.yml` by hand:

```yaml

starting_units:
  - { power: "austria", type: "army", province: "bud" }
  - { power: "austria", type: "army", province: "vie" }
  - { power: "austria", type: "fleet", province: "tri" }
  - { power: "england", type: "fleet", province: "edi" }
  - { power: "england", type: "army", province: "lvp" }
  - { power: "england", type: "fleet", province: "lon" }
  - { power: "france", type: "fleet", province: "bre" }
  - { power: "france", type: "army", province: "mar" }
  - { power: "france", type: "army", province: "par" }
  - { power: "germany", type: "army", province: "ber" }
  - { power: "germany", type: "fleet", province: "kie" }
  - { power: "germany", type: "army", province: "mun" }
  - { power: "italy", type: "fleet", province: "nap" }
  - { power: "italy", type: "army", province: "rom" }
  - { power: "italy", type: "army", province: "ven" }
  - { power: "russia", type: "army", province: "mos" }
  - { power: "russia", type: "fleet", province: "sev" }
  - { power: "russia", type: "fleet", province: "stp", coast: "sc" }
  - { power: "russia", type: "army", province: "war" }
  - { power: "turkey", type: "fleet", province: "ank" }
  - { power: "turkey", type: "army", province: "con" }
  - { power: "turkey", type: "army", province: "smy" }
```

Edit `map.rb` in four places.

1. In `from_file`, build the raw entries (plain symbols, no `Location` yet) and pass them to `new`. Add this before the `new(` call, and add `starting_units: starting_units` to the keyword arguments of `new`:

```ruby
          starting_units = raw["starting_units"].map do |u|
            { power: u["power"].to_sym, type: u["type"].to_sym,
              province: u["province"].to_sym, coast: u["coast"]&.to_sym }.freeze
          end.sort_by { |u| u[:province] }.freeze
```

2. In `initialize`, change the signature to `def initialize(id:, powers:, provinces:, armies:, fleets:, starting_units:)` and add `@starting_units = starting_units` before `freeze`.

3. Add the reader as a public method, above the `private` keyword:

```ruby
      # Internal: not part of docs/interface.md, and may change in any release.
      # The units a game starts with, for Map#starting_position (issue #10).
      # Each entry is a frozen Hash with :power, :type and :location (a TA::Location).
      # Built on each call so that no Location is made while the map is loading.
      def starting_units
        @starting_units.map do |u|
          { power: u[:power], type: u[:type],
            location: Location.new(province: u[:province], coast: u[:coast]) }.freeze
        end.freeze
      end
```

4. Nothing else changes. `@classic = from_file(DATA_PATH)` stays the last statement of the class body.

### Step 4.3: Run to green, then commit

`bundle exec rspec`. Expected: 0 failures. Commit: "Store the 1901 starting units in the map data and read them back".

---

## Phase 5: Changelog, final verification

**Implements:** FR-7 | **Satisfies:** AC-7.1, AC-7.2, AC-1.9
**Files:** `CHANGELOG.md`

### Step 5.1: The changelog entry

First merge `main`, so that another worker's line is already there: `git fetch origin`, then `git merge origin/main` (a merge, never a rebase). Then add this line under "Unreleased" → "Added", after the existing entries:

```markdown
- The classic map as a data file, `data/maps/classic.yml` (75 provinces, 34 supply centers, 22 home centers, army and fleet adjacency with split coasts, and the 1901 starting units), with `TA::Map.classic` and its queries, `TA::Location` and `TA::InvalidInput`. `Map#starting_position` arrives with #10; until then the starting units are available through an internal reader. (#9)
```

Commit: "Record the classic map in the changelog".

### Step 5.2: Full verification

From `adjudicator/`:

| Check | Expected |
|---|---|
| `bundle exec rspec` | `0 failures`, and no warnings from the code under test |
| `bundle exec rake` | the same run, exit code 0 |
| Counts (command below) | `[75, {sea: 19, coastal: 42, inland: 14}, 34, 22]` (`tally` keeps first-seen order) |
| Packaging (commands below) | `data/maps/classic.yml` is listed; delete the built `.gem` afterwards |
| Naming (command below) | no output |
| Scope (command below) | only paths beginning `adjudicator/` |
| Interface untouched (command below) | empty |

```sh
bundle exec ruby -Ilib -rtrucebearer/adjudicator -e '
  m = Trucebearer::Adjudicator::Map.classic
  p [m.provinces.size, m.provinces.map(&:type).tally, m.supply_centers.size,
     m.powers.sum { |x| m.home_centers(x.id).size }]'

gem build trucebearer-adjudicator.gemspec
tar -xOf trucebearer-adjudicator-0.0.0.gem data.tar.gz | tar -tz | grep classic
rm trucebearer-adjudicator-0.0.0.gem

# The bracketed first letters keep the pattern from matching this plan's own text.
grep -rniE '[d]iplo|\b[d]ip' lib spec data docs/specs/009-classic-map CHANGELOG.md

git diff --stat origin/main...HEAD
git diff origin/main...HEAD -- docs/interface.md
```

Map every acceptance criterion to its example in `map_spec.rb`, `map_data_spec.rb`, `location_spec.rb` or `errors_spec.rb`. The implementation review reads this table first.

## Spec coverage

| Spec item | Phase |
|---|---|
| FR-1 data file (provinces, powers) | 1 |
| FR-1 adjacency | 3 |
| FR-1 starting units | 4 |
| FR-2 loader | 1 (tables extended in 3 and 4) |
| FR-3 queries | 1, and 3 for `adjacent?` |
| FR-4 `TA::Location` | 2 |
| FR-5 `TA::InvalidInput` | 1 (class and spec), used from 1 on |
| FR-6 starting-units reader | 4 |
| FR-7 packaging and changelog | 1 (packaging spec), 5 |
| AC-1.1 to AC-1.9 | 1 |
| AC-2.1 to AC-2.10 | 3 |
| AC-3.1 to AC-3.8 | 2 |
| AC-4.1 to AC-4.4 | 4 |
| AC-5.1 | 1, 3, 4 (each adds its part to the identifier check) |
| AC-5.2 to AC-5.4 | 3 |
| AC-5.5 | 4 |
| AC-5.6 | review (the loader reads the file with `YAML.safe_load_file`) |
| AC-6.1 to AC-6.3 | 1 |
| AC-7.1, AC-7.2 | 5 |
