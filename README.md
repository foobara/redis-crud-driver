# Foobara::RedisCrudDriver

`foobara-redis-crud-driver` is a Redis CRUD driver for Foobara.

## Installation

You can install the gem into an existing Foobara project by running `foob g redis-crud-driver`.

Or add `foobara-redis-crud-driver` to your Gemfile or .gemspec file and `bundle install`.

Or even just `gem install foobara-redis-crud-driver` if playing with it directly in the scripts.

## Usage

Set up the Redis CRUD driver:

```ruby
require "foobara/redis_crud_driver" 

driver = Foobara::RedisCrudDriver.new
Foobara::Persistence.default_crud_driver = driver 
```

### Things to know

- **Key prefix** `key_prefix:` This will automatically prefix all keys this crud driver uses with the indicated prefix.

### Choosing how to connect

The first argument to `Foobara::RedisCrudDriver.new` can be any of these:

- **A Redis URL**.

- An existing `Redis` client.

- **A credentials hash**, which is anything `Redis.new` accepts could look like so:

```ruby
require "foobara/redis_crud_driver" 

driver = Foobara::RedisCrudDriver.new(
  { host: "localhost", port: 6379, db: 0, username: "default", password: "your-password" },
  key_prefix: "myapp"
)
Foobara::Persistence.default_crud_driver = driver
```

You can also leave the connection out. The driver then reads `ENV["REDIS_URL"]` itself.

## Contributing

Bug reports and pull requests are welcome at [github.com/foobara/redis-crud-driver](https://github.com/foobara/redis-crud-driver).

To work on an existing issue or submit a Pull Request:

1. Fork the repository and clone it to your local machine
2. Run `bundle install` to install dependencies
3. Start a Redis server and run `rake` to ensure that everything works as expected before making any changes
4. Implement your changes
5. Restart the Redis server and re-run `rake` to make sure that all tests and Rubocop pass
6. Commit your changes, push to GitHub and open a Pull Request for review

## License

This project is licensed under the MPL-2.0 license. Please see [LICENSE.txt](LICENSE.txt) for more information.
