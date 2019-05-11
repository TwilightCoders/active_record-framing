[![License     ](https://img.shields.io/github/license/TwilightCoders/active_record-framing.svg)]()
[![Version     ](https://img.shields.io/gem/v/active_record-framing.svg)](https://rubygems.org/gems/active_record-framing)
[![Build Status](https://travis-ci.org/TwilightCoders/active_record-framing.svg)](https://travis-ci.org/TwilightCoders/active_record-framing)
[![Maintenence ](https://api.codeclimate.com/v1/badges/762cdcd63990efa768b0/maintainability)](https://codeclimate.com/github/TwilightCoders/active_record-framing/maintainability)
[![Coverage    ](https://codeclimate.com/github/TwilightCoders/active_record-framing/badges/coverage.svg)](https://codeclimate.com/github/TwilightCoders/active_record-framing/coverage)

# ActiveRecord::Framing

Works similar to `scopes`. Rather than modifying the where clause of the `ActiveRecord::Relation`, it creates a common table expression (CTE) to be applied upon execution.

Unlike scopes, they do not affect the values of attributes upon creation.

## Requirements

- Ruby 2.3+
- ActiveRecord 4.2+

_Note: Check the builds to be sure your version is in-fact supported. The requirements are left unbounded on the upper constraint for posterity, but may not be gaurenteed to work._

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'active_record-framing'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install active_record-framing

## Usage

Any `ActiveRecord::Base` descendant has access to two additional methods: `frame` and `default_frame`.

```ruby
class User < ActiveRecord::Base
  default_frame { where(active: true) }
  # ...
end
```
Afterwards, `User.all.to_sql` yields
```sql
WITH "users" AS
  (SELECT "users".* FROM "users" WHERE "users"."active" = true)
SELECT "users".* FROM "users"
```

```ruby
class Admin < User
  default_frame { where(arel_table[:kind].eq(1)) }
  # ...
end
```

Note: In `ActiveRecord` versions less than `5.2` (Arel `9.0`), `default_frames` where clauses must be constructed with `arel` (`arel_table[:column]` etc) for values other than `nil`, `true`, and `false`. This is due to a limitation with what ActiveRecord calls "bind values" (beyond the scope of this document).

Afterwards, `Admin.all.to_sql` yields
```sql
WITH "users" AS
  (SELECT "users".* FROM "users" WHERE "users"."kind" = 1)
```

Similar to how `named_scopes` work in `ActiveRecord`, frames can be named:

```ruby
class User < ActiveRecord::Base
  frame :admin, -> { where(arel_table[:kind].eq(1)) }
  # ...
end
```

Named frames are accessed through assigned consts under the original class. This helps avoid collision with scopes, and helps indicate the mutual exclusivity of frames (by design).

```ruby
User::Admin.all.to_sql
# =>
# WITH "admin/users" AS
#   (SELECT "users".* FROM "users" WHERE "users".kind = 1)
# SELECT "admin/users".* FROM "admin/users"
```

## Development

After checking out the repo, run `bundle` to install dependencies. Then, run `bundle exec rspec` to run the tests.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/TwilightCoders/active_record-framing. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
