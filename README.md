[![License     ](https://img.shields.io/github/license/TwilightCoders/active_record-framing.svg)]()
[![Version     ](https://img.shields.io/gem/v/active_record-framing.svg)](https://rubygems.org/gems/active_record-framing)
[![Build Status](https://travis-ci.org/TwilightCoders/active_record-framing.svg)](https://travis-ci.org/TwilightCoders/active_record-framing)
[![Maintenence ](https://api.codeclimate.com/v1/badges/762cdcd63990efa768b0/maintainability)](https://codeclimate.com/github/TwilightCoders/active_record-framing/maintainability)
[![Coverage    ](https://codeclimate.com/github/TwilightCoders/active_record-framing/badges/coverage.svg)](https://codeclimate.com/github/TwilightCoders/active_record-framing/coverage)
[![Dependencies](https://img.shields.io/librariesio/github/twilightcoders/active_record-framing.svg)](https://depfu.com/github/TwilightCoders/active_record-framing)

# ActiveRecord::Framing

Works similar to `scopes`. Rather than modifying the where clause of the `ActiveRecord::Relation`, it creates a common table expression (CTE) to be applied upon execution.

Unlike scopes, they do not affect the values of attributes upon creation.

## Requirements

- Ruby 2.3+
- ActiveRecord 4.2+

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
  default_frame('admins') { where(kind: 1) }
  # ...
end
```

Afterwards, `Admin.all.to_sql` yields
```sql
WITH "admins" AS
  (SELECT "users".* )
```

If you're starting with a brand-new table, the existing `timestamps` DSL has been extended to accept `deleted_at: true` as an option, for convenience. Or you can do it seperately as shown above.

```ruby
class CreatCommentsTable < ActiveRecord::Migration

  def change
    create_table :comments do |t|
      # ...
      #  to the `timestamps` DSL
      t.timestamps null: false, deleted_at: true
    end
  end

end
```

## Development

After checking out the repo, run `bundle` to install dependencies. Then, run `bundle exec rspec` to run the tests.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/TwilightCoders/active_record-framing. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
