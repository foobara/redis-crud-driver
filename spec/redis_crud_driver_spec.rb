require "base64"
require "foobara/spec_helpers/it_behaves_like_a_crud_driver"

RSpec.describe Foobara::RedisCrudDriver do
  after do
    Foobara.reset_alls
    described_class.reset_all
  end

  it_behaves_like_a_crud_driver

  let(:redis) { described_class.redis }
  let(:skip_setting_default_crud_driver) { false }
  let(:credentials) { nil }

  before do
    unless skip_setting_default_crud_driver
      Foobara::Persistence.default_crud_driver = described_class.new(credentials)
    end
  end

  describe ".redis" do
    let(:skip_setting_default_crud_driver) { true }

    def creds(redis)
      client = redis._client

      {
        host: client.host,
        port: client.port,
        db: client.db,
        username: client.username
      }
    end

    context "with no REDIS_URL env var" do
      stub_env_var("REDIS_URL", nil)

      it "raises" do
        expect {
          described_class.redis
        }.to raise_error(described_class::NoRedisUrlError)
      end
    end

    context "with REDIS_URL env var" do
      stub_env_var("REDIS_URL", "redis://localhost:6379/1")

      it "defaults to Redis.new" do
        expect(creds(described_class.redis)).to eq(
          host: "localhost",
          port: 6379,
          db: 1,
          username: "default"
        )
      end
    end
  end

  describe "#initialize" do
    let(:skip_setting_default_crud_driver) { true }

    let(:driver) { described_class.new(credentials) }

    let(:fake_redis) { Redis.new }
    let(:fake_client) { fake_redis._client }

    let(:username) { fake_client.username }
    let(:password) { fake_client.password }
    let(:host) { fake_client.host }
    let(:port) { fake_client.port }
    let(:db) { fake_client.db + 1 }

    stub_env_var("REDIS_URL", nil)

    context "when using nothing" do
      let(:credentials) { nil }

      it "raises" do
        expect {
          described_class.new(credentials)
        }.to raise_error(described_class::NoRedisUrlError)
      end
    end

    context "when using Redis instance" do
      let(:credentials) { fake_redis }

      it "uses the existing connection" do
        expect(driver.raw_connection).to be(credentials)
      end
    end

    context "when using url" do
      let(:credentials) do
        "redis://#{username}:#{password}@#{host}:#{port}/#{db}"
      end

      it "connects using the url" do
        expect(driver.raw_connection._client.db).to eq(db)
      end
    end

    context "when using hash" do
      let(:credentials) do
        {
          host:,
          port:,
          db:,
          username:,
          password:
        }
      end

      it "connects using the hash" do
        expect(driver.raw_connection._client.db).to eq(db)
      end
    end
  end
end
