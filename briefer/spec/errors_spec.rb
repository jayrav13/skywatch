# frozen_string_literal: true

RSpec.describe Briefer::Error do
  it "is a StandardError" do
    expect(described_class.new).to be_a(StandardError)
  end
end

RSpec.describe Briefer::ConnectionError do
  it "is a Briefer::Error" do
    expect(described_class.new).to be_a(Briefer::Error)
  end
end

RSpec.describe Briefer::ApiError do
  it "is a Briefer::Error" do
    expect(described_class.new).to be_a(Briefer::Error)
  end

  it "stores the response" do
    error = described_class.new("bad", response: { status: 500 })
    expect(error.response).to eq({ status: 500 })
  end
end

RSpec.describe Briefer::ParseError do
  it "is a Briefer::Error" do
    expect(described_class.new).to be_a(Briefer::Error)
  end
end
