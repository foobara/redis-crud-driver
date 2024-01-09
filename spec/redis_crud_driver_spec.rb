RSpec.describe RedisCrudDriver do
  it "has a version number" do
    expect(RedisCrudDriver::Version::VERSION).to_not be_nil
  end
end
