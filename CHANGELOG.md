# ActiveRecord::Framing

## 0.2.0 _(June 27, 2026)_
- Support `activerecord` 5.1 through 8.x (Rails 6.1 / 7.0 / 7.1 / 7.2 / 8.0) and Ruby 3.x.
- Replace the internal `ModelProxy` (a `SimpleDelegator` wrapping the model) with
  real-class framing: relations keep the real model as `klass`/`model`, and framed
  tables flow through the relation's table and `current_frame`. Fixes `is_a?`/identity
  checks that broke under ActiveRecord 7.2+.
- Track ActiveRecord internal renames across the supported range: the `@klass` → `@model`
  relation ivar (7.2), `assert_mutability!` → `assert_modifiable!` (7.2),
  `ActiveSupport::PerThreadRegistry` removal (7.2), and `TypeCaster::Map#types` → `klass`.
- Declare `railties` as a runtime dependency (required by the Railtie).
- Handles automatic creation of framed relations
  - has_many :users produces has_many :deleted_users etc

## 0.1.0 _(May 25, 2019)_
- Initial Release
