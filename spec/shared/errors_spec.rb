# frozen_string_literal: true

RSpec.describe Skywatch::Error do
  it 'is a StandardError' do
    expect(described_class.new).to be_a(StandardError)
  end
end

RSpec.describe Skywatch::ConnectionError do
  it 'is a Skywatch::Error' do
    expect(described_class.new).to be_a(Skywatch::Error)
  end
end

RSpec.describe Skywatch::ApiError do
  it 'is a Skywatch::Error' do
    expect(described_class.new).to be_a(Skywatch::Error)
  end

  it 'stores the response' do
    error = described_class.new('bad', response: { status: 500 })
    expect(error.response).to eq({ status: 500 })
  end
end

RSpec.describe Skywatch::ParseError do
  it 'is a Skywatch::Error' do
    expect(described_class.new).to be_a(Skywatch::Error)
  end
end
