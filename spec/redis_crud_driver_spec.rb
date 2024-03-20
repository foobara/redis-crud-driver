RSpec.describe Foobara::RedisCrudDriver do
  let(:entity_class) do
    stub_class("SomeEntity", Foobara::Entity) do
      attributes id: :integer,
                 foo: :integer,
                 bar: :symbol,
                 created_at: :datetime

      primary_key :id
    end
  end
  let(:skip_setting_default_crud_driver) { false }
  let(:credentials) { nil }

  after do
    Foobara.reset_alls
    described_class.reset_all
  end

  before do
    unless skip_setting_default_crud_driver
      Foobara::Persistence.default_crud_driver = described_class.new(credentials)
    end
  end

  it "has a version number" do
    expect(Foobara::RedisCrudDriverVersion::VERSION).to_not be_nil
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

  describe ".transaction" do
    it "can create, load, and update records" do
      expect {
        entity_class.create(foo: 1, bar: :baz)
      }.to raise_error(Foobara::Persistence::EntityBase::Transaction::NoCurrentTransactionError)

      transaction = nil

      entity1 = entity_class.transaction do |tx|
        transaction = tx

        entity = entity_class.create(foo: 1, bar: :baz)

        expect(entity).to be_a(entity_class)
        expect(entity).to_not be_persisted
        expect(entity).to_not be_loaded

        expect(tx).to be_open
        expect(Foobara::Persistence.current_transaction(entity)).to be(tx)

        entity
      end

      expect(transaction).to be_closed
      expect(Foobara::Persistence.current_transaction(entity1)).to be_nil

      expect(entity1).to be_a(entity_class)
      expect(entity1).to be_persisted
      expect(entity1).to be_loaded

      entity_class.transaction do
        entity = entity_class.thunk(entity1.primary_key)

        expect(entity).to be_a(entity_class)
        expect(entity).to be_persisted
        expect(entity).to_not be_loaded

        expect(entity.bar).to eq(:baz)

        expect(entity).to be_loaded

        singleton = entity_class.thunk(entity.primary_key)
        expect(singleton).to be(entity)

        entity.bar = "bazbaz"
      end

      entity_class.transaction do
        entity = Foobara::Persistence.current_transaction(entity_class).load(entity_class, entity1.primary_key)
        expect(entity.bar).to eq(:bazbaz)

        expect(entity_class.all.to_a).to eq([entity1])
      end
    end

    it "can rollback" do
      entity1 = entity_class.transaction do
        entity_class.create(foo: 10, bar: :baz)
      end

      entity_class.transaction do |tx|
        entity = entity_class.thunk(entity1.primary_key)
        expect(entity.foo).to eq(10)

        entity.foo = 20

        expect(entity.foo).to eq(20)

        begin
          tx.rollback!
        rescue Foobara::Persistence::EntityBase::Transaction::RolledBack # rubocop:disable Lint/SuppressedException
        end

        expect(entity.foo).to eq(10)

        entity_class.transaction do
          expect(entity_class.load(entity.primary_key).foo).to eq(10)
        end

        expect {
          entity.foo = 20
        }.to raise_error(Foobara::Persistence::EntityBase::Transaction::NoCurrentTransactionError)
      end

      entity_class.transaction do |tx|
        entity = entity_class.load(entity1.primary_key)
        entity = entity_class.load(entity.primary_key)
        expect(entity.foo).to eq(10)

        entity.foo = 20

        expect(entity.foo).to eq(20)

        tx.flush!

        expect(entity.foo).to eq(20)

        entity.foo = 30

        tx.revert!

        expect(entity.foo).to eq(20)
      end

      entity_class.transaction do
        entity = entity_class.load(entity1.primary_key)
        expect(entity.foo).to eq(20)
      end
    end

    it "can hard delete" do
      entity_class.transaction do
        expect(entity_class.all.to_a).to be_empty
        entity = entity_class.create(foo: 10, bar: :baz)
        expect(entity_class.all.to_a).to eq([entity])
        entity.hard_delete!
        expect(entity_class.all.to_a).to be_empty
      end

      entity1 = entity_class.transaction do
        expect(entity_class.all.to_a).to be_empty
        entity_class.create(foo: 10, bar: :baz)
      end

      entity_class.transaction do
        entity = entity_class.thunk(entity1.primary_key)
        expect(entity.foo).to eq(10)

        entity.hard_delete!

        expect(entity).to be_hard_deleted

        # TODO: make this work without needing to call #to_a
        expect(entity_class.all.to_a).to be_empty

        expect {
          entity.foo = 20
        }.to raise_error(Foobara::Entity::CannotUpdateHardDeletedRecordError)

        expect(entity.foo).to eq(10)

        entity.restore!
        expect(entity_class.all.to_a).to eq([entity])

        entity.foo = 20
      end

      entity_class.transaction do
        # TODO: make calling #to_a not necessary
        expect(entity_class.all.to_a).to eq([entity1])
        entity = entity_class.thunk(entity1.primary_key)

        expect(entity).to be_persisted
        expect(entity).to_not be_hard_deleted
        expect(entity.foo).to eq(20)

        entity.hard_delete!

        expect(entity_class.all.to_a).to be_empty
        expect(entity).to be_hard_deleted
      end

      entity_class.transaction do
        expect {
          entity_class.load(entity1.primary_key)
        }.to raise_error(Foobara::Entity::NotFoundError)

        expect(entity_class.all.to_a).to be_empty
      end
    end

    describe "#hard_delete_all" do
      it "deletes everything" do
        entities = []

        entity_class.transaction do
          4.times do
            entity = entity_class.create(foo: 1, bar: :baz)
            entities << entity
          end

          # TODO: make calling #to_a not necessary
          expect(entity_class.all.to_a).to eq(entities)
        end

        entity_ids = entities.map(&:primary_key)

        expect(entity_ids).to contain_exactly(1, 2, 3, 4)

        entity_class.transaction do
          entities = []

          entity_class.all do |record|
            entities << record
          end

          entity_ids = entities.map(&:primary_key)

          expect(entity_ids).to contain_exactly(1, 2, 3, 4)

          4.times do
            entity = entity_class.create(foo: 1, bar: :baz)
            entities << entity
          end

          expect(entity_class.all).to match_array(entities)

          Foobara::Persistence.current_transaction(entities.first).hard_delete_all!(entity_class)

          expect(entities).to all be_hard_deleted
          expect(entity_class.all.to_a).to be_empty
        end

        entity_class.transaction do
          expect(entity_class.all.to_a).to be_empty
        end
      end
    end

    describe "#truncate" do
      it "deletes everything" do
        entity_class.transaction do
          4.times do
            entity_class.create(foo: 1, bar: :baz)
          end

          # TODO: make calling #to_a not necessary
          expect(entity_class.count).to eq(4)
        end

        entity_class.transaction do
          expect(entity_class.count).to eq(4)

          Foobara::Persistence.current_transaction(entity_class).truncate!

          expect(entity_class.count).to eq(0)
          expect(entity_class.all.to_a).to be_empty
        end

        entity_class.transaction do
          expect(entity_class.count).to eq(0)
          expect(entity_class.all.to_a).to be_empty
        end
      end
    end

    describe "#load_many" do
      it "loads many" do
        entities = nil
        entity_ids = nil

        entity_class.transaction do |tx|
          [
            { foo: 11, bar: :baz },
            { foo: 22, bar: :baz },
            { foo: 33, bar: :baz },
            { foo: 44, bar: :baz }
          ].map do |attributes|
            entity_class.create(attributes)
          end

          expect(entity_class.count).to eq(4)

          entity_class.transaction(mode: :use_existing) do
            expect(entity_class.count).to eq(4)
          end

          tx2 = entity_class.transaction(mode: :use_existing)

          entity_class.entity_base.using_transaction(tx2) do
            expect(entity_class.count).to eq(4)
          end

          entity_class.transaction(mode: :open_nested) do
            expect(entity_class.count).to eq(0)
          end

          tx.flush!

          entity_class.transaction(mode: :use_existing) do
            expect(entity_class.count).to eq(4)
          end

          entity_class.transaction(mode: :open_nested) do
            expect(entity_class.count).to eq(4)
          end

          entities = entity_class.all

          expect(entities).to all be_a(Foobara::Entity)
          expect(entities.size).to eq(4)

          entity_ids = entities.map(&:primary_key)
          expect(entity_ids).to contain_exactly(1, 2, 3, 4)
        end

        entity_class.transaction do
          entity_class.load_many([entity_class.thunk(1)])
          loaded_entities = entity_class.load_many(entity_ids)
          expect(loaded_entities).to all be_loaded
          expect(loaded_entities).to eq(entities)
        end
      end
    end

    describe "#all_exist?" do
      it "answers whether they all exist or not" do
        entity_class.transaction do
          expect(entity_class.all_exist?([101, 102])).to be(false)

          [
            { foo: 11, bar: :baz, id: 101 },
            { foo: 22, bar: :baz, id: 102 },
            { foo: 33, bar: :baz },
            { foo: 44, bar: :baz }
          ].map do |attributes|
            entity_class.create(attributes)
          end

          entity_class.all do |record|
            expect(record).to_not be_persisted
          end

          expect(entity_class.all_exist?([101, 102])).to be(true)
          expect(entity_class.all_exist?([1, 2, 101, 102])).to be(false)
        end

        entity_class.transaction do
          expect(entity_class.all_exist?([1, 2, 101, 102])).to be(true)
          expect(entity_class.all_exist?([3])).to be(false)
        end
      end
    end

    describe "#unhard_delete!" do
      context "when record was dirty when hard deleted" do
        it "is still dirty" do
          entity = entity_class.transaction do
            entity_class.create(foo: 11, bar: :baz)
          end

          entity_class.transaction do
            entity = entity_class.thunk(entity.primary_key)

            expect(entity).to be_persisted

            expect(entity).to_not be_dirty

            entity.foo = 12

            expect(entity).to be_dirty
            expect(entity).to_not be_hard_deleted

            entity.foo = 11

            expect(entity).to_not be_dirty
            expect(entity).to_not be_hard_deleted

            entity.foo = 12

            expect(entity).to be_dirty
            expect(entity).to_not be_hard_deleted

            entity.hard_delete!

            expect(entity).to be_dirty
            expect(entity).to be_hard_deleted

            entity.unhard_delete!

            expect(entity).to be_dirty
            expect(entity).to_not be_hard_deleted
          end
        end
      end
    end

    describe "#exists?" do
      it "answers it exists or not" do
        entity_class.transaction do
          expect(entity_class.all_exist?([101, 102])).to be(false)

          entity_class.create(foo: 11, bar: :baz, id: 101)

          expect(entity_class.exists?(101)).to be(true)

          entity_class.create(foo: 11, bar: :baz)

          expect(entity_class.exists?(1)).to be(false)
        end

        entity_class.transaction do
          expect(entity_class.exists?(101)).to be(true)

          expect(entity_class.exists?(1)).to be(true)
          expect(entity_class.exists?(2)).to be(false)
        end
      end
    end

    context "when creating a record with an already-in-use key" do
      it "explodes" do
        entity_class.transaction do
          entity_class.create(foo: 11, bar: :baz, id: 101)
        end

        expect {
          entity_class.transaction do
            entity_class.create(foo: 11, bar: :baz, id: 101)
          end
        }.to raise_error(Foobara::Persistence::EntityAttributesCrudDriver::Table::CannotInsertError)
      end
    end

    context "when restoring with a created record" do
      it "hard deletes it" do
        entity_class.transaction do |tx|
          record = entity_class.create(foo: 11, bar: :baz, id: 101)

          tx.revert!

          expect(record).to be_hard_deleted
        end

        entity_class.transaction do
          expect(entity_class.count).to eq(0)
        end
      end
    end

    context "when persisting entity with an association" do
      let(:aggregate_class) do
        entity_class
        some_model_class

        stub_class "SomeAggregate", Foobara::Entity do
          attributes do
            id :integer
            foo :integer
            some_model SomeModel, :required
            some_entities [SomeEntity]
          end

          primary_key :id
        end
      end

      let(:some_model_class) do
        some_other_entity_class

        stub_class "SomeModel", Foobara::Model do
          attributes do
            some_other_entity SomeOtherEntity, :required
          end
        end
      end

      let(:some_other_entity_class) do
        stub_class "SomeOtherEntity", Foobara::Entity do
          attributes do
            id :integer
            foo :integer, :required
          end

          primary_key :id
        end
      end

      it "writes the records to disk using primary keys" do
        some_entity2 = nil

        some_entity1 = aggregate_class.transaction do
          some_entity2 = entity_class.create(foo: 11, bar: :baz, created_at: Time.now)
          entity_class.create(foo: 11, bar: :baz, id: 101)
        end

        some_other_entity = nil

        entity_class.transaction do
          some_entity3 = entity_class.create(foo: 11, bar: :baz, id: 102)
          some_entity4 = entity_class.create(foo: 11, bar: :baz)
          some_other_entity = SomeOtherEntity.create(foo: 11)

          some_model = SomeModel.new(some_other_entity:)

          aggregate_class.create(
            foo: 30,
            some_model:,
            some_entities: [
              1,
              some_entity1,
              some_entity3,
              some_entity4
            ]
          )
        end

        entity_class.transaction do
          crud_table = aggregate_class.current_transaction_table.entity_attributes_crud_driver_table
          raw_records = crud_table.all.to_a
          expect(raw_records.size).to eq(1)
          raw_record = raw_records.first
          expect(raw_record[:some_entities]).to contain_exactly(1, 2, 101, 102)
          expect(raw_record[:some_model]["some_other_entity"]).to eq(some_other_entity.id)

          loaded_aggregate = aggregate_class.load(1)
          expect(loaded_aggregate.some_entities).to all be_a(SomeEntity)
          expect(loaded_aggregate.some_entities.map(&:primary_key)).to contain_exactly(1, 2, 101, 102)

          new_aggregate = aggregate_class.create(
            foo: "30",
            some_entities: [
              entity_class.create(foo: 11, bar: :baz)
            ],
            some_model: {
              some_other_entity: {
                foo: 10
              }
            }
          )

          expect(new_aggregate.some_model.some_other_entity.foo).to eq(10)

          expect(aggregate_class.contains_associations?).to be(true)
          expect(entity_class.contains_associations?).to be(false)
        end
      end
    end
  end
end
